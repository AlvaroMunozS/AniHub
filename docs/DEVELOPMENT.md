# Development

## Stack

| Concern | Choice |
|---|---|
| App | Flutter, Android only |
| State | Riverpod |
| Navigation | go_router |
| Library storage | SQLite through sqflite |
| Metadata | MyAnimeList API v2 over plain `http`, public endpoints only |
| Images | `cached_network_image` with a long-lived disk cache |
| Localization | `flutter_localizations` and `intl`, generated from ARB files |
| Preferences | `shared_preferences` |
| Updates | GitHub Releases, installed with Android's `PackageInstaller` |

## Architecture

The code follows a light hexagonal layout:

```
lib/domain          entities, value objects and ports
lib/application     use cases
lib/infrastructure  adapters: local/, mal/, backup/, cache/, images/,
                    github/, update/, links/
lib/ui              screens, widgets, state, theme
lib/l10n            ARB files and the context.l10n extension
lib/main.dart       composition root
```

The UI and the application layer depend only on the ports in
`lib/domain/ports/`. Concrete adapters are wired in `lib/main.dart` and nowhere
else. Tests run the UI against `InMemoryEntryRepository` and the fakes in
`test/support/`, without touching the disk or the network.

## Setup

Requirements: Flutter 3.47.1 or later (stable channel, the version CI uses), an
Android device or emulator and a MyAnimeList client id.

To get a client id, create an app at <https://myanimelist.net/apiconfig> with
the type *android*, then save the id in `env.json` at the repository root. The
file is git-ignored. Use your own client id: do not publish it or reuse the
official one.

```json
{"MAL_CLIENT_ID": "your client id"}
```

```bash
flutter pub get
flutter run -d <device> --dart-define-from-file=env.json
```

Without a client id the app still runs, but search and anime details show an
error. Tests do not need one.

Run the same checks as CI before opening a pull request (CI runs the formatter
in check mode):

```bash
dart format lib test
flutter analyze
flutter test
```

CI skips these checks when a change touches no code, build or workflow files,
and builds a debug APK only when `android/`, `assets/`, `pubspec.*` or the CI
workflow change.

## Local storage

The library is a SQLite database, `library.db`, in the app's private directory.
`openAniHubDatabase()` in `lib/infrastructure/local/sqflite_entry_repository.dart`
opens it once, before `runApp`.

```sql
CREATE TABLE entries (
  id TEXT PRIMARY KEY,                 -- random UUID v4
  mal_id INTEGER NOT NULL UNIQUE,
  title TEXT NOT NULL,
  cover_url TEXT,
  total_episodes INTEGER,              -- NULL while airing or when unknown
  status TEXT NOT NULL CHECK(status IN ('watching', 'planned', 'completed')),
  is_favorite INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL             -- ISO-8601, UTC
);
CREATE INDEX idx_entries_updated_at ON entries (updated_at);
```

Schema changes need an `onUpgrade` callback: bump `_schemaVersion` and add
the migration step. The relation graph from MyAnimeList is cached separately in
`SharedPreferences`.

## Import format

*More → Settings → Backup → Import library* reads an `anihub-library` file:

```json
{
  "format": "anihub-library",
  "version": 1,
  "exportedAt": "2026-09-22T10:00:00Z",
  "entries": [
    {
      "malId": 1,
      "title": "Cowboy Bebop",
      "coverUrl": "https://…",
      "totalEpisodes": 26,
      "status": "completed",
      "isFavorite": false,
      "updatedAt": "2026-09-20T10:00:00.000Z"
    }
  ]
}
```

- The file must be UTF-8 JSON with a `.json` extension. `format` must be `"anihub-library"`, `version`
  must be `1` and `entries` must be a list; `exportedAt` is ignored.
- Each entry needs an integer `malId`, a non-blank `title`, a `status` of
  `watching`, `planned` or `completed`, and an ISO-8601 `updatedAt`, read as
  local time when it has no offset. `coverUrl`, `totalEpisodes` and
  `isFavorite` are optional; missing or mistyped values become `null`, `null`
  and `false`, and so does a negative `totalEpisodes`.
- If any entry is invalid, the whole file is rejected and nothing is imported.
- If a `malId` appears more than once, the entry with the latest `updatedAt`
  is used.
- Entries are merged by `malId`. New series are added. An existing entry is
  replaced only when the file's `updatedAt` is newer. Nothing is deleted.

## MyAnimeList API

`lib/infrastructure/mal/` talks to `https://api.myanimelist.net/v2` with the
`X-MAL-CLIENT-ID` header. No user token is involved.

- `GET /anime?q=` searches, and `GET /anime/{id}` returns one anime. Both only
  return the fields listed in `fields`.
- Queries shorter than three characters are rejected with HTTP 400, so the app
  does not send them.
- Search leaves out anime rated not safe for work unless `nsfw=true` is sent,
  which the app never does.
- `num_episodes` is `0` when the count is unknown. `start_date` may be `YYYY`,
  `YYYY-MM` or `YYYY-MM-DD`, and `start_season` may be missing.
- There is no banner image; the details screen uses the cover as background.
- There is no batch lookup. Relations cost one request per anime, with nested
  fields (`related_anime{node{...}}`) for the related titles. At most four
  requests run at a time, and each chunk of 25 anime is cached as it arrives.
  Results are refreshed after 30 days, and older copies are kept for up to 90
  days as an offline fallback.
- An unknown id answers HTTP 404, and an invalid client id HTTP 400 with the
  message `Invalid client id`.
- The rate limit is not documented. HTTP 429 is handled, honoring
  `Retry-After` in seconds.

MyAnimeList's [API license](https://myanimelist.net/static/apiagreement.html)
allows its name only to credit it as the source and forbids altering or
translating its content. It also requires a privacy policy shown before
installation ([PRIVACY.md](../PRIVACY.md)) and notifying MyAnimeList of
releases with substantially new functionality ([RELEASING.md](RELEASING.md)).
The app credits it in *More → About*.

## Updates

*More → About → Check for updates* checks for a newer release and a second
tap installs it. Nothing is requested until the user taps.

- `lib/infrastructure/github/` reads
  `GET /repos/AlvaroMunozS/AniHub/releases/latest`, which never returns drafts
  or pre-releases. With *Get pre-release versions* on, it reads
  `GET /releases?per_page=30` instead and picks the highest semantic version,
  skipping drafts and tags that are not versions.
- A release must have exactly one `.apk` asset with a `sha256:` `digest`,
  which GitHub computes on upload; nothing is installed unverified. Without
  one, `/latest` fails the check and the list skips to the next release,
  since the workflow publishes a release before uploading its APK.
- Versions compare by semantic versioning, so `1.1.0-beta.1` is older than
  `1.1.0`. An installed pre-release is kept until a newer stable version
  exists, even with the switch off.
- `lib/infrastructure/update/` downloads the APK to the app's cache, checks
  its SHA-256 and hands it through the `anihub/installer` channel to
  `ApkInstaller.kt`, which copies it into a `PackageInstaller` session and
  deletes the file. The first update shows the system dialogs for unknown
  sources and confirmation. On Android 12 and later, once AniHub is the
  installer of record, later updates install without a dialog.
- Unauthenticated API requests are limited to 60 per hour and IP; the app
  says so when GitHub refuses one.

## Design decisions

- **Local only.** No account and no server: the app works offline and there is
  nothing to operate. The cost is no sync between devices, and no backup of its
  own beyond Android's system backup.
- **Three statuses.** *On hold* and *dropped* fit in *planned*; more statuses
  would complicate every screen for little benefit.
- **Narrow scope.** AniHub answers what you are watching and what you have
  finished, nothing more. [CONTRIBUTING.md](../CONTRIBUTING.md#scope) lists
  what is left out.
- **Favorites imply completed.** Favoriting a series that is not completed
  moves it to *completed* in the same write, and moving a favorite out of
  *completed* removes the favorite. An import keeps the status of an entry and
  drops the favorite if the entry is not completed.
- **Nullable `total_episodes`.** Airing series have no total; the type says so
  instead of using a sentinel value.
- **One layout.** A single phone layout, also used in landscape and on
  tablets.
- **Manual updates.** The app looks for a new version only when asked, so it
  makes no request the user did not expect and needs no background work.
- **Long image cache.** A MyAnimeList cover URL always serves the same file, so
  images are cached for a year (up to 3000 files) and load offline.
  *More → Settings → Storage* shows its size and clears it.
- **Preferences without a port.** Theme, accent and language are UI state:
  notifiers in `lib/ui/state/settings_providers.dart` read and write
  `SharedPreferences` directly.
- **Few dependencies.** UUIDs come from a small helper over `Random.secure()`
  instead of a package. New dependencies need a clear reason.

## Code style

- Identifiers, comments, documentation and commits are in English. User-facing
  strings live in the ARB files (see [Localization](#localization)), never as
  literals in `lib/ui`.
- Colors come from the theme (see [Theming](#theming)), never as literals
  outside `lib/ui/theme`.
- Comments explain *why*: a constraint, an edge case or a platform quirk. They
  do not restate the code or narrate its history; that belongs in git.
- Doc comments follow [Effective Dart](https://dart.dev/effective-dart/documentation):
  public API whose behavior is not obvious, a one-sentence summary first, and
  `[Symbol]` references.
- No commented-out code. `TODO`s reference an issue: `TODO(#12)`.
- Test names describe behavior: `'rejects the file when an entry is invalid'`.
- No dead code, debug output, swallowed errors or speculative abstractions.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/).

## Localization

The app is in Spanish and English. Strings live in `lib/l10n/app_es.arb`, the
template, and `lib/l10n/app_en.arb`. `flutter pub get` generates
`lib/l10n/app_localizations*.dart`, which is git-ignored.

- To add a string, add the key to both files and read it with
  `context.l10n.<key>`. Keys are lowerCamelCase with the screen as prefix:
  `aboutCheckForUpdates`, `storageImageCache`. Add an `@<key>` description
  only when the context is not obvious.
- Counts use ICU plurals and values use placeholders, never concatenation.
- The language is the one picked in *Appearance*, or else the first device
  language with a translation, in any regional variant; anything else falls
  back to English (`resolveAppLocale` in `lib/ui/locale_resolution.dart`).
- Data from MyAnimeList (titles, synopses, genres) is never translated.

## Theming

`buildTheme` in `lib/ui/theme/app_theme.dart` builds the light, dark and pure
black themes from an `AppPalette` and an `AppAccent`. Widgets read colors with
`context.palette` or the `ColorScheme`, so they follow the theme without
knowing which one is active. Only `AppOverlays`, drawn over cover art, is the
same in every theme. Each accent keeps a 3:1 contrast against the surfaces of
every theme, checked by `test/ui/theme/accents_test.dart`.

## App icon

`tool/anihub-icon.svg` is the source of `assets/images/app_icon.png`, the
legacy launcher mipmaps and the adaptive icon layers in `android/`. The
adaptive foreground scales the glyph to 75% around (54, 54) so it survives
circular masks.

## Signing a release build

Release builds are signed with the keystore described in
`android/key.properties`. Without that file they fall back to the debug keys,
so `flutter run --release` works out of the box.

To sign your own builds:

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties
```

Fill in the passwords in `android/key.properties` and run
`flutter build apk --release --dart-define-from-file=env.json`. Both files are git-ignored.

APKs signed with a different key cannot be installed over the official
releases.

Publishing official releases is covered in [RELEASING.md](RELEASING.md).
