import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_utils.dart' as du;
import 'diary_providers.dart';

class DiaryListScreen extends ConsumerStatefulWidget {
  const DiaryListScreen({super.key});

  @override
  ConsumerState<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends ConsumerState<DiaryListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _search = '';

  @override
  void initState() {
    super.initState();
    unawaited(_syncFromRemote());
  }

  Future<void> _syncFromRemote() async {
    if (!mounted) return;
    try {
      await ref.read(diaryRepositoryProvider).syncFromRemote();
    } catch (_) {
      // The stream below keeps showing local entries if background sync fails.
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(diarySearchQueryProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final diaries = ref.watch(diaryListProvider);
    final searchQuery = ref.watch(diarySearchQueryProvider);
    final searchResults = searchQuery.isEmpty
        ? null
        : ref.watch(diarySearchProvider(searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Diary'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search diary entries...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _searchDebounce?.cancel();
                          setState(() => _search = '');
                          ref.read(diarySearchQueryProvider.notifier).state =
                              '';
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: searchQuery.isNotEmpty
          ? searchResults!.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Search failed: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const _EmptyState(hasSearch: true);
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return isWide
                        ? _GridView(entries: list)
                        : _ListView(entries: list);
                  },
                );
              },
            )
          : diaries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const _EmptyState(hasSearch: false);
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return isWide
                        ? _GridView(entries: list)
                        : _ListView(entries: list);
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/diary/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Entry'),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  final List<DiaryEntry> entries;
  const _ListView({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: entries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _DiaryCard(entry: entries[index]),
      ),
    );
  }
}

class _GridView extends StatelessWidget {
  final List<DiaryEntry> entries;
  const _GridView({required this.entries});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 160,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _DiaryCard(entry: entries[index]),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  const _DiaryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final localId = entry.localId;
    final canOpen = localId != null;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canOpen
            ? () => context.push('/diary/$localId')
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Entry is still syncing. Please try again.'),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      du.DateUtils.toShortFormat(entry.date),
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: cs.primary),
                    ),
                  ),
                  if (entry.syncStatus == 'pending')
                    Tooltip(
                      message: 'Pending sync',
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        size: 16,
                        color: cs.outline,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.postType.value,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: cs.secondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: entry.tags
                      .take(3)
                      .map(
                        (t) => Chip(
                          label: Text(t.name),
                          labelStyle: const TextStyle(fontSize: 11),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.book_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No entries found' : 'No diary entries yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 8),
            Text(
              'Tap + to write your first entry',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
