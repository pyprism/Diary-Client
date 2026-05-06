import 'package:drift/drift.dart' as drift;
import '../../../core/storage/app_database.dart';
import '../../../core/utils/content_utils.dart';
import '../domain/models/diary_entry.dart';

class DiaryLocalDataSource {
  final AppDatabase _db;

  DiaryLocalDataSource(this._db);

  Stream<List<DiaryEntry>> watchAll() =>
      _db.watchAllDiaries().asyncMap(_mapList);

  Future<List<DiaryEntry>> getAll() async {
    final entries = await _db.getAllDiaries();
    return Future.wait(entries.map(_mapEntry));
  }

  Future<DiaryEntry?> getByLocalId(int id) async {
    final entry = await _db.getDiaryById(id);
    if (entry == null) return null;
    return _mapEntry(entry);
  }

  Future<DiaryEntry?> getByRemoteId(int remoteId) async {
    final entry = await _db.getDiaryByRemoteId(remoteId);
    if (entry == null) return null;
    return _mapEntry(entry);
  }

  Stream<DiaryEntry?> watchByLocalId(int id) =>
      _db.watchDiaryById(id).asyncMap((e) => e != null ? _mapEntry(e) : null);

  Future<int> insert(DiaryEntry entry, List<int> tagLocalIds) async {
    final id = await _db.insertDiary(
      DiaryEntriesCompanion.insert(
        remoteId: drift.Value(entry.remoteId),
        title: entry.title,
        date: entry.date,
        postType: drift.Value(entry.postType.value),
        contentJson: entry.content.toJsonString(),
        syncStatus: drift.Value(entry.syncStatus),
      ),
    );
    await _db.setTagsForDiary(id, tagLocalIds);
    return id;
  }

  Future<void> update(DiaryEntry entry, List<int> tagLocalIds) async {
    if (entry.localId == null) return;
    await _db.updateDiary(
      DiaryEntriesCompanion(
        id: drift.Value(entry.localId!),
        remoteId: drift.Value(entry.remoteId),
        title: drift.Value(entry.title),
        date: drift.Value(entry.date),
        postType: drift.Value(entry.postType.value),
        contentJson: drift.Value(entry.content.toJsonString()),
        syncStatus: drift.Value(entry.syncStatus),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
    await _db.setTagsForDiary(entry.localId!, tagLocalIds);
  }

  Future<void> delete(int localId) => _db.deleteDiary(localId);

  Future<List<DiaryEntry>> _mapList(List<DiaryEntryData> list) =>
      Future.wait(list.map(_mapEntry));

  Future<DiaryEntry> _mapEntry(DiaryEntryData e) async {
    final localTags = await _db.getTagsForDiary(e.id);
    final diaryTags = localTags
        .map((t) => DiaryTag(id: t.remoteId ?? t.id, name: t.name))
        .toList();
    return DiaryEntry(
      localId: e.id,
      remoteId: e.remoteId,
      title: e.title,
      date: e.date,
      postType: PostTypeExt.fromString(e.postType),
      content: DiaryContent.fromJsonString(e.contentJson),
      tags: diaryTags,
      syncStatus: e.syncStatus,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }
}
