import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'tags_providers.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: tags.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No tags yet. Add one below.'));
          }
          return LayoutBuilder(builder: (context, constraints) {
            final maxWidth =
                constraints.maxWidth > 600 ? 600.0 : double.infinity;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _TagTile(tag: list[i]),
                ),
              ),
            );
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTagDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateTagDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Tag'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Tag name',
            hintText: 'e.g. travel',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await ref.read(tagRepositoryProvider).createTag(name);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _TagTile extends ConsumerWidget {
  final Tag tag;
  const _TagTile({required this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.label_outline),
      title: Text(tag.name),
      onTap: tag.localId == null
          ? null
          : () => context.push('/tags/${tag.localId}/entries'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Tag'),
                  content: Text('Delete "${tag.name}"?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true && tag.localId != null) {
                await ref.read(tagRepositoryProvider).deleteTag(tag.localId!);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: tag.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Tag'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Tag name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty && tag.localId != null) {
                await ref
                    .read(tagRepositoryProvider)
                    .updateTag(tag.localId!, name);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class TagEntriesScreen extends ConsumerWidget {
  final int tagLocalId;

  const TagEntriesScreen({super.key, required this.tagLocalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(tagEntriesProvider(tagLocalId));
    final tagName = ref.watch(tagsProvider).maybeWhen(
          data: (tags) => _tagName(tags, tagLocalId),
          orElse: () => null,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(tagName == null ? 'Tagged entries' : '#$tagName'),
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No entries under this tag yet.'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth > 720 ? 720.0 : double.infinity;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final entry = list[index];
                      return ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: Text(entry.title),
                        subtitle: entry.localId == null
                            ? const Text('Sync diary list to open this entry')
                            : null,
                        onTap: entry.localId == null
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This entry is not available locally yet.',
                                    ),
                                  ),
                                );
                              }
                            : () => context.push('/diary/${entry.localId}'),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String? _tagName(List<Tag> tags, int localId) {
    for (final tag in tags) {
      if (tag.localId == localId) return tag.name;
    }
    return null;
  }
}
