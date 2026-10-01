import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/values/airing_reminder.dart';
import 'package:anihub/domain/values/broadcast.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/l10n/l10n.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/shell/airing_reminders_sync.dart';
import 'package:anihub/ui/state/airing_reminder_providers.dart';
import 'package:anihub/ui/state/settings_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_airing_reminders.dart';
import '../support/fake_anime_catalog.dart';
import '../support/in_memory_entry_repository.dart';
import 'support/pump_app.dart';

const Map<String, Object> _on = <String, Object>{'notifications.airing': true};

// Thursday 22:00 in Japan is 13:00 UTC, after the clock below.
final DateTime _start = DateTime.utc(2026, 9, 24, 12);

const CatalogAnime _frieren = CatalogAnime(
  malId: 1,
  title: 'Frieren',
  isAiring: true,
  broadcast: Broadcast(weekday: DateTime.thursday, hour: 22, minute: 0),
);

final Entry _watching = Entry(
  malId: 1,
  title: 'Frieren',
  status: WatchStatus.watching,
  updatedAt: DateTime.utc(2026, 9),
);

AiringReminder _at(DateTime at) =>
    AiringReminder(malId: 1, title: 'Frieren', at: at);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AiringRemindersSync)));

// The app goes to the background and comes back through the states Android
// reports.
void _resume(WidgetTester tester) {
  for (final AppLifecycleState state in <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  late FakeAiringReminders fake;
  late DateTime now;

  setUp(() {
    fake = FakeAiringReminders();
    now = _start;
  });

  Future<GoRouter> pump(
    WidgetTester tester, {
    FakeAnimeCatalog? catalog,
    InMemoryEntryRepository? repo,
    Map<String, Object> prefs = _on,
  }) {
    return pumpApp(
      tester,
      reminders: fake,
      catalog: catalog ?? FakeAnimeCatalog(airing: const [_frieren]),
      repo: repo ?? inMemoryLibrary(<Entry>[_watching]),
      prefs: prefs,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
  }

  testWidgets('schedules the watched series when the app starts', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    expect(fake.replaced.single.$1, <AiringReminder>[
      _at(DateTime.utc(2026, 9, 24, 13)),
      _at(DateTime.utc(2026, 10, 1, 13)),
    ]);
    expect(fake.replaced.single.$2.body, spanish.reminderBody);
  });

  testWidgets('reschedules when a series leaves Watching', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary(<Entry>[_watching]);
    await pump(tester, repo: repo);
    final Entry stored = (await repo.findAll()).single;

    await repo.save(stored.withStatus(WatchStatus.completed));
    await tester.pumpAndSettle();

    expect(fake.replaced.last.$1, isEmpty);
  });

  testWidgets('cancels pending reminders when turned off', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    _container(tester).read(airingRemindersEnabledProvider.notifier).disable();
    await tester.pumpAndSettle();

    expect(fake.replaced.last.$1, isEmpty);
  });

  testWidgets('leaves reminders alone when the airing list fails', (
    WidgetTester tester,
  ) async {
    final FakeAnimeCatalog catalog = FakeAnimeCatalog(
      airingError: const CatalogNetworkException('offline'),
    );
    await pump(tester, catalog: catalog);

    expect(catalog.airingRequests, isNotEmpty);
    expect(_container(tester).read(airingReminderPlanProvider), isNull);
    expect(fake.replaced, isEmpty);
  });

  testWidgets('does not request the airing list at start while reminders are '
      'off', (WidgetTester tester) async {
    final FakeAnimeCatalog catalog = FakeAnimeCatalog(airing: const [_frieren]);

    await pump(tester, catalog: catalog, prefs: const <String, Object>{});

    expect(catalog.airingRequests, isEmpty);
    expect(fake.replaced.single.$1, isEmpty);
  });

  testWidgets('reschedules in the new language', (WidgetTester tester) async {
    await pump(tester);

    _container(tester).read(appLanguageProvider.notifier).set(AppLanguage.en);
    await tester.pumpAndSettle();

    final AppLocalizations english = lookupAppLocalizations(const Locale('en'));
    expect(fake.replaced.last.$1, fake.replaced.first.$1);
    expect(fake.replaced.last.$2.body, 'Now airing in Japan');
    expect(fake.replaced.last.$2.channelName, english.reminderChannelName);
  });

  testWidgets('reschedules on resume with the clock read again', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    now = _start.add(const Duration(days: 8));
    _resume(tester);
    await tester.pumpAndSettle();

    expect(fake.replaced.last.$1.first.at, DateTime.utc(2026, 10, 8, 13));
  });

  testWidgets('reads the system permission again on resume', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    final ProviderContainer container = _container(tester);
    container.listen(airingRemindersAllowedProvider, (_, _) {});
    await tester.pumpAndSettle();
    expect(container.read(airingRemindersAllowedProvider).value, isFalse);

    fake.allowed = true;
    _resume(tester);
    await tester.pumpAndSettle();

    expect(container.read(airingRemindersAllowedProvider).value, isTrue);
  });

  testWidgets('opens the details of a tapped reminder', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester);

    fake.tapController.add(1);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/anime/1');
  });

  testWidgets('opens the details of the reminder that launched the app', (
    WidgetTester tester,
  ) async {
    fake.launch = 1;

    final GoRouter router = await pump(tester);

    expect(router.state.uri.path, '/anime/1');
  });

  testWidgets('reports a failure to schedule without crashing', (
    WidgetTester tester,
  ) async {
    fake.error = StateError('x');

    await pump(tester);

    expect(tester.takeException(), isA<StateError>());
  });
}
