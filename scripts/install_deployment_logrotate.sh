#!/usr/bin/env bash
set -euo pipefail

app_dir="${APP_DIR:-/var/www/myapp}"
logrotate_config_path="${LOGROTATE_CONFIG_PATH:-/etc/logrotate.d/myapp-deployments}"

if ! command -v logrotate >/dev/null 2>&1; then
  echo "logrotate is not installed. Install it first with:"
  echo "sudo apt-get update && sudo apt-get install -y logrotate"
  exit 1
fi

echo "Installing deployment logrotate config at: $logrotate_config_path"

sudo tee "$logrotate_config_path" >/dev/null <<CONFIG
$app_dir/logs/deployments.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0644 ubuntu ubuntu
    su ubuntu ubuntu
}
CONFIG

echo "Installed deployment logrotate config"

echo
echo "Previewing logrotate behavior:"
sudo logrotate -d "$logrotate_config_path"
