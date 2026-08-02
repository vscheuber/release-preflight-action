# Changelog

## Unreleased

## [v1.0.1] - 2026-08-02

### Added
- Introduced the release preflight action, which includes validation checks for versions and tags to ensure consistency and correctness before a release. This feature helps prevent common release errors by verifying that version numbers and tags are correctly formatted and aligned with the repository's history. (commit 24edd29)

## [v1.0.1-1] - 2026-08-02

### Added
- Introduced the release preflight action, which includes validation checks for versions and tags to ensure consistency and correctness before a release. This feature helps prevent common release errors by verifying that version numbers and tags are correctly formatted and aligned with the repository's history. (commit 24edd29)

## [v1.0.0] - 2026-08-02

### Added
- Initial release preflight action for validating candidate versions and tags against git and npm.
- Optional checks for remote tag collisions, npm version collisions, and version drift from latest known release.
