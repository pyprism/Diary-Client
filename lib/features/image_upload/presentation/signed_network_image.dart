import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/image_upload_repository.dart';

/// Displays a private R2 image behind a presigned read URL, re-signing once
/// if the currently displayed URL has expired (e.g. a long-open screen).
class SignedNetworkImage extends ConsumerStatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context) placeholderBuilder;
  final Widget Function(BuildContext context) errorBuilder;

  const SignedNetworkImage({
    super.key,
    required this.url,
    required this.placeholderBuilder,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  ConsumerState<SignedNetworkImage> createState() => _SignedNetworkImageState();
}

class _SignedNetworkImageState extends ConsumerState<SignedNetworkImage> {
  bool _hasRetried = false;

  void _retryOnce() {
    if (_hasRetried) return;
    _hasRetried = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(signedImageUrlProvider(widget.url));
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedUrl = ref.watch(signedImageUrlProvider(widget.url));
    return signedUrl.when(
      data: (displayUrl) => Image.network(
        displayUrl,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : widget.placeholderBuilder(context),
        errorBuilder: (context, error, stackTrace) {
          _retryOnce();
          return widget.errorBuilder(context);
        },
      ),
      loading: () => widget.placeholderBuilder(context),
      error: (error, stackTrace) {
        _retryOnce();
        return widget.errorBuilder(context);
      },
    );
  }
}
