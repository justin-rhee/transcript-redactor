#!/bin/bash
# Pins the FAIL-OPEN behavior: when redactor.sh cannot be found or is not
# executable, redact-bash-output.sh allows the ORIGINAL command through
# completely unwrapped — no redaction pipe at all. This is the property most
# likely to fool someone (a missing/broken redactor looks identical to "no
# credentials found" from the caller's side: both are a plain, unmodified
# "allow"). This test exists so that a future change which flips this to
# fail-closed (or to some silently-degraded third behavior) breaks a test
# instead of shipping quietly.
#
# Every assertion here runs against a TEMPORARY copy of the package (never
# the checked-in src/), so this suite never mutates src/ even transiently.
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SELF_DIR/lib.sh"

echo "== fail-open pin: redactor.sh missing or non-executable =="

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/redactor-test-failopen.XXXXXX")
trap 'rm -rf "$WORKDIR"' EXIT
cp "$WRAPPER" "$WORKDIR/redact-bash-output.sh"
chmod +x "$WORKDIR/redact-bash-output.sh"
# Deliberately do NOT copy redactor.sh into $WORKDIR — the sibling file the
# wrapper looks for by default simply does not exist here.

resp_missing=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}' | "$WORKDIR/redact-bash-output.sh")
assert_eq "sibling redactor.sh absent -> exact fail-open JSON (no updatedInput)" \
  "$resp_missing" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'

# Same, but the file exists and is non-executable rather than absent.
touch "$WORKDIR/redactor.sh"
chmod -x "$WORKDIR/redactor.sh"
resp_noexec=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}' | "$WORKDIR/redact-bash-output.sh")
assert_eq "sibling redactor.sh present but non-executable -> same fail-open JSON" \
  "$resp_noexec" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
rm -f "$WORKDIR/redactor.sh"

# --- prove what fail-open ACTUALLY costs: run it end-to-end with a synthetic
# secret in the command output, the way an agent framework would. Because
# there is no updatedInput, the caller runs the ORIGINAL command as written —
# with no pipe to any redactor — so the raw secret-shaped string reaches
# whatever records the output, completely unredacted. ---
key="sk-or-v1-$(printf 'a%.0s' {1..64})"
req=$(python3 -c "
import json
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': 'echo token=$key'}}))
")
resp_secret=$(printf '%s' "$req" | "$WORKDIR/redact-bash-output.sh")
assert_not_contains "fail-open response carries no wrapped/updatedInput command" "$resp_secret" "updatedInput"
# Simulate the caller's next step: since there was no updatedInput, it runs
# the untouched original command.
raw_run_output=$(bash -c "echo token=$key")
assert_contains "the raw synthetic key reaches command output completely unredacted" \
  "$raw_run_output" "$key"

report "test_fail_open"
exit $FAIL_COUNT
