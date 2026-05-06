import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/providers.dart';
import '../data/analysis_repository.dart';
import '../domain/models/diary_analysis.dart';
import '../../diary/presentation/widgets/block_renderer.dart';
import '../../diary/presentation/widgets/mood_chip.dart';
import '../../../core/utils/content_utils.dart';

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  return AnalysisRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(dioClientProvider),
    ref.watch(serverConfigProvider),
  );
});

final analysisProvider =
    FutureProvider.family<DiaryAnalysis?, ({int localId, int remoteId})>((
      ref,
      ids,
    ) async {
      return ref
          .watch(analysisRepositoryProvider)
          .getAnalysis(ids.localId, ids.remoteId);
    });

final analysisStreamProvider = StreamProvider.family<DiaryAnalysis?, int>((
  ref,
  localId,
) {
  return ref.watch(analysisRepositoryProvider).watchAnalysis(localId);
});

class AnalysisPanel extends ConsumerStatefulWidget {
  final int diaryLocalId;
  final int diaryRemoteId;

  const AnalysisPanel({
    super.key,
    required this.diaryLocalId,
    required this.diaryRemoteId,
  });

  @override
  ConsumerState<AnalysisPanel> createState() => _AnalysisPanelState();
}

class _AnalysisPanelState extends ConsumerState<AnalysisPanel> {
  bool _expanded = false;
  bool _hydrating = true;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateExisting());
  }

  @override
  void didUpdateWidget(covariant AnalysisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diaryLocalId != widget.diaryLocalId ||
        oldWidget.diaryRemoteId != widget.diaryRemoteId) {
      _hydrateExisting();
    }
  }

  Future<void> _hydrateExisting() async {
    if (!mounted) return;
    setState(() => _hydrating = true);
    try {
      await ref
          .read(analysisRepositoryProvider)
          .getAnalysis(widget.diaryLocalId, widget.diaryRemoteId);
    } finally {
      if (mounted) setState(() => _hydrating = false);
    }
  }

  Future<void> _triggerAndPoll() async {
    setState(() => _polling = true);
    final repo = ref.read(analysisRepositoryProvider);
    try {
      final analysis = await repo.triggerAnalysis(
        widget.diaryLocalId,
        widget.diaryRemoteId,
      );
      if (analysis.isPending) {
        await repo.pollUntilDone(
          widget.diaryLocalId,
          widget.diaryRemoteId,
          initialDelay: _pollDelayFor(analysis),
        );
      }
      ref.invalidate(analysisStreamProvider(widget.diaryLocalId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis request failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _polling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysisStream = ref.watch(
      analysisStreamProvider(widget.diaryLocalId),
    );
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, color: cs.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: analysisStream.when(
                                  loading: () =>
                                      const _AnalysisTitle(status: null),
                                  error: (error, stackTrace) =>
                                      const _AnalysisTitle(status: null),
                                  data: (a) => _AnalysisTitle(
                                    status: a == null ? null : _statusLabel(a),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: _expanded ? 'Collapse' : 'Expand',
                                icon: Icon(
                                  _expanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                                onPressed: () =>
                                    setState(() => _expanded = !_expanded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: analysisStream.when(
                              loading: () => const SizedBox.shrink(),
                              error: (error, stackTrace) =>
                                  const SizedBox.shrink(),
                              data: (a) => _AnalysisAction(
                                analysis: a,
                                compact: true,
                                busy: _hydrating || _polling,
                                onPressed: _triggerAndPoll,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.auto_awesome, color: cs.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: analysisStream.when(
                              loading: () => const _AnalysisTitle(status: null),
                              error: (error, stackTrace) =>
                                  const _AnalysisTitle(status: null),
                              data: (a) => _AnalysisTitle(
                                status: a == null ? null : _statusLabel(a),
                              ),
                            ),
                          ),
                          analysisStream.when(
                            loading: () => const SizedBox.shrink(),
                            error: (error, stackTrace) =>
                                const SizedBox.shrink(),
                            data: (a) => _AnalysisAction(
                              analysis: a,
                              compact: false,
                              busy: _hydrating || _polling,
                              onPressed: _triggerAndPoll,
                            ),
                          ),
                          IconButton(
                            tooltip: _expanded ? 'Collapse' : 'Expand',
                            icon: Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                            ),
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                          ),
                        ],
                      ),
              ),
              if (_expanded)
                analysisStream.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('$e'),
                  ),
                  data: (analysis) {
                    if (analysis == null) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No analysis yet. Tap "Analyze" to generate AI insights.',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      );
                    }
                    if (analysis.isPending) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Analysis in progress...'),
                          ],
                        ),
                      );
                    }
                    if (analysis.isFailed) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Analysis failed: ${analysis.error ?? "Unknown error"}',
                          style: TextStyle(color: cs.error),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (analysis.mood != null) ...[
                            MoodChip(mood: analysis.mood!),
                            const SizedBox(height: 12),
                          ],
                          if (analysis.summary != null) ...[
                            Text(
                              'Summary',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(analysis.summary!),
                            const SizedBox(height: 16),
                          ],
                          if (analysis.banglaContent != null) ...[
                            Text(
                              'Bengali Translation',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            BlockRenderer(
                              content: DiaryContent.fromJson(
                                analysis.banglaContent!,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalysisTitle extends StatelessWidget {
  final String? status;

  const _AnalysisTitle({required this.status});

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Analysis',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (status != null) ...[
          const SizedBox(height: 2),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnalysisAction extends StatelessWidget {
  final DiaryAnalysis? analysis;
  final bool compact;
  final bool busy;
  final VoidCallback onPressed;

  const _AnalysisAction({
    required this.analysis,
    required this.compact,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final analysis = this.analysis;
    if (busy || (analysis != null && analysis.isPending)) {
      return const SizedBox.square(
        dimension: 36,
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final retry = analysis != null && analysis.isFailed;
    final rerun = analysis != null && analysis.isDone;
    if (compact) {
      return IconButton(
        tooltip: retry
            ? 'Retry analysis'
            : rerun
            ? 'Analyze again'
            : 'Analyze',
        onPressed: onPressed,
        icon: Icon(retry || rerun ? Icons.refresh : Icons.play_arrow),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(retry || rerun ? Icons.refresh : Icons.play_arrow, size: 18),
      label: Text(
        retry
            ? 'Retry'
            : rerun
            ? 'Analyze again'
            : 'Analyze',
      ),
    );
  }
}

String _statusLabel(DiaryAnalysis analysis) {
  if (analysis.isDone) return 'Completed';
  if (analysis.isFailed) return 'Failed';
  if (analysis.status == DiaryAnalysis.processing) return 'Processing';
  return 'Pending';
}

Duration _pollDelayFor(DiaryAnalysis analysis) {
  final seconds = analysis.retryAfterSeconds;
  if (seconds == null || seconds <= 0) {
    return AppConstants.analysisPollInterval;
  }
  return Duration(seconds: seconds);
}
