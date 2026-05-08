import 'package:diary_client/core/utils/content_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentBlock', () {
    test('fromJson strips type while preserving remaining data', () {
      final block = ContentBlock.fromJson({
        'type': 'heading',
        'level': 2,
        'text': 'Trip recap',
      });

      expect(block.type, 'heading');
      expect(block.data, {'level': 2, 'text': 'Trip recap'});
    });

    test('toJson restores type alongside data fields', () {
      final block = ContentBlock.paragraph(text: 'Sunset walk');

      expect(block.toJson(), {'type': 'paragraph', 'text': 'Sunset walk'});
    });
  });

  group('DiaryContent', () {
    test('fromJson defaults missing version and blocks', () {
      final content = DiaryContent.fromJson({});

      expect(content.version, 1);
      expect(content.blocks, isEmpty);
    });

    test('fromJsonString returns empty content for invalid json', () {
      final content = DiaryContent.fromJsonString('not-json');

      expect(content.isEmpty, isTrue);
      expect(content.version, 1);
    });

    test(
      'plainText includes text blocks while ignoring divider and image blocks',
      () {
        final content = DiaryContent(
          blocks: [
            ContentBlock.heading(level: 1, text: 'Morning'),
            ContentBlock.paragraph(text: 'Walked by the sea'),
            ContentBlock.quote(text: 'Keep going'),
            ContentBlock.bulletList(items: ['Tea', 'Journal']),
            ContentBlock.checklist(
              items: [
                {'text': 'Call home', 'checked': true},
                {'text': 'Pack bag', 'checked': false},
              ],
            ),
            ContentBlock.divider(),
            ContentBlock.image(url: 'https://example.com/photo.jpg'),
          ],
        );

        expect(
          content.plainText,
          'Morning Walked by the sea Keep going Tea Journal Call home Pack bag  ',
        );
      },
    );

    test('validateForApi accepts supported block types', () {
      final content = DiaryContent(
        blocks: [
          ContentBlock.heading(level: 2, text: 'Trip'),
          ContentBlock.paragraph(text: 'A calm day'),
          ContentBlock.quote(text: 'Stay present'),
          ContentBlock.bulletList(items: ['Breakfast', 'Beach']),
          ContentBlock.checklist(
            items: [
              {'text': 'Book tickets', 'checked': true},
            ],
          ),
          ContentBlock.divider(),
          ContentBlock.image(url: 'https://example.com/cover.png'),
        ],
      );

      expect(content.validateForApi(), isNull);
    });

    test('validateForApi rejects more than 500 blocks', () {
      final content = DiaryContent(
        blocks: List.generate(
          501,
          (_) => ContentBlock.paragraph(text: 'A short memory'),
        ),
      );

      expect(content.validateForApi(), 'Content cannot exceed 500 blocks.');
    });

    test('validateForApi rejects unsupported types', () {
      final content = DiaryContent(
        blocks: const [
          ContentBlock(
            type: 'audio',
            data: {'url': 'https://example.com/a.mp3'},
          ),
        ],
      );

      expect(
        content.validateForApi(),
        'Block 1 uses unsupported type "audio".',
      );
    });

    test('validateForApi rejects invalid heading levels and empty text', () {
      final invalidLevel = DiaryContent(
        blocks: [ContentBlock.heading(level: 4, text: 'Too deep')],
      );
      final emptyParagraph = DiaryContent(
        blocks: [ContentBlock.paragraph(text: '   ')],
      );

      expect(
        invalidLevel.validateForApi(),
        'Heading 1 must use level 1, 2, or 3.',
      );
      expect(emptyParagraph.validateForApi(), 'Paragraph 1 cannot be empty.');
    });

    test('validateForApi rejects invalid lists and checklist states', () {
      final emptyList = DiaryContent(
        blocks: [ContentBlock.bulletList(items: const [])],
      );
      final badChecklist = DiaryContent(
        blocks: [
          ContentBlock.checklist(
            items: [
              {'text': 'Bring notebook', 'checked': 'yes'},
            ],
          ),
        ],
      );

      expect(
        emptyList.validateForApi(),
        'Bullet list 1 must contain 1 to 200 items.',
      );
      expect(
        badChecklist.validateForApi(),
        'Checklist 1 item 1 needs a checked state.',
      );
    });

    test(
      'validateForApi rejects non-http images unless local images allowed',
      () {
        final content = DiaryContent(
          blocks: [ContentBlock.image(url: 'data:image/png;base64,abc123')],
        );

        expect(
          content.validateForApi(),
          'Image 1 must use a valid http(s) URL.',
        );
        expect(content.validateForApi(allowLocalImages: true), isNull);
      },
    );
  });
}
