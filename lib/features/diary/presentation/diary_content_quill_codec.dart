import 'package:dart_quill_delta/dart_quill_delta.dart' as dq;
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../core/utils/content_utils.dart';

class DiaryContentQuillCodec {
  static quill.Document blocksToDocument(List<ContentBlock> blocks) {
    final delta = dq.Delta();

    for (final block in blocks) {
      switch (block.type) {
        case 'heading':
          final level = (block.data['level'] as int?) ?? 1;
          delta.insert((block.data['text'] ?? '').toString());
          delta.insert('\n', {'header': level.clamp(1, 3)});
          break;
        case 'paragraph':
          final text = (block.data['text'] ?? '').toString();
          for (final line in text.split('\n')) {
            delta.insert(line);
            delta.insert('\n');
          }
          break;
        case 'quote':
          delta.insert((block.data['text'] ?? '').toString());
          delta.insert('\n', {'blockquote': true});
          break;
        case 'bullet_list':
          final items = (block.data['items'] as List? ?? []).map(
            (e) => e.toString(),
          );
          for (final item in items) {
            delta.insert(item);
            delta.insert('\n', {'list': 'bullet'});
          }
          break;
        case 'checklist':
          final items = (block.data['items'] as List? ?? []).cast<Map>();
          for (final item in items) {
            delta.insert((item['text'] ?? '').toString());
            delta.insert('\n', {
              'list': item['checked'] == true ? 'checked' : 'unchecked',
            });
          }
          break;
        case 'image':
          final url = (block.data['url'] ?? '').toString();
          if (url.isNotEmpty) {
            delta.insert({'image': url});
            delta.insert('\n');
          }
          break;
        case 'divider':
          delta.insert('---');
          delta.insert('\n');
          break;
      }
    }

    if (delta.isEmpty) {
      delta.insert('\n');
    }

    return quill.Document.fromDelta(delta);
  }

  static List<ContentBlock> documentToBlocks(quill.Document document) {
    final ops = document.toDelta().toList();
    final lines = <_QuillLine>[];
    final current = StringBuffer();

    for (final op in ops) {
      if (!op.isInsert) continue;
      final attrs = op.attributes ?? const <String, dynamic>{};
      final data = op.data;

      if (data is String) {
        var start = 0;
        while (true) {
          final nl = data.indexOf('\n', start);
          if (nl == -1) {
            current.write(data.substring(start));
            break;
          }

          current.write(data.substring(start, nl));
          lines.add(_QuillLine(text: current.toString(), attrs: attrs));
          current.clear();
          start = nl + 1;
        }
      } else if (data is Map && data['image'] != null) {
        if (current.isNotEmpty) {
          lines.add(
            _QuillLine(
              text: current.toString(),
              attrs: const <String, dynamic>{},
            ),
          );
          current.clear();
        }
        lines.add(
          _QuillLine(
            imageUrl: data['image'].toString(),
            attrs: const <String, dynamic>{},
          ),
        );
      }
    }

    if (current.isNotEmpty) {
      lines.add(
        _QuillLine(text: current.toString(), attrs: const <String, dynamic>{}),
      );
    }

    final blocks = <ContentBlock>[];
    final paragraphLines = <String>[];

    void flushParagraph() {
      if (paragraphLines.isEmpty) return;
      final text = paragraphLines.join('\n').trim();
      if (text.isNotEmpty) {
        blocks.add(ContentBlock.paragraph(text: text));
      }
      paragraphLines.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.imageUrl != null) {
        flushParagraph();
        blocks.add(ContentBlock.image(url: line.imageUrl!));
        continue;
      }

      final text = line.text.trimRight();
      if (text.trim().isEmpty) {
        flushParagraph();
        continue;
      }

      final attrs = line.attrs;
      final listType = attrs['list'];

      if (listType == 'bullet') {
        flushParagraph();
        final items = <String>[];
        var j = i;
        while (j < lines.length && lines[j].attrs['list'] == 'bullet') {
          items.add(lines[j].text.trim());
          j++;
        }
        blocks.add(ContentBlock.bulletList(items: items));
        i = j - 1;
        continue;
      }

      if (listType == 'checked' || listType == 'unchecked') {
        flushParagraph();
        final items = <Map<String, dynamic>>[];
        var j = i;
        while (j < lines.length) {
          final currentList = lines[j].attrs['list'];
          if (currentList != 'checked' && currentList != 'unchecked') break;
          items.add({
            'text': lines[j].text.trim(),
            'checked': currentList == 'checked',
          });
          j++;
        }
        blocks.add(ContentBlock.checklist(items: items));
        i = j - 1;
        continue;
      }

      final header = attrs['header'];
      if (header is int) {
        flushParagraph();
        blocks.add(
          ContentBlock.heading(level: header.clamp(1, 3), text: text.trim()),
        );
        continue;
      }

      if (attrs['blockquote'] == true) {
        flushParagraph();
        blocks.add(ContentBlock.quote(text: text.trim()));
        continue;
      }

      if (text.trim() == '---') {
        flushParagraph();
        blocks.add(ContentBlock.divider());
        continue;
      }

      paragraphLines.add(text);
    }

    flushParagraph();
    return blocks;
  }
}

class _QuillLine {
  final String text;
  final Map<String, dynamic> attrs;
  final String? imageUrl;

  const _QuillLine({
    this.text = '',
    this.attrs = const <String, dynamic>{},
    this.imageUrl,
  });
}
