import 'package:diary_client/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App exceptions', () {
    test('preserve message and status code', () {
      const error = NetworkException('Offline', statusCode: 503);

      expect(error.message, 'Offline');
      expect(error.statusCode, 503);
      expect(error.toString(), 'AppException(503): Offline');
    });

    test('can be matched by subtype in tests', () {
      const auth = AuthException('Expired');
      const missing = NotFoundException('Not here');
      const validation = ValidationException(
        'Bad input',
        errors: {
          'title': ['Required'],
        },
      );

      expect(auth, isA<AuthException>());
      expect(missing.statusCode, 404);
      expect(validation.errors, {
        'title': ['Required'],
      });
    });
  });
}
