#!/usr/bin/env bash
set -euo pipefail

status="${1:-}"
target_commit="${2:-unknown}"
previous_commit="${3:-unknown}"
message="${4:-}"

log_dir="${DEPLOY_LOG_DIR:-logs}"
log_file="$log_dir/deployments.log"

if [ -z "$status" ]; then
  echo "Usage: $0 <status> [target_commit] [previous_commit] [message]"
  exit 2
fi

mkdir -p "$log_dir"

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
current_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

printf '%s | status=%s | target=%s | previous=%s | current=%s | message=%s\n' \
  "$timestamp" \
  "$status" \
  "$target_commit" \
  "$previous_commit" \
  "$current_commit" \
  "$message" >> "$log_file"

echo "Recorded deployment event: $status"
