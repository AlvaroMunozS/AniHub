import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../providers.dart';
import '../../shell/content_column.dart';
import '../../state/airing_reminder_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_section_header.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool enabled = ref.watch(airingRemindersEnabledProvider);
    final AsyncValue<bool> system = ref.watch(airingRemindersAllowedProvider);
    // While the system answer loads, the switch shows the stored choice so
    // it does not flicker.
    final bool allowed = system.value ?? enabled;
    final bool blocked = enabled && system.value == false;
    final AiringRemindersEnabledNotifier reminders = ref.read(
      airingRemindersEnabledProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNotifications)),
      body: SafeArea(
        top: false,
        child: ContentColumn(
          maxWidth: AppLayout.readableMaxWidth,
          child: ListView(
            children: <Widget>[
              SettingsSectionHeader(l10n.notificationsAiring),
              SwitchListTile(
                title: Text(l10n.notificationsAiringReminders),
                subtitle: blocked
                    ? Text(
                        l10n.notificationsBlocked,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : null,
                value: enabled && allowed,
                onChanged: (bool on) =>
                    on ? unawaited(reminders.enable()) : reminders.disable(),
              ),
              if (blocked)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                    ),
                    child: TextButton(
                      onPressed: () => unawaited(
                        ref.read(airingRemindersProvider).openSystemSettings(),
                      ),
                      child: Text(l10n.notificationsOpenSystemSettings),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        ),
      ),
    );
  }
}
