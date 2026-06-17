#!/bin/bash

URL="http://localhost/health"
DISK_THRESHOLD=80
TIMESTAMP=$(date --iso-8601=seconds)
ALERT=0

if STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL"); then
  :
else
  STATUS="000"
fi

if [ "$STATUS" = "200" ]; then
  echo "$TIMESTAMP | OK | APPLICATION HEALTHY | Status: $STATUS"
else
  echo "$TIMESTAMP | ALERT | APPLICATION DOWN | Status: $STATUS"
  ALERT=1
fi

DISK_USAGE=$(df -P / | awk 'NR==2 {gsub("%", "", $5); print $5}')
DISK_AVAILABLE=$(df -hP / | awk 'NR==2 {print $4}')

if [ "$DISK_USAGE" -ge "$DISK_THRESHOLD" ]; then
  echo "$TIMESTAMP | ALERT | DISK USAGE ${DISK_USAGE}% | Available: $DISK_AVAILABLE"
  docker system df
  ALERT=1
else
  echo "$TIMESTAMP | OK | DISK USAGE ${DISK_USAGE}% | Available: $DISK_AVAILABLE"
fi

exit "$ALERT"
