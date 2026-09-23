# AniHub

Minimal anime tracker for Android. Local only: no account, no server; the
library lives in SQLite on the device. Metadata comes from the MyAnimeList
API.

Stack, architecture, storage, import format, design decisions and code style
are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). The release process is in
[docs/RELEASING.md](docs/RELEASING.md). Read them before changing code.

## Rules

- UI and application code depend on the ports in `lib/domain/ports/`, never on
  adapters. Adapters are wired only in `lib/main.dart`.
- Changing a port in `lib/domain/ports/` or adding, removing or upgrading a
  dependency in `pubspec.yaml` needs the maintainer's agreement first.
- Everything is in English except user-facing strings, which are in Spanish.
- Follow the code style in `docs/DEVELOPMENT.md`. A comment explains why, not
  what, and never tells the history of the code.
- `dart format lib test`, `flutter analyze` (no issues) and `flutter test`
  must pass before a pull request is merged.
- No secrets, personal paths or personal data in the repository.

## Scope

Three statuses: `watching`, `planned`, `completed`. No scores, reviews,
episode counters, tags or statistics. When in doubt, leave it out. The full list
is in [CONTRIBUTING.md](CONTRIBUTING.md#scope).

## Workflow

1. Every change starts from a GitHub issue.
2. Plans for larger changes go in `PLAN-<topic>.md` at the repository root.
   These files are git-ignored and never committed. Writing a plan is not
   approval to implement it.
3. Work on a `feat/<topic>`, `fix/<topic>` or `chore/<topic>` branch from
   `main`. Direct pushes to `main` are blocked.
4. Open a pull request with a Conventional Commits title (it becomes the squash
   commit message), `Closes #N` in the body and the template checklist filled.
5. User-facing changes add a line under `## [Unreleased]` in `CHANGELOG.md`,
   written for users.
6. Review the diff against the code style before merging. When the change was
   written by an agent, a different agent reviews it.
7. Squash-merge once CI passes.

### Parallel agents

- One `git worktree` and one branch (`feat/<topic>-<track>`) per agent, with
  exclusive ownership of its folders.
- An agent that needs to touch another track's files stops and reports it.
- Agents do not push, merge or open pull requests. The coordinating agent
  merges the tracks into `feat/<topic>` in the planned order and opens a single
  pull request.

## Commands

```bash
flutter run -d <device> --dart-define-from-file=env.json   # env.json holds MAL_CLIENT_ID
flutter test
flutter analyze
dart format lib test
flutter build apk --release --dart-define-from-file=env.json
```

## Pitfalls

- Without `android/key.properties`, release builds are signed with the debug
  keys. The release workflow rejects any APK whose certificate does not match
  `ANDROID_CERT_SHA256`.
- The build number in `pubspec.yaml` (`X.Y.Z+N`) must always increase, or the
  APK will not install over the previous version.
