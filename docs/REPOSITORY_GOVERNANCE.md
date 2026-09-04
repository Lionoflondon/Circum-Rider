# Circum Rider Repository Governance

## Repository Purpose

`Circum-Rider` is the canonical source for the Circum Rider application. It owns Rider mobile presentation, Rider app workflows, Rider tests, and Rider release artifacts only.

It must not be used to release Sender, Website, Admin, Cloud Functions, Firestore Rules, or Storage Rules.

## Ownership

The default code owner is `@Lionoflondon` through `.github/CODEOWNERS`.

Ownership can be expanded later by adding maintainers to CODEOWNERS and then increasing the required approval count in the repository ruleset.

## Pull Request Workflow

All changes to `main` must be reviewed through a pull request.

Required review policy:

- At least 1 approval.
- Code owner review required.
- All review conversations resolved before merge.
- Stale approvals dismissed when new commits are pushed.
- No direct pushes to `main`.
- Force pushes blocked.
- Branch deletion blocked.

## CI Workflow

The repository CI workflow is `Circum Rider Flutter CI`.

It runs:

- `flutter pub get`
- `flutter analyze`
- `flutter test`

The workflow validates code quality only. It does not deploy, publish, or upload application artifacts.

## Merge Requirements

Before merge, GitHub branch rules should require:

- Pull request review.
- 1 code owner approval.
- Resolved conversations.
- Passing required status checks.
- Up-to-date branch where practical.

Merge commits, squash merges, or rebase merges may be allowed by policy, but history rewriting of protected branches is not allowed.

## Release Process

Releases are separate from merges. A reviewed and merged commit can be promoted only through the Rider release lane.

Recommended tag pattern:

- `rider-vYYYY.MM.DD-N`
- `rider-android-vYYYY.MM.DD-N`
- `rider-ios-vYYYY.MM.DD-N`

Release tags should point to reviewed commits from `main`.

## Deployment Responsibilities

Rider deployment is independent from Sender, Website, Admin, Cloud Functions, Firestore Rules, and Storage Rules.

Rider release tasks must validate and publish only Rider artifacts. Cross-product deployments are not permitted from this repository.

## Branch Strategy

`main` is the protected canonical branch.

Feature, fix, and governance work should use short-lived branches and merge back through pull requests after required checks pass.
