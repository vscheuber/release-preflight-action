#!/usr/bin/env bash
set -euo pipefail

candidate_version="${CANDIDATE_VERSION:-}"
candidate_tag="${CANDIDATE_TAG:-}"
package_name="${PACKAGE_NAME:-}"
current_version="${CURRENT_VERSION:-}"
check_remote_tag="${CHECK_REMOTE_TAG:-true}"
check_npm_version="${CHECK_NPM_VERSION:-true}"
check_version_drift="${CHECK_VERSION_DRIFT:-false}"
git_remote="${GIT_REMOTE:-origin}"

passed='true'
tag_exists='false'
npm_version_exists='false'
drift_detected='false'
latest_npm_version=''
latest_tag_version=''
latest_known_version=''

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd"
    exit 1
  fi
}

fail_check() {
  local message="$1"
  echo "::error::${message}"
  passed='false'
}

case "$check_remote_tag" in
  true|false) ;;
  *)
    echo "check-remote-tag must be one of: true, false"
    exit 1
    ;;
esac

case "$check_npm_version" in
  true|false) ;;
  *)
    echo "check-npm-version must be one of: true, false"
    exit 1
    ;;
esac

case "$check_version_drift" in
  true|false) ;;
  *)
    echo "check-version-drift must be one of: true, false"
    exit 1
    ;;
esac

if [[ -z "$candidate_version" ]]; then
  echo "candidate-version is required"
  exit 1
fi

if [[ -z "$candidate_tag" ]]; then
  echo "candidate-tag is required"
  exit 1
fi

if [[ "$check_npm_version" == 'true' || "$check_version_drift" == 'true' ]]; then
  require_cmd npm
fi

if [[ "$check_remote_tag" == 'true' || "$check_version_drift" == 'true' ]]; then
  require_cmd git
fi

if [[ "$check_remote_tag" == 'true' ]]; then
  if git ls-remote --tags --refs "$git_remote" "refs/tags/${candidate_tag}" | grep -q "refs/tags/${candidate_tag}"; then
    tag_exists='true'
    fail_check "Tag ${candidate_tag} already exists in ${git_remote}."
  fi
fi

if [[ "$check_npm_version" == 'true' ]]; then
  if [[ -z "$package_name" ]]; then
    echo "package-name is required when check-npm-version=true"
    exit 1
  fi

  if npm view "${package_name}@${candidate_version}" version >/dev/null 2>&1; then
    npm_version_exists='true'
    fail_check "Version ${candidate_version} is already published for ${package_name}."
  fi
fi

if [[ "$check_version_drift" == 'true' ]]; then
  if [[ -z "$current_version" ]]; then
    echo "current-version is required when check-version-drift=true"
    exit 1
  fi

  if [[ -z "$package_name" ]]; then
    echo "package-name is required when check-version-drift=true"
    exit 1
  fi

  latest_npm_version="$(npm view "$package_name" version 2>/dev/null || true)"
  latest_tag_version="$(git ls-remote --tags --refs "$git_remote" 'refs/tags/v*' | awk -F'/' '{print $3}' | sed 's/^v//' | sort -V | tail -n1)"

  latest_known_version="$latest_npm_version"
  if [[ -n "$latest_tag_version" ]]; then
    if [[ -z "$latest_known_version" ]]; then
      latest_known_version="$latest_tag_version"
    else
      latest_known_version="$(printf '%s\n%s\n' "$latest_known_version" "$latest_tag_version" | sort -V | tail -n1)"
    fi
  fi

  if [[ -n "$latest_known_version" ]]; then
    newest_seen="$(printf '%s\n%s\n' "$current_version" "$latest_known_version" | sort -V | tail -n1)"
    if [[ "$newest_seen" != "$current_version" ]]; then
      drift_detected='true'
      fail_check "current-version (${current_version}) is behind latest known version (${latest_known_version})."
    fi
  fi
fi

if [[ "$passed" != 'true' ]]; then
  {
    echo "passed=false"
    echo "tag_exists=${tag_exists}"
    echo "npm_version_exists=${npm_version_exists}"
    echo "drift_detected=${drift_detected}"
    echo "latest_npm_version=${latest_npm_version}"
    echo "latest_tag_version=${latest_tag_version}"
    echo "latest_known_version=${latest_known_version}"
  } >> "$GITHUB_OUTPUT"
  exit 1
fi

{
  echo "passed=true"
  echo "tag_exists=${tag_exists}"
  echo "npm_version_exists=${npm_version_exists}"
  echo "drift_detected=${drift_detected}"
  echo "latest_npm_version=${latest_npm_version}"
  echo "latest_tag_version=${latest_tag_version}"
  echo "latest_known_version=${latest_known_version}"
} >> "$GITHUB_OUTPUT"
