# release-preflight-action

Validate a candidate release version and tag against git and npm before publishing, failing fast on collisions or drift.

## What It Checks

Depending on enabled inputs, this action can validate:

- Candidate tag does not already exist in remote git tags
- Candidate package version is not already published on npm
- Current version is not behind the latest known npm/tag version (drift check)

This action does not compute versions, update manifests, publish to npm, or create tags.

## Inputs

- `candidate-version`: candidate semantic version, e.g. `1.2.3` or `1.2.3-1` (required)
- `candidate-tag`: candidate git tag, e.g. `v1.2.3` (required)
- `package-name`: npm package name for npm/drift checks (optional, required when those checks are enabled)
- `current-version`: current manifest version for drift checks (optional, required when drift check is enabled)
- `check-remote-tag`: fail when candidate tag exists in remote (default: `true`)
- `check-npm-version`: fail when candidate version exists on npm (default: `true`)
- `check-version-drift`: compare current-version against latest known npm/tag version (default: `false`)
- `git-remote`: git remote to query (default: `origin`)

## Outputs

- `passed`: `true` when all enabled checks passed
- `tag_exists`: `true` when candidate tag exists in remote
- `npm_version_exists`: `true` when package@candidate-version exists on npm
- `drift_detected`: `true` when current-version is behind latest known npm/tag version
- `latest_npm_version`: latest version discovered on npm for package-name
- `latest_tag_version`: latest `v*` semantic version from git tags
- `latest_known_version`: highest version across npm/tag sources

## Example

```yaml
- name: Release preflight checks
  id: preflight
  uses: vscheuber/release-preflight-action@v1
  with:
    candidate-version: ${{ steps.version-bump.outputs.newVersion }}
    candidate-tag: ${{ steps.version-bump.outputs.newTag }}
    package-name: '@rockcarver/frodo-cli'
    current-version: ${{ steps.version-bump.outputs.base }}
    check-remote-tag: true
    check-npm-version: true
    check-version-drift: true
```

## Prerequisites

For reliable git tag checks, fetch full history and tags before invoking this action:

```yaml
- uses: actions/checkout@v6
  with:
    fetch-depth: 0
    fetch-tags: true
```

For npm checks, ensure network access to npm registry and a valid package name.
