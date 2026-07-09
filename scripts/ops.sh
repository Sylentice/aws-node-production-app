#!/usr/bin/env bash
set -euo pipefail

command_name="${1:-help}"

if [ "$#" -gt 0 ]; then
  shift
fi

print_help() {
  cat <<HELP
Usage:
  ./scripts/ops.sh <command>

Commands:
  help             Show this help menu
  status           Show app, Git, Docker, and deployment status
  doctor           Run common health checks and show logs if something fails
  snapshot         Save a diagnostic snapshot to logs/diagnostics
  snapshots        List saved diagnostic snapshots
  clean-snapshots  Delete diagnostic snapshots older than the retention period
  disk             Show Docker disk usage and cleanup candidates
  clean-docker     Safely clean stopped containers and dangling Docker images
  secrets          Check .env safety without printing secret values
  verify           Run strict deployment verification against the current Git commit
  smoke            Run production smoke tests against the current Git commit
  ps               Show Docker Compose services and myapp containers
  logs             Show recent Docker Compose logs
  deploy-log       Show recent deployment audit log entries
  version          Show the public /version response
  ready            Show the public /ready response

Examples:
  ./scripts/ops.sh status
  ./scripts/ops.sh doctor
  ./scripts/ops.sh snapshot
  ./scripts/ops.sh snapshots
  ./scripts/ops.sh disk
  ./scripts/ops.sh clean-docker
  ./scripts/ops.sh secrets
  DRY_RUN=false ./scripts/ops.sh clean-docker
  AGGRESSIVE=true DRY_RUN=false ./scripts/ops.sh clean-docker
  ENV_FILE=.env ./scripts/ops.sh secrets
  ./scripts/ops.sh verify
  ./scripts/ops.sh smoke
  ./scripts/ops.sh logs

Environment overrides:
  LOG_TAIL=200 ./scripts/ops.sh logs
  DEPLOY_LOG_TAIL=50 ./scripts/ops.sh deploy-log
  SNAPSHOT_RETENTION_DAYS=30 ./scripts/ops.sh clean-snapshots
  DRY_RUN=true ./scripts/ops.sh clean-snapshots
  DRY_RUN=false ./scripts/ops.sh clean-docker
  AGGRESSIVE=true DRY_RUN=false ./scripts/ops.sh clean-docker
HELP
}

current_commit() {
  git rev-parse HEAD
}

snapshot_directory() {
  echo "${SNAPSHOT_DIR:-logs/diagnostics}"
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

show_docker_disk() {
  echo
  echo "============================================================"
  echo "Docker Disk Usage"
  echo "============================================================"
  docker system df

  echo
  echo "============================================================"
  echo "Dangling Images"
  echo "============================================================"
  docker image ls --filter dangling=true

  echo
  echo "============================================================"
  echo "Stopped Containers"
  echo "============================================================"
  docker container ls -a --filter status=exited

  echo
  echo "============================================================"
  echo "Docker Volumes"
  echo "============================================================"
  docker volume ls
}

clean_docker() {
  dry_run="${DRY_RUN:-true}"
  aggressive="${AGGRESSIVE:-false}"

  echo "Docker cleanup mode"
  echo "DRY_RUN=$dry_run"
  echo "AGGRESSIVE=$aggressive"
  echo
  echo "This cleanup does not remove Docker volumes."
  echo "Your Postgres data volume is not targeted by this command."
  echo

  if [ "$dry_run" != "false" ]; then
    echo "Dry run preview only. No Docker resources will be deleted."
    echo
    show_docker_disk
    echo
    echo "To clean stopped containers and dangling images, run:"
    echo "DRY_RUN=false ./scripts/ops.sh clean-docker"
    echo
    echo "To also remove unused non-running images, run:"
    echo "AGGRESSIVE=true DRY_RUN=false ./scripts/ops.sh clean-docker"
    return 0
  fi

  echo "Cleaning stopped containers..."
  docker container prune -f

  echo
  echo "Cleaning dangling images..."
  docker image prune -f

  echo
  echo "Cleaning build cache..."
  docker builder prune -f || true

  if [ "$aggressive" = "true" ]; then
    echo
    echo "Aggressive cleanup enabled."
    echo "Removing unused images not attached to running containers..."
    docker image prune -a -f
  fi

  echo
  echo "Docker cleanup complete."

  show_docker_disk
}

check_secrets() {
  env_file="${ENV_FILE:-.env}"
  required_vars="${REQUIRED_ENV_VARS:-DATABASE_URL JWT_SECRET}"
  secrets_failed=false

  echo
  echo "============================================================"
  echo "Secrets Safety Check"
  echo "============================================================"
  echo "Env file: $env_file"
  echo "Required variables: $required_vars"
  echo
  echo "Secret values will not be printed."

  if [ ! -f "$env_file" ]; then
    echo "$env_file does not exist"
    exit 1
  fi

  echo
  echo "Checking file permissions..."

  permissions=$(stat -c "%a" "$env_file")
  owner_group=$(stat -c "%U:%G" "$env_file")

  echo "$env_file permissions: $permissions"
  echo "$env_file owner/group: $owner_group"

  if [ "$permissions" = "600" ]; then
    echo "File permissions passed"
  else
    echo "File permissions failed: expected 600"
    secrets_failed=true
  fi

  echo
  echo "Checking Git ignore status..."

  if git check-ignore -q "$env_file"; then
    echo "$env_file is ignored by Git"
  else
    echo "$env_file is not ignored by Git"
    secrets_failed=true
  fi

  echo
  echo "Checking Git tracking status..."

  if git ls-files --error-unmatch "$env_file" >/dev/null 2>&1; then
    echo "$env_file is tracked by Git"
    secrets_failed=true
  else
    echo "$env_file is not tracked by Git"
  fi

  echo
  echo "Checking required variables..."

  for var_name in $required_vars; do
    if grep -Eq "^[[:space:]]*$var_name=" "$env_file"; then
      var_value=$(grep -E "^[[:space:]]*$var_name=" "$env_file" | tail -n 1 | sed -E "s/^[[:space:]]*$var_name=//")

      if [ -n "$var_value" ]; then
        echo "$var_name is present and non-empty"
      else
        echo "$var_name is present but empty"
        secrets_failed=true
      fi
    else
      echo "$var_name is missing"
      secrets_failed=true
    fi
  done

  if [ "$secrets_failed" = "true" ]; then
    echo
    echo "Secrets safety check failed"
    exit 1
  fi

  echo
  echo "Secrets safety check passed"
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
    echo >> "$snapshot_file"
    echo "$label failed with exit code $exit_code" >> "$snapshot_file"
  fi
}

create_snapshot() {
  snapshot_dir="$(snapshot_directory)"
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

list_snapshots() {
  snapshot_dir="$(snapshot_directory)"

  echo "Diagnostic snapshot directory: $snapshot_dir"

  if [ ! -d "$snapshot_dir" ]; then
    echo "No diagnostic snapshot directory found"
    return 0
  fi

  snapshot_count=$(find "$snapshot_dir" -type f -name 'diagnostic_snapshot_*.log' | wc -l | tr -d ' ')

  if [ "$snapshot_count" -eq 0 ]; then
    echo "No diagnostic snapshots found"
    return 0
  fi

  echo "Found $snapshot_count diagnostic snapshot(s)"
  echo

  find "$snapshot_dir" -type f -name 'diagnostic_snapshot_*.log' -printf '%TY-%Tm-%Td %TH:%TM %10s bytes %p\n' | sort -r
}

clean_snapshots() {
  snapshot_dir="$(snapshot_directory)"
  retention_days="${1:-${SNAPSHOT_RETENTION_DAYS:-14}}"
  dry_run="${DRY_RUN:-false}"

  if ! [[ "$retention_days" =~ ^[0-9]+$ ]]; then
    echo "Retention days must be a whole number"
    echo "Example: ./scripts/ops.sh clean-snapshots 30"
    exit 2
  fi

  echo "Diagnostic snapshot directory: $snapshot_dir"
  echo "Retention days: $retention_days"

  if [ ! -d "$snapshot_dir" ]; then
    echo "No diagnostic snapshot directory found"
    return 0
  fi

  echo
  echo "Snapshots older than $retention_days day(s):"

  old_snapshots=$(find "$snapshot_dir" -type f -name 'diagnostic_snapshot_*.log' -mtime +"$retention_days" -print)

  if [ -z "$old_snapshots" ]; then
    echo "No old diagnostic snapshots found"
    return 0
  fi

  echo "$old_snapshots"

  if [ "$dry_run" = "true" ]; then
    echo
    echo "DRY_RUN=true, no files deleted"
    return 0
  fi

  echo "$old_snapshots" | while IFS= read -r snapshot; do
    rm -f "$snapshot"
    echo "Deleted $snapshot"
  done

  echo
  echo "Old diagnostic snapshot cleanup complete"
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

  snapshots)
    list_snapshots
    ;;

  clean-snapshots)
    clean_snapshots "$@"
    ;;

  disk)
    show_docker_disk
    ;;

  clean-docker)
    clean_docker
    ;;


  secrets)
    check_secrets
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
