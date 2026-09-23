import 'package:anihub/ui/widgets/cover_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_cache_manager.dart';
import '../support/pump_app.dart';

const String _url = 'https://example.com/cover.jpg';

Future<void> _pump(
  WidgetTester tester,
  FakeCacheManager cacheManager, {
  String? url = _url,
}) {
  return pumpInScaffold(
    tester,
    Center(child: CoverImage(url: url, width: 48, height: 72)),
    cacheManager: cacheManager,
  );
}

/// Lets the fake manager deliver the file and the engine decode it, both of
/// which happen outside the test's fake clock.
Future<void> _settleImage(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Starts every test with an empty in-memory image cache.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('decodes a cached image at the displayed width only', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, FakeCacheManager());

    final CachedNetworkImage cached = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(cached.imageUrl, _url);
    expect(cached.memCacheWidth, 96);
    expect(cached.memCacheHeight, isNull);
    expect(cached.fit, BoxFit.cover);
  });

  testWidgets('shows a placeholder until the cached image arrives', (
    WidgetTester tester,
  ) async {
    final FakeCacheManager cacheManager = FakeCacheManager();
    await _pump(tester, cacheManager);

    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);

    await _settleImage(tester);

    expect(cacheManager.requested, <String>[_url]);
    expect(find.byIcon(Icons.movie_outlined), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    final Image image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect(
      (image.image as ResizeImage).imageProvider,
      isA<CachedNetworkImageProvider>(),
    );
  });

  testWidgets('shows the error fallback when the manager fails', (
    WidgetTester tester,
  ) async {
    await _pump(tester, FakeCacheManager(fail: true));

    await _settleImage(tester);

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsNothing);
  });

  testWidgets('shows the fallback without a URL and requests nothing', (
    WidgetTester tester,
  ) async {
    final FakeCacheManager cacheManager = FakeCacheManager();
    await _pump(tester, cacheManager, url: null);

    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(cacheManager.requested, isEmpty);
  });
}
