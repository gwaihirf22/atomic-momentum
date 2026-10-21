#!/usr/bin/env bash
# The monkey test (test/monkey) for longer walks, over several seeds: random
# taps, holds, swipes, scrolls, typing and backs on a year of use, at two
# phone sizes. Stops at the first failure and prints where it happened
# (the seed and steps replay it exactly; build/monkey_report.txt has it too).
#   tool/monkey.sh [steps per run, 2000] [first seed, 1] [how many seeds, 5]
set -euo pipefail
cd "$(dirname "$0")/.."

steps="${1:-2000}"
first="${2:-1}"
count="${3:-5}"
mkdir -p build
for ((seed = first; seed < first + count; seed++)); do
  echo "== seed $seed, $steps steps"
  log="build/monkey_seed_$seed.log"
  status=0
  ./flutter/bin/flutter test test/monkey/monkey_test.dart --reporter=compact \
    --dart-define=MONKEY_STEPS="$steps" --dart-define=MONKEY_SEED="$seed" --dart-define=MONKEY_VERBOSE=true \
    >"$log" 2>&1 || status=$?
  grep -E "^MONKEY" "$log" || true
  if [ "$status" -ne 0 ]; then
    grep -A30 "Monkey failed\|EXCEPTION CAUGHT" "$log" | head -60
    echo "Seed $seed failed: the whole log is $log"
    exit 1
  fi
done
echo "All $count seeds passed."
