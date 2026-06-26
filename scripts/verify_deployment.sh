#!/usr/bin/env bash
set -euo pipefail

expected_commit="${1:-}"
expected_api_count="${EXPECTED_API_COUNT:-3}"
max_ready_attempts="${MAX_READY_ATTEMPTS:-12}"
ready_sleep_seconds="${READY_SLEEP_SECONDS:-5}"
max_health_attempts="${MAX_HEALTH_ATTEMPTS:-12}"
health_sleep_seconds="${HEALTH_SLEEP_SECONDS:-5}"

if [ -z "$expected_commit" ]; then
  echo "Usage: $0 <expected_git_commit>"
  exit 2
fi

wait_for_ready() {
  echo "Waiting for application readiness..."

  for i in $(seq 1 "$max_ready_attempts"); do
    if curl -fsS http://localhost/ready; then
      echo
      echo "Application is ready"
      return 0
    fi

    echo "Readiness attempt $i failed; retrying..."
    sleep "$ready_sleep_seconds"
  done

  echo "Application did not become ready"
  return 1
}

verify_api_count() {
  api_count=$(docker-compose ps -q api | wc -l | tr -d ' ')

  if [ "$api_count" -ne "$expected_api_count" ]; then
    echo "Expected $expected_api_count API containers, found $api_count"
    docker ps
    return 1
  fi

  echo "Verified $expected_api_count API containers"
}

wait_for_api_container_health() {
  echo "Waiting for API containers to report Docker health status: healthy"

  for attempt in $(seq 1 "$max_health_attempts"); do
    all_healthy=true

    for container_id in $(docker-compose ps -q api); do
      container_name=$(docker inspect -f '{{.Name}}' "$container_id" | sed 's#^/##')
      health_status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container_id")

      echo "$container_name health status: $health_status"

      if [ "$health_status" != "healthy" ]; then
        all_healthy=false
      fi
    done

    if [ "$all_healthy" = "true" ]; then
      echo "Verified all API containers are Docker-healthcheck healthy"
      return 0
    fi

    echo "API container health attempt $attempt failed; retrying..."
    sleep "$health_sleep_seconds"
  done

  echo "API containers did not become Docker-healthcheck healthy"
  docker ps
  return 1
}

verify_load_balanced_version() {
  echo "Verifying load-balanced /version reports commit: $expected_commit"

  version_response=$(curl -fsS http://localhost/version || true)

  if [ -z "$version_response" ]; then
    echo "Version endpoint did not return a response"
    return 1
  fi

  echo "$version_response"

  if ! echo "$version_response" | grep -q "$expected_commit"; then
    echo "Version verification failed. Expected commit was not found in load-balanced /version response."
    return 1
  fi

  echo "Verified load-balanced deployed version commit"
}

verify_all_api_versions() {
  containers=$(docker-compose ps -q api)

  if [ -z "$containers" ]; then
    echo "No API containers found for per-replica version verification"
    return 1
  fi

  echo "Verifying every API replica reports commit: $expected_commit"

  for container_id in $containers; do
    container_name=$(docker inspect -f '{{.Name}}' "$container_id" | sed 's#^/##')
    echo "Checking $container_name"

    version_response=$(docker exec "$container_id" curl -fsS http://localhost:3000/version || true)

    if [ -z "$version_response" ]; then
      echo "$container_name did not return a /version response"
      return 1
    fi

    echo "$version_response"

    if ! echo "$version_response" | grep -q "$expected_commit"; then
      echo "$container_name is not running expected commit $expected_commit"
      return 1
    fi
  done

  echo "Verified every API replica reports the expected commit"
}

wait_for_ready
verify_api_count
wait_for_api_container_health
verify_load_balanced_version
verify_all_api_versions

echo "Deployment verification passed for commit: $expected_commit"
