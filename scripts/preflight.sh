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

is_semver() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]
}

compare_semver() {
  local left="$1"
  local right="$2"
  LEFT="$left" RIGHT="$right" node <<'NODE'
const left = process.env.LEFT || '';
const right = process.env.RIGHT || '';

const parse = (v) => {
  if (typeof v !== 'string' || v.length === 0) {
    return null;
  }
  const m = v.match(/^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$/);
  if (!m) {
    return null;
  }
  return {
    major: Number(m[1]),
    minor: Number(m[2]),
    patch: Number(m[3]),
    prerelease: m[4] ? m[4].split('.') : null,
  };
};

const cmpIdentifier = (a, b) => {
  const aNum = /^\d+$/.test(a);
  const bNum = /^\d+$/.test(b);
  if (aNum && bNum) {
    const ai = Number(a);
    const bi = Number(b);
    return ai === bi ? 0 : ai > bi ? 1 : -1;
  }
  if (aNum && !bNum) return -1;
  if (!aNum && bNum) return 1;
  if (a === b) return 0;
  return a > b ? 1 : -1;
};

const cmp = (a, b) => {
  if (a.major !== b.major) return a.major > b.major ? 1 : -1;
  if (a.minor !== b.minor) return a.minor > b.minor ? 1 : -1;
  if (a.patch !== b.patch) return a.patch > b.patch ? 1 : -1;

  if (!a.prerelease && !b.prerelease) return 0;
  if (!a.prerelease) return 1;
  if (!b.prerelease) return -1;

  const len = Math.max(a.prerelease.length, b.prerelease.length);
  for (let i = 0; i < len; i += 1) {
    const ai = a.prerelease[i];
    const bi = b.prerelease[i];
    if (ai === undefined) return -1;
    if (bi === undefined) return 1;
    const c = cmpIdentifier(ai, bi);
    if (c !== 0) return c;
  }

  return 0;
};

const a = parse(left);
const b = parse(right);
if (!a || !b) {
  console.log('0');
  process.exit(0);
}

console.log(String(cmp(a, b)));
NODE
}

max_semver() {
  local best=''
  local candidate=''

  while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    if ! is_semver "$candidate"; then
      continue
    fi

    if [[ -z "$best" ]]; then
      best="$candidate"
      continue
    fi

    if [[ "$(compare_semver "$candidate" "$best")" == '1' ]]; then
      best="$candidate"
    fi
  done

  printf '%s' "$best"
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
  require_cmd node
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
  latest_tag_version="$(git ls-remote --tags --refs "$git_remote" 'refs/tags/v*' | awk -F'/' '{print $3}' | sed 's/^v//' | max_semver)"

  latest_known_version="$(printf '%s\n%s\n' "$latest_npm_version" "$latest_tag_version" | max_semver)"

  if [[ -n "$latest_known_version" ]]; then
    if ! is_semver "$current_version"; then
      echo "current-version must be a valid semver when check-version-drift=true"
      exit 1
    fi

    if [[ "$(compare_semver "$current_version" "$latest_known_version")" == '-1' ]]; then
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
