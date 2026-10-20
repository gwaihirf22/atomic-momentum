#!/usr/bin/env bash
# The home screen and lock screen with Momentum's widgets, for the App Store
# set: a UI test (tool/springboard_shots/) drives SpringBoard on the 6.9"
# simulator to add them, then takes the whole screen. Run it right after
# tool/store_screens.sh, which leaves the example habits in the widgets.
#
#   tool/widget_screens.sh ["<simulator name>"]
#
# Saves build/store_screens/home_widgets.png and lock_screen.png; then
# python3 tool/store_frames.py frames them with the rest.
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:-Store iPhone 17 Pro Max}"
udid=$(xcrun simctl list devices | grep -F "$device (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[[ -n "$udid" ]] || { echo "No simulator named \"$device\"" >&2; exit 1; }

project=build/widget_screens/proj
rm -rf "$project" && mkdir -p "$project" build/store_screens
GEM_HOME="${GEM_HOME:-$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec 2>/dev/null | tail -1)}" \
  ruby tool/springboard_shots/make.rb "$project"

# Variables starting TEST_RUNNER_ reach the UI test's environment
TEST_RUNNER_SCREENS_DIR="$PWD/build/store_screens" xcodebuild test \
  -project "$project/WidgetScreens.xcodeproj" -scheme WidgetScreens \
  -destination "id=$udid" -derivedDataPath build/widget_screens/dd \
  -only-testing:WidgetScreens/WidgetScreens/testHomeScreen \
  -only-testing:WidgetScreens/WidgetScreens/testLockScreen 2>&1 |
  grep -E "error:|Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)" || true
ls -1 build/store_screens/home_widgets.png build/store_screens/lock_screen.png
