#!/bin/bash
# Builds Momentum in release mode and installs it on a real iPhone.
#
#   tool/install_on_iphone.sh [device id]
#
# Without an id it uses the first paired physical iPhone (xcrun devicectl
# list devices). Needs Xcode signed into an Apple ID with a team chosen for
# the Runner target, and Developer Mode on the phone.
#
# With a free (personal) team, signing leaves out time-sensitive
# notifications and the widgets' App Group (Runner-PersonalTeam.entitlements;
# the widget extension gets none, so widgets only say to open the app), and
# the install expires after 7 days: run this again to renew it (the app's
# data stays). With the paid program, set FULL_ENTITLEMENTS=1 to sign the app
# and the widgets with their own entitlements.
#
# DEV_TOOLS=1 keeps Settings → Developer in the release build (sample habits,
# "Load a year of use", the notification tester), for testing real speed
# with a year of history. Never for a store build.
set -euo pipefail
cd "$(dirname "$0")/.."

device="${1:-$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && !/simulated/ && /available|connected/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')}"
if [ -z "$device" ]; then
  echo "No paired iPhone found. Connect it by cable, unlock it and trust this Mac." >&2
  exit 1
fi

# Each target's entitlements are its own setting (RUNNER_ENTITLEMENTS,
# WIDGETS_ENTITLEMENTS), so overriding one doesn't touch the other
entitlements="Runner/Runner-PersonalTeam.entitlements"
widgets_entitlements=""
if [ "${FULL_ENTITLEMENTS:-0}" = "1" ]; then
  entitlements="Runner/Runner.entitlements"
  widgets_entitlements="MomentumWidgets/MomentumWidgets.entitlements"
fi

echo "Building for $device (entitlements: $entitlements)"
defines=()
if [ "${DEV_TOOLS:-0}" = "1" ]; then
  defines=(--dart-define=DEV_TOOLS=true)
  echo "With Settings → Developer"
  # Flutter keeps the switch in ios/Flutter/Generated.xcconfig; put that back
  # to a plain build afterwards (even on failure), so nothing built from Xcode
  # later carries it. Archiving with it fails anyway (tool/check_no_dev_tools.sh)
  trap './flutter/bin/flutter build ios --release --config-only >/dev/null 2>&1 && echo "Build settings reset (no DEV_TOOLS)"' EXIT
fi
./flutter/bin/flutter build ios --release --config-only "${defines[@]+"${defines[@]}"}"
derived="build/ios/device-derived"
app="$derived/Build/Products/Release-iphoneos/Runner.app"
# Never install an app left from an earlier build
rm -rf "$app"
log="$derived/last-build.log"
mkdir -p "$derived"
status=0
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination "id=$device" -derivedDataPath "$derived" -allowProvisioningUpdates \
  RUNNER_ENTITLEMENTS="$entitlements" WIDGETS_ENTITLEMENTS="$widgets_entitlements" build >"$log" 2>&1 || status=$?
grep -E "error:|warning: .*(sign|profile)|BUILD (SUCCEEDED|FAILED)" "$log" || true
if [ "$status" -ne 0 ] || [ ! -d "$app" ]; then
  echo "Build failed: nothing installed (full log: $log)." >&2
  echo "A 'has been modified since the module file was built' error means a stale module cache: rm -rf $derived/ModuleCache.noindex" >&2
  exit 1
fi
xcrun devicectl device install app --device "$device" "$app"
echo "Installed. The first time, trust the developer on the phone: Settings → General → VPN & Device Management."
