import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../data/tag_repository.dart';
import '../domain/models/tag.dart';

export '../domain/models/tag.dart';

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(dioClientProvider),
    ref.watch(serverConfigProvider),
    ref.watch(connectivityServiceProvider),
  );
});

final tagsProvider = StreamProvider<List<Tag>>((ref) {
  // Trigger remote sync
  ref.watch(tagRepositoryProvider).syncFromRemote();
  return ref.watch(tagRepositoryProvider).watchAll();
});

final tagEntriesProvider =
    FutureProvider.family<List<TagEntrySummary>, int>((ref, tagLocalId) {
  return ref.watch(tagRepositoryProvider).listEntriesForTag(tagLocalId);
});
