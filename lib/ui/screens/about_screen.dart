import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_release.dart';
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
    if (!await ref.read(externalLinksProvider).open(url)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? version = ref.watch(packageInfoProvider).value?.version;
    final bool busy = ref.watch(
      updateControllerProvider.select((UpdateState s) => s.isBusy),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
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
                title: const Text('Versión'),
                subtitle: Text(version ?? '…'),
              ),
              const _UpdateTile(),
              SwitchListTile(
                secondary: const Icon(Icons.science_outlined),
                title: const Text('Recibir versiones preliminares'),
                subtitle: const Text(
                  'Versiones de prueba, pueden tener errores',
                ),
                value: ref.watch(includePrereleasesProvider),
                onChanged: busy
                    ? null
                    : ref.read(includePrereleasesProvider.notifier).set,
              ),
              ListTile(
                leading: const Icon(Icons.new_releases_outlined),
                title: const Text('Novedades'),
                onTap: () =>
                    unawaited(_open(context, ref, ProjectLinks.releases)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Código fuente'),
                subtitle: const Text('GitHub · Licencia MIT'),
                onTap: () =>
                    unawaited(_open(context, ref, ProjectLinks.repository)),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Política de privacidad'),
                onTap: () =>
                    unawaited(_open(context, ref, ProjectLinks.privacy)),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Licencias de código abierto'),
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
                  'Los datos de anime proceden de MyAnimeList '
                  '(myanimelist.net). AniHub no está afiliada a '
                  'MyAnimeList.',
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
      UpdateIdle() => (
        'Comprueba si hay una versión nueva',
        null,
        controller.check,
      ),
      UpdateChecking() => ('Comprobando…', spinner, null),
      UpdateUpToDate() => ('Tienes la última versión', null, controller.check),
      UpdateAvailable(:final AppRelease release) => (
        'Versión ${release.version} disponible · Toca para instalar',
        const Icon(Icons.download_outlined),
        controller.install,
      ),
      UpdateDownloading(:final double progress) => (
        'Descargando… ${(progress * 100).floor()} %',
        SizedBox(
          width: _progressSize,
          height: _progressSize,
          child: CircularProgressIndicator(strokeWidth: 2, value: progress),
        ),
        null,
      ),
      UpdateInstalling() => ('Instalando…', spinner, null),
      UpdateFailed(:final UpdateFailure failure) => switch (failure) {
        UpdateFailure.check => (
          'No se pudo comprobar. Revisa la conexión',
          null,
          controller.check,
        ),
        UpdateFailure.rateLimit => (
          'GitHub ha limitado las consultas. Prueba más tarde',
          null,
          controller.check,
        ),
        UpdateFailure.download => (
          'No se pudo descargar la actualización',
          null,
          controller.install,
        ),
        UpdateFailure.checksum => (
          'La descarga está dañada. Vuelve a intentarlo',
          null,
          controller.install,
        ),
        UpdateFailure.install => (
          'No se pudo instalar la actualización',
          null,
          controller.install,
        ),
      },
    };

    return ListTile(
      leading: const Icon(Icons.system_update_outlined),
      title: const Text('Buscar actualizaciones'),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap == null ? null : () => unawaited(onTap()),
    );
  }
}
