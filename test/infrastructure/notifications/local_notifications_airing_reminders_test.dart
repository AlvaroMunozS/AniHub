import 'package:anihub/domain/values/airing_reminder.dart';
import 'package:anihub/infrastructure/notifications/local_notifications_airing_reminders.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

const ReminderTexts _texts = ReminderTexts(
  channelName: 'Airing',
  channelDescription: 'New episodes',
  body: 'Airs now',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> calls = <MethodCall>[];
  final Map<String, Object?> answers = <String, Object?>{};
  // The plugin checks the date against its own clock, which the test does not
  // control, so the test uses margins of hours.
  final DateTime now = DateTime.now().toUtc();

  LocalNotificationsAiringReminders build({DateTime Function()? clock}) =>
      LocalNotificationsAiringReminders(
        AndroidFlutterLocalNotificationsPlugin(),
        now: clock ?? () => now,
      );

  AiringReminder reminder(int malId, DateTime at) =>
      AiringReminder(malId: malId, title: 'Title $malId', at: at);

  List<MethodCall> called(String method) =>
      calls.where((MethodCall c) => c.method == method).toList();

  setUp(() {
    answers['initialize'] = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          return answers[call.method];
        });
  });

  tearDown(() {
    calls.clear();
    answers.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('initializes once with the monochrome icon', () async {
    answers['areNotificationsEnabled'] = true;
    final LocalNotificationsAiringReminders reminders = build();

    await reminders.areAllowed();
    await reminders.areAllowed();

    final List<MethodCall> initializations = called('initialize');
    expect(initializations, hasLength(1));
    expect(
      (initializations.single.arguments
          as Map<Object?, Object?>)['defaultIcon'],
      'ic_stat_anihub',
    );
  });

  test('replaces pending reminders and keeps shown ones', () async {
    final DateTime first = now.add(const Duration(hours: 2));
    final DateTime second = now.add(const Duration(days: 3));

    await build().replaceAll(<AiringReminder>[
      reminder(1, first),
      reminder(2, second),
    ], _texts);

    expect(calls.map((MethodCall c) => c.method).toList(), <String>[
      'initialize',
      'cancelAllPendingNotifications',
      'createNotificationChannel',
      'zonedSchedule',
      'zonedSchedule',
    ]);
    final Map<Object?, Object?> channel =
        called('createNotificationChannel').single.arguments
            as Map<Object?, Object?>;
    expect(channel['id'], 'airing');
    expect(channel['name'], 'Airing');
    final List<Map<Object?, Object?>> scheduled = called('zonedSchedule')
        .map((MethodCall c) => c.arguments as Map<Object?, Object?>)
        .toList();
    expect(scheduled.map((Map<Object?, Object?> s) => s['title']), <String>[
      'Title 1',
      'Title 2',
    ]);
    expect(scheduled.map((Map<Object?, Object?> s) => s['payload']), <String>[
      '1',
      '2',
    ]);
    for (final Map<Object?, Object?> s in scheduled) {
      expect(s['body'], 'Airs now');
      expect(s['timeZoneName'], 'Etc/UTC');
      expect(
        (s['platformSpecifics'] as Map<Object?, Object?>)['scheduleMode'],
        'inexactAllowWhileIdle',
      );
    }
    expect(
      DateTime.parse(scheduled.first['scheduledDateTimeISO8601'] as String),
      first,
    );
    expect(
      DateTime.parse(scheduled.last['scheduledDateTimeISO8601'] as String),
      second,
    );
    expect(called('cancelAll'), isEmpty);
  });

  test('skips a reminder whose time has passed', () async {
    await build().replaceAll(<AiringReminder>[
      reminder(1, now.subtract(const Duration(seconds: 1))),
      reminder(2, now),
      reminder(3, now.add(const Duration(minutes: 1))),
    ], _texts);

    final List<MethodCall> scheduled = called('zonedSchedule');
    expect(scheduled, hasLength(1));
    expect(
      (scheduled.single.arguments as Map<Object?, Object?>)['payload'],
      '3',
    );
  });

  test('gives each broadcast its own id', () async {
    final DateTime at = now.add(const Duration(days: 1));

    await build().replaceAll(<AiringReminder>[
      reminder(1, at),
      reminder(2, at),
      reminder(1, at.add(const Duration(days: 7))),
    ], _texts);

    final Set<Object?> ids = called('zonedSchedule')
        .map((MethodCall c) => (c.arguments as Map<Object?, Object?>)['id'])
        .toSet();
    expect(ids, hasLength(3));
  });

  test('never shares an id between two series', () async {
    // Two different series whose broadcasts are 9390 minutes apart must still
    // get different ids.
    final int a =
        ((now.add(const Duration(days: 1)).millisecondsSinceEpoch ~/
                Duration.millisecondsPerMinute) |
            0x3FFF) +
        1;
    DateTime atMinute(int minute) => DateTime.fromMillisecondsSinceEpoch(
      minute * Duration.millisecondsPerMinute,
      isUtc: true,
    );

    await build().replaceAll(<AiringReminder>[
      reminder(50000, atMinute(a)),
      reminder(49698, atMinute(a + 9390)),
    ], _texts);

    final Set<Object?> ids = called('zonedSchedule')
        .map((MethodCall c) => (c.arguments as Map<Object?, Object?>)['id'])
        .toSet();
    expect(ids, hasLength(2));
  });

  test(
    'keeps scheduling after a reminder became past during the loop',
    () async {
      final List<DateTime> readings = <DateTime>[
        now,
        now.add(const Duration(hours: 2)),
        now.add(const Duration(hours: 2)),
      ];
      int next = 0;

      await build(clock: () => readings[next++]).replaceAll(<AiringReminder>[
        reminder(1, now.add(const Duration(hours: 1))),
        reminder(2, now.add(const Duration(hours: 1, minutes: 1))),
        reminder(3, now.add(const Duration(hours: 3))),
      ], _texts);

      expect(
        called('zonedSchedule').map(
          (MethodCall c) => (c.arguments as Map<Object?, Object?>)['payload'],
        ),
        <String>['1', '3'],
      );
    },
  );

  test('keeps scheduling when the plugin rejects a reminder as past', () async {
    // The adapter's clock is behind the plugin's, so the check passes and the
    // plugin throws.
    final DateTime behind = DateTime.now().toUtc().subtract(
      const Duration(hours: 1),
    );

    await build(clock: () => behind).replaceAll(<AiringReminder>[
      reminder(1, DateTime.now().toUtc().subtract(const Duration(seconds: 1))),
      reminder(2, DateTime.now().toUtc().add(const Duration(days: 1))),
    ], _texts);

    expect(
      called('zonedSchedule').map(
        (MethodCall c) => (c.arguments as Map<Object?, Object?>)['payload'],
      ),
      <String>['2'],
    );
  });

  test(
    'only cancels pending reminders when there is nothing to schedule',
    () async {
      await build().replaceAll(<AiringReminder>[], _texts);

      expect(calls.map((MethodCall c) => c.method).toList(), <String>[
        'initialize',
        'cancelAllPendingNotifications',
      ]);
    },
  );

  test('falls back to whether notifications are enabled when the system '
      'does not ask', () async {
    answers['requestNotificationsPermission'] = null;
    answers['areNotificationsEnabled'] = true;

    expect(await build().requestPermission(), isTrue);
  });

  test('reports the anime that launched the app', () async {
    answers['getNotificationAppLaunchDetails'] = <String, Object?>{
      'notificationLaunchedApp': true,
      'notificationResponse': <String, Object?>{
        'payload': '42',
        'notificationResponseType': 0,
        'notificationId': 1,
      },
    };

    expect(await build().launchTap(), 42);
  });

  test('reports no launch tap when the app was not launched by a '
      'notification', () async {
    answers['getNotificationAppLaunchDetails'] = <String, Object?>{
      'notificationLaunchedApp': false,
    };

    expect(await build().launchTap(), isNull);
  });

  group('taps', () {
    Future<void> tap(String? payload) => TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          _channel.codec.encodeMethodCall(
            MethodCall('didReceiveNotificationResponse', <String, Object?>{
              'notificationId': 1,
              'actionId': null,
              'input': null,
              'payload': payload,
              'notificationResponseType': 0,
            }),
          ),
          (ByteData? _) {},
        );

    test('emits the parsed id and ignores an unparsable payload', () async {
      final LocalNotificationsAiringReminders reminders = build();
      await reminders.areAllowed();
      final List<int> taps = <int>[];
      reminders.taps.listen(taps.add);

      await tap('42');
      await tap('not an id');
      await tap(null);
      await tap('7');
      await Future<void>.delayed(Duration.zero);

      expect(taps, <int>[42, 7]);
    });
  });
}
