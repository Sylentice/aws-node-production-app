#!/usr/bin/env bash
set -euo pipefail

preflight_failed=false

print_section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

check_command() {
  command_name="$1"

  if command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name found: $(command -v "$command_name")"
  else
    echo "$command_name is missing"
    preflight_failed=true
  fi
}

check_file_executable() {
  file_path="$1"

  if [ -x "$file_path" ]; then
    echo "$file_path exists and is executable"
  else
    echo "$file_path is missing or not executable"
    preflight_failed=true
  fi
}

check_file_exists() {
  file_path="$1"

  if [ -f "$file_path" ]; then
    echo "$file_path exists"
  else
    echo "$file_path is missing"
    preflight_failed=true
  fi
}

print_section "Deployment Preflight Checks"

echo "Running from: $(pwd)"
echo "Host: $(hostname)"
echo "UTC time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

print_section "Required Commands"

check_command git
check_command docker
check_command docker-compose
check_command curl
check_command bash

print_section "Git Repository"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Git repository check passed"
  echo "Current branch: $(git branch --show-current)"
  echo "Current commit: $(git rev-parse HEAD)"
else
  echo "This directory is not a Git repository"
  preflight_failed=true
fi

print_section "Required Files"

check_file_exists docker-compose.yml
check_file_exists .env
check_file_exists .env.example

print_section "Required Scripts"

check_file_executable scripts/verify_deployment.sh
check_file_executable scripts/record_deployment.sh
check_file_executable scripts/deployment_status.sh
check_file_executable scripts/smoke_test.sh
check_file_executable scripts/check_env_example.sh
check_file_executable scripts/ops.sh

print_section "Docker Daemon"

if docker info >/dev/null 2>&1; then
  echo "Docker daemon is reachable"
else
  echo "Docker daemon is not reachable"
  preflight_failed=true
fi

print_section "Docker Compose Configuration"

if docker-compose config >/dev/null; then
  echo "Docker Compose configuration is valid"
else
  echo "Docker Compose configuration is invalid"
  preflight_failed=true
fi

print_section "Secrets Safety"

if ./scripts/ops.sh secrets; then
  echo "Secrets safety check passed from preflight"
else
  echo "Secrets safety check failed from preflight"
  preflight_failed=true
fi

print_section "Environment Example Safety"

if ./scripts/check_env_example.sh; then
  echo "Environment example check passed from preflight"
else
  echo "Environment example check failed from preflight"
  preflight_failed=true
fi

print_section "Logs Directory"

mkdir -p logs

if [ -w logs ]; then
  echo "logs directory is writable"
else
  echo "logs directory is not writable"
  preflight_failed=true
fi

print_section "Preflight Result"

if [ "$preflight_failed" = "true" ]; then
  echo "Deployment preflight checks failed"
  exit 1
fi

echo "Deployment preflight checks passed"
