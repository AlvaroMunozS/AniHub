# Releasing

Releases are built and published by `.github/workflows/release.yml` when a
`v*` tag is pushed. Only the maintainer can create those tags, and the job waits
for approval in the `release` environment before it runs.

## Steps

0. Before the first release, and before any release with substantially new
   functionality, notify MyAnimeList through its
   [support form](https://help.myanimelist.net/hc/en-us/requests/new), as its API license
   requires.
1. Open a pull request titled `chore: release X.Y.Z` that:
   - renames `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z] - YYYY-MM-DD`,
     adds a new empty `## [Unreleased]` above it and updates the comparison
     links at the bottom;
   - bumps `version` in `pubspec.yaml` to `X.Y.Z+N`, where `N` is the previous
     build number plus one.
2. Squash-merge it once CI passes.
3. Tag the merge commit and push the tag:

   ```bash
   git switch main && git pull
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

4. Approve the `release` deployment in the Actions tab.
5. Check the release page: APK, `.sha256` file, changelog and verification
   section.

The workflow fails before building if the tag does not match the `pubspec.yaml`
version or if `CHANGELOG.md` has no section for it. It also fails if the APK is
not signed with the certificate in `ANDROID_CERT_SHA256`.

## Versioning

- Patch: bug fixes.
- Minor: new features.
- Major: changes that break the `anihub-library` format or installing over the
  previous version.

The build number must always increase. Android refuses to install an APK with a
lower build number over an existing one.

## Configuration

Secrets in the `release` environment:

| Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Upload keystore (`.jks`), base64-encoded on one line |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `MAL_CLIENT_ID` | MyAnimeList client id, built into the APK |

Keystore passwords must not contain backslashes: `key.properties` is a Java
properties file, where a backslash starts an escape sequence.

Variables in the `release` environment:

| Name | Value |
|---|---|
| `ANDROID_KEY_ALIAS` | Key alias (`upload`) |
| `ANDROID_CERT_SHA256` | SHA-256 digest of the signing certificate, lowercase hex without separators |

Repository settings the pipeline relies on:

- The `release` environment requires the maintainer's approval and only
  accepts deployments from `v*` tags.
- A tag ruleset lets only the maintainer create, move or delete `v*` tags.
- Releases are immutable, so a published APK cannot be replaced.

Changing the signing key breaks updates for every installed copy. Keep the
keystore and its passwords backed up outside the repository.
