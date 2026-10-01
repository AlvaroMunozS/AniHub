import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/ports/airing_reminders.dart';
import '../../domain/values/airing_reminder.dart';

/// [AiringReminders] on Android's alarm manager through
/// `flutter_local_notifications`, whose boot receiver schedules them again
/// after a reboot.
class LocalNotificationsAiringReminders implements AiringReminders {
  LocalNotificationsAiringReminders(this._plugin, {this._now = DateTime.now});

  static const String _channelId = 'airing';
  static const String _icon = 'ic_stat_anihub';

  final AndroidFlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _now;
  final StreamController<int> _taps = StreamController<int>.broadcast();

  // Lazy, so a failure here never keeps the app from starting.
  late final Future<void> _ready = _plugin.initialize(
    settings: const AndroidInitializationSettings(_icon),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (_malIdOf(response.payload) case final int id) _taps.add(id);
    },
  );

  @override
  Stream<int> get taps => _taps.stream;

  @override
  Future<int?> launchTap() async {
    await _ready;
    final NotificationAppLaunchDetails? details = await _plugin
        .getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return _malIdOf(details.notificationResponse?.payload);
  }

  @override
  Future<bool> requestPermission() async {
    await _ready;
    // Null below Android 13, where there is nothing to ask.
    return await _plugin.requestNotificationsPermission() ?? await areAllowed();
  }

  @override
  Future<bool> areAllowed() async {
    await _ready;
    return await _plugin.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> openSystemSettings() async {
    await _ready;
    await _plugin.openAppNotificationSettings();
  }

  @override
  Future<void> replaceAll(
    List<AiringReminder> reminders,
    ReminderTexts texts,
  ) async {
    await _ready;
    // Pending only: a reminder already in the tray stays until dismissed.
    await _plugin.cancelAllPendingNotifications();
    if (reminders.isEmpty) return;
    // Creating it again renames it when the app language changes.
    await _plugin.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        texts.channelName,
        description: texts.channelDescription,
      ),
    );
    final AndroidNotificationDetails details = AndroidNotificationDetails(
      _channelId,
      texts.channelName,
      channelDescription: texts.channelDescription,
      icon: _icon,
      category: AndroidNotificationCategory.reminder,
    );
    for (final AiringReminder reminder in reminders) {
      // Read per reminder: scheduling takes time, and the plugin rejects a
      // time in the past.
      if (!reminder.at.isAfter(_now())) continue;
      try {
        await _plugin.zonedSchedule(
          id: _idOf(reminder),
          title: reminder.title,
          body: texts.body,
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
          payload: '${reminder.malId}',
          notificationDetails: details,
          scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on ArgumentError {
        // Became past between the check and the plugin's own: the rest
        // still count.
        continue;
      }
    }
  }

  /// A series has at most one broadcast a day and its reminders are a week
  /// apart, so the day modulo 64 repeats only after 64 weeks, and different
  /// series never share an id. Scheduling again replaces a reminder instead
  /// of piling it up.
  static int _idOf(AiringReminder reminder) =>
      reminder.malId * 64 +
      (reminder.at.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay) % 64;

  static int? _malIdOf(String? payload) =>
      payload == null ? null : int.tryParse(payload);
}
