import 'package:diary_client/features/tags/domain/models/tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tag', () {
    test('fromJson parses remote id and name', () {
      final tag = Tag.fromJson({'id': 7, 'name': 'Travel'});

      expect(tag.remoteId, 7);
      expect(tag.name, 'Travel');
    });
  });

  group('TagEntrySummary', () {
    test('accepts pk or id and defaults title', () {
      final fromPk = TagEntrySummary.fromJson({'pk': 8});
      final fromId = TagEntrySummary.fromJson({'id': 9, 'title': 'Sunset'});

      expect(fromPk.remoteId, 8);
      expect(fromPk.title, 'Untitled entry');
      expect(fromId.remoteId, 9);
      expect(fromId.title, 'Sunset');
    });

    test('copyWith preserves unspecified values', () {
      const summary = TagEntrySummary(
        localId: 1,
        remoteId: 2,
        title: 'Original',
      );

      final updated = summary.copyWith(title: 'Updated');

      expect(updated.localId, 1);
      expect(updated.remoteId, 2);
      expect(updated.title, 'Updated');
    });
  });
}
