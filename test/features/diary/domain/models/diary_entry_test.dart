import 'package:diary_client/core/utils/content_utils.dart';
import 'package:diary_client/features/diary/domain/models/diary_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostTypeExt', () {
    test('maps values to and from api strings', () {
      expect(PostType.short.value, 'SHORT');
      expect(PostType.long.value, 'LONG');
      expect(PostTypeExt.fromString('SHORT'), PostType.short);
      expect(PostTypeExt.fromString('LONG'), PostType.long);
      expect(PostTypeExt.fromString('UNKNOWN'), PostType.long);
    });
  });

  group('DiaryTag', () {
    test('round trips json fields', () {
      const tag = DiaryTag(id: 5, name: 'Travel');

      expect(DiaryTag.fromJson(tag.toJson()).id, 5);
      expect(DiaryTag.fromJson(tag.toJson()).name, 'Travel');
    });
  });

  group('DiaryEntry', () {
    test('fromJson parses remote fields and defaults missing values', () {
      final entry = DiaryEntry.fromJson({
        'id': 42,
        'title': 'Beach Day',
        'date': '08-05-2026',
        'tags': [
          {'id': 1, 'name': 'Travel'},
        ],
        'created_at': '2026-05-08T08:30:00Z',
        'updated_at': '2026-05-08T09:00:00Z',
      });

      expect(entry.remoteId, 42);
      expect(entry.postType, PostType.long);
      expect(entry.content.isEmpty, isTrue);
      expect(entry.tags.single.name, 'Travel');
      expect(entry.createdAt, DateTime.parse('2026-05-08T08:30:00Z'));
      expect(entry.updatedAt, DateTime.parse('2026-05-08T09:00:00Z'));
    });

    test('copyWith updates selected values and preserves others', () {
      final original = DiaryEntry(
        localId: 1,
        remoteId: 10,
        title: 'Morning',
        date: '08-05-2026',
        postType: PostType.long,
        content: DiaryContent.empty(),
        tags: const [DiaryTag(id: 1, name: 'Daily')],
        syncStatus: 'synced',
        createdAt: DateTime.parse('2026-05-08T08:00:00Z'),
        updatedAt: DateTime.parse('2026-05-08T09:00:00Z'),
      );

      final updated = original.copyWith(
        title: 'Evening',
        postType: PostType.short,
        syncStatus: 'pending',
      );

      expect(updated.localId, 1);
      expect(updated.remoteId, 10);
      expect(updated.title, 'Evening');
      expect(updated.postType, PostType.short);
      expect(updated.tags.single.name, 'Daily');
      expect(updated.syncStatus, 'pending');
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, original.updatedAt);
    });
  });

  group('DiaryListItem', () {
    test('fromJson parses remote id and defaults post type', () {
      final item = DiaryListItem.fromJson({
        'id': 21,
        'title': 'Memory',
        'date': '08-05-2026',
      });

      expect(item.remoteId, 21);
      expect(item.postType, PostType.long);
    });

    test('copyWith preserves unspecified values', () {
      const item = DiaryListItem(
        localId: 1,
        remoteId: 2,
        title: 'Old title',
        date: '08-05-2026',
        postType: PostType.long,
      );

      final updated = item.copyWith(title: 'New title');

      expect(updated.localId, 1);
      expect(updated.remoteId, 2);
      expect(updated.title, 'New title');
      expect(updated.date, '08-05-2026');
      expect(updated.postType, PostType.long);
    });
  });
}
