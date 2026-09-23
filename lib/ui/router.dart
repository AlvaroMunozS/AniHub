import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/values/watch_status.dart';
import '../l10n/l10n.dart';
import 'screens/about_screen.dart';
import 'screens/anime_detail_screen.dart';
import 'screens/library_screen.dart';
import 'screens/more_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings/appearance_settings_screen.dart';
import 'screens/settings/backup_settings_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/storage_settings_screen.dart';
import 'shell/app_shell.dart';

/// Counts the mounted detail routes. Navigating between related anime stacks
/// one detail route on top of another, so the count can exceed one.
class _AnimeDetailDepth extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;

  /// Does nothing once the container is disposed, as when the app exits with
  /// a detail route mounted.
  void decrement() {
    if (ref.mounted) state--;
  }
}

final NotifierProvider<_AnimeDetailDepth, int> _animeDetailDepthProvider =
    NotifierProvider<_AnimeDetailDepth, int>(_AnimeDetailDepth.new);

/// Whether a detail screen is on the navigation stack.
///
/// Detail routes are pushed inside the [ShellRoute], and the location that
/// [AppShell] receives keeps pointing at the originating route, so the shell
/// cannot tell from its location that it must hide the navigation bar. Each
/// detail route reports its own mount and unmount instead.
final Provider<bool> inAnimeDetailProvider = Provider<bool>(
  (Ref ref) => ref.watch(_animeDetailDepthProvider) > 0,
);

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});

class RoutePaths {
  const RoutePaths._();

  static const String search = '/search';
  static const String more = '/more';
  static const String about = '/more/about';
  static const String settings = '/more/settings';
  static const String appearanceSettings = '/more/settings/appearance';
  static const String backupSettings = '/more/settings/backup';
  static const String storageSettings = '/more/settings/storage';

  static const String libraryRoot = '/library';

  static String libraryFor(WatchStatus status) => '$libraryRoot/${status.wire}';

  static String get library => libraryFor(WatchStatus.watching);

  static const String libraryPattern = '$libraryRoot/:status';

  static const String animeDetailPattern = '/anime/:id';

  static String animeDetail(int malId) => '/anime/$malId';

  /// Returns the library tab shown at [location], or null when [location] is
  /// not a library route.
  static WatchStatus? libraryStatusOf(String location) {
    const String prefix = '$libraryRoot/';
    if (!location.startsWith(prefix)) return null;
    final String slug = location.substring(prefix.length);
    for (final WatchStatus status in WatchStatus.values) {
      if (status.wire == slug) return status;
    }
    return null;
  }
}

GoRouter buildRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation ?? RoutePaths.library,
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;
      // In-app navigation never produces an unknown status.
      final bool unknownLibraryRoute =
          location == RoutePaths.libraryRoot ||
          (location.startsWith('${RoutePaths.libraryRoot}/') &&
              RoutePaths.libraryStatusOf(location) == null);
      return unknownLibraryRoute ? RoutePaths.library : null;
    },
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.libraryPattern,
            // One route for every tab, with a fixed page key and no
            // transition: the shell's navigator keeps the same page when the
            // tab changes, so the `TabController` in `LibraryScreen` animates
            // the swipe instead of the screen being rebuilt.
            pageBuilder: (BuildContext context, GoRouterState state) {
              return NoTransitionPage<void>(
                key: const ValueKey<String>('library'),
                child: LibraryScreen(
                  status: RoutePaths.libraryStatusOf(state.matchedLocation)!,
                ),
              );
            },
          ),
          GoRoute(
            path: RoutePaths.search,
            builder: (BuildContext context, GoRouterState state) =>
                const SearchScreen(),
          ),
          GoRoute(
            path: RoutePaths.more,
            builder: (BuildContext context, GoRouterState state) =>
                const MoreScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'about',
                builder: (BuildContext context, GoRouterState state) =>
                    const AboutScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'appearance',
                    builder: (BuildContext context, GoRouterState state) =>
                        const AppearanceSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'backup',
                    builder: (BuildContext context, GoRouterState state) =>
                        const BackupSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'storage',
                    builder: (BuildContext context, GoRouterState state) =>
                        const StorageSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: RoutePaths.animeDetailPattern,
            builder: (BuildContext context, GoRouterState state) {
              final int? id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) {
                return const _InvalidAnimeRoute();
              }
              return _AnimeDetailRoute(malId: id);
            },
          ),
        ],
      ),
    ],
  );
}

/// Wraps [AnimeDetailScreen] to keep [inAnimeDetailProvider] up to date.
///
/// Both counter updates run in a post-frame callback: mounting and unmounting
/// happen while the page transition builds, and modifying a provider during a
/// build throws in debug mode.
class _AnimeDetailRoute extends ConsumerStatefulWidget {
  const _AnimeDetailRoute({required this.malId});

  final int malId;

  @override
  ConsumerState<_AnimeDetailRoute> createState() => _AnimeDetailRouteState();
}

class _AnimeDetailRouteState extends ConsumerState<_AnimeDetailRoute> {
  // Captured in `initState` because using `ref` in `dispose` throws.
  late final _AnimeDetailDepth _depth;

  /// Whether the increment ran; a route that mounts and unmounts within one
  /// frame skips it and must skip the decrement too.
  bool _counted = false;

  @override
  void initState() {
    super.initState();
    _depth = ref.read(_animeDetailDepthProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _counted = true;
      _depth.increment();
    });
  }

  @override
  void dispose() {
    if (_counted) {
      final _AnimeDetailDepth depth = _depth;
      WidgetsBinding.instance.addPostFrameCallback((_) => depth.decrement());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimeDetailScreen(malId: widget.malId);
}

/// Shown for `/anime/:id` with a non-numeric id, which in-app navigation
/// never produces.
class _InvalidAnimeRoute extends StatelessWidget {
  const _InvalidAnimeRoute();

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(context.l10n.routerAnimeNotFound));
  }
}
