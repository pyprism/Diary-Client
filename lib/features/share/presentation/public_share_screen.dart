import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/content_utils.dart';
import '../../../core/utils/date_utils.dart' as du;
import '../../diary/presentation/widgets/block_renderer.dart';
import 'share_links_screen.dart';

class PublicShareScreen extends ConsumerWidget {
  final String token;

  const PublicShareScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(shareRepositoryProvider);

    return FutureBuilder(
      future: repo.getPublicShare(token),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_off, size: 64),
                  const SizedBox(height: 16),
                  const Text('This link is invalid or has expired'),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Shared Diary'),
            automaticallyImplyLeading: false,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth > 800 ? 800.0 : double.infinity;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        data.diaryTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        du.DateUtils.toDisplayFormat(data.diaryDate),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      if (data.shareType == 'EXCERPT')
                        Text(
                          data.content?.toString() ?? '',
                          style: Theme.of(context).textTheme.bodyLarge,
                        )
                      else
                        BlockRenderer(
                          content: data.content is Map<String, dynamic>
                              ? DiaryContent.fromJson(
                                  data.content as Map<String, dynamic>)
                              : DiaryContent.empty(),
                        ),
                      const SizedBox(height: 32),
                      Text(
                        'Shared via Diary App',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
