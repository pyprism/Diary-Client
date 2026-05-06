import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../../../core/constants/app_constants.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/content_utils.dart';
import '../../image_upload/data/image_upload_repository.dart';
import '../domain/models/diary_entry.dart';
import 'diary_local_ds.dart';
import 'diary_remote_ds.dart';

class DiaryRepository {
  final DiaryLocalDataSource _local;
  final DiaryRemoteDataSource _remote;
  final ConnectivityService _connectivity;
  final AppDatabase _db;
  final ImageUploadRepository _imageUpload;

  DiaryRepository(
    this._local,
    this._remote,
    this._connectivity,
    this._db,
    this._imageUpload,
  );

  Stream<List<DiaryEntry>> watchAll() => _local.watchAll();

  Future<List<DiaryEntry>> getAll() => _local.getAll();

  Stream<DiaryEntry?> watchById(int localId) => _local.watchByLocalId(localId);

  Future<DiaryEntry?> getById(int localId) => _local.getByLocalId(localId);

  Future<List<DiaryEntry>> searchDiaries(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    if (!await _connectivity.isOnline) {
      return _searchLocal(q);
    }

    try {
      final results = <DiaryEntry>[];
      final seenLocalIds = <int>{};

      var page = 1;
      while (true) {
        final remoteList = await _remote.listDiaries(
          page: page,
          search: q,
          ordering: '-date',
        );
        if (remoteList.isEmpty) break;

        for (final item in remoteList) {
          if (item.remoteId == null) continue;

          var local = await _local.getByRemoteId(item.remoteId!);
          if (local == null) {
            final localId = await _local.insert(
              DiaryEntry(
                remoteId: item.remoteId,
                title: item.title,
                date: item.date,
                postType: item.postType,
                content: DiaryContent.empty(),
                syncStatus: 'synced',
              ),
              const [],
            );
            local = await _local.getByLocalId(localId);
          } else if (local.syncStatus != 'pending') {
            await _local.update(
              local.copyWith(
                title: item.title,
                date: item.date,
                postType: item.postType,
                syncStatus: 'synced',
              ),
              await _resolveTagIdsByName(
                local.tags.map((tag) => tag.name).toList(),
              ),
            );
            local = await _local.getByLocalId(local.localId!);
          }

          final localId = local?.localId;
          if (local != null && localId != null && seenLocalIds.add(localId)) {
            results.add(local);
          }
        }

        if (remoteList.length < AppConstants.defaultPageSize) break;
        page++;
      }

      // Include unsynced local entries that server cannot know about yet.
      final localMatches = await _searchLocal(q);
      for (final local in localMatches) {
        final localId = local.localId;
        if (localId != null && seenLocalIds.add(localId)) {
          results.add(local);
        }
      }

      return results;
    } catch (_) {
      return _searchLocal(q);
    }
  }

  /// Fetch from remote and sync to local
  Future<void> syncFromRemote() async {
    if (!await _connectivity.isOnline) return;
    try {
      var page = 1;
      while (true) {
        final remoteList = await _remote.listDiaries(
          page: page,
          ordering: '-date',
        );
        if (remoteList.isEmpty) break;

        for (final item in remoteList) {
          if (item.remoteId == null) continue;
          final existing = await _local.getByRemoteId(item.remoteId!);
          final full = await _remote.getDiary(item.remoteId!);
          final tagLocalIds = await _resolveTagIds(full.tags);

          if (existing == null) {
            await _local.insert(
              full.copyWith(syncStatus: 'synced'),
              tagLocalIds,
            );
          } else if (existing.syncStatus != 'pending') {
            await _local.update(
              full.copyWith(
                localId: existing.localId,
                remoteId: item.remoteId,
                syncStatus: 'synced',
              ),
              tagLocalIds,
            );
          }
        }

        if (remoteList.length < AppConstants.defaultPageSize) break;
        page++;
      }
    } catch (_) {}
  }

  Future<void> syncPendingDiaries() async {
    if (!await _connectivity.isOnline) return;

    await _syncQueuedDeletes();

    final pending = await _db.getPendingDiaries();
    for (final row in pending) {
      final local = await _local.getByLocalId(row.id);
      if (local == null) continue;

      final tagNames = local.tags.map((t) => t.name).toList();

      try {
        final content = await _prepareContentForSync(local);
        _throwIfInvalidForApi(content);
        final payload = <String, dynamic>{
          'title': local.title,
          'date': local.date,
          'post_type': local.postType.value,
          'content': content.toJson(),
          'tags_attach': tagNames,
        };

        if (local.remoteId == null) {
          final created = await _remote.createDiary(payload);
          final tagLocalIds = await _resolveTagIdsByName(tagNames);
          await _local.update(
            local.copyWith(remoteId: created.remoteId, syncStatus: 'synced'),
            tagLocalIds,
          );
        } else {
          await _remote.updateDiary(local.remoteId!, payload);
          final tagLocalIds = await _resolveTagIdsByName(tagNames);
          await _local.update(
            local.copyWith(syncStatus: 'synced'),
            tagLocalIds,
          );
        }
      } catch (_) {
        // Keep pending; scheduler will retry on the next tick.
      }
    }
  }

  Future<DiaryEntry> createDiary({
    required String title,
    required String date,
    required PostType postType,
    required DiaryContent content,
    required List<String> tagNames,
  }) async {
    // Resolve local tag IDs
    final tagLocalIds = await _resolveTagIdsByName(tagNames);

    final entry = DiaryEntry(
      title: title,
      date: date,
      postType: postType,
      content: content,
      syncStatus: 'pending',
    );
    final localId = await _local.insert(entry, tagLocalIds);
    final createdLocal = (await _local.getByLocalId(localId))!;

    // Try sync immediately
    if (await _connectivity.isOnline) {
      try {
        final syncedContent = await _imageUpload.uploadEmbeddedImages(content);
        _throwIfInvalidForApi(syncedContent);
        final remote = await _remote.createDiary({
          'title': title,
          'date': date,
          'post_type': postType.value,
          'content': syncedContent.toJson(),
          'tags_attach': tagNames,
        });
        await _local.update(
          createdLocal.copyWith(
            remoteId: remote.remoteId,
            content: syncedContent,
            syncStatus: 'synced',
          ),
          tagLocalIds,
        );
        return (await _local.getByLocalId(localId))!;
      } catch (_) {}
    }
    return createdLocal;
  }

  Future<DiaryEntry> updateDiary({
    required int localId,
    required String title,
    required String date,
    required PostType postType,
    required DiaryContent content,
    required List<String> tagNames,
  }) async {
    final existing = await _local.getByLocalId(localId);
    if (existing == null) throw Exception('Diary not found');

    final tagLocalIds = await _resolveTagIdsByName(tagNames);
    final updated = existing.copyWith(
      title: title,
      date: date,
      postType: postType,
      content: content,
      syncStatus: 'pending',
    );
    await _local.update(updated, tagLocalIds);
    if (content.toJsonString() != existing.content.toJsonString()) {
      await _db.deleteAnalysis(localId);
    }

    if (await _connectivity.isOnline && existing.remoteId != null) {
      try {
        final syncedContent = await _imageUpload.uploadEmbeddedImages(content);
        _throwIfInvalidForApi(syncedContent);
        await _remote.updateDiary(existing.remoteId!, {
          'title': title,
          'date': date,
          'post_type': postType.value,
          'content': syncedContent.toJson(),
          'tags_attach': tagNames,
        });
        await _local.update(
          updated.copyWith(content: syncedContent, syncStatus: 'synced'),
          tagLocalIds,
        );
      } catch (_) {}
    }
    return (await _local.getByLocalId(localId))!;
  }

  Future<void> deleteDiary(int localId) async {
    final existing = await _local.getByLocalId(localId);
    if (existing == null) return;

    var deletedRemotely = existing.remoteId == null;
    if (await _connectivity.isOnline && existing.remoteId != null) {
      try {
        await _remote.deleteDiary(existing.remoteId!);
        deletedRemotely = true;
      } catch (_) {}
    }
    if (!deletedRemotely && existing.remoteId != null) {
      await _db.enqueueSync(
        SyncQueueCompanion.insert(
          entityType: 'diary',
          entityLocalId: existing.remoteId!,
          operation: 'delete',
          payloadJson: drift.Value(jsonEncode({'remoteId': existing.remoteId})),
        ),
      );
    }
    await _local.delete(localId);
  }

  Future<void> _syncQueuedDeletes() async {
    final queued = await _db.getQueuedSync(
      entityType: 'diary',
      operation: 'delete',
    );
    for (final item in queued) {
      final payload = _decodeQueuePayload(item.payloadJson);
      final remoteId = payload['remoteId'] as int? ?? item.entityLocalId;
      try {
        await _remote.deleteDiary(remoteId);
        await _db.deleteQueuedSync(item.id);
      } catch (_) {
        await _db.incrementQueuedSyncRetry(item.id);
      }
    }
  }

  Future<DiaryEntry?> getFullEntry(int localId) async {
    final local = await _local.getByLocalId(localId);
    if (local == null) return null;

    // Fetch from remote if online and content is empty
    if (local.remoteId != null &&
        local.content.isEmpty &&
        await _connectivity.isOnline) {
      try {
        final remote = await _remote.getDiary(local.remoteId!);
        final tagLocalIds = await _resolveTagIds(remote.tags);
        final merged = local.copyWith(
          content: remote.content,
          syncStatus: 'synced',
        );
        await _local.update(merged, tagLocalIds);
        return await _local.getByLocalId(localId);
      } catch (_) {}
    }
    return local;
  }

  Future<List<int>> _resolveTagIds(List<DiaryTag> diaryTags) async {
    final ids = <int>[];
    for (final tag in diaryTags) {
      var local = await _db.getTagByRemoteId(tag.id);
      local ??= await _db.getTagByName(tag.name);
      if (local == null) {
        final id = await _db.insertTag(
          TagsCompanion.insert(
            remoteId: drift.Value(tag.id),
            name: tag.name,
            syncStatus: const drift.Value('synced'),
          ),
        );
        ids.add(id);
      } else {
        if (local.remoteId == null ||
            local.name != tag.name ||
            local.syncStatus != 'pending') {
          await _db.updateTag(
            TagsCompanion(
              id: drift.Value(local.id),
              remoteId: drift.Value(tag.id),
              name: drift.Value(tag.name),
              syncStatus: const drift.Value('synced'),
            ),
          );
        }
        ids.add(local.id);
      }
    }
    return ids;
  }

  Future<List<int>> _resolveTagIdsByName(List<String> names) async {
    final ids = <int>[];
    for (final name in names) {
      final local = await _db.getTagByName(name);
      if (local != null) ids.add(local.id);
    }
    return ids;
  }

  Future<DiaryContent> _prepareContentForSync(DiaryEntry local) async {
    final content = await _imageUpload.uploadEmbeddedImages(local.content);
    if (content.toJsonString() != local.content.toJsonString()) {
      final tagLocalIds = await _resolveTagIdsByName(
        local.tags.map((tag) => tag.name).toList(),
      );
      await _local.update(local.copyWith(content: content), tagLocalIds);
    }
    return content;
  }

  void _throwIfInvalidForApi(DiaryContent content) {
    final error = content.validateForApi();
    if (error != null) throw FormatException(error);
  }

  Map<String, dynamic> _decodeQueuePayload(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) return const {};
    final decoded = jsonDecode(payloadJson);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  Future<List<DiaryEntry>> _searchLocal(String query) async {
    final q = query.toLowerCase();
    final local = await _local.getAll();
    return local.where((entry) {
      final inTitle = entry.title.toLowerCase().contains(q);
      final inPostType = entry.postType.value.toLowerCase().contains(q);
      final inTags = entry.tags.any((t) => t.name.toLowerCase().contains(q));
      final inContent = entry.content.plainText.toLowerCase().contains(q);
      return inTitle || inPostType || inTags || inContent;
    }).toList();
  }
}
