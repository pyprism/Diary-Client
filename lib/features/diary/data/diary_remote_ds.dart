import '../../../../core/network/dio_client.dart';
import '../../../../core/network/server_config.dart';
import '../domain/models/diary_entry.dart';

class DiaryRemoteDataSource {
  final DioClient _client;
  final ServerConfig _config;

  DiaryRemoteDataSource(this._client, this._config);

  String get _base => _config.endpoint('diaries');

  Future<List<DiaryListItem>> listDiaries({
    int page = 1,
    String? search,
    String? dateFrom,
    String? dateTo,
    String? postType,
    List<String>? tags,
    String ordering = '-date',
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'ordering': ordering,
      'search': ?search,
      'date_from': ?dateFrom,
      'date_to': ?dateTo,
      'post_type': ?postType,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
    };
    final res = await _client.dio.get(_base, queryParameters: params);
    final results = res.data['results'] as List? ?? [];
    return results
        .map((e) => DiaryListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DiaryEntry> getDiary(int remoteId) async {
    final res = await _client.dio.get(_config.endpoint('diaries/$remoteId'));
    return DiaryEntry.fromJson(res.data as Map<String, dynamic>);
  }

  Future<DiaryEntry> createDiary(Map<String, dynamic> data) async {
    final res = await _client.dio.post(_base, data: data);
    return DiaryEntry.fromJson(res.data as Map<String, dynamic>);
  }

  Future<DiaryEntry> updateDiary(
      int remoteId, Map<String, dynamic> data) async {
    final res = await _client.dio
        .patch(_config.endpoint('diaries/$remoteId'), data: data);
    return DiaryEntry.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteDiary(int remoteId) async {
    await _client.dio.delete(_config.endpoint('diaries/$remoteId'));
  }
}
