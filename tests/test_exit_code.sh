#!/bin/bash
# End-to-end exit-code preservation through the full wrapper -> redactor
# pipeline: build the PreToolUse request the way an agent framework would,
# get back the wrapped command, actually run it, and check the exit code
# your shell sees matches what the ORIGINAL command would have exited with.
#
# This is the other half of the headline promise: redaction must not come at
# the cost of silently turning a failing command into a "successful" one.
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SELF_DIR/lib.sh"

echo "== end-to-end exit code preservation (through wrapper + redactor pipe) =="

# --- zero exit, with a credential in the output that must be redacted ---
key="sk-or-v1-$(printf 'a%.0s' {1..64})"
cmd="echo token=$key; exit 0"
wrapped=$(wrapped_command_for "$cmd")
assert_contains "zero-exit case: wrapper actually wrapped the command" "$wrapped" "redactor.sh"
actual_out=$(bash -c "$wrapped")
actual_exit=$?
assert_contains "zero-exit case: credential redacted in the actual run" "$actual_out" "[REDACTED:openrouter]"
assert_not_contains "zero-exit case: raw key does not survive in output" "$actual_out" "$key"
assert_eq "zero-exit case: exit code preserved (0)" "$actual_exit" "0"

# --- non-zero exit, arbitrary code, no credential involved ---
cmd2="echo will-fail; exit 37"
wrapped2=$(wrapped_command_for "$cmd2")
actual_out2=$(bash -c "$wrapped2")
actual_exit2=$?
assert_contains "non-zero case: output still comes through" "$actual_out2" "will-fail"
assert_eq "non-zero case: exit code preserved (37, not swallowed to 0)" "$actual_exit2" "37"

# --- non-zero exit WITH a credential in the output, together ---
key3="ghp_$(printf 'a%.0s' {1..36})"
cmd3="echo leaking=$key3 >&2; exit 5"
wrapped3=$(wrapped_command_for "$cmd3")
actual_out3=$(bash -c "$wrapped3" 2>&1)
actual_exit3=$?
assert_contains "combined case: stderr credential redacted" "$actual_out3" "[REDACTED:github-classic]"
assert_not_contains "combined case: raw key does not survive" "$actual_out3" "$key3"
assert_eq "combined case: non-zero exit (5) preserved alongside redaction" "$actual_exit3" "5"

report "test_exit_code"
exit $FAIL_COUNT
