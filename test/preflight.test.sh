#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/preflight.sh"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "preflight script not found at $SCRIPT_PATH"
  exit 1
fi

workspace="$(mktemp -d "${TMPDIR:-/tmp}/release-preflight-test.XXXXXX")"
trap 'rm -rf "$workspace"' EXIT

real_node="$(command -v node || true)"
if [[ -z "$real_node" ]]; then
  echo "node executable not found in PATH"
  exit 1
fi

mock_bin="$workspace/bin"
mkdir -p "$mock_bin"

cat > "$mock_bin/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ge 3 && "$1" == "view" && "$2" == "release-preflight-action" && "$3" == "version" ]]; then
  # Simulate npm latest (defaults to pointing at a prerelease).
  echo "${MOCK_NPM_LATEST:-1.0.1-1}"
  exit 0
fi

# Simulate "version already exists" lookup miss by returning failure.
exit 1
EOF
chmod +x "$mock_bin/npm"

cat > "$mock_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ge 5 && "$1" == "ls-remote" && "$2" == "--tags" && "$3" == "--refs" ]]; then
  pattern="${5:-}"
  if [[ "$pattern" == "refs/tags/v*" ]]; then
    # Return the mocked tag list (defaults to one stable tag).
    for tag in ${MOCK_TAGS:-v1.0.1}; do
      printf '0123456789abcdef0123456789abcdef01234567\trefs/tags/%s\n' "$tag"
    done
    exit 0
  fi

  # Candidate tag check should report no match.
  exit 0
fi

if [[ "$1" == "version" ]]; then
  echo "git version 2.42.0"
  exit 0
fi

exit 1
EOF
chmod +x "$mock_bin/git"

cat > "$mock_bin/node" <<EOF
#!/usr/bin/env bash
exec "$real_node" "$@"
EOF
chmod +x "$mock_bin/node"

assert_file_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -q "^${expected}$" "$file"; then
    echo "Expected line not found: ${expected}"
    echo "Actual output:"
    cat "$file"
    exit 1
  fi
}

assert_file_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -q "^${unexpected}$" "$file"; then
    echo "Unexpected line found: ${unexpected}"
    echo "Actual output:"
    cat "$file"
    exit 1
  fi
}

run_case_stable_not_behind_prerelease_latest() {
  local output_file="$workspace/output-1.txt"

  PATH="$mock_bin:$PATH" \
  CANDIDATE_VERSION='1.0.2' \
  CANDIDATE_TAG='v1.0.2' \
  PACKAGE_NAME='release-preflight-action' \
  CURRENT_VERSION='1.0.1' \
  CHECK_REMOTE_TAG='false' \
  CHECK_NPM_VERSION='false' \
  CHECK_VERSION_DRIFT='true' \
  GIT_REMOTE='origin' \
  GITHUB_OUTPUT="$output_file" \
  bash "$SCRIPT_PATH"

  assert_file_contains "$output_file" 'passed=true'
  assert_file_contains "$output_file" 'drift_detected=false'
  assert_file_contains "$output_file" 'latest_npm_version=1.0.1-1'
  assert_file_contains "$output_file" 'latest_tag_version=1.0.1'
  assert_file_contains "$output_file" 'latest_known_version=1.0.1'
  assert_file_not_contains "$output_file" 'passed=false'
}

run_drift_check() {
  local output_file="$1"
  local current_version="$2"
  local candidate_version="$3"

  PATH="$mock_bin:$PATH" \
  CANDIDATE_VERSION="$candidate_version" \
  CANDIDATE_TAG="v${candidate_version}" \
  PACKAGE_NAME='release-preflight-action' \
  CURRENT_VERSION="$current_version" \
  CHECK_REMOTE_TAG='false' \
  CHECK_NPM_VERSION='false' \
  CHECK_VERSION_DRIFT='true' \
  GIT_REMOTE='origin' \
  GITHUB_OUTPUT="$output_file" \
  bash "$SCRIPT_PATH" >/dev/null 2>&1
}

# Promoting a prerelease: stable base 1.0.1, prerelease tag 1.0.2-1 exists,
# patch release candidate 1.0.2. The prerelease is not drift.
run_case_stable_base_ahead_prerelease_tag_is_not_drift() {
  local output_file="$workspace/output-2.txt"

  MOCK_TAGS='v1.0.1 v1.0.2-0 v1.0.2-1' MOCK_NPM_LATEST='1.0.1' \
    run_drift_check "$output_file" '1.0.1' '1.0.2'

  assert_file_contains "$output_file" 'passed=true'
  assert_file_contains "$output_file" 'drift_detected=false'
  assert_file_contains "$output_file" 'latest_tag_version=1.0.2-1'
  assert_file_contains "$output_file" 'latest_known_version=1.0.2-1'
}

# A newer stable release exists than the stable base: genuine drift.
run_case_stable_base_behind_newer_stable_is_drift() {
  local output_file="$workspace/output-3.txt"

  if MOCK_TAGS='v1.0.1 v1.0.2 v1.0.3-0' MOCK_NPM_LATEST='1.0.2' \
    run_drift_check "$output_file" '1.0.1' '1.0.2'; then
    echo "Expected preflight to fail for stable base behind newer stable release"
    exit 1
  fi

  assert_file_contains "$output_file" 'passed=false'
  assert_file_contains "$output_file" 'drift_detected=true'
}

# A prerelease base is still compared against prereleases.
run_case_prerelease_base_behind_newer_prerelease_is_drift() {
  local output_file="$workspace/output-4.txt"

  if MOCK_TAGS='v1.0.1 v1.0.2-0 v1.0.2-1' MOCK_NPM_LATEST='1.0.1' \
    run_drift_check "$output_file" '1.0.2-0' '1.0.2-1'; then
    echo "Expected preflight to fail for prerelease base behind newer prerelease"
    exit 1
  fi

  assert_file_contains "$output_file" 'passed=false'
  assert_file_contains "$output_file" 'drift_detected=true'
}

run_case_stable_not_behind_prerelease_latest
run_case_stable_base_ahead_prerelease_tag_is_not_drift
run_case_stable_base_behind_newer_stable_is_drift
run_case_prerelease_base_behind_newer_prerelease_is_drift

echo "All preflight tests passed"
