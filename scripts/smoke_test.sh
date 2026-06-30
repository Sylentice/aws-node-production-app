#!/usr/bin/env bash
set -euo pipefail

base_url="${BASE_URL:-http://localhost}"
expected_commit="${1:-}"

tmp_body=$(mktemp)
trap 'rm -f "$tmp_body"' EXIT

assert_json() {
  label="$1"
  assertion_script="$2"

  BODY_FILE="$tmp_body" LABEL="$label" node -e "
const fs = require('fs');

const label = process.env.LABEL;
const bodyFile = process.env.BODY_FILE;
const assertionScript = process.argv[1];

let data;

try {
  data = JSON.parse(fs.readFileSync(bodyFile, 'utf8'));
} catch (error) {
  console.error(label + ' failed: response was not valid JSON');
  console.error(fs.readFileSync(bodyFile, 'utf8'));
  process.exit(1);
}

const assert = (condition, message) => {
  if (!condition) {
    console.error(label + ' failed: ' + message);
    console.error(JSON.stringify(data, null, 2));
    process.exit(1);
  }
};

const fn = new Function('data', 'assert', assertionScript);
fn(data, assert);
console.log(label + ' JSON assertions passed');
" "$assertion_script"
}

check_success_json() {
  path="$1"
  label="$2"
  assertion_script="$3"

  echo "Checking $label: $base_url$path"

  if curl -fsS "$base_url$path" > "$tmp_body"; then
    cat "$tmp_body"
    echo
    assert_json "$label" "$assertion_script"
    echo "$label passed"
  else
    echo "$label failed"
    cat "$tmp_body" || true
    echo
    return 1
  fi
}

check_status_json() {
  path="$1"
  expected_status="$2"
  label="$3"
  assertion_script="$4"

  echo "Checking $label: $base_url$path expects HTTP $expected_status"

  actual_status=$(curl -sS -o "$tmp_body" -w "%{http_code}" "$base_url$path")

  cat "$tmp_body" || true
  echo

  if [ "$actual_status" != "$expected_status" ]; then
    echo "$label failed: expected HTTP $expected_status, got HTTP $actual_status"
    return 1
  fi

  assert_json "$label" "$assertion_script"

  echo "$label passed with HTTP $actual_status"
}

echo "Starting production smoke tests against: $base_url"

check_success_json "/" "home route" '
assert(typeof data.message === "string", "message should be a string");
assert(data.message.length > 0, "message should not be empty");
assert(typeof data.timestamp === "string", "timestamp should be a string");
assert(!Number.isNaN(Date.parse(data.timestamp)), "timestamp should be parseable");
'

check_success_json "/live" "liveness route" '
assert(data.status === "OK", "status should be OK");
assert(data.service === "alive", "service should be alive");
assert(typeof data.hostname === "string", "hostname should be a string");
assert(typeof data.uptime === "number", "uptime should be a number");
assert(typeof data.timestamp === "string", "timestamp should be a string");
assert(!Number.isNaN(Date.parse(data.timestamp)), "timestamp should be parseable");
'

check_success_json "/ready" "readiness route" '
assert(data.status === "OK", "status should be OK");
assert(data.service === "ready", "service should be ready");
assert(data.database === "connected", "database should be connected");
assert(typeof data.hostname === "string", "hostname should be a string");
assert(typeof data.uptime === "number", "uptime should be a number");
assert(typeof data.timestamp === "string", "timestamp should be a string");
assert(!Number.isNaN(Date.parse(data.timestamp)), "timestamp should be parseable");
'

check_success_json "/version" "version route" "
assert(data.service === 'myapp-api', 'service should be myapp-api');
assert(typeof data.commit === 'string', 'commit should be a string');
assert(data.commit.length > 0, 'commit should not be empty');
assert(data.environment === 'production', 'environment should be production');
assert(typeof data.hostname === 'string', 'hostname should be a string');
assert(typeof data.uptime === 'number', 'uptime should be a number');
assert(typeof data.timestamp === 'string', 'timestamp should be a string');
assert(!Number.isNaN(Date.parse(data.timestamp)), 'timestamp should be parseable');

const expectedCommit = '$expected_commit';
if (expectedCommit.length > 0) {
  assert(data.commit === expectedCommit, 'commit should match expected commit ' + expectedCommit);
}
"

check_status_json "/users" "401" "protected users route without token" '
assert(typeof data.error === "string", "error should be a string");
assert(data.error.length > 0, "error should not be empty");
'

check_status_json "/smoke-test-missing-route" "404" "unknown route" '
assert(typeof data.error === "string", "error should be a string");
assert(data.error.length > 0, "error should not be empty");
'

echo "Production smoke tests passed"
