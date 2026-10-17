#!/usr/bin/env bash
# Runs the notification simulator (test/simulation) in four time zones, so
# daylight-saving changes are covered: UTC, New York and London fall back
# on Nov 1 / Oct 25, and Lord Howe moves by 30 minutes on Oct 4.
# Run after changing anything about reminders, streak warnings or dates.
#   tool/notification_sim.sh                  check every zone
#   tool/notification_sim.sh --update-goldens  save new timelines (review the diff!)
set -euo pipefail
cd "$(dirname "$0")/.."

status=0
for zone in UTC America/New_York Europe/London Australia/Lord_Howe; do
  echo "== $zone"
  if ! TZ="$zone" ./flutter/bin/flutter test test/simulation "$@" --reporter=compact; then
    status=1
  fi
done
exit $status
