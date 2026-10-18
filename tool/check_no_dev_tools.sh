#!/bin/bash
# Run by Xcode (the Runner target's "Check no dev tools" build phase) on every
# build. When archiving (an App Store or TestFlight upload, ACTION=install),
# it stops the archive if the build carries DEV_TOOLS=true, which would show
# Settings → Developer to everyone. Flutter keeps --dart-define values in
# ios/Flutter/Generated.xcconfig (DART_DEFINES, base64 and comma-separated),
# so a leftover from tool/install_on_iphone.sh would otherwise ship.
#
# Fix: rebuild without the switch, e.g. ./flutter/bin/flutter build ipa
set -euo pipefail

[ "${ACTION:-build}" = "install" ] || exit 0

for define in $(echo "${DART_DEFINES:-}" | tr ',' ' '); do
  if [ "$(echo "$define" | base64 --decode 2>/dev/null || true)" = "DEV_TOOLS=true" ]; then
    echo "error: This archive was built with DEV_TOOLS=true (Settings → Developer would ship). Rebuild without it: ./flutter/bin/flutter build ipa" >&2
    exit 1
  fi
done
