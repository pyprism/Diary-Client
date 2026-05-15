import 'package:diary_client/core/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateUtils', () {
    test('formats and parses valid dates', () {
      final date = DateTime(2026, 5, 8);

      expect(DateUtils.toApiFormat(date), '08-05-2026');
      expect(DateUtils.fromApiFormat('08-05-2026'), date);
      expect(DateUtils.toDisplayFormat('08-05-2026'), 'May 8, 2026');
      expect(DateUtils.toShortFormat('08-05-2026'), 'May 8, 2026');
      expect(DateUtils.toTitleFormat(date), '08-May-2026');
    });

    test('returns safe fallbacks for invalid date strings', () {
      expect(DateUtils.fromApiFormat('2026/05/08'), isNull);
      expect(DateUtils.toDisplayFormat('2026/05/08'), '2026/05/08');
      expect(DateUtils.toShortFormat('2026/05/08'), '2026/05/08');
    });
  });
}
