import '../../../../core/network/dio_client.dart';
import '../../../../core/network/server_config.dart';
import '../domain/models/share_link.dart';

class ShareRepository {
  final DioClient _client;
  final ServerConfig _config;

  ShareRepository(this._client, this._config);

  String _base(int diaryRemoteId) =>
      _config.endpoint('diaries/$diaryRemoteId/shares');

  Future<List<ShareLink>> listLinks(int diaryRemoteId) async {
    final res = await _client.dio.get(_base(diaryRemoteId));
    return (res.data as List)
        .map((e) => ShareLink.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ShareLink>> listAllLinks() async {
    final res = await _client.dio.get(_config.endpoint('shares'));
    return (res.data as List)
        .map((e) => ShareLink.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShareLink> createLink({
    required int diaryRemoteId,
    String shareType = 'FULL',
    String? excerpt,
    int? expirySeconds,
  }) async {
    final data = <String, dynamic>{'share_type': shareType};
    if (excerpt != null) data['excerpt'] = excerpt;
    if (expirySeconds != null) data['expiry_seconds'] = expirySeconds;

    final res = await _client.dio.post(_base(diaryRemoteId), data: data);
    return ShareLink.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteLink(int diaryRemoteId, String token) async {
    await _client.dio.delete(
      _config.endpoint('diaries/$diaryRemoteId/shares/$token'),
    );
  }

  Future<void> deleteGlobalLink(ShareLink link) async {
    final diaryId = link.diaryId;
    if (diaryId == null) {
      throw StateError('Share link response is missing diary_id.');
    }
    await deleteLink(diaryId, link.token);
  }

  Future<PublicShareData> getPublicShare(String token) async {
    final res = await _client.dio.get(_config.endpoint('share/$token'));
    return PublicShareData.fromJson(res.data as Map<String, dynamic>);
  }
}
