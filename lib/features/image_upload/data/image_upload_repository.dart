import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/server_config.dart';
import '../../../../core/utils/content_utils.dart';

class ImageUploadRepository {
  final DioClient _client;
  final ServerConfig _config;

  ImageUploadRepository(this._client, this._config);

  Future<String> uploadImage(XFile file) async {
    final bytes = await file.readAsBytes();
    return uploadImageBytes(filename: file.name, bytes: bytes);
  }

  Future<String> uploadDataUrl(String dataUrl) async {
    final match = RegExp(
      r'^data:(image/[^;]+);base64,(.+)$',
    ).firstMatch(dataUrl);
    if (match == null) {
      throw const AppException('Invalid local image data.');
    }
    final contentType = match.group(1)!;
    final bytes = base64Decode(match.group(2)!);
    return uploadImageBytes(
      filename:
          'offline-image-${DateTime.now().millisecondsSinceEpoch}.${_extensionForContentType(contentType)}',
      bytes: bytes,
    );
  }

  Future<String> getReadUrl(String url) async {
    if (url.startsWith('data:image/')) return url;

    final normalized = _normalizeReturnedUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.queryParameters.containsKey('X-Amz-Signature')) {
      return normalized;
    }

    if (!_config.isConfigured) return normalized;

    try {
      final res = await _client.dio.post(
        _config.endpoint('uploads/read-url'),
        data: {'url': normalized},
      );
      return res.data['url'] as String? ?? normalized;
    } catch (_) {
      return normalized;
    }
  }

  Future<DiaryContent> uploadEmbeddedImages(DiaryContent content) async {
    final blocks = <ContentBlock>[];
    var changed = false;

    for (final block in content.blocks) {
      if (block.type == 'image') {
        final url = block.data['url'] as String? ?? '';
        if (url.startsWith('data:image/')) {
          final remoteUrl = await uploadDataUrl(url);
          blocks.add(ContentBlock.image(url: remoteUrl));
          changed = true;
          continue;
        }
      }
      blocks.add(block);
    }

    return changed
        ? DiaryContent(version: content.version, blocks: blocks)
        : content;
  }

  Future<String> uploadImageBytes({
    required String filename,
    required List<int> bytes,
  }) async {
    if (!_config.isConfigured) {
      throw const AppException('Server URL is not configured.');
    }

    try {
      final res = await _client.dio.post(
        _config.endpoint('uploads/image'),
        data: FormData.fromMap({
          'image': MultipartFile.fromBytes(bytes, filename: filename),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );

      return _normalizeReturnedUrl(res.data['file_url'] as String);
    } on DioException catch (e) {
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] != null) {
        throw AppException(
          detail['detail'].toString(),
          statusCode: e.response?.statusCode,
        );
      }
      if (e.message != null && e.message!.isNotEmpty) {
        throw AppException(e.message!, statusCode: e.response?.statusCode);
      }
      throw const AppException('Image upload failed');
    }
  }

  String _extensionForContentType(String contentType) {
    return switch (contentType.toLowerCase()) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  String _normalizeReturnedUrl(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      final firstSegment = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : '';
      final isLocalHost = uri.host == 'localhost' || uri.host == '127.0.0.1';
      if (isLocalHost && firstSegment.endsWith('.r2.cloudflarestorage.com')) {
        final path = uri.pathSegments.skip(1).join('/');
        final query = uri.hasQuery ? '?${uri.query}' : '';
        return 'https://$firstSegment/$path$query';
      }
      return trimmed;
    }
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    return 'https://$trimmed';
  }
}

final imageUploadRepositoryProvider = Provider<ImageUploadRepository>((ref) {
  return ImageUploadRepository(
    ref.watch(dioClientProvider),
    ref.watch(serverConfigProvider),
  );
});

final signedImageUrlProvider = FutureProvider.family<String, String>((
  ref,
  url,
) {
  return ref.watch(imageUploadRepositoryProvider).getReadUrl(url);
});
