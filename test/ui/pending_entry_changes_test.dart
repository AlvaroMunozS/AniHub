import 'dart:async';

import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/state/library_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/controllable_repository.dart';

Entry _entry({
  String? id = 'e-1',
  bool isFavorite = false,
  WatchStatus status = WatchStatus.watching,
}) => Entry(
  id: id,
  malId: 1,
  title: 'One Piece',
  status: status,
  updatedAt: DateTime(2024),
  isFavorite: isFavorite,
);

/// Holds [patches] from the start, whatever the library emits.
class _FixedPatches extends PendingEntryChanges {
  _FixedPatches(this.patches);

  final Map<String, EntryPatch> patches;

  @override
  Map<String, EntryPatch> build() => patches;
}

PendingEntryChanges _changes(ProviderContainer container) =>
    container.read(pendingEntryChangesProvider.notifier);

/// Returns a container over [repo]; both are disposed when the test ends.
ProviderContainer _container(ControllableRepository repo) {
  addTearDown(repo.dispose);
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[entryRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  late List<FlutterErrorDetails> reported;

  setUp(() {
    reported = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
  });

  test(
    'patches a favorited entry as completed before the write completes',
    () async {
      final ProviderContainer container = _container(
        ControllableRepository(<Entry>[_entry()]),
      );

      final Future<ChangeOutcome> pending = _changes(container)
          .toggleFavorite(_entry());

      expect(container.read(pendingEntryChangesProvider), <String, EntryPatch>{
        'e-1': const EntryPatch(
          status: WatchStatus.completed,
          isFavorite: true,
        ),
      });
      expect(await pending, ChangeOutcome.applied);
    },
  );

  test('drops a patch once the stream confirms it', () async {
    final ControllableRepository repo = ControllableRepository(<Entry>[
      _entry(),
    ]);
    final ProviderContainer container = _container(repo);
    container.listen(visibleLibraryEntriesProvider, (_, _) {});
    // Lets the stream deliver its first value, so it listens for the next.
    await Future<void>.delayed(Duration.zero);

    await _changes(container).toggleFavorite(_entry());
    expect(container.read(pendingEntryChangesProvider), isNotEmpty);

    // `save` already stored the favorite, so the emission matches the patch.
    repo.emitCurrent();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(pendingEntryChangesProvider), isEmpty);
  });

  test('clears the favorite of an entry that leaves completed', () async {
    final Entry favorite = _entry(
      status: WatchStatus.completed,
      isFavorite: true,
    );
    final ProviderContainer container = _container(
      ControllableRepository(<Entry>[favorite]),
    );

    final Future<ChangeOutcome> pending = _changes(container)
        .changeStatus(favorite, WatchStatus.watching);

    expect(container.read(pendingEntryChangesProvider), <String, EntryPatch>{
      'e-1': const EntryPatch(status: WatchStatus.watching, isFavorite: false),
    });
    expect(await pending, ChangeOutcome.applied);
  });

  test('rolls back and reports a failed favorite change', () async {
    final ProviderContainer container = _container(
      ControllableRepository(<Entry>[_entry()])..failSave = true,
    );

    final ChangeOutcome outcome = await _changes(container)
        .toggleFavorite(_entry());

    expect(outcome, ChangeOutcome.failed);
    expect(container.read(pendingEntryChangesProvider), isEmpty);
    expect(reported.single.exception, isA<StateError>());
  });

  test('rolls back and reports a failed status change', () async {
    final ProviderContainer container = _container(
      ControllableRepository(<Entry>[_entry()])..failSave = true,
    );

    final ChangeOutcome outcome = await _changes(container)
        .changeStatus(_entry(), WatchStatus.completed);

    expect(outcome, ChangeOutcome.failed);
    expect(container.read(pendingEntryChangesProvider), isEmpty);
    expect(reported.single.exception, isA<StateError>());
  });

  test('rolls back and reports a failed removal', () async {
    final ProviderContainer container = _container(
      ControllableRepository(<Entry>[_entry()])..failDelete = true,
    );

    final ChangeOutcome outcome = await _changes(container).remove(_entry());

    expect(outcome, ChangeOutcome.failed);
    expect(container.read(pendingEntryChangesProvider), isEmpty);
    expect(reported.single.exception, isA<StateError>());
  });

  test('ignores an unsaved entry', () async {
    final ProviderContainer container = _container(
      ControllableRepository(<Entry>[]),
    );

    final ChangeOutcome outcome = await _changes(container)
        .toggleFavorite(_entry(id: null));

    expect(outcome, ChangeOutcome.ignored);
    expect(container.read(pendingEntryChangesProvider), isEmpty);
  });

  test('ignores a second change while one is in flight', () async {
    final ControllableRepository repo = ControllableRepository(<Entry>[
      _entry(),
    ])..saveGate = Completer<void>();
    final ProviderContainer container = _container(repo);

    final Future<ChangeOutcome> first = _changes(container)
        .toggleFavorite(_entry());
    final ChangeOutcome second = await _changes(container)
        .toggleFavorite(_entry());

    expect(second, ChangeOutcome.ignored);

    repo.saveGate!.complete();
    expect(await first, ChangeOutcome.applied);
  });

  test('applies an optimistic status change to the visible library', () async {
    final ProviderContainer container = _container(
      ControllableRepository(<Entry>[_entry()]),
    );

    // Keeps the provider alive until the stream's first value arrives.
    container.listen(visibleLibraryEntriesProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    final Future<ChangeOutcome> pending = _changes(container)
        .changeStatus(_entry(), WatchStatus.completed);

    final List<Entry>? visible = container
        .read(visibleLibraryEntriesProvider)
        .asData
        ?.value;
    expect(visible?.single.status, WatchStatus.completed);
    expect(await pending, ChangeOutcome.applied);
  });

  test('drops the favorite of a completed entry patched to another '
      'status', () async {
    final ControllableRepository repo = ControllableRepository(<Entry>[
      _entry(status: WatchStatus.completed, isFavorite: true),
    ]);
    addTearDown(repo.dispose);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        entryRepositoryProvider.overrideWithValue(repo),
        pendingEntryChangesProvider.overrideWith(
          () => _FixedPatches(<String, EntryPatch>{
            'e-1': const EntryPatch(status: WatchStatus.planned),
          }),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.listen(visibleLibraryEntriesProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    final Entry visible = container
        .read(visibleLibraryEntriesProvider)
        .requireValue
        .single;
    expect(visible.status, WatchStatus.planned);
    expect(visible.isFavorite, isFalse);
  });
}
