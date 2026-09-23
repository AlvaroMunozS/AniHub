import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_release.dart';
import '../../domain/errors/update_exception.dart';
import '../providers.dart';
import '../report_error.dart';

const String _includePrereleasesPrefsKey = 'updates.includePrereleases';

/// Whether update checks offer pre-releases, persisted in
/// `SharedPreferences`.
class IncludePrereleasesNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .watch(sharedPreferencesProvider)
          .getBool(_includePrereleasesPrefsKey) ??
      false;

  void set(bool value) {
    state = value;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setBool(_includePrereleasesPrefsKey, value),
    );
  }
}

final NotifierProvider<IncludePrereleasesNotifier, bool>
includePrereleasesProvider = NotifierProvider<IncludePrereleasesNotifier, bool>(
  IncludePrereleasesNotifier.new,
);

/// The step of an update check or installation that failed.
enum UpdateFailure { check, rateLimit, download, checksum, install }

sealed class UpdateState {
  const UpdateState();

  /// Whether a request or the installer is running.
  bool get isBusy =>
      this is UpdateChecking ||
      this is UpdateDownloading ||
      this is UpdateInstalling;
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release);

  final AppRelease release;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.release, this.progress);

  final AppRelease release;

  /// Downloaded fraction, from 0 to 1.
  final double progress;
}

class UpdateInstalling extends UpdateState {
  const UpdateInstalling(this.release);

  final AppRelease release;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.failure, [this.release]);

  final UpdateFailure failure;

  /// The release being installed, so a failed installation can be retried
  /// without checking again.
  final AppRelease? release;
}

/// Checks for a newer release and installs it, both only on request.
///
/// Kept alive, so a download continues when the user leaves the screen.
/// Changing [includePrereleasesProvider] starts over from [UpdateIdle].
class UpdateController extends Notifier<UpdateState> {
  /// Bumped on every rebuild and operation, so a result that arrives after
  /// the state moved on is dropped.
  int _generation = 0;

  @override
  UpdateState build() {
    ref.watch(includePrereleasesProvider);
    _generation++;
    return const UpdateIdle();
  }

  Future<void> check() async {
    if (state is! UpdateIdle &&
        state is! UpdateUpToDate &&
        state is! UpdateFailed) {
      return;
    }
    final int generation = ++_generation;
    state = const UpdateChecking();
    try {
      final String installed = (await ref.read(packageInfoProvider.future))
          .version;
      final AppRelease? release = await ref.read(checkForUpdateProvider)(
        installedVersion: installed,
        includePrereleases: ref.read(includePrereleasesProvider),
      );
      _emit(
        generation,
        release == null ? const UpdateUpToDate() : UpdateAvailable(release),
      );
    } on UpdateRateLimitException {
      _emit(generation, const UpdateFailed(UpdateFailure.rateLimit));
    } on UpdateException {
      _emit(generation, const UpdateFailed(UpdateFailure.check));
    } on Object catch (error, stack) {
      reportUiError(error, stack);
      _emit(generation, const UpdateFailed(UpdateFailure.check));
    }
  }

  Future<void> install() async {
    final AppRelease? release = switch (state) {
      UpdateAvailable(:final AppRelease release) => release,
      UpdateFailed(:final AppRelease? release) => release,
      _ => null,
    };
    if (release == null) return;
    final int generation = ++_generation;
    state = UpdateDownloading(release, 0);
    try {
      final bool installed = await ref
          .read(appInstallerProvider)
          .install(
            release,
            onProgress: (double progress) {
              if (progress < 1) {
                _emit(generation, UpdateDownloading(release, progress));
              } else {
                _emit(generation, UpdateInstalling(release));
              }
            },
          );
      if (!installed) _emit(generation, UpdateAvailable(release));
    } on UpdateChecksumException {
      _emit(generation, UpdateFailed(UpdateFailure.checksum, release));
    } on UpdateInstallException {
      _emit(generation, UpdateFailed(UpdateFailure.install, release));
    } on UpdateException {
      _emit(generation, UpdateFailed(UpdateFailure.download, release));
    } on Object catch (error, stack) {
      reportUiError(error, stack);
      _emit(generation, UpdateFailed(UpdateFailure.install, release));
    }
  }

  void _emit(int generation, UpdateState next) {
    if (ref.mounted && generation == _generation) state = next;
  }
}

final NotifierProvider<UpdateController, UpdateState> updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
