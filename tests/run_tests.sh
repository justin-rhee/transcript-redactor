#!/bin/bash
# Runs every tests/test_*.sh in this directory and reports a total. Exits
# non-zero if any suite had a failure. No external test framework required —
# only bash, sed, and python3 (the same runtime the tool itself needs).
#
# Usage:  ./tests/run_tests.sh
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

total_pass=0
total_fail=0
suite_failures=0

for suite in "$SELF_DIR"/test_*.sh; do
  echo "### $(basename "$suite")"
  # Run each suite in its own subshell/process so one suite's exit doesn't
  # kill the runner, and so PASS_COUNT/FAIL_COUNT don't leak across suites.
  out=$(bash "$suite")
  status=$?
  echo "$out"
  echo
  pass_line=$(printf '%s\n' "$out" | grep -Eo '[0-9]+ passed, [0-9]+ failed' | tail -1)
  p=$(printf '%s' "$pass_line" | grep -Eo '^[0-9]+')
  f=$(printf '%s' "$pass_line" | grep -Eo '[0-9]+ failed' | grep -Eo '^[0-9]+')
  total_pass=$((total_pass + ${p:-0}))
  total_fail=$((total_fail + ${f:-0}))
  if [ "$status" -ne 0 ]; then
    suite_failures=$((suite_failures + 1))
  fi
done

echo "=================================================="
echo "TOTAL: $total_pass passed, $total_fail failed, across $(ls "$SELF_DIR"/test_*.sh | wc -l | tr -d ' ') suites"

if [ "$total_fail" -ne 0 ] || [ "$suite_failures" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
