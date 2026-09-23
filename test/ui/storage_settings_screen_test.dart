import 'package:anihub/ui/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_image_cache_storage.dart';
import 'support/pump_app.dart';

Future<void> _pumpStorage(WidgetTester tester, FakeImageCacheStorage storage) {
  return pumpApp(
    tester,
    imageCacheStorage: storage,
    initialLocation: RoutePaths.storageSettings,
  );
}

void main() {
  testWidgets('shows the size of the cached covers', (
    WidgetTester tester,
  ) async {
    await _pumpStorage(tester, FakeImageCacheStorage(size: 12400000));

    expect(find.text('Portadas: 12,4 MB'), findsOneWidget);
  });

  testWidgets('says so when the size cannot be measured', (
    WidgetTester tester,
  ) async {
    await _pumpStorage(
      tester,
      FakeImageCacheStorage(sizeError: StateError('unreadable')),
    );

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('No se pudo calcular el tamaño'), findsOneWidget);
  });

  testWidgets('clears the cache after confirming and measures it again', (
    WidgetTester tester,
  ) async {
    final FakeImageCacheStorage storage = FakeImageCacheStorage(size: 5000);
    await _pumpStorage(tester, storage);

    await tester.tap(find.text('Caché de imágenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(storage.clears, 1);
    expect(find.text('Caché de imágenes borrada'), findsOneWidget);
    expect(find.text('Portadas: 0 B'), findsOneWidget);
  });

  testWidgets('does not clear the cache when cancelled', (
    WidgetTester tester,
  ) async {
    final FakeImageCacheStorage storage = FakeImageCacheStorage(size: 5000);
    await _pumpStorage(tester, storage);

    await tester.tap(find.text('Caché de imágenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(storage.clears, 0);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Portadas: 5 KB'), findsOneWidget);
  });

  testWidgets('reports a failure to clear the cache', (
    WidgetTester tester,
  ) async {
    await _pumpStorage(
      tester,
      FakeImageCacheStorage(size: 5000, clearError: StateError('locked')),
    );

    await tester.tap(find.text('Caché de imágenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('No se pudo borrar la caché de imágenes'), findsOneWidget);
  });
}
