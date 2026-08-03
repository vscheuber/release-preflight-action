# Changelog

## Unreleased

## [v1.0.2] - 2026-08-03

### Added
- Enhanced version checks with semantic versioning support, improving the validation process by ensuring that version numbers adhere to semantic versioning standards. This enhancement helps maintain consistency and correctness in versioning practices. (commit 35434e5)

### Changed
- Updated CI and release workflows to include Node.js setup, facilitating a more robust testing and release process. This change ensures that the necessary environment is consistently prepared for all workflow executions. (commit f8022c6)

### Fixed
- Utilized the action itself to perform preflight checks, ensuring that the validation process is self-consistent and reliable. This fix addresses potential discrepancies by using the same logic for both validation and execution. (commit 0c0b70e)

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
