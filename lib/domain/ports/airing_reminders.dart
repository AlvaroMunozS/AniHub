import '../values/airing_reminder.dart';

/// The system's scheduled notifications for broadcasts.
abstract interface class AiringReminders {
  /// Asks for the permission to notify where the system requires it, and
  /// returns whether notifications are allowed afterwards.
  Future<bool> requestPermission();

  /// Whether the system allows the app to notify.
  Future<bool> areAllowed();

  /// Opens the system's notification settings for the app.
  Future<void> openSystemSettings();

  /// Replaces every pending reminder with [reminders]; reminders already
  /// shown stay.
  Future<void> replaceAll(List<AiringReminder> reminders, ReminderTexts texts);

  /// The MyAnimeList id of each reminder tapped while the app runs.
  Stream<int> get taps;

  /// The MyAnimeList id of the reminder that launched the app, if any.
  Future<int?> launchTap();
}
