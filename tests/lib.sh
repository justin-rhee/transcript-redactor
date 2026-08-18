#!/bin/bash
# Shared test-assertion helpers, sourced by the other tests/test_*.sh files.
# No external test framework — plain bash, so the suite has zero dependencies
# beyond bash, sed, and python3 (the same runtime src/ itself needs).

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$TESTS_DIR/../src" && pwd)"
REDACTOR="$SRC_DIR/redactor.sh"
WRAPPER="$SRC_DIR/redact-bash-output.sh"

PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    echo "  ok   $label"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL $label"
    echo "       expected to find: $needle"
    echo "       actual output:    $haystack"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    echo "  FAIL $label"
    echo "       expected NOT to find: $needle"
    echo "       actual output:        $haystack"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "  ok   $label"
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
}

assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ok   $label"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL $label"
    echo "       expected: $expected"
    echo "       actual:   $actual"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Build the hook's PreToolUse request JSON for a given Bash command, run it
# through the wrapper, and extract the wrapped shell command it produced (or
# empty string if the wrapper did not produce updatedInput).
wrapped_command_for() {
  local cmd="$1"
  local extra_env="${2:-}"
  local req resp
  req=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$cmd")
  if [ -n "$extra_env" ]; then
    resp=$(printf '%s' "$req" | env "$extra_env" "$WRAPPER")
  else
    resp=$(printf '%s' "$req" | "$WRAPPER")
  fi
  printf '%s' "$resp" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d["hookSpecificOutput"].get("updatedInput", {}).get("command", ""))
except Exception:
    print("")
'
}

report() {
  local suite="$1"
  echo "  -- $suite: $PASS_COUNT passed, $FAIL_COUNT failed --"
}
