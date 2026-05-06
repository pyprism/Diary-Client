import 'dart:convert';

class ContentBlock {
  final String type;
  final Map<String, dynamic> data;

  const ContentBlock({required this.type, required this.data});

  factory ContentBlock.heading({required int level, required String text}) =>
      ContentBlock(type: 'heading', data: {'level': level, 'text': text});

  factory ContentBlock.paragraph({required String text}) =>
      ContentBlock(type: 'paragraph', data: {'text': text});

  factory ContentBlock.bulletList({required List<String> items}) =>
      ContentBlock(type: 'bullet_list', data: {'items': items});

  factory ContentBlock.checklist({required List<Map<String, dynamic>> items}) =>
      ContentBlock(type: 'checklist', data: {'items': items});

  factory ContentBlock.quote({required String text}) =>
      ContentBlock(type: 'quote', data: {'text': text});

  factory ContentBlock.divider() => ContentBlock(type: 'divider', data: {});

  factory ContentBlock.image({required String url}) =>
      ContentBlock(type: 'image', data: {'url': url});

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: json['type'] as String,
      data: Map<String, dynamic>.from(json)..remove('type'),
    );
  }

  Map<String, dynamic> toJson() => {'type': type, ...data};

  @override
  String toString() => jsonEncode(toJson());
}

class DiaryContent {
  final int version;
  final List<ContentBlock> blocks;

  const DiaryContent({this.version = 1, required this.blocks});

  factory DiaryContent.empty() => const DiaryContent(blocks: []);

  factory DiaryContent.fromJson(Map<String, dynamic> json) {
    final blockList = (json['blocks'] as List? ?? [])
        .map((b) => ContentBlock.fromJson(b as Map<String, dynamic>))
        .toList();
    return DiaryContent(
      version: (json['version'] as int?) ?? 1,
      blocks: blockList,
    );
  }

  factory DiaryContent.fromJsonString(String jsonStr) {
    try {
      return DiaryContent.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return DiaryContent.empty();
    }
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  bool get isEmpty => blocks.isEmpty;

  String get plainText => blocks.map((b) {
        switch (b.type) {
          case 'heading':
          case 'paragraph':
          case 'quote':
            return b.data['text'] ?? '';
          case 'bullet_list':
            return (b.data['items'] as List? ?? []).join(' ');
          case 'checklist':
            return (b.data['items'] as List? ?? [])
                .map((i) => (i as Map)['text'] ?? '')
                .join(' ');
          default:
            return '';
        }
      }).join(' ');

  String? validateForApi({bool allowLocalImages = false}) {
    if (blocks.length > 500) return 'Content cannot exceed 500 blocks.';

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      switch (block.type) {
        case 'heading':
          final level = block.data['level'];
          final text = block.data['text'];
          if (level is! int || level < 1 || level > 3) {
            return 'Heading ${i + 1} must use level 1, 2, or 3.';
          }
          final error = _validateText(text, 'Heading ${i + 1}');
          if (error != null) return error;
          break;
        case 'paragraph':
          final error = _validateText(block.data['text'], 'Paragraph ${i + 1}');
          if (error != null) return error;
          break;
        case 'quote':
          final error = _validateText(block.data['text'], 'Quote ${i + 1}');
          if (error != null) return error;
          break;
        case 'bullet_list':
          final items = block.data['items'];
          if (items is! List || items.isEmpty || items.length > 200) {
            return 'Bullet list ${i + 1} must contain 1 to 200 items.';
          }
          for (var j = 0; j < items.length; j++) {
            final error = _validateText(
              items[j],
              'Bullet list ${i + 1} item ${j + 1}',
            );
            if (error != null) return error;
          }
          break;
        case 'checklist':
          final items = block.data['items'];
          if (items is! List || items.isEmpty || items.length > 200) {
            return 'Checklist ${i + 1} must contain 1 to 200 items.';
          }
          for (var j = 0; j < items.length; j++) {
            final item = items[j];
            if (item is! Map) {
              return 'Checklist ${i + 1} item ${j + 1} is invalid.';
            }
            final error = _validateText(
              item['text'],
              'Checklist ${i + 1} item ${j + 1}',
            );
            if (error != null) return error;
            if (item['checked'] is! bool) {
              return 'Checklist ${i + 1} item ${j + 1} needs a checked state.';
            }
          }
          break;
        case 'divider':
          break;
        case 'image':
          final url = block.data['url'];
          if (url is! String || url.trim().isEmpty) {
            return 'Image ${i + 1} needs a URL.';
          }
          final uri = Uri.tryParse(url);
          final validRemote =
              uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
          final validLocal = allowLocalImages && url.startsWith('data:image/');
          if (!validRemote && !validLocal) {
            return 'Image ${i + 1} must use a valid http(s) URL.';
          }
          break;
        default:
          return 'Block ${i + 1} uses unsupported type "${block.type}".';
      }
    }

    return null;
  }

  String? _validateText(Object? value, String label) {
    if (value is! String || value.trim().isEmpty) {
      return '$label cannot be empty.';
    }
    if (value.length > 10000) {
      return '$label cannot exceed 10000 characters.';
    }
    return null;
  }
}
