import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/values/airing_reminder.dart';
import 'package:anihub/domain/values/anime_season.dart';
import 'package:anihub/domain/values/broadcast.dart';
import 'package:anihub/domain/values/watch_status.dart';
import 'package:anihub/ui/providers.dart';
import 'package:anihub/ui/state/airing_providers.dart';
import 'package:anihub/ui/state/airing_reminder_providers.dart';
import 'package:anihub/ui/state/library_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_airing_reminders.dart';
import '../../support/fake_anime_catalog.dart';
import '../../support/in_memory_entry_repository.dart';
import '../support/controllable_repository.dart';

const String _prefsKey = 'notifications.airing';

// A Thursday in summer; the clock sits before the slot of the series below.
final DateTime _now = DateTime(2026, 9, 24, 12);

const CatalogAnime _airing = CatalogAnime(
  malId: 1,
  title: 'Watched',
  isAiring: true,
  broadcast: Broadcast(weekday: DateTime.thursday, hour: 22, minute: 0),
);

Entry _watching() => Entry(
  malId: 1,
  title: 'Watched',
  status: WatchStatus.watching,
  updatedAt: DateTime(2026, 9),
);

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  test('plans nothing while reminders are off', () async {
    final FakeAnimeCatalog catalog = FakeAnimeCatalog(
      airing: const <CatalogAnime>[_airing],
    );
    final InMemoryEntryRepository repo = InMemoryEntryRepository(
      seed: <Entry>[_watching()],
    );
    addTearDown(repo.dispose);
    final ProviderContainer container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await _prefs({})),
        entryRepositoryProvider.overrideWithValue(repo),
        animeCatalogProvider.overrideWithValue(catalog),
        airingRemindersProvider.overrideWithValue(FakeAiringReminders()),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    container.listen(airingReminderPlanProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    expect(container.read(airingReminderPlanProvider), isEmpty);
    expect(catalog.airingRequests, isEmpty);
  });

  test(
    'requests the airing list and plans the watched series when on',
    () async {
      final FakeAnimeCatalog catalog = FakeAnimeCatalog(
        airing: const <CatalogAnime>[_airing],
      );
      final InMemoryEntryRepository repo = InMemoryEntryRepository(
        seed: <Entry>[_watching()],
      );
      addTearDown(repo.dispose);
      final ProviderContainer container = ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await _prefs({_prefsKey: true}),
          ),
          entryRepositoryProvider.overrideWithValue(repo),
          animeCatalogProvider.overrideWithValue(catalog),
          airingRemindersProvider.overrideWithValue(FakeAiringReminders()),
          clockProvider.overrideWithValue(() => _now),
        ],
      );
      container.listen(airingReminderPlanProvider, (_, _) {});
      await container.read(libraryEntriesProvider.future);
      await container.read(airingAnimeProvider(seasonAt(_now)).future);

      final List<AiringReminder>? plan = container.read(
        airingReminderPlanProvider,
      );
      expect(plan, isNotNull);
      expect(plan, isNotEmpty);
      expect(plan!.every((AiringReminder r) => r.malId == 1), isTrue);
      expect(catalog.airingRequests, <(int, AnimeSeason)>[
        (2026, AnimeSeason.summer),
      ]);
    },
  );

  test('is unknown while the library loads', () async {
    final ControllableRepository repo = ControllableRepository(<Entry>[
      _watching(),
    ]);
    addTearDown(repo.dispose);
    final ProviderContainer container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await _prefs({_prefsKey: true}),
        ),
        entryRepositoryProvider.overrideWithValue(repo),
        animeCatalogProvider.overrideWithValue(
          FakeAnimeCatalog(airing: const <CatalogAnime>[_airing]),
        ),
        airingRemindersProvider.overrideWithValue(FakeAiringReminders()),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    container.listen(airingReminderPlanProvider, (_, _) {});

    expect(container.read(airingReminderPlanProvider), isNull);
  });

  test('is unknown when the airing list fails', () async {
    final InMemoryEntryRepository repo = InMemoryEntryRepository(
      seed: <Entry>[_watching()],
    );
    addTearDown(repo.dispose);
    final ProviderContainer container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await _prefs({_prefsKey: true}),
        ),
        entryRepositoryProvider.overrideWithValue(repo),
        animeCatalogProvider.overrideWithValue(
          FakeAnimeCatalog(
            airingError: const CatalogNetworkException('offline'),
          ),
        ),
        airingRemindersProvider.overrideWithValue(FakeAiringReminders()),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    container.listen(airingReminderPlanProvider, (_, _) {});
    await container.read(libraryEntriesProvider.future);
    await expectLater(
      container.read(airingAnimeProvider(seasonAt(_now)).future),
      throwsA(isA<CatalogNetworkException>()),
    );

    expect(container.read(airingReminderPlanProvider), isNull);
  });

  test('enable stores the preference and asks for the permission', () async {
    final SharedPreferences prefs = await _prefs({});
    final FakeAiringReminders reminders = FakeAiringReminders();
    final ProviderContainer container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        airingRemindersProvider.overrideWithValue(reminders),
      ],
    );

    await container.read(airingRemindersEnabledProvider.notifier).enable();

    expect(container.read(airingRemindersEnabledProvider), isTrue);
    expect(reminders.permissionRequests, 1);
    expect(prefs.getBool(_prefsKey), isTrue);
  });

  test('disable stores false', () async {
    final SharedPreferences prefs = await _prefs({_prefsKey: true});
    final ProviderContainer container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        airingRemindersProvider.overrideWithValue(FakeAiringReminders()),
      ],
    );

    container.read(airingRemindersEnabledProvider.notifier).disable();

    expect(container.read(airingRemindersEnabledProvider), isFalse);
    expect(prefs.getBool(_prefsKey), isFalse);
  });
}
