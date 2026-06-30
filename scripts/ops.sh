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
  verify        Run strict deployment verification against the current Git commit
  smoke         Run production smoke tests against the current Git commit
  ps            Show Docker Compose services and myapp containers
  logs          Show recent Docker Compose logs
  deploy-log    Show recent deployment audit log entries
  version       Show the public /version response
  ready         Show the public /ready response

Examples:
  ./scripts/ops.sh status
  ./scripts/ops.sh verify
  ./scripts/ops.sh smoke
  ./scripts/ops.sh logs
HELP
}

current_commit() {
  git rev-parse HEAD
}

case "$command_name" in
  help|-h|--help)
    print_help
    ;;

  status)
    ./scripts/deployment_status.sh
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
    docker-compose logs --tail="${LOG_TAIL:-100}"
    ;;

  deploy-log)
    if [ -f logs/deployments.log ]; then
      tail -n "${DEPLOY_LOG_TAIL:-20}" logs/deployments.log
    else
      echo "No deployment log found at logs/deployments.log"
    fi
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
