#!/usr/bin/env bash
# Screenshots of the tours on a real simulator or emulator, for review
# (integration_test/tour_screens_test.dart): every step in Light, Sepia and
# Charged, at the default text size and 135%. Storage is in memory, so the
# device's own habits are never touched; the real app is put back after.
#
#   tool/tour_screens.sh "Year iPhone 17 Pro"
#   tool/tour_screens.sh emulator-5554
#
# Pictures land in build/tour_screens/<device>/.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter="${FLUTTER:-./flutter/bin/flutter}"
device="${1:?Usage: tool/tour_screens.sh \"<simulator name or device id>\"}"
bundle_id="com.paulblake.momentum"

udid=$(xcrun simctl list devices booted 2>/dev/null | grep -F "$device (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)
id="${udid:-$device}"
screens="build/tour_screens/$(echo "$device" | tr -c 'A-Za-z0-9\n' '_')"
rm -rf "$screens"

if [[ -z "$udid" ]]; then
  # Android: a permission prompt nobody answered (the real app's first
  # launch asks for notifications) would sit on top of the app's task and
  # take every launch, so grant it and close any system screens first
  adb="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}/platform-tools/adb"
  "$adb" -s "$id" shell pm grant "$bundle_id" android.permission.POST_NOTIFICATIONS 2>/dev/null || true
  for p in com.google.android.permissioncontroller com.google.android.healthconnect.controller; do
    "$adb" -s "$id" shell am force-stop "$p"
  done
fi

status=0
log=$(mktemp)
YEAR_SCREENS="$screens" "$flutter" drive \
  --driver=test_driver/year_driver.dart \
  --target=integration_test/tour_screens_test.dart \
  -d "$id" --keep-app-running 2>&1 | tee "$log" || status=$?
# The driver can say "All tests passed" after the test itself failed
if grep -qE "Some tests failed|\[E\]" "$log"; then status=1; fi
rm -f "$log"

echo "Putting the real app back on $device..."
[[ -n "$udid" ]] && { xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true; }
"$flutter" run -d "$id" --no-resident

if [[ $status -eq 0 ]]; then
  echo "Screenshots in $screens"
else
  echo "The tour screenshots FAILED on $device (see above)" >&2
fi
exit $status
