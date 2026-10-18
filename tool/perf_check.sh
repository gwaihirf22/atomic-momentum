#!/usr/bin/env bash
# The real app's speed with a year (or two) of history, in profile mode (as
# it ships): launch, the first look at Insights, the full heatmap, the
# Achievements page, a habit page and a tap. Prints wall time and frame
# times. Profile mode needs an Android emulator or a real phone; storage is
# in memory, so the device's own habits are never touched.
#
#   tool/perf_check.sh emulator-5556 [years]
set -euo pipefail
cd "$(dirname "$0")/.."
flutter="${FLUTTER:-./flutter/bin/flutter}"
device="${1:?Usage: tool/perf_check.sh <device id> [years]}"
years="${2:-1}"

"$flutter" drive --profile --no-dds \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/year_performance_test.dart \
  --dart-define=YEARS="$years" \
  -d "$device"

python3 - <<'PY'
import json
data = json.load(open('build/integration_response_data.json'))
wall = data.get('wall_ms', {})
print(f"\n{data.get('years')} year(s) of history, profile mode; habits on screen {data.get('loaded_ms')} ms after start")
print(f"{'':36}{'wall ms':>8}{'worst build':>13}{'avg build':>11}{'janky':>7}")
for name, ms in wall.items():
    t = data.get(name, {})
    # The app's own work (build); raster is drawing, which an emulator does in software
    worst = t.get('worst_frame_build_time_millis', 0)
    avg = t.get('average_frame_build_time_millis', 0)
    janky = t.get('missed_frame_build_budget_count', 0)
    print(f"{name:36}{ms:>8}{worst:>13.1f}{avg:>11.1f}{janky:>7}")
PY
