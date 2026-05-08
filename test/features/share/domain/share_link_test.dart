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

    test('accepts string diary ids and defaults optional fields', () {
      final link = ShareLink.fromJson({
        'id': 8,
        'diary_id': '43',
        'token': 'xyz',
        'share_type': 'EXCERPT',
        'diary_title': 'Late night thoughts',
        'expires_at': '2026-05-04T10:30:00Z',
        'public_url': 'https://example.com/share/xyz',
        'created_at': '2026-05-03T10:30:00Z',
      });

      expect(link.diaryId, 43);
      expect(link.excerpt, isEmpty);
      expect(link.isExpired, isFalse);
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
        link.expiryStatusLabel(now: DateTime.parse('2026-05-04T08:00:00Z')),
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
        link.expiryStatusLabel(now: DateTime.parse('2026-05-04T10:31:00Z')),
        'Expired',
      );
    });

    test(
      'exposes expiry helpers across positive, zero, negative, and malformed dates',
      () {
        final valid = ShareLink.fromJson({
          'id': 7,
          'diary_id': 42,
          'token': 'abc',
          'share_type': 'FULL',
          'excerpt': '',
          'diary_title': 'Cox Bazar Trip',
          'expires_at': '2026-05-04T10:30:00Z',
          'is_expired': false,
          'created_at': '2026-05-03T10:30:00Z',
          'public_url': 'https://example.com/share/abc',
        });
        final malformed = ShareLink.fromJson({
          'id': 8,
          'diary_id': 42,
          'token': 'def',
          'share_type': 'FULL',
          'excerpt': '',
          'diary_title': 'Cox Bazar Trip',
          'expires_at': 'not-a-date',
          'is_expired': false,
          'created_at': '2026-05-03T10:30:00Z',
          'public_url': 'https://example.com/share/def',
        });

        expect(valid.expiresAtDate, DateTime.parse('2026-05-04T10:30:00Z'));
        expect(
          valid.remainingUntilExpiry(
            now: DateTime.parse('2026-05-04T10:00:00Z'),
          ),
          const Duration(minutes: 30),
        );
        expect(
          valid.remainingUntilExpiry(
            now: DateTime.parse('2026-05-04T10:30:00Z'),
          ),
          Duration.zero,
        );
        expect(
          valid.remainingUntilExpiry(
            now: DateTime.parse('2026-05-04T11:00:00Z'),
          ),
          const Duration(minutes: -30),
        );
        expect(malformed.expiresAtDate, isNull);
        expect(
          malformed.remainingUntilExpiry(
            now: DateTime.parse('2026-05-04T10:00:00Z'),
          ),
          isNull,
        );
      },
    );

    test('treats server-expired links as expired before timestamp', () {
      final link = ShareLink.fromJson({
        'id': 7,
        'diary_id': 42,
        'token': 'ghi',
        'share_type': 'FULL',
        'excerpt': '',
        'diary_title': 'Cox Bazar Trip',
        'expires_at': '2026-05-04T10:30:00Z',
        'is_expired': true,
        'created_at': '2026-05-03T10:30:00Z',
        'public_url': 'https://example.com/share/ghi',
      });

      expect(
        link.isExpiredAt(now: DateTime.parse('2026-05-04T09:00:00Z')),
        isTrue,
      );
    });

    test('formats expiry labels for several remaining durations', () {
      final link = ShareLink.fromJson({
        'id': 7,
        'diary_id': 42,
        'token': 'jkl',
        'share_type': 'FULL',
        'excerpt': '',
        'diary_title': 'Cox Bazar Trip',
        'expires_at': '2026-05-06T12:15:00Z',
        'is_expired': false,
        'created_at': '2026-05-03T10:30:00Z',
        'public_url': 'https://example.com/share/jkl',
      });
      final shortLink = ShareLink.fromJson({
        'id': 8,
        'diary_id': 42,
        'token': 'mno',
        'share_type': 'FULL',
        'excerpt': '',
        'diary_title': 'Cox Bazar Trip',
        'expires_at': '2026-05-04T10:30:20Z',
        'is_expired': false,
        'created_at': '2026-05-03T10:30:00Z',
        'public_url': 'https://example.com/share/mno',
      });
      final malformed = ShareLink.fromJson({
        'id': 9,
        'diary_id': 42,
        'token': 'pqr',
        'share_type': 'FULL',
        'excerpt': '',
        'diary_title': 'Cox Bazar Trip',
        'expires_at': 'not-a-date',
        'is_expired': false,
        'created_at': '2026-05-03T10:30:00Z',
        'public_url': 'https://example.com/share/pqr',
      });

      expect(
        link.expiryStatusLabel(now: DateTime.parse('2026-05-04T10:00:00Z')),
        'Expires in 2d 2h',
      );
      expect(
        link.expiryStatusLabel(now: DateTime.parse('2026-05-06T10:00:00Z')),
        'Expires in 2h 15m',
      );
      expect(
        link.expiryStatusLabel(now: DateTime.parse('2026-05-06T12:00:00Z')),
        'Expires in 15m',
      );
      expect(
        shortLink.expiryStatusLabel(
          now: DateTime.parse('2026-05-04T10:30:00Z'),
        ),
        'Expires in less than 1m',
      );
      expect(
        malformed.expiryStatusLabel(
          now: DateTime.parse('2026-05-04T10:30:00Z'),
        ),
        'Expires not-a-date',
      );
    });
  });

  group('PublicShareData.fromJson', () {
    test('supports string and structured content payloads', () {
      final text = PublicShareData.fromJson({
        'share_type': 'EXCERPT',
        'diary_title': 'Evening',
        'diary_date': '08-05-2026',
        'content': 'Rendered text',
        'expires_at': '2026-05-04T10:30:00Z',
      });
      final structured = PublicShareData.fromJson({
        'share_type': 'FULL',
        'diary_title': 'Evening',
        'diary_date': '08-05-2026',
        'content': {
          'version': 1,
          'blocks': [
            {'type': 'paragraph', 'text': 'Rendered text'},
          ],
        },
        'expires_at': '2026-05-04T10:30:00Z',
      });

      expect(text.content, 'Rendered text');
      expect(structured.content, isA<Map<String, dynamic>>());
    });
  });
}
