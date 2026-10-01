import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ports/airing_reminders.dart';
import '../../domain/values/airing_reminder.dart';
import '../../l10n/l10n.dart';
import '../providers.dart';
import '../report_error.dart';
import '../router.dart';
import '../state/airing_reminder_providers.dart';

/// Keeps the system's airing reminders in step with the app while it is in
/// the foreground, and opens the anime of a tapped reminder.
///
/// The app does no background work: reminders are planned only here, when
/// their inputs change, when the app returns to the foreground and when the
/// language changes, since the texts are built from the app's strings.
class AiringRemindersSync extends ConsumerStatefulWidget {
  const AiringRemindersSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AiringRemindersSync> createState() =>
      _AiringRemindersSyncState();
}

class _AiringRemindersSyncState extends ConsumerState<AiringRemindersSync> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<int>? _taps;
  // Runs one replacement at a time, so a slow one cannot overwrite a newer
  // plan.
  Future<void> _queue = Future<void>.value();
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    ref.listenManual<List<AiringReminder>?>(
      airingReminderPlanProvider,
      (List<AiringReminder>? previous, List<AiringReminder>? next) =>
          _apply(next),
    );
    final AiringReminders reminders = ref.read(airingRemindersProvider);
    _taps = reminders.taps.listen(_open);
    unawaited(
      reminders.launchTap().then((int? id) {
        if (id != null) _open(id);
      }, onError: reportUiError),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Locale locale = Localizations.localeOf(context);
    // Also the first plan: the texts need the localizations, which are not
    // available in initState.
    if (_locale != locale) _apply(ref.read(airingReminderPlanProvider));
    _locale = locale;
  }

  void _onResume() {
    // The clock and the season are read again, and so is the permission.
    ref
      ..invalidate(airingReminderPlanProvider)
      ..invalidate(airingRemindersAllowedProvider);
  }

  void _open(int malId) {
    if (mounted) {
      unawaited(ref.read(routerProvider).push(RoutePaths.animeDetail(malId)));
    }
  }

  void _apply(List<AiringReminder>? plan) {
    if (plan == null) return;
    final AppLocalizations l10n = context.l10n;
    final ReminderTexts texts = ReminderTexts(
      channelName: l10n.reminderChannelName,
      channelDescription: l10n.reminderChannelDescription,
      body: l10n.reminderBody,
    );
    final AiringReminders reminders = ref.read(airingRemindersProvider);
    _queue = _queue
        .then((_) => reminders.replaceAll(plan, texts))
        .catchError(reportUiError);
  }

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
