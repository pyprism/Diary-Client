import 'dart:async';

import 'package:diary_client/core/storage/app_database.dart';
import 'package:diary_client/core/utils/content_utils.dart';
import 'package:diary_client/features/diary/data/diary_local_ds.dart';
import 'package:diary_client/features/diary/domain/models/diary_entry.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiaryLocalDataSource dataSource;

  setUp(() {
    db = createTestDatabase();
    dataSource = DiaryLocalDataSource(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insert writes diary fields and tag links', () async {
    final tagId = await db.insertTag(
      TagsCompanion.insert(remoteId: drift.Value(7), name: 'Travel'),
    );
    final localId = await dataSource.insert(
      _entry(
        remoteId: 20,
        syncStatus: 'pending',
        content: DiaryContent(
          blocks: [ContentBlock.paragraph(text: 'A windy afternoon')],
        ),
      ),
      [tagId],
    );

    final row = await db.getDiaryById(localId);
    final tags = await db.getTagsForDiary(localId);

    expect(row?.remoteId, 20);
    expect(row?.postType, 'LONG');
    expect(row?.syncStatus, 'pending');
    expect(
      row?.contentJson,
      '{"version":1,"blocks":[{"type":"paragraph","text":"A windy afternoon"}]}',
    );
    expect(tags.single.name, 'Travel');
  });

  test('getAll hydrates tags using remote id when available', () async {
    final remoteTagId = await db.insertTag(
      TagsCompanion.insert(remoteId: drift.Value(9), name: 'Travel'),
    );
    final localOnlyTagId = await db.insertTag(
      TagsCompanion.insert(name: 'Private'),
    );
    final localId = await dataSource.insert(_entry(), [
      remoteTagId,
      localOnlyTagId,
    ]);

    final entries = await dataSource.getAll();

    expect(entries.single.localId, localId);
    expect(entries.single.tags.map((tag) => (id: tag.id, name: tag.name)), [
      (id: 9, name: 'Travel'),
      (id: localOnlyTagId, name: 'Private'),
    ]);
  });

  test(
    'getByLocalId returns null when missing and getByRemoteId returns match',
    () async {
      await dataSource.insert(_entry(remoteId: 44), const []);

      expect(await dataSource.getByLocalId(999), isNull);
      expect((await dataSource.getByRemoteId(44))?.title, 'Diary title');
    },
  );

  test('watchByLocalId emits null after deletion', () async {
    final localId = await dataSource.insert(_entry(), const []);

    final expectation = expectLater(
      dataSource.watchByLocalId(localId).map((entry) => entry?.title).take(2),
      emitsInOrder(['Diary title', null]),
    );

    await dataSource.delete(localId);

    await expectation;
  });

  test('watchAll re-emits hydrated tags when diary tags change', () async {
    final localId = await dataSource.insert(_entry(), const []);
    final tagId = await db.insertTag(TagsCompanion.insert(name: 'Travel'));

    final stream = StreamIterator(
      dataSource.watchAll().map(
        (entries) => entries.single.tags.map((tag) => tag.name).toList(),
      ),
    );

    expect(await stream.moveNext(), isTrue);
    expect(stream.current, isEmpty);

    await db.setTagsForDiary(localId, [tagId]);

    expect(await stream.moveNext(), isTrue);
    expect(stream.current, ['Travel']);

    await stream.cancel();
  });

  test(
    'update changes diary fields, replaces tags, and invalid json maps to empty',
    () async {
      final firstTagId = await db.insertTag(
        TagsCompanion.insert(name: 'Before'),
      );
      final secondTagId = await db.insertTag(
        TagsCompanion.insert(remoteId: drift.Value(12), name: 'After'),
      );
      final localId = await dataSource.insert(_entry(), [firstTagId]);

      await db.updateDiary(
        DiaryEntriesCompanion(
          id: drift.Value(localId),
          contentJson: const drift.Value('bad-json'),
        ),
      );
      expect((await dataSource.getByLocalId(localId))?.content.isEmpty, isTrue);

      await dataSource.update(
        _entry(
          localId: localId,
          remoteId: 55,
          title: 'Updated title',
          postType: PostType.short,
          syncStatus: 'synced',
          content: DiaryContent(
            blocks: [ContentBlock.heading(level: 1, text: 'Updated')],
          ),
        ),
        [secondTagId],
      );

      final updated = await dataSource.getByLocalId(localId);
      expect(updated?.remoteId, 55);
      expect(updated?.title, 'Updated title');
      expect(updated?.postType, PostType.short);
      expect(updated?.syncStatus, 'synced');
      expect(updated?.content.blocks.single.data['text'], 'Updated');
      expect(updated?.tags.single.id, 12);
      expect(updated?.tags.single.name, 'After');
    },
  );
}

DiaryEntry _entry({
  int? localId,
  int? remoteId,
  String title = 'Diary title',
  String date = '08-05-2026',
  PostType postType = PostType.long,
  DiaryContent? content,
  String syncStatus = 'pending',
}) {
  return DiaryEntry(
    localId: localId,
    remoteId: remoteId,
    title: title,
    date: date,
    postType: postType,
    content: content ?? DiaryContent.empty(),
    syncStatus: syncStatus,
  );
}
