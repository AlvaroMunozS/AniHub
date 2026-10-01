import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/usecases/usecases.dart';
import '../../../domain/entities/catalog_anime.dart';
import '../../../domain/values/anime_season.dart';
import '../../../l10n/l10n.dart';
import '../../catalog_messages.dart';
import '../../format/anime_meta.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shell/content_column.dart';
import '../../state/airing_providers.dart';
import '../../state/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../catalog_card.dart';
import '../empty_state.dart';
import '../poster_grid.dart';
import '../skeleton.dart';

/// Diameter of the dot that marks today's tab.
const double _todayDotSize = 5;

/// The season running now, one tab per local weekday, opening on today; or,
/// after stepping with the header's arrows, a past season or the next one as a
/// single grid, most followed first.
///
/// Anime in [inLibrary] are dimmed, as in search results, unless the current
/// season is filtered to the series being watched, which are then listed by
/// broadcast time. The season and today are read from the clock on every
/// build, and the broadcast times are converted again when the app returns to
/// the foreground, since the app can stay open across midnight, a season, a
/// daylight saving change or a move to another time zone.
class AiringView extends ConsumerStatefulWidget {
  const AiringView({required this.inLibrary, super.key});

  /// MyAnimeList ids of the library's entries.
  final Set<int> inLibrary;

  @override
  ConsumerState<AiringView> createState() => _AiringViewState();
}

class _AiringViewState extends ConsumerState<AiringView> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      // The season and today come from the clock, not from a provider, so
      // `setState` rebuilds them; the conversion is cached in a provider, so
      // it has to be invalidated as well.
      ref.invalidate(
        airingScheduleProvider(seasonAt(ref.read(clockProvider)())),
      );
      ref.invalidate(airingCanFilterProvider);
      setState(() {});
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = ref.watch(clockProvider)();
    final int offset = ref.watch(browsedSeasonOffsetProvider);
    final YearSeason season = seasonAt(now).shifted(offset);
    final FutureProvider<List<CatalogAnime>> source = offset == 0
        ? airingAnimeProvider(season)
        : seasonPremieresProvider(season);
    final AsyncValue<List<CatalogAnime>> list = ref.watch(source);

    final List<CatalogAnime>? loaded = list.value;
    final AiringSchedule? schedule = offset == 0 && loaded != null
        ? ref.watch(airingScheduleProvider(season))
        : null;
    final List<CatalogAnime>? ranked = offset != 0 && loaded != null
        ? ref.watch(rankSeasonProvider)(loaded, upcoming: offset > 0)
        : null;
    // Elsewhere the bookmark is hidden and the preference is kept.
    final bool mine =
        ref.watch(airingCanFilterProvider) && ref.watch(airingOnlyMineProvider);
    final AiringSchedule? shown = mine
        ? schedule!.only(ref.watch(watchingIdsProvider))
        : schedule;
    final String? count = switch ((shown, ranked)) {
      (final AiringSchedule s, _) when !s.isEmpty =>
        context.l10n.searchAiringCount(s.length),
      (_, final List<CatalogAnime> r) when r.isNotEmpty =>
        context.l10n.searchSeasonCount(r.length),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SeasonHeader(
          season: season,
          offset: offset,
          count: count,
          loading: list.isLoading && loaded == null,
        ),
        Expanded(
          // A failed refresh keeps the last list; the grid reports it.
          child: list.when(
            skipError: true,
            loading: () => _AiringSkeleton(tabs: offset == 0),
            error: (Object error, StackTrace stackTrace) => ContentColumn(
              child: EmptyState(
                icon: catalogErrorIcon(error),
                title: context.l10n.searchAiringFailed,
                message: catalogErrorMessage(context.l10n, error),
                actionLabel: context.l10n.commonRetry,
                onAction: () => ref.invalidate(source),
              ),
            ),
            data: (List<CatalogAnime> _) => switch ((schedule, ranked)) {
              (final AiringSchedule s, _) when s.isEmpty => ContentColumn(
                child: EmptyState(
                  icon: Icons.live_tv_outlined,
                  title: context.l10n.searchAiringEmptyTitle,
                  message: context.l10n.searchAiringEmptyMessage,
                ),
              ),
              (AiringSchedule(), _) when shown!.isEmpty => RefreshIndicator(
                onRefresh: () =>
                    _refresh(context, ref, airingAnimeProvider(season)),
                child: _ScrollableEmpty(
                  storageKey: const PageStorageKey<String>('mine'),
                  child: EmptyState(
                    icon: Icons.live_tv_outlined,
                    title: context.l10n.searchAiringMineEmptyTitle,
                    message: context.l10n.searchAiringMineEmptyMessage,
                    actionLabel: context.l10n.searchAiringMineShowAll,
                    onAction: () =>
                        ref.read(airingOnlyMineProvider.notifier).set(false),
                  ),
                ),
              ),
              (AiringSchedule(), _) => _AiringTabs(
                season: season,
                today: now.weekday,
                schedule: shown!,
                inLibrary: mine ? const <int>{} : widget.inLibrary,
                dayEmptyTitle: mine
                    ? context.l10n.searchAiringMineDayEmpty
                    : context.l10n.searchAiringDayEmpty,
              ),
              (_, final List<CatalogAnime> r) => _SeasonGrid(
                season: season,
                anime: r,
                inLibrary: widget.inLibrary,
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    );
  }
}

class _AiringTabs extends ConsumerWidget {
  const _AiringTabs({
    required this.season,
    required this.today,
    required this.schedule,
    required this.inLibrary,
    required this.dayEmptyTitle,
  });

  final YearSeason season;

  /// From [DateTime.monday] to [DateTime.sunday].
  final int today;

  final AiringSchedule schedule;
  final Set<int> inLibrary;

  /// Shown on a day without anime.
  final String dayEmptyTitle;

  /// Weekdays from [DateTime.monday] to [DateTime.sunday], starting on
  /// [first].
  static List<int> _weekdays(int first) => <int>[
    for (int i = 0; i < DateTime.daysPerWeek; i++)
      (first + i - 1) % DateTime.daysPerWeek + 1,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<int> weekdays = _weekdays(ref.watch(firstWeekdayProvider));
    final DateFormat dayName = DateFormat.E(
      Localizations.localeOf(context).toLanguageTag(),
    );

    return DefaultTabController(
      // A new controller when the first day or today change, since its
      // index would point at another day.
      key: ValueKey<(int, int)>((weekdays.first, today)),
      length: weekdays.length,
      initialIndex: weekdays.indexOf(today),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ContentColumn(
            padded: false,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Widget>[
                for (final int weekday in weekdays)
                  _DayTab(
                    label: dayName.format(_dateOnWeekday(weekday)),
                    isToday: weekday == today,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                for (final int weekday in weekdays)
                  _AiringGrid(
                    season: season,
                    storageKey: weekday,
                    anime: <_AiringItem>[
                      for (final ScheduledAnime item
                          in schedule.byWeekday[weekday] ??
                              const <ScheduledAnime>[])
                        (
                          anime: item.anime,
                          time: _formatTime(context, item.hour, item.minute),
                        ),
                    ],
                    inLibrary: inLibrary,
                    dayEmptyTitle: dayEmptyTitle,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A date that falls on [weekday], to name it; 2024-01-01 was a Monday.
  static DateTime _dateOnWeekday(int weekday) =>
      DateTime(2024, 1, weekday - DateTime.monday + 1);

  static String? _formatTime(BuildContext context, int? hour, int? minute) {
    if (hour == null || minute == null) return null;
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: hour, minute: minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
}

/// A weekday tab; today's carries a dot in the accent color.
class _DayTab extends StatelessWidget {
  const _DayTab({required this.label, required this.isToday});

  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    if (!isToday) return Tab(text: label);
    return Tab(
      child: Semantics(
        label: context.l10n.searchAiringToday(label),
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label),
            const SizedBox(width: AppSpacing.s4),
            Container(
              width: _todayDotSize,
              height: _todayDotSize,
              decoration: BoxDecoration(
                color: context.palette.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _AiringItem = ({CatalogAnime anime, String? time});

class _AiringGrid extends ConsumerWidget {
  const _AiringGrid({
    required this.season,
    required this.storageKey,
    required this.anime,
    required this.inLibrary,
    required this.dayEmptyTitle,
  });

  /// The season that pulling to refresh requests again.
  final YearSeason season;

  /// Keeps the scroll position of each tab apart.
  final int storageKey;
  final List<_AiringItem> anime;
  final Set<int> inLibrary;

  /// Shown on a day without anime.
  final String dayEmptyTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => _refresh(context, ref, airingAnimeProvider(season)),
      child: anime.isEmpty
          // Scrollable so that an empty day can be pulled to refresh too.
          ? _ScrollableEmpty(
              storageKey: PageStorageKey<int>(storageKey),
              child: EmptyState(
                icon: Icons.event_available_outlined,
                title: dayEmptyTitle,
              ),
            )
          : ContentColumn(
              alignment: Alignment.topCenter,
              child: PosterGrid(
                key: PageStorageKey<int>(storageKey),
                itemCount: anime.length,
                itemBuilder: (BuildContext context, int index) {
                  final _AiringItem item = anime[index];
                  return CatalogCard(
                    anime: item.anime,
                    caption: item.time,
                    inLibrary: inLibrary.contains(item.anime.malId),
                    onOpen: () =>
                        context.push(RoutePaths.animeDetail(item.anime.malId)),
                  );
                },
              ),
            ),
    );
  }
}

/// The season shown, the arrows that step to another one and how many anime
/// it lists.
class _SeasonHeader extends ConsumerWidget {
  const _SeasonHeader({
    required this.season,
    required this.offset,
    required this.count,
    required this.loading,
  });

  final YearSeason season;

  /// Seasons from the current one; see [BrowsedSeasonOffset].
  final int offset;

  /// Null while loading, after a failure or when the season is empty.
  final String? count;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BrowsedSeasonOffset stepper = ref.read(
      browsedSeasonOffsetProvider.notifier,
    );
    return ContentColumn(
      padded: false,
      child: Padding(
        // The arrow's glyph, not its tap target, lines up with the grid.
        padding: const EdgeInsets.only(
          left: ContentColumn.gutter - AppSpacing.s12,
          right: ContentColumn.gutter,
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: context.l10n.searchSeasonPrevious,
                  icon: const Icon(Icons.chevron_left, size: AppSizes.iconMd),
                  onPressed: stepper.previous,
                ),
                // Shrinks and wraps instead of overflowing with large text.
                Flexible(
                  child: _SeasonTitle(
                    season: season,
                    offset: offset,
                    onReset: stepper.reset,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.searchSeasonNext,
                  icon: const Icon(Icons.chevron_right, size: AppSizes.iconMd),
                  onPressed: offset < BrowsedSeasonOffset.max
                      ? stepper.next
                      : null,
                ),
              ],
            ),
            if (count != null || loading)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s12),
                // Wraps instead of overflowing with large text.
                child: Wrap(
                  spacing: AppSpacing.s8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (count case final String count)
                      Text(
                        count,
                        style: AppTypography.caption.copyWith(
                          color: context.palette.textFaint,
                        ),
                      )
                    else if (loading)
                      const Skeleton(width: 70, height: 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The season's name; away from the current season it takes the accent and
/// tapping it goes back.
///
/// The name slides in from the side the user stepped towards, so the
/// direction of travel is visible.
class _SeasonTitle extends StatefulWidget {
  const _SeasonTitle({
    required this.season,
    required this.offset,
    required this.onReset,
  });

  final YearSeason season;
  final int offset;
  final VoidCallback onReset;

  @override
  State<_SeasonTitle> createState() => _SeasonTitleState();
}

class _SeasonTitleState extends State<_SeasonTitle> {
  /// 1 when the last step went forward, -1 when it went back.
  int _direction = 1;

  @override
  void didUpdateWidget(_SeasonTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.offset != oldWidget.offset) {
      _direction = widget.offset > oldWidget.offset ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool away = widget.offset != 0;
    final ValueKey<YearSeason> key = ValueKey<YearSeason>(widget.season);
    return Semantics(
      liveRegion: true,
      button: away,
      hint: away ? context.l10n.searchSeasonBackToCurrent : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: away ? widget.onReset : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s16,
          ),
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppDuration.base,
            switchInCurve: AppDuration.curve,
            switchOutCurve: AppDuration.curve,
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              alignment: Alignment.centerLeft,
              // The outgoing name stays out of semantics so the live region
              // announces only the new one.
              children: <Widget>[
                ...previous.map(
                  (Widget outgoing) => ExcludeSemantics(child: outgoing),
                ),
                ?current,
              ],
            ),
            transitionBuilder: (Widget child, Animation<double> animation) {
              // The outgoing name runs the animation backwards, so it leaves
              // towards the side opposite the incoming one.
              final double side = child.key == key
                  ? _direction.toDouble()
                  : -_direction.toDouble();
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(0.25 * side, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              formatSeasonOf(
                context.l10n,
                widget.season.season,
                widget.season.year,
              ),
              key: key,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: away ? context.palette.accent : null),
            ),
          ),
        ),
      ),
    );
  }
}

/// The series of a season other than the current one, most followed first.
class _SeasonGrid extends ConsumerWidget {
  const _SeasonGrid({
    required this.season,
    required this.anime,
    required this.inLibrary,
  });

  /// Also keeps the scroll position of each season apart.
  final YearSeason season;
  final List<CatalogAnime> anime;
  final Set<int> inLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      child: RefreshIndicator(
        onRefresh: () =>
            _refresh(context, ref, seasonPremieresProvider(season)),
        child: anime.isEmpty
            // Scrollable so that an empty season can be pulled to refresh.
            ? _ScrollableEmpty(
                storageKey: PageStorageKey<YearSeason>(season),
                child: EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: context.l10n.searchSeasonEmptyTitle,
                  message: context.l10n.searchAiringEmptyMessage,
                ),
              )
            : ContentColumn(
                alignment: Alignment.topCenter,
                child: PosterGrid(
                  key: PageStorageKey<YearSeason>(season),
                  itemCount: anime.length,
                  itemBuilder: (BuildContext context, int index) {
                    final CatalogAnime item = anime[index];
                    return CatalogCard(
                      anime: item,
                      inLibrary: inLibrary.contains(item.malId),
                      onOpen: () =>
                          context.push(RoutePaths.animeDetail(item.malId)),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// An empty state that can still be pulled to refresh.
class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty({required this.storageKey, required this.child});

  final Key storageKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: storageKey,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ContentColumn(alignment: Alignment.topCenter, child: child),
        ),
      ],
    );
  }
}

/// Requests [provider] again. On failure the last list stays and a snack bar
/// says why; the provider has already reported any unexpected error.
Future<void> _refresh(
  BuildContext context,
  WidgetRef ref,
  FutureProvider<List<CatalogAnime>> provider,
) async {
  try {
    final Future<List<CatalogAnime>> reload = ref.refresh(provider.future);
    await reload;
  } on Object catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(catalogErrorMessage(context.l10n, error))),
    );
  }
}

class _AiringSkeleton extends StatelessWidget {
  const _AiringSkeleton({required this.tabs});

  /// Whether to leave the space of the weekday tabs.
  final bool tabs;

  @override
  Widget build(BuildContext context) {
    return ContentColumn(
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(height: tabs ? AppSpacing.s48 : AppSpacing.s16),
          const Expanded(child: PosterGridSkeleton()),
        ],
      ),
    );
  }
}
