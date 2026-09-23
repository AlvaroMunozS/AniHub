# Privacy policy

This policy covers the AniHub Android app published in this repository.

## Data collected

None. AniHub has no account, analytics, advertising or crash reporting, and
the developer receives no data from the app.

## Network requests

The app connects to MyAnimeList:

- `api.myanimelist.net`, to search anime and load their details;
- `cdn.myanimelist.net`, to load cover images.

These requests include the device's IP address and the app's MyAnimeList
client id, and are handled under
[MyAnimeList's privacy policy](https://myanimelist.net/about/privacy_policy).
Covers of an imported library are loaded from the addresses in the imported
file.

The app connects to GitHub only when you tap *Check for updates* in
*More → About*, or install the update it finds:

- `api.github.com`, to look up the latest release;
- `github.com` and `release-assets.githubusercontent.com`, to download its
  APK.

These requests include the device's IP address and a user agent naming AniHub,
and are handled under
[GitHub's privacy statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement).
The links in *About* open in your browser.

## Data on the device

The library, the sort and pre-release preferences and the cached anime data
and covers are stored in the app's private storage. They are included in
Android's system backup when it is enabled on the device. Uninstalling the app
deletes them.

A downloaded update is stored in the app's cache, which is not backed up, and
deleted once it is handed to the system installer or the download fails. An
interrupted download is replaced by the next one.

## Changes

Changes to this policy are published in this file, and its history is kept in
the repository.
