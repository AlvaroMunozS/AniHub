import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../router.dart';
import '../../shell/content_column.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        top: false,
        child: ContentColumn(
          maxWidth: AppLayout.readableMaxWidth,
          child: ListView(
            children: <Widget>[
              const SizedBox(height: AppSpacing.s8),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(l10n.settingsAppearance),
                onTap: () => context.go(RoutePaths.appearanceSettings),
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: Text(l10n.settingsBackup),
                onTap: () => context.go(RoutePaths.backupSettings),
              ),
              ListTile(
                leading: const Icon(Icons.sd_storage_outlined),
                title: Text(l10n.settingsStorage),
                onTap: () => context.go(RoutePaths.storageSettings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
