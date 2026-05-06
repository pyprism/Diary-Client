import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../image_upload/data/image_upload_repository.dart';
import '../data/diary_local_ds.dart';
import '../data/diary_remote_ds.dart';
import '../data/diary_repository.dart';
import '../domain/models/diary_entry.dart';

export '../domain/models/diary_entry.dart';

final diaryLocalDsProvider = Provider<DiaryLocalDataSource>((ref) {
  return DiaryLocalDataSource(ref.watch(appDatabaseProvider));
});

final diaryRemoteDsProvider = Provider<DiaryRemoteDataSource>((ref) {
  return DiaryRemoteDataSource(
    ref.watch(dioClientProvider),
    ref.watch(serverConfigProvider),
  );
});

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository(
    ref.watch(diaryLocalDsProvider),
    ref.watch(diaryRemoteDsProvider),
    ref.watch(connectivityServiceProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(imageUploadRepositoryProvider),
  );
});

final diaryListProvider = StreamProvider<List<DiaryEntry>>((ref) {
  return ref.watch(diaryRepositoryProvider).watchAll();
});

final diarySearchQueryProvider = StateProvider<String>((ref) => '');

final diarySearchProvider =
    FutureProvider.family<List<DiaryEntry>, String>((ref, query) {
  return ref.watch(diaryRepositoryProvider).searchDiaries(query);
});

final diaryDetailProvider =
    FutureProvider.family<DiaryEntry?, int>((ref, localId) async {
  return ref.watch(diaryRepositoryProvider).getFullEntry(localId);
});

final diaryDetailStreamProvider =
    StreamProvider.family<DiaryEntry?, int>((ref, localId) {
  ref.watch(diaryRepositoryProvider).getFullEntry(localId);
  return ref.watch(diaryRepositoryProvider).watchById(localId);
});
