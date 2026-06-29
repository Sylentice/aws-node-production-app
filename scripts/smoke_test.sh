#!/usr/bin/env bash
set -euo pipefail

base_url="${BASE_URL:-http://localhost}"
expected_commit="${1:-}"

tmp_body=$(mktemp)
trap 'rm -f "$tmp_body"' EXIT

check_success() {
  path="$1"
  label="$2"

  echo "Checking $label: $base_url$path"

  if curl -fsS "$base_url$path" > "$tmp_body"; then
    cat "$tmp_body"
    echo
    echo "$label passed"
  else
    echo "$label failed"
    cat "$tmp_body" || true
    echo
    return 1
  fi
}

check_status() {
  path="$1"
  expected_status="$2"
  label="$3"

  echo "Checking $label: $base_url$path expects HTTP $expected_status"

  actual_status=$(curl -sS -o "$tmp_body" -w "%{http_code}" "$base_url$path")

  cat "$tmp_body" || true
  echo

  if [ "$actual_status" != "$expected_status" ]; then
    echo "$label failed: expected HTTP $expected_status, got HTTP $actual_status"
    return 1
  fi

  echo "$label passed with HTTP $actual_status"
}

check_version_commit() {
  if [ -z "$expected_commit" ]; then
    echo "No expected commit provided; skipping /version commit match check"
    return 0
  fi

  echo "Checking /version contains expected commit: $expected_commit"

  version_response=$(curl -fsS "$base_url/version")

  echo "$version_response"

  if ! echo "$version_response" | grep -q "$expected_commit"; then
    echo "/version did not contain expected commit"
    return 1
  fi

  echo "/version commit match passed"
}

echo "Starting production smoke tests against: $base_url"

check_success "/" "home route"
check_success "/live" "liveness route"
check_success "/ready" "readiness route"
check_success "/version" "version route"
check_version_commit
check_status "/users" "401" "protected users route without token"
check_status "/smoke-test-missing-route" "404" "unknown route"

echo "Production smoke tests passed"
