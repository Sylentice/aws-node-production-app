#!/usr/bin/env bash
set -euo pipefail

deployment_log="${DEPLOY_LOG_FILE:-logs/deployments.log}"

print_section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

print_section "Git Status"

echo "Current branch:"
git branch --show-current || true

echo
echo "Current commit:"
git rev-parse HEAD || true

echo
echo "Latest commit:"
git --no-pager log -1 --oneline || true

print_section "Application Readiness"

if curl -fsS http://localhost/ready; then
  echo
  echo "Readiness check passed"
else
  echo
  echo "Readiness check failed"
fi

print_section "Application Version"

if curl -fsS http://localhost/version; then
  echo
  echo "Version endpoint passed"
else
  echo
  echo "Version endpoint failed"
fi

print_section "Docker Compose Services"

docker-compose ps || true

print_section "Running Containers"

docker ps --filter "name=myapp" || true

print_section "Recent Deployment Events"

if [ -f "$deployment_log" ]; then
  tail -n 10 "$deployment_log"
else
  echo "No deployment log found at $deployment_log"
fi

print_section "Status Summary Complete"
