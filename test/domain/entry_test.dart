import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry({
  WatchStatus status = WatchStatus.completed,
  bool isFavorite = false,
}) => Entry(
  id: 'e-1',
  malId: 1,
  title: 'Cowboy Bebop',
  status: status,
  isFavorite: isFavorite,
  updatedAt: DateTime.utc(2024),
);

void main() {
  for (final WatchStatus status in <WatchStatus>[
    WatchStatus.watching,
    WatchStatus.planned,
  ]) {
    test('rejects a favorite that is ${status.wire}', () {
      expect(
        () => _entry(status: status, isFavorite: true),
        throwsArgumentError,
      );
    });
  }

  test('accepts a completed favorite', () {
    expect(_entry(isFavorite: true).isFavorite, isTrue);
  });

  group('withStatus', () {
    test('keeps the favorite of an entry that stays completed', () {
      final Entry entry = _entry(isFavorite: true);

      expect(entry.withStatus(WatchStatus.completed), entry);
    });

    for (final WatchStatus status in <WatchStatus>[
      WatchStatus.watching,
      WatchStatus.planned,
    ]) {
      test('clears the favorite when a favorite moves to ${status.wire}', () {
        final Entry moved = _entry(isFavorite: true).withStatus(status);

        expect(moved.status, status);
        expect(moved.isFavorite, isFalse);
      });
    }

    test('keeps every other field', () {
      final Entry entry = _entry(status: WatchStatus.planned);

      expect(
        entry.withStatus(WatchStatus.watching).withStatus(WatchStatus.planned),
        entry,
      );
    });
  });

  group('withFavorite', () {
    for (final WatchStatus status in <WatchStatus>[
      WatchStatus.watching,
      WatchStatus.planned,
    ]) {
      test('completes a ${status.wire} entry when favoriting it', () {
        final Entry favorite = _entry(status: status).withFavorite(true);

        expect(favorite.status, WatchStatus.completed);
        expect(favorite.isFavorite, isTrue);
      });
    }

    test('unfavorites an entry without changing its status', () {
      final Entry entry = _entry(isFavorite: true).withFavorite(false);

      expect(entry.status, WatchStatus.completed);
      expect(entry.isFavorite, isFalse);
    });
  });
}
