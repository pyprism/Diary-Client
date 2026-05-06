import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/providers.dart';
import '../../diary/presentation/diary_providers.dart';
import '../data/share_repository.dart';
import '../domain/models/share_link.dart';
import '../../../core/constants/app_constants.dart';

final shareRepositoryProvider = Provider<ShareRepository>((ref) {
  return ShareRepository(
    ref.watch(dioClientProvider),
    ref.watch(serverConfigProvider),
  );
});

final shareLinksProvider =
    FutureProvider.family<List<ShareLink>, int>((ref, diaryRemoteId) async {
  return ref.watch(shareRepositoryProvider).listLinks(diaryRemoteId);
});

final allShareLinksProvider = FutureProvider<List<ShareLink>>((ref) {
  return ref.watch(shareRepositoryProvider).listAllLinks();
});

class AllShareLinksScreen extends ConsumerWidget {
  const AllShareLinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(allShareLinksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shared Links')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(allShareLinksProvider.future),
        child: links.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [Text('Error: $e')],
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No public share links yet.')),
                ],
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth =
                    constraints.maxWidth > 860 ? 860.0 : double.infinity;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) => _ShareLinkTile(
                        link: list[index],
                        showDiaryTitle: true,
                        onDelete: () async {
                          final confirmed =
                              await _confirmDelete(context, list[index]);
                          if (!confirmed) return;
                          try {
                            await ref
                                .read(shareRepositoryProvider)
                                .deleteGlobalLink(list[index]);
                            ref.invalidate(allShareLinksProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Delete failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, ShareLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete share link?'),
        content: Text('Delete the public link for "${link.diaryTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

class ShareLinksScreen extends ConsumerStatefulWidget {
  final int diaryLocalId;
  final int? diaryRemoteId;

  const ShareLinksScreen({
    super.key,
    required this.diaryLocalId,
    required this.diaryRemoteId,
  });

  @override
  ConsumerState<ShareLinksScreen> createState() => _ShareLinksScreenState();
}

class _ShareLinksScreenState extends ConsumerState<ShareLinksScreen> {
  List<ShareLink> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.diaryRemoteId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final links = await ref
          .read(shareRepositoryProvider)
          .listLinks(widget.diaryRemoteId!);
      setState(() {
        _links = links;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Share Links',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (widget.diaryRemoteId != null)
                  FilledButton.icon(
                    onPressed: () => _showCreateSheet(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Link'),
                  ),
              ],
            ),
          ),
          if (widget.diaryRemoteId == null)
            const Expanded(
              child: Center(
                child: Text('Save the diary online first to share it'),
              ),
            )
          else if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_links.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No share links yet. Tap + to create one.',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _links.length,
                itemBuilder: (_, i) => _ShareLinkTile(
                  link: _links[i],
                  onDelete: () async {
                    final confirmed = await _confirmDelete(_links[i]);
                    if (!confirmed) return;
                    await ref.read(shareRepositoryProvider).deleteLink(
                          widget.diaryRemoteId!,
                          _links[i].token,
                        );
                    ref.invalidate(allShareLinksProvider);
                    _load();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateShareSheet(
        diaryLocalId: widget.diaryLocalId,
        diaryRemoteId: widget.diaryRemoteId!,
        onCreated: (_) => _load(),
      ),
    );
  }

  Future<bool> _confirmDelete(ShareLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete share link?'),
        content: Text('Delete this ${link.shareType.toLowerCase()} link?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _ShareLinkTile extends StatefulWidget {
  final ShareLink link;
  final VoidCallback? onDelete;
  final bool showDiaryTitle;

  const _ShareLinkTile({
    required this.link,
    this.onDelete,
    this.showDiaryTitle = false,
  });

  @override
  State<_ShareLinkTile> createState() => _ShareLinkTileState();
}

class _ShareLinkTileState extends State<_ShareLinkTile> {
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _startExpiryTimer();
  }

  @override
  void didUpdateWidget(covariant _ShareLinkTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link.expiresAt != widget.link.expiresAt ||
        oldWidget.link.isExpired != widget.link.isExpired) {
      _startExpiryTimer();
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    if (widget.link.isExpiredAt()) return;
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isExpired = widget.link.isExpiredAt(now: now);
    final expiryLabel = widget.link.expiryStatusLabel(now: now);
    final subtitle = widget.showDiaryTitle
        ? '${widget.link.shareType} - $expiryLabel\n${widget.link.publicUrl}'
        : '$expiryLabel\n${widget.link.publicUrl}';

    return Card(
      child: ListTile(
        leading: Icon(
          isExpired ? Icons.link_off : Icons.link,
          color:
              isExpired ? Colors.grey : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          widget.showDiaryTitle
              ? widget.link.diaryTitle
              : widget.link.shareType + (isExpired ? ' (expired)' : ''),
        ),
        subtitle: Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.link.publicUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied!')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 20),
              onPressed: isExpired
                  ? null
                  : () => launchUrl(
                        Uri.parse(widget.link.publicUrl),
                        mode: LaunchMode.externalApplication,
                      ),
            ),
            if (widget.onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.red),
                onPressed: widget.onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateShareSheet extends ConsumerStatefulWidget {
  final int diaryLocalId;
  final int diaryRemoteId;
  final void Function(ShareLink) onCreated;

  const _CreateShareSheet({
    required this.diaryLocalId,
    required this.diaryRemoteId,
    required this.onCreated,
  });

  @override
  ConsumerState<_CreateShareSheet> createState() => _CreateShareSheetState();
}

class _CreateShareSheetState extends ConsumerState<_CreateShareSheet> {
  String _shareType = 'FULL';
  final _excerptCtrl = TextEditingController();
  int _expirySeconds = 86400;
  bool _loading = false;

  @override
  void dispose() {
    _excerptCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final excerpt = _shareType == 'EXCERPT' ? _excerptCtrl.text.trim() : null;
      if (_shareType == 'EXCERPT') {
        final error = await _validateExcerpt(excerpt ?? '');
        if (error != null) {
          throw Exception(error);
        }
      }
      final link = await ref.read(shareRepositoryProvider).createLink(
            diaryRemoteId: widget.diaryRemoteId,
            shareType: _shareType,
            excerpt: excerpt,
            expirySeconds: _expirySeconds,
          );
      if (mounted) {
        widget.onCreated(link);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_readableError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _validateExcerpt(String excerpt) async {
    if (excerpt.isEmpty) return 'Excerpt text is required.';
    final entry =
        await ref.read(diaryRepositoryProvider).getById(widget.diaryLocalId);
    final plainText = entry?.content.plainText ?? '';
    if (!plainText.contains(excerpt)) {
      return 'Excerpt must be copied from the diary content.';
    }
    return null;
  }

  String _readableError(Object error) {
    final text = error.toString();
    return text.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Share Link',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'FULL', label: Text('Full Post')),
              ButtonSegment(value: 'EXCERPT', label: Text('Excerpt')),
            ],
            selected: {_shareType},
            onSelectionChanged: (s) => setState(() => _shareType = s.first),
          ),
          if (_shareType == 'EXCERPT') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _excerptCtrl,
              decoration: const InputDecoration(
                labelText: 'Excerpt text',
                hintText: 'Enter the text to share...',
              ),
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _expirySeconds,
            decoration: const InputDecoration(labelText: 'Expires in'),
            items: List.generate(
              AppConstants.shareExpiryOptions.length,
              (i) => DropdownMenuItem(
                value: AppConstants.shareExpiryOptions[i],
                child: Text(AppConstants.shareExpiryLabels[i]),
              ),
            ),
            onChanged: (v) => setState(() => _expirySeconds = v!),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _create,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Link'),
            ),
          ),
        ],
      ),
    );
  }
}
