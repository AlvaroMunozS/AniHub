import 'package:anihub/ui/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_airing_reminders.dart';
import 'support/pump_app.dart';

const Map<String, Object> _on = <String, Object>{'notifications.airing': true};

Future<void> _pump(
  WidgetTester tester,
  FakeAiringReminders fake, {
  Map<String, Object> prefs = const <String, Object>{},
}) {
  return pumpApp(
    tester,
    initialLocation: RoutePaths.notificationSettings,
    reminders: fake,
    prefs: prefs,
  );
}

bool _switchValue(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

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

Future<bool?> _storedPreference() async =>
    (await SharedPreferences.getInstance()).getBool('notifications.airing');

void main() {
  testWidgets('is off by default and shows no warning', (
    WidgetTester tester,
  ) async {
    await _pump(tester, FakeAiringReminders());

    expect(_switchValue(tester), isFalse);
    expect(find.text(spanish.notificationsBlocked), findsNothing);
  });

  testWidgets('turns on after the permission is granted', (
    WidgetTester tester,
  ) async {
    final FakeAiringReminders fake = FakeAiringReminders();
    await _pump(tester, fake);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(fake.permissionRequests, 1);
    expect(_switchValue(tester), isTrue);
    expect(await _storedPreference(), isTrue);
    expect(find.text(spanish.notificationsBlocked), findsNothing);
  });

  testWidgets('stays off and says why when the permission is denied', (
    WidgetTester tester,
  ) async {
    final FakeAiringReminders fake = FakeAiringReminders()
      ..grantOnRequest = false;
    await _pump(tester, fake);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(_switchValue(tester), isFalse);
    expect(find.text(spanish.notificationsBlocked), findsOneWidget);

    await tester.tap(find.text(spanish.notificationsOpenSystemSettings));
    await tester.pumpAndSettle();

    expect(fake.settingsOpened, 1);
  });

  testWidgets('turns on by itself when allowed in the system after a denial', (
    WidgetTester tester,
  ) async {
    final FakeAiringReminders fake = FakeAiringReminders();
    await _pump(tester, fake, prefs: _on);
    expect(find.text(spanish.notificationsBlocked), findsOneWidget);

    fake.allowed = true;
    _resume(tester);
    await tester.pumpAndSettle();

    expect(_switchValue(tester), isTrue);
    expect(find.text(spanish.notificationsBlocked), findsNothing);
  });

  testWidgets('turning it off hides the warning', (WidgetTester tester) async {
    final FakeAiringReminders fake = FakeAiringReminders()..allowed = true;
    await _pump(tester, fake, prefs: _on);
    expect(_switchValue(tester), isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(_switchValue(tester), isFalse);
    expect(await _storedPreference(), isFalse);
    expect(find.text(spanish.notificationsBlocked), findsNothing);
  });
}
