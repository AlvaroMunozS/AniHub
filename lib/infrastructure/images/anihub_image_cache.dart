import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for network images: covers, banners and relation thumbnails.
///
/// Images belong to anime the user has saved or opened, so they are kept for
/// a year to render instantly and offline.
class AniHubImageCache extends CacheManager {
  AniHubImageCache()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 365),
          maxNrOfCacheObjects: _maxImages,
        ),
      );

  /// Names both the cache folder and its metadata database, so changing it
  /// orphans the existing cache.
  static const String key = 'anihubImages';

  // Caps disk use while leaving room for the covers of a large library and
  // the relation thumbnails of its franchises.
  static const int _maxImages = 3000;
}
