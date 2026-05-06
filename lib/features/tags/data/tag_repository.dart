import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/server_config.dart';
import '../../../../core/storage/app_database.dart';
import '../domain/models/tag.dart';

class TagRepository {
  final AppDatabase _db;
  final DioClient _client;
  final ServerConfig _config;
  final ConnectivityService _connectivity;

  TagRepository(this._db, this._client, this._config, this._connectivity);

  String get _base => _config.endpoint('tags');

  Stream<List<Tag>> watchAll() => _db.watchAllTags().map(
    (list) => list
        .map((t) => Tag(localId: t.id, remoteId: t.remoteId, name: t.name))
        .toList(),
  );

  Future<Tag?> getByLocalId(int localId) async {
    final row = await _db.getTagById(localId);
    if (row == null) return null;
    return Tag(localId: row.id, remoteId: row.remoteId, name: row.name);
  }

  Future<List<TagEntrySummary>> listEntriesForTag(int tagLocalId) async {
    final tag = await getByLocalId(tagLocalId);
    if (tag == null) return const [];

    if (await _connectivity.isOnline && tag.remoteId != null) {
      try {
        final res = await _client.dio.get(
          _config.endpoint('tags/${tag.remoteId}/entries'),
        );
        final entries = (res.data['entries'] as List? ?? [])
            .map((e) => TagEntrySummary.fromJson(e as Map<String, dynamic>))
            .toList();

        return Future.wait(
          entries.map((entry) async {
            if (entry.remoteId == null) return entry;
            final local = await _db.getDiaryByRemoteId(entry.remoteId!);
            return entry.copyWith(localId: local?.id);
          }),
        );
      } catch (_) {}
    }

    return _listLocalEntriesForTag(tagLocalId);
  }

  Future<List<TagEntrySummary>> _listLocalEntriesForTag(int tagLocalId) async {
    final rows = await _db.getDiariesForTag(tagLocalId);
    return rows
        .map(
          (entry) => TagEntrySummary(
            localId: entry.id,
            remoteId: entry.remoteId,
            title: entry.title,
          ),
        )
        .toList();
  }

  Future<void> syncFromRemote() async {
    if (!await _connectivity.isOnline) return;
    try {
      var page = 1;
      while (true) {
        final res = await _client.dio.get(
          _base,
          queryParameters: {'page': page},
        );
        final results = res.data['results'] as List? ?? [];
        if (results.isEmpty) break;

        for (final item in results) {
          final remoteId = item['id'] as int;
          final name = item['name'] as String;
          var existing = await _db.getTagByRemoteId(remoteId);
          existing ??= await _db.getTagByName(name);

          if (existing == null) {
            await _db.insertTag(
              TagsCompanion.insert(
                remoteId: drift.Value(remoteId),
                name: name,
                syncStatus: const drift.Value('synced'),
              ),
            );
          } else if (existing.syncStatus != 'pending' ||
              existing.remoteId == null) {
            await _db.updateTag(
              TagsCompanion(
                id: drift.Value(existing.id),
                remoteId: drift.Value(remoteId),
                name: drift.Value(name),
                syncStatus: const drift.Value('synced'),
              ),
            );
          }
        }

        if (results.length < AppConstants.defaultPageSize) break;
        page++;
      }
    } catch (_) {}
  }

  Future<void> syncPendingTags() async {
    if (!await _connectivity.isOnline) return;

    await _syncQueuedDeletes();

    final pending = await _db.getPendingTags();
    for (final tag in pending) {
      try {
        if (tag.remoteId == null) {
          final res = await _client.dio.post(_base, data: {'name': tag.name});
          final remoteId = res.data['id'] as int;
          await _db.updateTag(
            TagsCompanion(
              id: drift.Value(tag.id),
              remoteId: drift.Value(remoteId),
              syncStatus: const drift.Value('synced'),
            ),
          );
        } else {
          await _client.dio.patch(
            _config.endpoint('tags/${tag.remoteId}'),
            data: {'name': tag.name},
          );
          await _db.updateTag(
            TagsCompanion(
              id: drift.Value(tag.id),
              syncStatus: const drift.Value('synced'),
            ),
          );
        }
      } catch (_) {
        await syncFromRemote();
        final remoteDuplicate = await _db.getTagByName(tag.name);
        if (remoteDuplicate != null && remoteDuplicate.remoteId != null) {
          await _db.updateTag(
            TagsCompanion(
              id: drift.Value(tag.id),
              remoteId: drift.Value(remoteDuplicate.remoteId),
              syncStatus: const drift.Value('synced'),
            ),
          );
        }
      }
    }
  }

  Future<Tag> createTag(String name) async {
    final existing = await _db.getTagByName(name);
    if (existing != null) {
      return Tag(
        localId: existing.id,
        remoteId: existing.remoteId,
        name: existing.name,
      );
    }

    final localId = await _db.insertTag(
      TagsCompanion.insert(
        name: name,
        syncStatus: const drift.Value('pending'),
      ),
    );
    if (await _connectivity.isOnline) {
      try {
        final res = await _client.dio.post(_base, data: {'name': name});
        final remoteId = res.data['id'] as int;
        await _db.updateTag(
          TagsCompanion(
            id: drift.Value(localId),
            remoteId: drift.Value(remoteId),
            syncStatus: const drift.Value('synced'),
          ),
        );
      } catch (_) {}
    }
    final local = await _db.getTagById(localId);
    return Tag(localId: local!.id, remoteId: local.remoteId, name: local.name);
  }

  Future<void> updateTag(int localId, String name) async {
    final local = await _db.getTagById(localId);
    if (local == null) return;
    final duplicate = await _db.getTagByName(name);
    if (duplicate != null && duplicate.id != localId) {
      return;
    }
    await _db.updateTag(
      TagsCompanion(
        id: drift.Value(localId),
        name: drift.Value(name),
        syncStatus: const drift.Value('pending'),
      ),
    );
    if (await _connectivity.isOnline && local.remoteId != null) {
      try {
        await _client.dio.patch(
          _config.endpoint('tags/${local.remoteId}'),
          data: {'name': name},
        );
        await _db.updateTag(
          TagsCompanion(
            id: drift.Value(localId),
            syncStatus: const drift.Value('synced'),
          ),
        );
      } catch (_) {}
    }
  }

  Future<void> deleteTag(int localId) async {
    final local = await _db.getTagById(localId);
    if (local == null) return;
    var deletedRemotely = local.remoteId == null;
    if (await _connectivity.isOnline && local.remoteId != null) {
      try {
        await _client.dio.delete(_config.endpoint('tags/${local.remoteId}'));
        deletedRemotely = true;
      } catch (_) {}
    }
    if (!deletedRemotely && local.remoteId != null) {
      await _db.enqueueSync(
        SyncQueueCompanion.insert(
          entityType: 'tag',
          entityLocalId: local.remoteId!,
          operation: 'delete',
          payloadJson: drift.Value(jsonEncode({'remoteId': local.remoteId})),
        ),
      );
    }
    await _db.deleteTag(localId);
  }

  Future<void> _syncQueuedDeletes() async {
    final queued = await _db.getQueuedSync(
      entityType: 'tag',
      operation: 'delete',
    );
    for (final item in queued) {
      final payload = _decodeQueuePayload(item.payloadJson);
      final remoteId = payload['remoteId'] as int? ?? item.entityLocalId;
      try {
        await _client.dio.delete(_config.endpoint('tags/$remoteId'));
        await _db.deleteQueuedSync(item.id);
      } catch (_) {
        await _db.incrementQueuedSyncRetry(item.id);
      }
    }
  }

  Map<String, dynamic> _decodeQueuePayload(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) return const {};
    final decoded = jsonDecode(payloadJson);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }
}
