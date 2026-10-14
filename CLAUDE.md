# AniHub

Minimal anime tracker for Android. Local only: no account, no server; the
library lives in SQLite on the device. Metadata comes from the MyAnimeList
API.

Stack, architecture, storage, backup format, design decisions and code style
are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). The release process is in
[docs/RELEASING.md](docs/RELEASING.md). Read them before changing code.

## Rules

- UI and application code depend on the ports in `lib/domain/ports/`, never on
  adapters. Adapters are wired only in `lib/main.dart`.
- Changing a port in `lib/domain/ports/` or adding, removing or upgrading a
  dependency in `pubspec.yaml` needs the maintainer's agreement first.
- Everything is in English. User-facing strings live in `lib/l10n/*.arb`,
  with Spanish as the template and English as the translation; `lib/ui` has
  no literal strings.
- Follow the code style in `docs/DEVELOPMENT.md`. A comment explains why, not
  what, and never tells the history of the code.
- `dart format lib test`, `flutter analyze` (no issues) and `flutter test`
  must pass before a change reaches `main`. The `pre-push` hook in
  `.githooks/` enforces it.
- No secrets, personal paths or personal data in the repository.

## Scope

Three statuses: `watching`, `planned`, `completed`. No scores, reviews,
episode counters, tags or statistics. When in doubt, leave it out. The full list
is in [CONTRIBUTING.md](CONTRIBUTING.md#scope).

## Workflow

1. Every change starts from a GitHub issue.
2. Plans and specs for larger changes go in `PLAN-<topic>.md` at the
   repository root (see [Superpowers](#superpowers)). These files are
   git-ignored and never committed. Writing a plan is not approval to
   implement it.
3. Work on a `feat/<topic>`, `fix/<topic>` or `chore/<topic>` branch from
   `main`. Release commits are the exception: they go straight on `main`
   (see [docs/RELEASING.md](docs/RELEASING.md)).
4. User-facing changes add a line under `## [Unreleased]` in `CHANGELOG.md`,
   written for users.
5. Review the diff against the code style before merging. When the change was
   written by an agent, a different agent reviews it.
6. Update `main` with `git pull`, squash-merge locally with
   `git merge --squash <branch>` and commit with a Conventional Commits message
   and `Closes #N` in the body. Push `main` once the maintainer confirms. The
   `pre-push` hook runs the checks; a failure is fixed, never skipped with
   `--no-verify`.

Changes are not merged through pull requests, so CI runs only on Dependabot's.
The release workflow runs the checks again before building.

### Parallel agents

- One `git worktree` and one branch (`feat/<topic>-<track>`) per agent, with
  exclusive ownership of its folders.
- An agent that needs to touch another track's files stops and reports it.
- Agents do not push or merge. The coordinating agent merges the tracks into
  `feat/<topic>` in the planned order and then follows Workflow 5 and 6.

## Superpowers

- Every new feature and bug fix, whatever its size, is written with the
  Superpowers skill `test-driven-development`.
- Larger changes first go through `brainstorming` and `writing-plans`, and the
  plan is executed with `subagent-driven-development`. Small changes need no
  plan: the maintainer approves a short design in the conversation.
- Every behavior change starts with a test that fails for the expected
  reason; show the failing and then the passing output before calling it done.
  A bug fix starts with a test that reproduces the bug.
- Specs and plans are saved as `PLAN-<topic>.md` at the repository root, never
  under `docs/superpowers/`, and are not committed. The maintainer approves
  them before implementation starts.
- The test-first rule applies to what a change touches. Existing code and
  tests are not rewritten only to meet it.
- The review in Workflow 5 uses `requesting-code-review`. The agent that
  merges runs `finishing-a-development-branch` and takes the local merge
  option, never the pull request one, but merges as in Workflow 6: a squash,
  not a plain merge, and the branch is deleted with `git branch -D` after the
  push. In parallel tracks, track agents stop and report instead.

## Commands

```bash
git config core.hooksPath .githooks                        # once per clone
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
