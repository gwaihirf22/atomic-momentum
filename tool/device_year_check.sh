#!/usr/bin/env bash
# Lives the year simulation's persona on a real simulator or emulator, with
# screenshots of every screen at each month's end, then puts the real app
# back, with its data (the year runs on in-memory storage, never touching it).
#
#   tool/device_year_check.sh "iPhone 17 Pro"
#   tool/device_year_check.sh "iPhone SE (3rd generation)"
#   tool/device_year_check.sh emulator-5554 92     # Android, 92 days (slow emulator)
#
# Screenshots land in build/year_screens/<device>/ (m01_habits.png ...).
# Like device_notification_check.sh, this uses `flutter drive
# --keep-app-running`, never `flutter test integration_test` (which
# uninstalls the app and its habits).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter="${FLUTTER:-./flutter/bin/flutter}"

device="${1:?Usage: tool/device_year_check.sh \"<simulator name or device id>\" [days]}"
days="${2:-365}"
bundle_id="com.paulblake.momentum"

# A booted iPhone simulator by name, or any device id Flutter knows
udid=$(xcrun simctl list devices booted 2>/dev/null | grep -F "$device (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)
id="${udid:-$device}"
screens="build/year_screens/$(echo "$device" | tr -c 'A-Za-z0-9\n' '_')"
rm -rf "$screens"

# flutter drive now and then launches the app but never connects to it (a
# white screen, forever): give each try 4 minutes to connect, then retry
status=1
for attempt in 1 2 3; do
  log=$(mktemp)
  YEAR_SCREENS="$screens" "$flutter" drive \
    --driver=test_driver/year_driver.dart \
    --target=integration_test/year_on_device_test.dart \
    --dart-define=YEAR_DAYS="$days" \
    -d "$id" --keep-app-running >"$log" 2>&1 &
  pid=$!
  waited=0
  tail -f "$log" & tailer=$!
  while kill -0 "$pid" 2>/dev/null; do
    if ! grep -q "Connected to Flutter application" "$log" && [[ $waited -ge 240 ]]; then
      echo "flutter drive didn't connect within 4 minutes (try $attempt); retrying..." >&2
      pkill -P "$pid" 2>/dev/null || true
      kill "$pid" 2>/dev/null || true
      [[ -n "$udid" ]] && xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
      break
    fi
    sleep 5
    waited=$((waited + 5))
  done
  wait "$pid" 2>/dev/null && status=0 || status=$?
  kill "$tailer" 2>/dev/null || true
  if grep -q "Connected to Flutter application" "$log"; then
    rm -f "$log"
    break
  fi
  rm -f "$log"
  status=1
done

echo "Putting the real app back on $device..."
if [[ -n "$udid" ]]; then
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
fi
# Builds, installs over the test build (keeping data) and opens it, then exits
"$flutter" run -d "$id" --no-resident

if [[ $status -eq 0 ]]; then
  echo "A year passed on $device; screenshots in $screens. The app is back."
else
  echo "The year FAILED on $device (see above); screenshots so far in $screens. The app is back." >&2
fi
exit $status
