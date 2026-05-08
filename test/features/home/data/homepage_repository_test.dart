import 'package:diary_client/features/home/data/homepage_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomepageData.fromJson', () {
    test('defaults missing fields and parses entries', () {
      final data = HomepageData.fromJson({
        'entries': [
          {
            'id': 4,
            'title': 'Memory lane',
            'date': '08-05-2025',
            'post_type': 'SHORT',
          },
        ],
      });

      expect(data.isExactDate, isFalse);
      expect(data.matchedDate, isNull);
      expect(data.entries.single.remoteId, 4);
      expect(data.entries.single.title, 'Memory lane');
    });

    test('preserves matched_date and defaults missing entries', () {
      final data = HomepageData.fromJson({
        'is_exact_date': true,
        'matched_date': {'month': 5, 'day': 8},
      });

      expect(data.isExactDate, isTrue);
      expect(data.matchedDate, {'month': 5, 'day': 8});
      expect(data.entries, isEmpty);
    });
  });
}
