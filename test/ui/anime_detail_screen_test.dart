import 'package:anihub/domain/entities/anime_relation.dart';
import 'package:anihub/domain/entities/anime_relation_node.dart';
import 'package:anihub/domain/entities/catalog_anime.dart';
import 'package:anihub/domain/entities/entry.dart';
import 'package:anihub/domain/errors/catalog_exception.dart';
import 'package:anihub/domain/ports/anime_catalog.dart';
import 'package:anihub/domain/ports/anime_relations.dart';
import 'package:anihub/domain/ports/entry_repository.dart';
import 'package:anihub/domain/values/anime_season.dart';
import 'package:anihub/domain/values/relation_kind.dart';
import 'package:anihub/domain/values/watch_status.dart';

import 'package:anihub/ui/router.dart';
import 'package:anihub/ui/screens/anime_detail_screen.dart';
import 'package:anihub/ui/screens/library_screen.dart';
import 'package:anihub/ui/shell/content_column.dart';
import 'package:anihub/ui/theme/app_theme.dart';
import 'package:anihub/ui/widgets/detail/detail_action_row.dart';
import 'package:anihub/ui/widgets/detail/detail_header.dart';
import 'package:anihub/ui/widgets/detail/expandable_synopsis.dart';
import 'package:anihub/ui/widgets/status_selector.dart';
import 'package:flutter/foundation.dart' show FlutterExceptionHandler;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_anime_catalog.dart';
import '../support/fake_anime_relations.dart';
import '../support/in_memory_entry_repository.dart';
import '../support/sample_data.dart';
import 'support/pump_app.dart';

/// A landscape tablet, wider than any content column.
const Size _wideScreen = Size(1600, 900);

/// Fullmetal Alchemist: Brotherhood with a synopsis long enough to collapse
/// and a known season, which `sampleCatalog` lacks.
final CatalogAnime _anime = CatalogAnime(
  malId: 5114,
  title: 'Fullmetal Alchemist: Brotherhood',
  totalEpisodes: 64,
  seasonYear: 2009,
  season: AnimeSeason.spring,
  coverUrl: 'https://cdn.myanimelist.net/images/anime/1208/94745l.jpg',
  description: List<String>.filled(
    6,
    'After a failed alchemy ritual, the Elric brothers search for the '
    "Philosopher's Stone to restore their bodies.",
  ).join(' '),
  genres: const <String>['Action', 'Adventure', 'Drama', 'Fantasy'],
  studioName: 'Bones',
);

/// Prequel and sequel targets that exist in `sampleCatalog`, so their detail
/// screens load.
const AnimeRelationNode _relations = AnimeRelationNode(
  malId: 5114,
  title: 'Fullmetal Alchemist: Brotherhood',
  relations: <AnimeRelation>[
    AnimeRelation(
      malId: 1,
      kind: RelationKind.prequel,
      title: 'Cowboy Bebop',
      seasonYear: 1998,
    ),
    AnimeRelation(
      malId: 21,
      kind: RelationKind.sequel,
      title: 'One Piece',
      seasonYear: 1999,
    ),
  ],
);

Entry _watching() => Entry(
  malId: 5114,
  title: 'Fullmetal Alchemist: Brotherhood',
  status: WatchStatus.watching,
  totalEpisodes: 64,
  updatedAt: DateTime(2024),
);

FakeAnimeCatalog _offline() =>
    FakeAnimeCatalog(error: const CatalogNetworkException('down'));

/// Pumps the detail screen of [_anime].
Future<void> _pumpDetail(
  WidgetTester tester, {
  EntryRepository? repo,
  AnimeCatalog? catalog,
  AnimeRelations? relations,
}) {
  return pumpApp(
    tester,
    repo: repo,
    catalog:
        catalog ??
        FakeAnimeCatalog(
          catalog: <CatalogAnime>[
            for (final CatalogAnime anime in sampleCatalog)
              if (anime.malId == _anime.malId) _anime else anime,
          ],
        ),
    relations: relations,
    initialLocation: RoutePaths.animeDetail(_anime.malId),
  );
}

void main() {
  testWidgets('shows the metadata of the anime', (WidgetTester tester) async {
    await _pumpDetail(tester);

    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(find.text('64 episodios'), findsOneWidget);
    expect(find.text('Primavera 2009'), findsOneWidget);
    expect(find.text('Bones'), findsOneWidget);
    expect(find.text('Action · Adventure · Drama · Fantasy'), findsOneWidget);
  });

  testWidgets('collapses a long synopsis and expands it on tap', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester);

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('lists prequel and sequel and opens them on tap', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      relations: FakeAnimeRelations(
        graph: <int, AnimeRelationNode>{5114: _relations},
      ),
    );

    expect(find.text('Precuela'), findsOneWidget);
    expect(find.text('Secuela'), findsOneWidget);
    expect(find.text('Cowboy Bebop'), findsOneWidget);
    expect(find.text('One Piece'), findsOneWidget);

    await tester.ensureVisible(find.text('One Piece'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One Piece'));
    await tester.pumpAndSettle();

    final AnimeDetailScreen screen = tester.widget<AnimeDetailScreen>(
      find.byType(AnimeDetailScreen),
    );
    expect(screen.malId, 21);
    expect(find.byType(AnimeDetailScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('hides the relations section without relations', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester);

    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(find.text('Precuela'), findsNothing);
    expect(find.text('Secuela'), findsNothing);
  });

  testWidgets('hides the relations section when loading them fails', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      relations: FakeAnimeRelations(
        error: const CatalogNetworkException('down'),
      ),
    );

    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(find.text('Precuela'), findsNothing);
    expect(find.text('No se pudo cargar la ficha'), findsNothing);
  });

  testWidgets('reports an unexpected failure loading the relations', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      relations: FakeAnimeRelations(error: StateError('bug')),
    );

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Precuela'), findsNothing);
  });

  testWidgets('explains that the build has no valid client id', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      catalog: FakeAnimeCatalog(
        error: const CatalogUnauthorizedException('missing'),
      ),
    );

    expect(find.text(spanish.catalogUnauthorized), findsOneWidget);
  });

  testWidgets('offers a retry when loading fails', (WidgetTester tester) async {
    await _pumpDetail(tester, catalog: _offline());

    expect(find.text('No se pudo cargar la ficha'), findsOneWidget);
    expect(
      find.text('Revisa la conexión e inténtalo otra vez.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('does not blame the connection for an unknown anime', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      catalog: FakeAnimeCatalog(catalog: const <CatalogAnime>[]),
      initialLocation: RoutePaths.animeDetail(_anime.malId),
    );

    expect(find.text(spanish.detailUnavailableTitle), findsOneWidget);
    expect(find.text(spanish.catalogNotFound), findsOneWidget);
    expect(find.textContaining('Revisa la conexión'), findsNothing);
    expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);
  });

  testWidgets('does not offer retry for an anime that no longer exists', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      repo: inMemoryLibrary(<Entry>[_watching()]),
      catalog: FakeAnimeCatalog(catalog: const <CatalogAnime>[]),
    );

    expect(find.text(spanish.detailUnavailableTitle), findsOneWidget);
    expect(find.text(spanish.commonRetry), findsNothing);
  });

  testWidgets('offers to remove an anime that no longer exists', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary(<Entry>[_watching()]);
    await _pumpDetail(
      tester,
      repo: repo,
      catalog: FakeAnimeCatalog(catalog: const <CatalogAnime>[]),
    );

    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(find.text(spanish.detailUnavailableInLibrary), findsOneWidget);

    await tester.tap(
      find.widgetWithText(OutlinedButton, spanish.detailRemoveFromLibrary),
    );
    await tester.pumpAndSettle();
    expect(find.text(spanish.detailRemoveMessage), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, spanish.detailRemove));
    await tester.pumpAndSettle();

    expect(await repo.findAll(), isEmpty);
    expect(find.byType(AnimeDetailScreen), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsNothing);
  });

  testWidgets('hides the library controls of an anime that no longer exists', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      repo: inMemoryLibrary(<Entry>[_watching()]),
      catalog: FakeAnimeCatalog(catalog: const <CatalogAnime>[]),
    );

    expect(find.text(spanish.detailUnavailableTitle), findsOneWidget);
    expect(find.byType(StatusSelector), findsNothing);
    expect(find.text(spanish.detailFavorite), findsNothing);
  });

  testWidgets('does not report an anime that no longer exists', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      repo: inMemoryLibrary(<Entry>[_watching()]),
      catalog: FakeAnimeCatalog(catalog: const <CatalogAnime>[]),
    );

    expect(find.text(spanish.detailUnavailableTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not offer removal outside the library', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      catalog: FakeAnimeCatalog(catalog: const <CatalogAnime>[]),
    );

    expect(find.text(spanish.detailUnavailableTitle), findsOneWidget);
    expect(find.text(spanish.detailRemoveFromLibrary), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('reports an unexpected failure loading the anime', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      catalog: FakeAnimeCatalog(error: StateError('bug')),
    );

    expect(tester.takeException(), isA<StateError>());
    expect(find.text(spanish.catalogRetryLater), findsOneWidget);
  });

  testWidgets(
    'keeps title and status controls of a library entry when loading fails',
    (WidgetTester tester) async {
      await _pumpDetail(
        tester,
        repo: inMemoryLibrary(<Entry>[_watching()]),
        catalog: _offline(),
      );

      expect(find.text('No se pudo cargar la ficha'), findsOneWidget);
      expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
      expect(find.text('Viendo'), findsOneWidget);
    },
  );

  testWidgets('puts the offline notice below the header of a library entry', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      repo: inMemoryLibrary(<Entry>[_watching()]),
      catalog: _offline(),
    );

    final double titleTop = tester
        .getTopLeft(find.text('Fullmetal Alchemist: Brotherhood'))
        .dy;
    final double noticeTop = tester
        .getTopLeft(find.text('No se pudo cargar la ficha'))
        .dy;
    expect(titleTop, lessThan(noticeTop));
    expect(titleTop, lessThan(tester.getTopLeft(find.text('Viendo')).dy));
  });

  testWidgets('lays out the action row on a very narrow screen', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester);
    final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    tester.view.physicalSize = Size(90 * tester.view.devicePixelRatio, 2400);
    await tester.pumpAndSettle();
    FlutterError.onError = previous;

    expect(
      errors.map((FlutterErrorDetails e) => e.exception),
      isNot(contains(isArgumentError)),
    );
  });

  testWidgets('adds an anime outside the library with the chosen status', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary();
    await _pumpDetail(tester, repo: repo);

    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendiente'));
    await tester.pumpAndSettle();

    final List<Entry> all = await repo.findAll();
    expect(all, hasLength(1));
    expect(all.single.status, WatchStatus.planned);
    expect(find.text('Añadido a «Pendiente»'), findsOneWidget);
  });

  testWidgets('changes the status of a library entry', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary(<Entry>[_watching()]);
    await _pumpDetail(tester, repo: repo);

    await tester.tap(find.text('Viendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completado'));
    await tester.pumpAndSettle();

    expect((await repo.findAll()).single.status, WatchStatus.completed);
  });

  testWidgets('favoriting an anime outside the library adds it as completed', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary();
    await _pumpDetail(tester, repo: repo);

    await tester.tap(find.text('Favorito'));
    await tester.pumpAndSettle();

    final Entry added = (await repo.findAll()).single;
    expect(added.status, WatchStatus.completed);
    expect(added.isFavorite, isTrue);
  });

  testWidgets('favoriting a watching entry also completes it', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary(<Entry>[_watching()]);
    await _pumpDetail(tester, repo: repo);

    await tester.tap(find.text('Favorito'));
    await tester.pumpAndSettle();

    final Entry saved = (await repo.findAll()).single;
    expect(saved.status, WatchStatus.completed);
    expect(saved.isFavorite, isTrue);
    expect(find.text('Completado'), findsOneWidget);
  });

  testWidgets('announces whether the anime is a favorite', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpDetail(tester, repo: inMemoryLibrary(<Entry>[_watching()]));

    expect(
      tester.getSemantics(find.text('Favorito')),
      isSemantics(hasToggledState: true, isToggled: false),
    );

    await tester.tap(find.text('Favorito'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Favorito')),
      isSemantics(hasToggledState: true, isToggled: true),
    );
    semantics.dispose();
  });

  testWidgets('removes the entry after confirmation', (
    WidgetTester tester,
  ) async {
    final InMemoryEntryRepository repo = inMemoryLibrary(<Entry>[_watching()]);
    await _pumpDetail(tester, repo: repo);

    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    expect(
      find.text('¿Seguro que quieres eliminar este anime?'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(await repo.findAll(), isEmpty);
    expect(find.byType(AnimeDetailScreen), findsNothing);
  });

  testWidgets('fades in the top bar background on scroll', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      relations: FakeAnimeRelations(
        graph: <int, AnimeRelationNode>{5114: _relations},
      ),
    );
    // Shorter than the content, so it scrolls.
    tester.view.physicalSize = const Size(1200, 1500);
    await tester.pumpAndSettle();

    Color barColor() {
      final Container container = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.byTooltip('Volver'),
              matching: find.byType(Container),
            ),
          )
          .first;
      return container.color!;
    }

    expect(barColor().a, 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(barColor().a, greaterThan(0));
  });

  testWidgets('centers the content at a readable width on a wide screen', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, repo: inMemoryLibrary(<Entry>[_watching()]));
    tester.view.physicalSize = _wideScreen * tester.view.devicePixelRatio;
    await tester.pumpAndSettle();

    final Rect synopsis = tester.getRect(find.byType(ExpandableSynopsis));
    expect(synopsis.width, lessThanOrEqualTo(AppLayout.readableMaxWidth));
    expect(synopsis.center.dx, moreOrLessEquals(_wideScreen.width / 2));

    final Rect title = tester.getRect(
      find.text('Fullmetal Alchemist: Brotherhood'),
    );
    expect(title.left, greaterThanOrEqualTo(synopsis.left));
    expect(title.right, lessThanOrEqualTo(synopsis.right));

    final Rect actions = tester.getRect(find.byType(DetailActionRow));
    expect(actions.center.dx, moreOrLessEquals(_wideScreen.width / 2));
    expect(
      actions.width,
      lessThanOrEqualTo(AppLayout.readableMaxWidth + ContentColumn.gutter * 2),
    );

    // The faded cover behind the header still spans the whole screen.
    expect(tester.getSize(find.byType(DetailHeader)).width, _wideScreen.width);
  });
}
