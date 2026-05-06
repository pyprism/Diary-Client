import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/content_utils.dart';
import '../../../image_upload/data/image_upload_repository.dart';

class BlockRenderer extends StatelessWidget {
  final DiaryContent content;

  const BlockRenderer({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return Center(
        child: Text(
          'No content',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content.blocks.map((b) => _buildBlock(context, b)).toList(),
    );
  }

  Widget _buildBlock(BuildContext context, ContentBlock block) {
    switch (block.type) {
      case 'heading':
        return _Heading(block: block);
      case 'paragraph':
        return _Paragraph(block: block);
      case 'bullet_list':
        return _BulletList(block: block);
      case 'checklist':
        return _Checklist(block: block);
      case 'quote':
        return _Quote(block: block);
      case 'divider':
        return const _Divider();
      case 'image':
        return _ImageBlock(block: block);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _Heading extends StatelessWidget {
  final ContentBlock block;
  const _Heading({required this.block});

  @override
  Widget build(BuildContext context) {
    final level = block.data['level'] as int? ?? 1;
    final text = block.data['text'] as String? ?? '';
    final style = switch (level) {
      1 => Theme.of(context).textTheme.headlineMedium,
      2 => Theme.of(context).textTheme.headlineSmall,
      _ => Theme.of(context).textTheme.titleLarge,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: style?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final ContentBlock block;
  const _Paragraph({required this.block});

  @override
  Widget build(BuildContext context) {
    final text = block.data['text'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _BulletList extends StatelessWidget {
  final ContentBlock block;
  const _BulletList({required this.block});

  @override
  Widget build(BuildContext context) {
    final items = (block.data['items'] as List? ?? [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8, right: 8),
                        child: Icon(Icons.circle, size: 6),
                      ),
                      Expanded(
                        child: Text(item,
                            style: Theme.of(context).textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  final ContentBlock block;
  const _Checklist({required this.block});

  @override
  Widget build(BuildContext context) {
    final items = (block.data['items'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        (item['checked'] as bool? ?? false)
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['text'] as String? ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                decoration: (item['checked'] as bool? ?? false)
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  final ContentBlock block;
  const _Quote({required this.block});

  @override
  Widget build(BuildContext context) {
    final text = block.data['text'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(),
    );
  }
}

class _ImageBlock extends StatelessWidget {
  final ContentBlock block;
  const _ImageBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final url = block.data['url'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: url.isNotEmpty
              ? _buildImage(context, url)
              : Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.image_outlined)),
                ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String url) {
    final bytes = _decodeDataUrl(url);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Consumer(
      builder: (context, ref, _) {
        final signedUrl = ref.watch(signedImageUrlProvider(url));
        return signedUrl.when(
          data: (displayUrl) => Image.network(
            displayUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) =>
                _brokenImage(context),
          ),
          loading: () => _loadingImage(context),
          error: (error, stackTrace) => _brokenImage(context),
        );
      },
    );
  }

  Widget _loadingImage(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _brokenImage(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }

  Uint8List? _decodeDataUrl(String url) {
    final match = RegExp(r'^data:image/[^;]+;base64,(.+)$').firstMatch(url);
    if (match == null) return null;
    try {
      return base64Decode(match.group(1)!);
    } catch (_) {
      return null;
    }
  }
}
