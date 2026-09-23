import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../application/usecases/usecases.dart';
import '../../domain/entities/entry.dart';
import '../../domain/errors/backup_format_exception.dart';
import '../providers.dart';
import '../report_error.dart';
import '../shell/content_column.dart';
import '../theme/app_theme.dart';

const String _appIconAsset = 'assets/images/app_icon.png';
const double _headerIconSize = 96;
const double _dialogIconSize = 48;
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
      messenger.showSnackBar(SnackBar(content: Text(_describe(summary))));
    } on BackupFormatException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('El fichero no es una biblioteca de AniHub válida'),
        ),
      );
    } on Object catch (error, stack) {
      reportUiError(error, stack);
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo importar la biblioteca')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  static String _describe(ImportSummary summary) {
    String count(int n, String singular, String plural) =>
        '$n ${n == 1 ? singular : plural}';
    return 'Biblioteca importada: '
        '${count(summary.added, 'nueva', 'nuevas')}, '
        '${count(summary.updated, 'actualizada', 'actualizadas')}, '
        '${summary.unchanged} sin cambios';
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PackageInfo> info = ref.watch(packageInfoProvider);

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
              title: const Text('Importar biblioteca'),
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
              title: const Text('Acerca de'),
              subtitle: Text(
                info.hasValue
                    ? 'Versión ${info.value!.version} · Datos de MyAnimeList'
                    : 'Datos de MyAnimeList',
              ),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'AniHub',
                applicationVersion: info.value?.version,
                applicationIcon: Image.asset(
                  _appIconAsset,
                  width: _dialogIconSize,
                  height: _dialogIconSize,
                ),
                children: const <Widget>[
                  Text(
                    'Los datos de anime proceden de MyAnimeList '
                    '(myanimelist.net). AniHub no está afiliada a '
                    'MyAnimeList.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
          ],
        ),
      ),
    );
  }
}
