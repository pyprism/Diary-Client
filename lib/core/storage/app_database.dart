import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [DiaryEntries, DiaryTags, Tags, DiaryAnalyses, SyncQueue],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'diary_app.db',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS diary_entries_remote_id_unique '
          'ON diary_entries(remote_id) WHERE remote_id IS NOT NULL',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS tags_remote_id_unique '
          'ON tags(remote_id) WHERE remote_id IS NOT NULL',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS tags_name_unique ON tags(name)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS diary_analyses_diary_local_id_unique '
          'ON diary_analyses(diary_local_id)',
        );
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ─── Diary ───────────────────────────────────────────────────

  Stream<List<DiaryEntryData>> watchAllDiaries() =>
      select(diaryEntries).watch().map(_sortDiaryRowsByDateDesc);

  Future<List<DiaryEntryData>> getAllDiaries() async =>
      _sortDiaryRowsByDateDesc(await select(diaryEntries).get());

  Future<DiaryEntryData?> getDiaryById(int localId) => (select(
    diaryEntries,
  )..where((t) => t.id.equals(localId))).getSingleOrNull();

  Future<DiaryEntryData?> getDiaryByRemoteId(int remoteId) => (select(
    diaryEntries,
  )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();

  Stream<DiaryEntryData?> watchDiaryById(int localId) => (select(
    diaryEntries,
  )..where((t) => t.id.equals(localId))).watchSingleOrNull();

  Future<int> insertDiary(DiaryEntriesCompanion entry) =>
      into(diaryEntries).insert(entry);

  Future<void> updateDiary(DiaryEntriesCompanion entry) => (update(
    diaryEntries,
  )..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<void> deleteDiary(int localId) =>
      (delete(diaryEntries)..where((t) => t.id.equals(localId))).go();

  Future<List<DiaryEntryData>> getPendingDiaries() => (select(
    diaryEntries,
  )..where((t) => t.syncStatus.equals('pending'))).get();

  // ─── Tags for Diary ─────────────────────────────────────────

  Future<List<TagData>> getTagsForDiary(int diaryLocalId) async {
    final query = select(diaryTags).join([
      innerJoin(tags, tags.id.equalsExp(diaryTags.tagLocalId)),
    ])..where(diaryTags.diaryLocalId.equals(diaryLocalId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(tags)).toList();
  }

  Future<void> setTagsForDiary(int diaryLocalId, List<int> tagLocalIds) async {
    await (delete(
      diaryTags,
    )..where((t) => t.diaryLocalId.equals(diaryLocalId))).go();
    for (final tagId in tagLocalIds) {
      await into(diaryTags).insertOnConflictUpdate(
        DiaryTagsCompanion.insert(
          diaryLocalId: diaryLocalId,
          tagLocalId: tagId,
        ),
      );
    }
  }

  Future<List<DiaryEntryData>> getDiariesForTag(int tagLocalId) async {
    final query = select(diaryTags).join([
      innerJoin(
        diaryEntries,
        diaryEntries.id.equalsExp(diaryTags.diaryLocalId),
      ),
    ])..where(diaryTags.tagLocalId.equals(tagLocalId));
    final rows = await query.get();
    return _sortDiaryRowsByDateDesc(
      rows.map((r) => r.readTable(diaryEntries)).toList(),
    );
  }

  // ─── Tags ────────────────────────────────────────────────────

  Stream<List<TagData>> watchAllTags() =>
      (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<List<TagData>> getAllTags() =>
      (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<TagData?> getTagById(int localId) =>
      (select(tags)..where((t) => t.id.equals(localId))).getSingleOrNull();

  Future<TagData?> getTagByRemoteId(int remoteId) => (select(
    tags,
  )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();

  Future<TagData?> getTagByName(String name) =>
      (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<int> insertTag(TagsCompanion tag) => into(tags).insert(tag);

  Future<void> updateTag(TagsCompanion tag) =>
      (update(tags)..where((t) => t.id.equals(tag.id.value))).write(tag);

  Future<void> deleteTag(int localId) =>
      (delete(tags)..where((t) => t.id.equals(localId))).go();

  Future<List<TagData>> getPendingTags() =>
      (select(tags)..where((t) => t.syncStatus.equals('pending'))).get();

  // ─── Analysis ────────────────────────────────────────────────

  Future<DiaryAnalysisData?> getAnalysisByDiaryLocalId(int diaryLocalId) =>
      (select(diaryAnalyses)
            ..where((t) => t.diaryLocalId.equals(diaryLocalId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  Stream<DiaryAnalysisData?> watchAnalysisByDiaryLocalId(int diaryLocalId) =>
      (select(diaryAnalyses)
            ..where((t) => t.diaryLocalId.equals(diaryLocalId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .watchSingleOrNull();

  Future<void> upsertAnalysis(DiaryAnalysesCompanion entry) async {
    if (!entry.diaryLocalId.present) {
      await into(diaryAnalyses).insertOnConflictUpdate(entry);
      return;
    }
    await transaction(() async {
      await (delete(
        diaryAnalyses,
      )..where((t) => t.diaryLocalId.equals(entry.diaryLocalId.value))).go();
      await into(diaryAnalyses).insert(entry);
    });
  }

  Future<void> deleteAnalysis(int diaryLocalId) => (delete(
    diaryAnalyses,
  )..where((t) => t.diaryLocalId.equals(diaryLocalId))).go();

  // ─── Sync Queue ─────────────────────────────────────────────

  Future<int> enqueueSync(SyncQueueCompanion entry) =>
      into(syncQueue).insert(entry);

  Future<List<SyncQueueData>> getQueuedSync({
    String? entityType,
    String? operation,
  }) {
    final query = select(syncQueue)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    if (entityType != null) {
      query.where((t) => t.entityType.equals(entityType));
    }
    if (operation != null) {
      query.where((t) => t.operation.equals(operation));
    }
    return query.get();
  }

  Future<void> deleteQueuedSync(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();

  Future<void> incrementQueuedSyncRetry(int id) => customStatement(
    'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
    [id],
  );

  List<DiaryEntryData> _sortDiaryRowsByDateDesc(List<DiaryEntryData> rows) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      final aDate = _parseStoredDate(a.date);
      final bDate = _parseStoredDate(b.date);
      if (aDate != null && bDate != null) {
        return bDate.compareTo(aDate);
      }
      if (aDate != null) return -1;
      if (bDate != null) return 1;
      return b.date.compareTo(a.date);
    });
    return sorted;
  }

  DateTime? _parseStoredDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }
}
