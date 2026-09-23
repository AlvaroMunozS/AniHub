import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/ports/image_cache_storage.dart';
import '../../../l10n/l10n.dart';
import '../../format/byte_size.dart';
import '../../providers.dart';
import '../../report_error.dart';
import '../../shell/content_column.dart';
import '../../state/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_section_header.dart';

const double _progressSize = 20;

class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() =>
      _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  bool _clearing = false;

  Future<void> _clear() async {
    if (_clearing || !await _confirmClear(context) || !mounted) return;
    setState(() => _clearing = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    final ImageCacheStorage storage = ref.read(imageCacheStorageProvider);
    try {
      await storage.clear();
      messenger.showSnackBar(SnackBar(content: Text(l10n.storageCleared)));
    } on Object catch (error, stack) {
      reportUiError(error, stack);
      messenger.showSnackBar(SnackBar(content: Text(l10n.storageClearFailed)));
    } finally {
      if (mounted) {
        ref.invalidate(imageCacheSizeProvider);
        setState(() => _clearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final AsyncValue<int> size = ref.watch(imageCacheSizeProvider);
    final String subtitle = switch (size) {
      AsyncData<int>(:final int value) => l10n.storageImageCacheSize(
        formatByteSize(value, locale),
      ),
      AsyncError<int>() => l10n.storageImageCacheSizeFailed,
      _ => l10n.storageImageCacheCalculating,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsStorage)),
      body: SafeArea(
        top: false,
        child: ContentColumn(
          maxWidth: AppLayout.readableMaxWidth,
          child: ListView(
            children: <Widget>[
              SettingsSectionHeader(l10n.storageCache),
              ListTile(
                title: Text(l10n.storageImageCache),
                subtitle: Text(subtitle),
                trailing: _clearing
                    ? const SizedBox(
                        width: _progressSize,
                        height: _progressSize,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _clearing ? null : () => unawaited(_clear()),
              ),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirmClear(BuildContext context) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(context.l10n.storageClearTitle),
      content: Text(context.l10n.storageClearMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.storageClear),
        ),
      ],
    ),
  );
  return ok ?? false;
}
