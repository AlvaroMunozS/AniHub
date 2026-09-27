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

enum _BackupAction { export, import }

class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  /// The action in progress. The system file dialogs open one at a time, so
  /// both actions wait until it ends.
  _BackupAction? _running;

  Future<void> _export() async {
    if (_running != null) {
      return;
    }
    setState(() => _running = _BackupAction.export);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    // Read before the first await: the user may leave the screen while the
    // file is saved, and `ref` cannot be used once it is disposed.
    final ExportLibrary exportLibrary = ref.read(exportLibraryProvider);
    final DateTime now = ref.read(clockProvider)();
    try {
      final int? exported = await exportLibrary(now);
      if (exported == null) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            exported == 0
                ? l10n.exportEmptyLibrary
                : l10n.exportSummary(exported),
          ),
        ),
      );
    } on Object catch (error, stack) {
      reportUiError(error, stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Future<void> _import() async {
    if (_running != null) {
      return;
    }
    setState(() => _running = _BackupAction.import);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    // Read before the first await: the user may leave the screen while the
    // file is picked, and `ref` cannot be used once it is disposed.
    final ImportLibrary importLibrary = ref.read(importLibraryProvider);
    try {
      final List<Entry>? entries = await ref
          .read(libraryBackupsProvider)
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
      if (mounted) setState(() => _running = null);
    }
  }

  Widget _actionTile({
    required _BackupAction action,
    required String title,
    required String subtitle,
    required Future<void> Function() run,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: _running == action
          ? const SizedBox(
              width: _progressSize,
              height: _progressSize,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _running == null ? () => unawaited(run()) : null,
    );
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
              SettingsSectionHeader(l10n.backupExport),
              _actionTile(
                action: _BackupAction.export,
                title: l10n.exportLibrary,
                subtitle: l10n.exportLibrarySubtitle,
                run: _export,
              ),
              SettingsSectionHeader(l10n.backupRestore),
              _actionTile(
                action: _BackupAction.import,
                title: l10n.importLibrary,
                subtitle: l10n.importLibrarySubtitle,
                run: _import,
              ),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        ),
      ),
    );
  }
}
