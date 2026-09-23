import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/usecases/usecases.dart';
import '../../domain/entities/entry.dart';
import '../../domain/errors/backup_format_exception.dart';
import '../../l10n/l10n.dart';
import '../providers.dart';
import '../report_error.dart';
import '../router.dart';
import '../shell/content_column.dart';
import '../theme/app_theme.dart';

const String _appIconAsset = 'assets/images/app_icon.png';
const double _headerIconSize = 96;
const double _progressSize = 20;

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
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
    return SafeArea(
      child: ContentColumn(
        maxWidth: AppLayout.readableMaxWidth,
        child: ListView(
          children: <Widget>[
            const SizedBox(height: AppSpacing.s32),
            const Center(
              child: Image(
                image: AssetImage(_appIconAsset),
                width: _headerIconSize,
                height: _headerIconSize,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: AppSpacing.s32),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: Text(context.l10n.importLibrary),
              trailing: _importing
                  ? const SizedBox(
                      width: _progressSize,
                      height: _progressSize,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _importing ? null : () => unawaited(_import()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(context.l10n.aboutTitle),
              onTap: () => context.go(RoutePaths.about),
            ),
            const SizedBox(height: AppSpacing.s24),
          ],
        ),
      ),
    );
  }
}
