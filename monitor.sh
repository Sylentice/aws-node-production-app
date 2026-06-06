#!/bin/bash

URL="http://localhost:3001/health"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" $URL)

TIMESTAMP=$(date)

if [ "$STATUS" != "200" ]; then
  echo "$TIMESTAMP | ALERT | API DOWN | Status: $STATUS"
else
  echo "$TIMESTAMP | OK | API HEALTHY"
fi
