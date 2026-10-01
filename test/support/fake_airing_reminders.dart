import 'dart:async';

import 'package:anihub/domain/ports/airing_reminders.dart';
import 'package:anihub/domain/values/airing_reminder.dart';

/// Reminders the test drives: [allowed] is the system permission, [replaced]
/// records every plan, and [tapController] simulates taps while the app runs.
class FakeAiringReminders implements AiringReminders {
  bool allowed = false;

  /// What [requestPermission] leaves in [allowed].
  bool grantOnRequest = true;
  int permissionRequests = 0;
  int settingsOpened = 0;
  final List<(List<AiringReminder>, ReminderTexts)> replaced =
      <(List<AiringReminder>, ReminderTexts)>[];
  // The fake lives as long as one test, so nothing needs to close it.
  // ignore: close_sinks
  final StreamController<int> tapController = StreamController<int>.broadcast();
  int? launch;

  /// Thrown by [replaceAll] when set.
  Object? error;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    allowed = grantOnRequest;
    return allowed;
  }

  @override
  Future<bool> areAllowed() async => allowed;

  @override
  Future<void> openSystemSettings() async => settingsOpened++;

  @override
  Future<void> replaceAll(
    List<AiringReminder> reminders,
    ReminderTexts texts,
  ) async {
    final Object? failure = error;
    if (failure != null) throw failure;
    replaced.add((reminders, texts));
  }

  @override
  Stream<int> get taps => tapController.stream;

  @override
  Future<int?> launchTap() async => launch;
}
