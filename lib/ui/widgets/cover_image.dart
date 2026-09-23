import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/app_theme.dart';

/// Cover from [imageCacheManagerProvider]'s disk cache, decoded at its
/// displayed width, that fades in over a placeholder and falls back to an
/// icon for a missing URL or a failed load.
class CoverImage extends ConsumerWidget {
  const CoverImage({
    required this.url,
    this.width,
    this.height,
    this.radius = AppRadius.sm,
    super.key,
  });

  final String? url;

  /// Width and height of the image; when null, the image fills the incoming
  /// constraints.
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BaseCacheManager cacheManager = ref.watch(imageCacheManagerProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double displayWidth = width ?? constraints.maxWidth;
        final int? cacheWidth = displayWidth.isFinite && displayWidth > 0
            ? (displayWidth * MediaQuery.devicePixelRatioOf(context)).round()
            : null;
        final String? url = this.url;
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            width: width,
            height: height,
            child: url == null
                ? const _CoverFallback(icon: Icons.movie_outlined)
                : CachedNetworkImage(
                    imageUrl: url,
                    cacheManager: cacheManager,
                    fit: BoxFit.cover,
                    width: width,
                    height: height,
                    memCacheWidth: cacheWidth,
                    fadeInDuration: AppDuration.slow,
                    fadeInCurve: AppDuration.curve,
                    fadeOutDuration: Duration.zero,
                    placeholder: (BuildContext context, String url) =>
                        const _CoverFallback(icon: Icons.movie_outlined),
                    errorWidget:
                        (BuildContext context, String url, Object error) =>
                            const _CoverFallback(
                              icon: Icons.broken_image_outlined,
                            ),
                  ),
          ),
        );
      },
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.surfaceHigh,
      child: Center(child: Icon(icon, color: context.palette.textFaint)),
    );
  }
}
