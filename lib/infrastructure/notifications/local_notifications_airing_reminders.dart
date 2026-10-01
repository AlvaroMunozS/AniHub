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
    final DateTime now = _now();
    for (final AiringReminder reminder in reminders) {
      // The plugin rejects a time in the past.
      if (!reminder.at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: _idOf(reminder),
        title: reminder.title,
        body: texts.body,
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
        payload: '${reminder.malId}',
        notificationDetails: details,
        scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Stable for a broadcast, so a reminder scheduled again replaces itself
  /// instead of one in the tray for another series.
  static int _idOf(AiringReminder reminder) =>
      (reminder.malId * 31 ^
          reminder.at.millisecondsSinceEpoch ~/
              Duration.millisecondsPerMinute) &
      0x7fffffff;

  static int? _malIdOf(String? payload) =>
      payload == null ? null : int.tryParse(payload);
}
