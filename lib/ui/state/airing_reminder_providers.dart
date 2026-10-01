import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/catalog_anime.dart';
import '../../domain/values/airing_reminder.dart';
import '../providers.dart';
import 'airing_providers.dart';
import 'library_providers.dart';

const String _enabledPrefsKey = 'notifications.airing';

/// Whether the user wants airing reminders. The system may still block
/// them; see [airingRemindersAllowedProvider].
class AiringRemindersEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_enabledPrefsKey) ?? false;

  /// Stores the choice before asking, so that allowing notifications later
  /// in the system settings turns reminders on without another tap.
  Future<void> enable() async {
    _store(true);
    await ref.read(airingRemindersProvider).requestPermission();
    ref.invalidate(airingRemindersAllowedProvider);
  }

  void disable() => _store(false);

  void _store(bool value) {
    state = value;
    unawaited(
      ref.read(sharedPreferencesProvider).setBool(_enabledPrefsKey, value),
    );
  }
}

final NotifierProvider<AiringRemindersEnabledNotifier, bool>
airingRemindersEnabledProvider =
    NotifierProvider<AiringRemindersEnabledNotifier, bool>(
      AiringRemindersEnabledNotifier.new,
    );

/// Whether the system lets the app notify; read again when the app resumes,
/// since it can change in the system settings.
final FutureProvider<bool> airingRemindersAllowedProvider =
    FutureProvider<bool>(
      (Ref ref) => ref.watch(airingRemindersProvider).areAllowed(),
    );

/// The reminders to schedule now, or null while the data they need is not
/// there.
///
/// Null is not empty: an empty plan cancels what was scheduled, while a
/// library still loading or an airing list that failed offline must leave the
/// reminders already set alone.
final Provider<List<AiringReminder>?> airingReminderPlanProvider =
    Provider<List<AiringReminder>?>((Ref ref) {
      if (!ref.watch(airingRemindersEnabledProvider)) {
        return const <AiringReminder>[];
      }
      if (!ref.watch(visibleLibraryEntriesProvider).hasValue) return null;
      final DateTime now = ref.watch(clockProvider)();
      final AsyncValue<List<CatalogAnime>> airing = ref.watch(
        airingAnimeProvider(seasonAt(now)),
      );
      if (!airing.hasValue || airing.hasError) return null;
      return ref.watch(planAiringRemindersProvider)(
        airing.requireValue,
        watching: ref.watch(watchingIdsProvider),
        now: now,
      );
    });
