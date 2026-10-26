#!/usr/bin/env bash
# App Store screenshots (integration_test/store_screens_test.dart) on the
# 6.9" simulator "Store iPhone 17 Pro Max" (1320 x 2868, what App Store
# Connect asks for; smaller iPhones are scaled from it): the example habits
# on each screen the listing shows, in Sepia, Charged and Light, with the status
# bar at 9:41, full signal and battery. Storage is in memory.
#
#   tool/store_screens.sh ["<simulator name>"]
#
# With an iPad simulator ("Store iPad Pro 13-inch", 2064 x 2752, upright)
# the pictures are named ipad_… (tool/store_frames.py --ipad).
#
# Pictures land in build/store_screens/.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter="${FLUTTER:-./flutter/bin/flutter}"
device="${1:-Store iPhone 17 Pro Max}"

udid=$(xcrun simctl list devices | grep -F "$device (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[[ -n "$udid" ]] || { echo "No simulator named \"$device\"" >&2; exit 1; }
# (Not erased here: a Flutter app's first launch after an erase hung on its
# launch screen. Delete and recreate the simulator for a clean home screen.)
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
# An ISO date (UTC, with milliseconds) sets the lock screen's date and clock
# too (iOS 27): today, 9:41 here
at=$(python3 -c 'import datetime as d; t=d.datetime.now().astimezone().replace(hour=9,minute=41,second=0,microsecond=0); print(t.astimezone(d.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"))')
xcrun simctl status_bar "$udid" override --time "$at" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

mkdir -p build/store_screens
# A new run replaces its own kind of pictures (iPhone or iPad), never the other's
if [[ "$device" == *iPad* ]]; then rm -f build/store_screens/ipad_*.png; else find build/store_screens -name '*.png' ! -name 'ipad_*' -delete; fi
# The test prints STORE_SHOT <name> and holds still for a few seconds while
# the whole screen (status bar too) is taken here
status=0
log=$(mktemp)
# --keep-app-running: the app (and the example habits it left in the widgets)
# stays installed for tool/widget_screens.sh
# An iPad's pictures are named ipad_… (App Store Connect wants 13" iPad
# screenshots for an app that runs on iPad)
defines=()
if [[ "$device" == *iPad* ]]; then defines=(--dart-define=STORE_IPAD=true); fi
"$flutter" drive --driver=test_driver/integration_test.dart --target=integration_test/store_screens_test.dart \
  -d "$udid" --keep-app-running "${defines[@]+"${defines[@]}"}" 2>&1 |
  while IFS= read -r line; do
    echo "$line" >>"$log"
    if [[ "$line" =~ STORE_SHOT\ ([A-Za-z0-9_]+) ]]; then
      name="${BASH_REMATCH[1]}"
      xcrun simctl io "$udid" screenshot "build/store_screens/$name.png" >/dev/null 2>&1 && echo "  took $name"
    fi
  done
if grep -qE "Some tests failed|\[E\]|Test failed" "$log"; then status=1; tail -40 "$log"; fi
rm -f "$log"
echo "Screenshots in build/store_screens"
exit $status
