import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_release.dart';
import '../../l10n/l10n.dart';
import '../project_links.dart';
import '../providers.dart';
import '../shell/content_column.dart';
import '../state/update_providers.dart';
import '../theme/app_theme.dart';

const String _appIconAsset = 'assets/images/app_icon.png';
const double _headerIconSize = 96;
const double _licenseIconSize = 48;
const double _progressSize = 20;

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Uri url) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String failure = context.l10n.aboutOpenLinkFailed;
    if (!await ref.read(externalLinksProvider).open(url)) {
      messenger.showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? version = ref.watch(packageInfoProvider).value?.version;
    final bool busy = ref.watch(
      updateControllerProvider.select((UpdateState s) => s.isBusy),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        top: false,
        child: ContentColumn(
          maxWidth: AppLayout.readableMaxWidth,
          child: ListView(
            children: <Widget>[
              const SizedBox(height: AppSpacing.s24),
              const Center(
                child: Image(
                  image: AssetImage(_appIconAsset),
                  width: _headerIconSize,
                  height: _headerIconSize,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Center(
                child: Text(
                  'AniHub',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.aboutVersion),
                subtitle: Text(version ?? '…'),
              ),
              const _UpdateTile(),
              SwitchListTile(
                secondary: const Icon(Icons.science_outlined),
                title: Text(l10n.aboutPrereleases),
                subtitle: Text(l10n.aboutPrereleasesSubtitle),
                value: ref.watch(includePrereleasesProvider),
                onChanged: busy
                    ? null
                    : ref.read(includePrereleasesProvider.notifier).set,
              ),
              ListTile(
                leading: const Icon(Icons.new_releases_outlined),
                title: Text(l10n.aboutWhatsNew),
                onTap: () =>
                    unawaited(_open(context, ref, ProjectLinks.releases)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(l10n.aboutSourceCode),
                subtitle: Text(l10n.aboutSourceCodeSubtitle),
                onTap: () =>
                    unawaited(_open(context, ref, ProjectLinks.repository)),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l10n.aboutPrivacy),
                onTap: () =>
                    unawaited(_open(context, ref, ProjectLinks.privacy)),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.aboutLicenses),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'AniHub',
                  applicationVersion: version,
                  applicationIcon: const Padding(
                    padding: EdgeInsets.all(AppSpacing.s8),
                    child: Image(
                      image: AssetImage(_appIconAsset),
                      width: _licenseIconSize,
                      height: _licenseIconSize,
                    ),
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Text(
                  l10n.aboutAttribution,
                  style: Theme.of(context).textTheme.bodySmall,
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

/// Checks for updates and installs them, showing the progress in place.
class _UpdateTile extends ConsumerWidget {
  const _UpdateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final UpdateState state = ref.watch(updateControllerProvider);
    final UpdateController controller = ref.read(
      updateControllerProvider.notifier,
    );

    const Widget spinner = SizedBox(
      width: _progressSize,
      height: _progressSize,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    final (
      String subtitle,
      Widget? trailing,
      Future<void> Function()? onTap,
    ) = switch (state) {
      UpdateIdle() => (l10n.aboutUpdateIdle, null, controller.check),
      UpdateChecking() => (l10n.aboutUpdateChecking, spinner, null),
      UpdateUpToDate() => (l10n.aboutUpdateUpToDate, null, controller.check),
      UpdateAvailable(:final AppRelease release) => (
        l10n.aboutUpdateAvailable(release.version.toString()),
        const Icon(Icons.download_outlined),
        controller.install,
      ),
      UpdateDownloading(:final double progress) => (
        l10n.aboutUpdateDownloading((progress * 100).floor()),
        SizedBox(
          width: _progressSize,
          height: _progressSize,
          child: CircularProgressIndicator(strokeWidth: 2, value: progress),
        ),
        null,
      ),
      UpdateInstalling() => (l10n.aboutUpdateInstalling, spinner, null),
      UpdateFailed(:final UpdateFailure failure) => switch (failure) {
        UpdateFailure.check => (
          l10n.aboutUpdateCheckFailed,
          null,
          controller.check,
        ),
        UpdateFailure.rateLimit => (
          l10n.aboutUpdateRateLimited,
          null,
          controller.check,
        ),
        UpdateFailure.download => (
          l10n.aboutUpdateDownloadFailed,
          null,
          controller.install,
        ),
        UpdateFailure.checksum => (
          l10n.aboutUpdateChecksumFailed,
          null,
          controller.install,
        ),
        UpdateFailure.install => (
          l10n.aboutUpdateInstallFailed,
          null,
          controller.install,
        ),
      },
    };

    return ListTile(
      leading: const Icon(Icons.system_update_outlined),
      title: Text(l10n.aboutCheckForUpdates),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap == null ? null : () => unawaited(onTap()),
    );
  }
}
