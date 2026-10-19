#!/usr/bin/env bash
# Checks the real health store against what the app expects: Apple Health on
# an iPhone simulator, Health Connect on an Android emulator. Writes real
# samples into 02:00–03:00 yesterday, reads every metric back, writes and
# deletes the app's own water (and mindful minutes on iPhone), then deletes
# its samples there and checks Health is back where it started; anything
# else in Health is left alone. Puts the real app back afterwards.
#
#   tool/device_health_check.sh "Year iPhone 17 Pro"   # tap Allow once, the first time
#   tool/device_health_check.sh emulator-5554           # permissions granted by the script
set -euo pipefail
cd "$(dirname "$0")/.."
flutter="${FLUTTER:-./flutter/bin/flutter}"
device="${1:?Usage: tool/device_health_check.sh \"<simulator name or device id>\"}"
bundle_id="com.paulblake.momentum"

udid=$(xcrun simctl list devices booted 2>/dev/null | grep -F "$device (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)
id="${udid:-$device}"

status=0
if [[ -z "$udid" ]]; then
  # Android: install the test build, grant Health Connect's permissions
  # (runtime permissions the shell can grant), start it and read the result
  # from the log (one build, where flutter drive would build twice). Health
  # Connect's permission screens left open in the app's task (a request
  # nobody answered) would take every launch, so they're closed first.
  adb="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}/platform-tools/adb"
  "$flutter" build apk --debug --target=integration_test/health_on_device_test.dart
  "$adb" -s "$id" install -r build/app/outputs/flutter-apk/app-debug.apk
  for p in READ_STEPS READ_EXERCISE READ_SLEEP READ_HYDRATION READ_DISTANCE READ_TOTAL_CALORIES_BURNED \
           WRITE_HYDRATION WRITE_STEPS WRITE_EXERCISE WRITE_SLEEP; do
    "$adb" -s "$id" shell pm grant "$bundle_id" "android.permission.health.$p" || true
  done
  for p in com.google.android.healthconnect.controller com.google.android.permissioncontroller; do
    "$adb" -s "$id" shell am force-stop "$p"
  done
  "$adb" -s "$id" logcat -c
  "$adb" -s "$id" shell am start -n "$bundle_id/.MainActivity" >/dev/null
  result=""
  for _ in $(seq 1 150); do
    sleep 2
    result=$("$adb" -s "$id" logcat -d -s flutter:I | grep -oE "All tests passed|Some tests failed" | head -1 || true)
    [[ -n "$result" ]] && break
  done
  "$adb" -s "$id" logcat -d -s flutter:I | sed -E 's/^.* I flutter *: //' | grep -vE "^\[IMPORTANT" || true
  [[ "$result" == "All tests passed" ]] || { echo "${result:-No result after 5 minutes}" >&2; status=1; }
  "$adb" -s "$id" shell am force-stop "$bundle_id"
else
  log=$(mktemp)
  "$flutter" drive --no-dds \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/health_on_device_test.dart \
    -d "$id" --keep-app-running 2>&1 | tee "$log" || status=$?
  # The driver can say "All tests passed" after the test itself failed
  if grep -qE "Some tests failed|\[E\]" "$log"; then status=1; fi
  rm -f "$log"
fi

echo "Putting the real app back on $device..."
[[ -n "$udid" ]] && { xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true; }
"$flutter" run -d "$id" --no-resident

if [[ $status -eq 0 ]]; then
  echo "Health works as the app expects on $device; the app is back."
else
  echo "The Health check FAILED on $device (see above); the app is back." >&2
fi
exit $status
