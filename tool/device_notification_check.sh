#!/usr/bin/env bash
# Checks real notifications on a booted iOS simulator, then puts the real
# app back, with its data.
#
#   tool/device_notification_check.sh "iPhone 17 Pro"
#
# Don't use `flutter test integration_test` for this: it uninstalls the app
# afterwards, which deletes its habits. `flutter drive --keep-app-running`
# runs the same test and leaves the app installed; this script then installs
# the real app over the test build (`flutter run --no-resident`) and opens
# it, which also reschedules the reminders the check cleared.
set -euo pipefail
cd "$(dirname "$0")/.."

device="${1:?Usage: tool/device_notification_check.sh \"<simulator name>\"}"
bundle_id="com.paulblake.momentum"

udid=$(xcrun simctl list devices booted | grep -F "$device (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
if [[ -z "$udid" ]]; then
  echo "No booted simulator named \"$device\". Start it from DeviceHub first." >&2
  exit 1
fi

status=0
./flutter/bin/flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/notifications_on_device_test.dart \
  -d "$udid" --keep-app-running || status=$?

echo "Putting the real app back on $device..."
xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
# Builds, installs over the test build (keeping data) and opens it, then exits
./flutter/bin/flutter run -d "$udid" --no-resident

if [[ $status -eq 0 ]]; then
  echo "Notifications work on $device; the app is back."
else
  echo "The notification check FAILED on $device (see above); the app is back." >&2
fi
exit $status
