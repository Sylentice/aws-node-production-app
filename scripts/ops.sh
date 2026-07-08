#!/usr/bin/env bash
set -euo pipefail

command_name="${1:-help}"

print_help() {
  cat <<HELP
Usage:
  ./scripts/ops.sh <command>

Commands:
  help          Show this help menu
  status        Show app, Git, Docker, and deployment status
  doctor        Run common health checks and show logs if something fails
  snapshot      Save a diagnostic snapshot to logs/diagnostics
  verify        Run strict deployment verification against the current Git commit
  smoke         Run production smoke tests against the current Git commit
  ps            Show Docker Compose services and myapp containers
  logs          Show recent Docker Compose logs
  deploy-log    Show recent deployment audit log entries
  version       Show the public /version response
  ready         Show the public /ready response

Examples:
  ./scripts/ops.sh status
  ./scripts/ops.sh doctor
  ./scripts/ops.sh snapshot
  ./scripts/ops.sh verify
  ./scripts/ops.sh smoke
  ./scripts/ops.sh logs
HELP
}

current_commit() {
  git rev-parse HEAD
}

show_docker_logs() {
  echo
  echo "============================================================"
  echo "Recent Docker Compose Logs"
  echo "============================================================"
  docker-compose logs --tail="${LOG_TAIL:-100}" || true
}

show_deployment_log() {
  echo
  echo "============================================================"
  echo "Recent Deployment Audit Log"
  echo "============================================================"

  if [ -f logs/deployments.log ]; then
    tail -n "${DEPLOY_LOG_TAIL:-20}" logs/deployments.log
  else
    echo "No deployment log found at logs/deployments.log"
  fi
}

run_doctor_step() {
  label="$1"
  shift

  echo
  echo "============================================================"
  echo "$label"
  echo "============================================================"

  if "$@"; then
    echo
    echo "$label passed"
  else
    echo
    echo "$label failed"
    doctor_failed=true
  fi
}

run_doctor() {
  doctor_failed=false

  echo "Running ops doctor against commit: $(current_commit)"

  run_doctor_step "Ready endpoint check" curl -fsS http://localhost/ready

  run_doctor_step "Version endpoint check" curl -fsS http://localhost/version

  run_doctor_step "Docker Compose service check" docker-compose ps

  run_doctor_step "Production smoke tests" ./scripts/smoke_test.sh "$(current_commit)"

  run_doctor_step "Strict deployment verification" ./scripts/verify_deployment.sh "$(current_commit)"

  if [ "$doctor_failed" = "true" ]; then
    echo
    echo "Ops doctor found one or more failures."

    show_docker_logs
    show_deployment_log

    exit 1
  fi

  echo
  echo "============================================================"
  echo "Ops doctor passed"
  echo "============================================================"
}

run_snapshot_command() {
  label="$1"
  shift

  {
    echo
    echo "============================================================"
    echo "$label"
    echo "============================================================"
  } >> "$snapshot_file"

  if "$@" >> "$snapshot_file" 2>&1; then
    echo >> "$snapshot_file"
    echo "$label captured" >> "$snapshot_file"
  else
    exit_code=$?
    echo "$label failed with exit code $exit_code" >> "$snapshot_file"
  fi
}

create_snapshot() {
  snapshot_dir="${SNAPSHOT_DIR:-logs/diagnostics}"
  timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
  snapshot_file="$snapshot_dir/diagnostic_snapshot_$timestamp.log"

  mkdir -p "$snapshot_dir"

  echo "Creating diagnostic snapshot: $snapshot_file"

  {
    echo "Diagnostic Snapshot"
    echo "Generated UTC: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Host: $(hostname)"
    echo "App directory: $(pwd)"
    echo "Current commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
  } > "$snapshot_file"

  run_snapshot_command "Git Branch" git branch --show-current
  run_snapshot_command "Git Status" git status --short
  run_snapshot_command "Latest Commit" git --no-pager log -1 --oneline
  run_snapshot_command "Ready Endpoint" curl -fsS http://localhost/ready
  run_snapshot_command "Version Endpoint" curl -fsS http://localhost/version
  run_snapshot_command "Docker Compose Services" docker-compose ps
  run_snapshot_command "Running myapp Containers" docker ps --filter "name=myapp"
  run_snapshot_command "Docker Disk Usage" docker system df
  run_snapshot_command "Container Resource Usage" bash -c '
container_ids=$(docker ps --filter "name=myapp" -q)

if [ -n "$container_ids" ]; then
  docker stats --no-stream $container_ids
else
  echo "No myapp containers found"
fi
'
  run_snapshot_command "Recent Docker Compose Logs" docker-compose logs --tail="${LOG_TAIL:-100}"
  run_snapshot_command "Recent Deployment Audit Log" bash -c '
if [ -f logs/deployments.log ]; then
  tail -n "${DEPLOY_LOG_TAIL:-20}" logs/deployments.log
else
  echo "No deployment log found at logs/deployments.log"
fi
'

  echo "Diagnostic snapshot saved to: $snapshot_file"
}

case "$command_name" in
  help|-h|--help)
    print_help
    ;;

  status)
    ./scripts/deployment_status.sh
    ;;

  doctor)
    run_doctor
    ;;

  snapshot)
    create_snapshot
    ;;

  verify)
    ./scripts/verify_deployment.sh "$(current_commit)"
    ;;

  smoke)
    ./scripts/smoke_test.sh "$(current_commit)"
    ;;

  ps)
    echo "Docker Compose services:"
    docker-compose ps
    echo
    echo "Running myapp containers:"
    docker ps --filter "name=myapp"
    ;;

  logs)
    show_docker_logs
    ;;

  deploy-log)
    show_deployment_log
    ;;

  version)
    curl -fsS http://localhost/version
    echo
    ;;

  ready)
    curl -fsS http://localhost/ready
    echo
    ;;

  *)
    echo "Unknown command: $command_name"
    echo
    print_help
    exit 2
    ;;
esac
