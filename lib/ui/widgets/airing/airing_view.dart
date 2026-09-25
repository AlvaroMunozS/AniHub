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
import '../../theme/app_theme.dart';
import '../catalog_card.dart';
import '../empty_state.dart';
import '../poster_grid.dart';
import '../skeleton.dart';

/// Diameter of the dot that marks today's tab.
const double _todayDotSize = 5;

/// This season's airing anime, one tab per local weekday starting on today,
/// plus a last tab for those without a fixed slot when there are any.
///
/// Anime in [inLibrary] are dimmed, as in search results.
class AiringView extends ConsumerWidget {
  const AiringView({required this.inLibrary, super.key});

  /// MyAnimeList ids of the library's entries.
  final Set<int> inLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AiringSchedule> schedule = ref.watch(
      airingScheduleProvider,
    );
    return schedule.when(
      loading: () => const _AiringSkeleton(),
      error: (Object error, StackTrace stackTrace) => ContentColumn(
        child: EmptyState(
          icon: catalogErrorIcon(error),
          title: context.l10n.searchAiringFailed,
          message: catalogErrorMessage(context.l10n, error),
          actionLabel: context.l10n.commonRetry,
          onAction: () => ref.invalidate(airingScheduleProvider),
        ),
      ),
      data: (AiringSchedule schedule) {
        if (schedule.length == 0) {
          return ContentColumn(
            child: EmptyState(
              icon: Icons.live_tv_outlined,
              title: context.l10n.searchAiringEmptyTitle,
              message: context.l10n.searchAiringEmptyMessage,
            ),
          );
        }
        return _AiringTabs(schedule: schedule, inLibrary: inLibrary);
      },
    );
  }
}

class _AiringTabs extends ConsumerWidget {
  const _AiringTabs({required this.schedule, required this.inLibrary});

  final AiringSchedule schedule;
  final Set<int> inLibrary;

  /// Weekdays from [DateTime.monday] to [DateTime.sunday], starting on the
  /// first day of the week of the app's language.
  static List<int> _weekdays(BuildContext context) {
    // Material counts from Sunday, as 0; DateTime from Monday, as 1.
    final int first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return <int>[
      for (int i = 0; i < DateTime.daysPerWeek; i++)
        (first + i - 1) % DateTime.daysPerWeek + 1,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<int> weekdays = _weekdays(context);
    final bool hasOther = schedule.unscheduled.isNotEmpty;
    final int tabCount = weekdays.length + (hasOther ? 1 : 0);
    final int today = ref.watch(clockProvider)().weekday;
    final DateFormat dayName = DateFormat.E(
      Localizations.localeOf(context).toLanguageTag(),
    );

    return DefaultTabController(
      // A new controller when the tab count changes, since a controller's
      // length is fixed.
      key: ValueKey<int>(tabCount),
      length: tabCount,
      initialIndex: weekdays.indexOf(today),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _AiringHeader(count: schedule.length),
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
                if (hasOther) Tab(text: context.l10n.searchAiringOther),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                for (final int weekday in weekdays)
                  _AiringGrid(
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
                  ),
                if (hasOther)
                  _AiringGrid(
                    storageKey: 0,
                    anime: <_AiringItem>[
                      for (final CatalogAnime anime in schedule.unscheduled)
                        (anime: anime, time: null),
                    ],
                    inLibrary: inLibrary,
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

/// The season and how many anime air in it.
class _AiringHeader extends ConsumerWidget {
  const _AiringHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({int year, AnimeSeason season}) current = ref.watch(
      currentSeasonProvider,
    );
    return ContentColumn(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Expanded(
              child: Text(
                formatSeasonOf(context.l10n, current.season, current.year),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              context.l10n.searchAiringCount(count),
              style: AppTypography.caption.copyWith(
                color: context.palette.textFaint,
              ),
            ),
          ],
        ),
      ),
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
    required this.storageKey,
    required this.anime,
    required this.inLibrary,
  });

  /// Keeps the scroll position of each tab apart.
  final int storageKey;
  final List<_AiringItem> anime;
  final Set<int> inLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (anime.isEmpty) {
      return ContentColumn(
        alignment: Alignment.topCenter,
        child: EmptyState(
          icon: Icons.event_available_outlined,
          title: context.l10n.searchAiringDayEmpty,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.refresh(airingScheduleProvider.future),
      child: ContentColumn(
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

class _AiringSkeleton extends StatelessWidget {
  const _AiringSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ContentColumn(
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
            child: Row(
              children: <Widget>[
                Skeleton(width: 110, height: 16),
                Spacer(),
                Skeleton(width: 70, height: 12),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.s48),
          Expanded(child: PosterGridSkeleton()),
        ],
      ),
    );
  }
}
