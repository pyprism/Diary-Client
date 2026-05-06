import 'package:flutter_test/flutter_test.dart';

import 'package:diary_client/core/utils/content_utils.dart';
import 'package:diary_client/features/diary/presentation/diary_content_quill_codec.dart';

void main() {
  test('blocks -> document -> blocks keeps major block types', () {
    final input = <ContentBlock>[
      ContentBlock.heading(level: 2, text: 'Trip Day'),
      ContentBlock.paragraph(text: 'Went to the beach.'),
      ContentBlock.quote(text: 'Memories matter'),
      ContentBlock.bulletList(items: ['Sunrise', 'Seafood']),
      ContentBlock.checklist(items: [
        {'text': 'Book hotel', 'checked': true},
        {'text': 'Pack bag', 'checked': false},
      ]),
      ContentBlock.image(url: 'https://example.com/a.jpg'),
      ContentBlock.divider(),
    ];

    final doc = DiaryContentQuillCodec.blocksToDocument(input);
    final output = DiaryContentQuillCodec.documentToBlocks(doc);

    expect(output.length, input.length);
    expect(output[0].type, 'heading');
    expect(output[0].data['level'], 2);
    expect(output[0].data['text'], 'Trip Day');

    expect(output[1].type, 'paragraph');
    expect(output[1].data['text'], 'Went to the beach.');

    expect(output[2].type, 'quote');
    expect(output[2].data['text'], 'Memories matter');

    expect(output[3].type, 'bullet_list');
    expect(output[3].data['items'], ['Sunrise', 'Seafood']);

    expect(output[4].type, 'checklist');
    final checklist = output[4].data['items'] as List;
    expect(checklist[0]['text'], 'Book hotel');
    expect(checklist[0]['checked'], true);
    expect(checklist[1]['text'], 'Pack bag');
    expect(checklist[1]['checked'], false);

    expect(output[5].type, 'image');
    expect(output[5].data['url'], 'https://example.com/a.jpg');

    expect(output[6].type, 'divider');
  });

  test('empty document yields no blocks', () {
    final empty = DiaryContent.empty();
    final doc = DiaryContentQuillCodec.blocksToDocument(empty.blocks);
    final output = DiaryContentQuillCodec.documentToBlocks(doc);

    expect(output, isEmpty);
  });
}
