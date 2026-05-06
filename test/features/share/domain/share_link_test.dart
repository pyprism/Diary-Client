import 'package:diary_client/features/share/domain/models/share_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShareLink.fromJson', () {
    test('parses diary_id from the global share list response', () {
      final link = ShareLink.fromJson({
        'id': 7,
        'diary_id': 42,
        'token': 'AbCdEf1234567890',
        'share_type': 'FULL',
        'excerpt': '',
        'diary_title': 'Cox Bazar Trip',
        'expires_at': '2026-05-04T10:30:00Z',
        'is_expired': false,
        'created_at': '2026-05-03T10:30:00Z',
        'public_url': 'https://example.com/api/v1/share/AbCdEf1234567890',
      });

      expect(link.diaryId, 42);
    });

    test('formats time remaining before expiry', () {
      final link = ShareLink.fromJson({
        'id': 7,
        'diary_id': 42,
        'token': 'AbCdEf1234567890',
        'share_type': 'FULL',
        'excerpt': '',
        'diary_title': 'Cox Bazar Trip',
        'expires_at': '2026-05-04T10:30:00Z',
        'is_expired': false,
        'created_at': '2026-05-03T10:30:00Z',
        'public_url': 'https://example.com/api/v1/share/AbCdEf1234567890',
      });

      expect(
        link.expiryStatusLabel(
          now: DateTime.parse('2026-05-04T08:00:00Z'),
        ),
        'Expires in 2h 30m',
      );
    });

    test('shows expired when the link has passed its expiry', () {
      final link = ShareLink.fromJson({
        'id': 7,
        'diary_id': 42,
        'token': 'AbCdEf1234567890',
        'share_type': 'FULL',
        'excerpt': '',
        'diary_title': 'Cox Bazar Trip',
        'expires_at': '2026-05-04T10:30:00Z',
        'is_expired': false,
        'created_at': '2026-05-03T10:30:00Z',
        'public_url': 'https://example.com/api/v1/share/AbCdEf1234567890',
      });

      expect(
        link.expiryStatusLabel(
          now: DateTime.parse('2026-05-04T10:31:00Z'),
        ),
        'Expired',
      );
    });
  });
}
