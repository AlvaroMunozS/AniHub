# Changelog

All notable changes to AniHub are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- *Settings → Notifications* can remind you when a series you are watching airs in Japan. It is off by default; the time is the Japanese TV broadcast, so streaming services may publish the episode later.
- *Browse* shows the best-known anime airing this season, by day of the week, most popular first, with the broadcast time in your time zone. It opens on today, and anime already in your library are dimmed.
- *Browse* has arrows at the bottom of the screen to look at past seasons and the next one, most popular first. Tap the season's name between them to go back to the current one.
- *Browse* has a bookmark in the search bar that shows only the series you are watching, by broadcast time, and dims the days none of them airs. Series you watch are listed even when few people follow them.
- *Appearance* lets you start the week on Monday or Sunday; by default it follows your phone's region.
- *Settings → Backup → Export library* saves your library to a file, on your phone or in a cloud storage app, that *Import library* can restore on a new install or another phone.

### Fixed

- *Browse* airing times now follow daylight saving changes and time zone changes when you reopen the app, instead of staying wrong until it restarts. Episodes that already aired today now show next week's time.
- The app no longer stays on the splash screen when it fails to start. If the library cannot be opened it says so, and a damaged relations cache no longer keeps the app from opening.
- *Import library* no longer lets an entry with a date in the future overwrite your later changes on every import.
- With a large system text size, the status picker on the detail screen no longer overflows, and hints and secondary labels are easier to read.
- One anime that MyAnimeList fails to serve no longer stops the rest of your library from being grouped with its related anime.
- A failed load, such as an anime that no longer exists or no connection, now shows its error right away instead of a loading skeleton for about 40 seconds, and no longer repeats the request ten times in a row. A failed lookup is asked again when you come back to the screen.
- Hentai no longer appears among related anime, and opening one from a link now says it is not available. Related anime are fetched again once after updating.

## [1.3.0] - 2026-09-25

### Added

- In *Planned*, the *Not started* filter shows only anime from series you have not started, or hides them to leave the next seasons of series you follow.

### Changed

- The *Favorites* filter can also hide your favorites.
- Seasons of a series are grouped together, and count as started, even when the seasons in between are not in your library.
- Back from a prequel or sequel returns to the library or search, instead of going through every anime you opened on the way.

## [1.2.1] - 2026-09-23

### Fixed

- Search finds anime that MyAnimeList does not rate as suitable for all audiences, such as *Suzume*.

## [1.2.0] - 2026-09-23

### Added

- *Settings* in *More*, where you can pick a light, dark or system theme, pure black for OLED screens and an accent color.
- The app is available in English, and follows the device language unless you pick one in *Settings → Appearance*.
- The size of the image cache in *Settings → Storage*, where you can also clear it.

### Changed

- *Import library* moves to *Settings → Backup*.
- The details screen, the search bar and the tabs no longer stretch across tablets and landscape screens.
- When an anime is no longer on MyAnimeList, its page says so and offers to remove it from your library.

### Fixed

- Series changed within the same instant no longer appear out of order in the library.

## [1.1.0] - 2026-09-23

### Added

- *Acerca de* is now its own screen, where you can check for a new version and install it, with pre-releases as an option.
- Links to the release notes, the source code, the privacy policy and the open source licenses in *Acerca de*.

## [1.0.0] - 2026-09-23

First public release.

### Added

- Library with three lists: *Watching*, *Planned* and *Completed*.
- Favorites, with their own filter in the Completed list.
- Seasons of the same franchise grouped into a single expandable poster.
- Library search, filtering and sorting.
- Anime details with synopsis, genres, studio, season and links to the prequel and sequel.
- Catalog search powered by MyAnimeList.
- Offline use: the library and cover images are stored on the device.
- Library import from an `anihub-library` JSON file.

[Unreleased]: https://github.com/AlvaroMunozS/AniHub/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/AlvaroMunozS/AniHub/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/AlvaroMunozS/AniHub/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/AlvaroMunozS/AniHub/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/AlvaroMunozS/AniHub/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/AlvaroMunozS/AniHub/releases/tag/v1.0.0
