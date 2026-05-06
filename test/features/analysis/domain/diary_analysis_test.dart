import 'package:diary_client/features/analysis/domain/models/diary_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiaryAnalysis.fromJson', () {
    test('normalizes task_status done to DONE', () {
      final analysis = DiaryAnalysis.fromJson({
        'status': 'PENDING',
        'task_status': 'done',
      });

      expect(analysis.status, DiaryAnalysis.done);
      expect(analysis.isDone, isTrue);
      expect(analysis.isPending, isFalse);
    });

    test(
      'keeps explicit PENDING even when partial result fields are present',
      () {
        final analysis = DiaryAnalysis.fromJson({
          'status': 'PENDING',
          'summary': 'Finished summary',
          'bangla_content': {
            'version': 1,
            'blocks': [
              {'type': 'paragraph', 'text': 'শেষ'},
            ],
          },
        });

        expect(analysis.status, DiaryAnalysis.pending);
        expect(analysis.isPending, isTrue);
        expect(analysis.isDone, isFalse);
      },
    );

    test('infers DONE when analysis fields are present without status', () {
      final analysis = DiaryAnalysis.fromJson({
        'summary': 'Finished summary',
        'bangla_content': {
          'version': 1,
          'blocks': [
            {'type': 'paragraph', 'text': 'শেষ'},
          ],
        },
      });

      expect(analysis.status, DiaryAnalysis.done);
      expect(analysis.isDone, isTrue);
    });

    test('maps celery-style states', () {
      expect(
        DiaryAnalysis.fromJson({'state': 'SUCCESS'}).status,
        DiaryAnalysis.done,
      );
      expect(
        DiaryAnalysis.fromJson({'state': 'STARTED'}).status,
        DiaryAnalysis.processing,
      );
      expect(
        DiaryAnalysis.fromJson({'state': 'FAILURE'}).status,
        DiaryAnalysis.failed,
      );
    });

    test('parses retry_after_seconds', () {
      final analysis = DiaryAnalysis.fromJson({
        'status': 'PROCESSING',
        'retry_after_seconds': 10,
      });

      expect(analysis.retryAfterSeconds, 10);
      expect(analysis.isPending, isTrue);
    });
  });
}
