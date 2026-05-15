import 'package:diary_client/core/storage/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase diary queries', () {
    test(
      'insert and fetch diaries with chronological descending ordering',
      () async {
        final olderId = await _insertDiary(
          db,
          title: 'Older',
          date: '15-01-2024',
          remoteId: 10,
        );
        await _insertDiary(
          db,
          title: 'Newest',
          date: '02-12-2025',
          remoteId: 11,
        );

        final byId = await db.getDiaryById(olderId);
        final byRemoteId = await db.getDiaryByRemoteId(11);
        final all = await db.getAllDiaries();

        expect(byId?.title, 'Older');
        expect(byRemoteId?.title, 'Newest');
        expect(all.map((entry) => entry.title), ['Newest', 'Older']);
      },
    );

    test('watchAllDiaries emits inserts and updates', () async {
      final expectation = expectLater(
        db
            .watchAllDiaries()
            .map((rows) => rows.map((row) => row.title).toList())
            .take(2),
        emitsInOrder([
          ['Draft'],
          ['Published'],
        ]),
      );

      final id = await _insertDiary(db, title: 'Draft', date: '08-05-2026');
      await db.updateDiary(
        DiaryEntriesCompanion(
          id: drift.Value(id),
          title: const drift.Value('Published'),
          date: const drift.Value('08-05-2026'),
          postType: const drift.Value('LONG'),
          contentJson: const drift.Value('{"version":1,"blocks":[]}'),
          syncStatus: const drift.Value('synced'),
          updatedAt: drift.Value(DateTime(2026, 5, 8, 10)),
        ),
      );

      await expectation;
    });

    test('watchAllDiaries re-emits when diary tags change', () async {
      final diaryId = await _insertDiary(
        db,
        title: 'Tagged',
        date: '08-05-2026',
      );
      final tagId = await db.insertTag(TagsCompanion.insert(name: 'Travel'));

      final expectation = expectLater(
        db
            .watchAllDiaries()
            .map((rows) => rows.map((row) => row.id).toList())
            .take(2),
        emitsInOrder([
          [diaryId],
          [diaryId],
        ]),
      );

      await db.setTagsForDiary(diaryId, [tagId]);

      await expectation;
    });

    test('deleteDiary cascades diary tag links', () async {
      final diaryId = await _insertDiary(
        db,
        title: 'Tagged',
        date: '08-05-2026',
      );
      final tagId = await db.insertTag(TagsCompanion.insert(name: 'Travel'));

      await db.setTagsForDiary(diaryId, [tagId]);
      expect((await db.getTagsForDiary(diaryId)).single.name, 'Travel');

      await db.deleteDiary(diaryId);

      expect(await db.getDiaryById(diaryId), isNull);
      expect(await db.getTagsForDiary(diaryId), isEmpty);
    });

    test('getPendingDiaries returns only pending rows', () async {
      await _insertDiary(
        db,
        title: 'Pending',
        date: '08-05-2026',
        syncStatus: 'pending',
      );
      await _insertDiary(
        db,
        title: 'Synced',
        date: '07-05-2026',
        syncStatus: 'synced',
      );

      final pending = await db.getPendingDiaries();

      expect(pending.map((entry) => entry.title), ['Pending']);
    });
  });

  group('AppDatabase tags and analysis', () {
    test('tag lookups order by name and enforce uniqueness', () async {
      final remoteId = await db.insertTag(
        TagsCompanion.insert(remoteId: drift.Value(9), name: 'Travel'),
      );
      await db.insertTag(TagsCompanion.insert(name: 'Daily'));

      expect((await db.getTagById(remoteId))?.name, 'Travel');
      expect((await db.getTagByRemoteId(9))?.name, 'Travel');
      expect((await db.getTagByName('Daily'))?.name, 'Daily');
      expect((await db.getAllTags()).map((tag) => tag.name), [
        'Daily',
        'Travel',
      ]);
      expect(
        () => db.insertTag(TagsCompanion.insert(name: 'Travel')),
        throwsA(anything),
      );
    });

    test(
      'setTagsForDiary replaces tag links and diaries for tag stay sorted',
      () async {
        final firstDiaryId = await _insertDiary(
          db,
          title: 'First',
          date: '08-05-2024',
        );
        final secondDiaryId = await _insertDiary(
          db,
          title: 'Second',
          date: '09-05-2026',
        );
        final firstTagId = await db.insertTag(
          TagsCompanion.insert(name: 'Travel'),
        );
        final secondTagId = await db.insertTag(
          TagsCompanion.insert(name: 'Work'),
        );

        await db.setTagsForDiary(firstDiaryId, [firstTagId, secondTagId]);
        await db.setTagsForDiary(secondDiaryId, [secondTagId]);
        await db.setTagsForDiary(firstDiaryId, [secondTagId]);

        expect(
          (await db.getTagsForDiary(firstDiaryId)).map((tag) => tag.name),
          ['Work'],
        );
        expect(
          (await db.getDiariesForTag(secondTagId)).map((entry) => entry.title),
          ['Second', 'First'],
        );
      },
    );

    test('analysis rows are upserted per diary and can be deleted', () async {
      final diaryId = await _insertDiary(
        db,
        title: 'Analysed',
        date: '08-05-2026',
      );
      final watchExpectation = expectLater(
        db
            .watchAnalysisByDiaryLocalId(diaryId)
            .map((row) => row?.status)
            .take(2),
        emitsInOrder([null, 'PENDING']),
      );

      await db.upsertAnalysis(
        DiaryAnalysesCompanion.insert(
          diaryLocalId: diaryId,
          status: const drift.Value('PENDING'),
          summary: const drift.Value('Working'),
        ),
      );
      await watchExpectation;

      await db.upsertAnalysis(
        DiaryAnalysesCompanion.insert(
          diaryLocalId: diaryId,
          status: const drift.Value('DONE'),
          summary: const drift.Value('Finished'),
        ),
      );

      final analysis = await db.getAnalysisByDiaryLocalId(diaryId);
      expect(analysis?.status, 'DONE');
      expect(analysis?.summary, 'Finished');

      await db.deleteAnalysis(diaryId);
      expect(await db.getAnalysisByDiaryLocalId(diaryId), isNull);
    });
  });

  group('AppDatabase sync queue', () {
    test('enqueue, filter, delete, and retry queued sync rows', () async {
      final diaryQueueId = await db.enqueueSync(
        SyncQueueCompanion.insert(
          entityType: 'diary',
          entityLocalId: 1,
          operation: 'delete',
        ),
      );
      await db.enqueueSync(
        SyncQueueCompanion.insert(
          entityType: 'tag',
          entityLocalId: 2,
          operation: 'update',
        ),
      );

      final diaryDeletes = await db.getQueuedSync(
        entityType: 'diary',
        operation: 'delete',
      );
      expect(diaryDeletes.single.id, diaryQueueId);

      await db.incrementQueuedSyncRetry(diaryQueueId);
      expect(
        (await db.getQueuedSync(entityType: 'diary')).single.retryCount,
        1,
      );

      await db.deleteQueuedSync(diaryQueueId);
      expect(await db.getQueuedSync(entityType: 'diary'), isEmpty);
    });
  });
}

Future<int> _insertDiary(
  AppDatabase db, {
  required String title,
  required String date,
  int? remoteId,
  String syncStatus = 'synced',
}) {
  return db.insertDiary(
    DiaryEntriesCompanion.insert(
      remoteId: drift.Value(remoteId),
      title: title,
      date: date,
      contentJson: '{"version":1,"blocks":[]}',
      syncStatus: drift.Value(syncStatus),
    ),
  );
}
