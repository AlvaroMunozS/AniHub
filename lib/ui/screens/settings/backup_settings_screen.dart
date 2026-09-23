import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/usecases/usecases.dart';
import '../../../domain/entities/entry.dart';
import '../../../domain/errors/backup_format_exception.dart';
import '../../../l10n/l10n.dart';
import '../../providers.dart';
import '../../report_error.dart';
import '../../shell/content_column.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_section_header.dart';

const double _progressSize = 20;

class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  bool _importing = false;

  Future<void> _import() async {
    if (_importing) {
      return;
    }
    setState(() => _importing = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    // Read before the first await: the user may leave the screen while the
    // file is picked, and `ref` cannot be used once it is disposed.
    final ImportLibrary importLibrary = ref.read(importLibraryProvider);
    try {
      final List<Entry>? entries = await ref
          .read(libraryBackupSourceProvider)
          .pickLibrary();
      if (entries == null) {
        return;
      }
      final ImportSummary summary = await importLibrary(entries);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.importSummary(
              summary.added,
              summary.updated,
              summary.unchanged,
            ),
          ),
        ),
      );
    } on BackupFormatException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importInvalidFile)));
    } on Object catch (error, stack) {
      reportUiError(error, stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.importFailed)));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsBackup)),
      body: SafeArea(
        top: false,
        child: ContentColumn(
          maxWidth: AppLayout.readableMaxWidth,
          child: ListView(
            children: <Widget>[
              SettingsSectionHeader(l10n.backupRestore),
              ListTile(
                title: Text(l10n.importLibrary),
                subtitle: Text(l10n.importLibrarySubtitle),
                trailing: _importing
                    ? const SizedBox(
                        width: _progressSize,
                        height: _progressSize,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _importing ? null : () => unawaited(_import()),
              ),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        ),
      ),
    );
  }
}
