import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_utils.dart' as du;
import '../../../features/analysis/presentation/analysis_panel.dart';
import '../../../features/share/presentation/share_links_screen.dart';
import 'diary_providers.dart';
import 'widgets/block_renderer.dart';

class DiaryDetailScreen extends ConsumerWidget {
  final int localId;

  const DiaryDetailScreen({super.key, required this.localId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(diaryDetailStreamProvider(localId));

    return entryAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (entry) {
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Entry not found')),
          );
        }
        return _DetailView(entry: entry);
      },
    );
  }
}

class _DetailView extends ConsumerWidget {
  final DiaryEntry entry;
  const _DetailView({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final localId = entry.localId;

    return Scaffold(
      appBar: AppBar(
        title: Text(du.DateUtils.toDisplayFormat(entry.date)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: localId == null
                ? null
                : () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ShareLinksScreen(
                        diaryLocalId: localId,
                        diaryRemoteId: entry.remoteId,
                      ),
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: localId == null
                ? null
                : () => context.push('/diary/$localId/edit'),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (v) async {
              if (v == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Entry'),
                    content: const Text(
                        'Are you sure you want to delete this diary entry?'),
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
                if (confirm == true && localId != null) {
                  await ref.read(diaryRepositoryProvider).deleteDiary(localId);
                  if (context.mounted) context.go('/diary');
                }
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth > 800 ? 800.0 : constraints.maxWidth;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: SelectionArea(
                        child:
                            _DiaryDetailContent(entry: entry, colorScheme: cs),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiaryDetailContent extends StatelessWidget {
  final DiaryEntry entry;
  final ColorScheme colorScheme;

  const _DiaryDetailContent({
    required this.entry,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          entry.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        // Meta row
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  du.DateUtils.toDisplayFormat(entry.date),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.primary,
                      ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: cs.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                entry.postType.value,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.secondary),
              ),
            ),
          ],
        ),

        // Tags
        if (entry.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entry.tags.map((t) => Chip(label: Text(t.name))).toList(),
          ),
        ],

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // Content
        BlockRenderer(content: entry.content),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),

        // Analysis panel
        if (entry.remoteId != null && entry.localId != null)
          AnalysisPanel(
            diaryLocalId: entry.localId!,
            diaryRemoteId: entry.remoteId!,
          ),

        const SizedBox(height: 80),
      ],
    );
  }
}
