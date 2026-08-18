#!/bin/bash
# Contract tests for redact-bash-output.sh's PreToolUse JSON hook behavior,
# its symlink-safe path resolution, and its TRANSCRIPT_REDACTOR_PATH override.
# These exercise the wrapper AS A SCRIPT (invoked as a subprocess reading
# stdin), never by sourcing its internals — a script whose entry point is
# broken (e.g. under a symlink) can still have every unit test pass if the
# tests only import functions, so this suite deliberately never does that.
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SELF_DIR/lib.sh"

echo "== redact-bash-output.sh JSON hook contract =="

# --- non-Bash tool: passthrough, no wrapping ---
resp=$(printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}' | "$WRAPPER")
assert_contains "non-Bash tool_name -> plain allow" "$resp" '"permissionDecision":"allow"'
assert_not_contains "non-Bash tool_name -> no updatedInput" "$resp" "updatedInput"

# --- empty command: passthrough ---
resp=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":""}}' | "$WRAPPER")
assert_not_contains "empty command -> no updatedInput" "$resp" "updatedInput"

# --- malformed JSON: degrades to plain allow, does not crash ---
resp=$(printf 'not json at all' | "$WRAPPER")
assert_contains "malformed JSON -> plain allow (does not error out)" "$resp" '"permissionDecision":"allow"'

# --- normal Bash command: gets wrapped, points at the sibling redactor.sh ---
wrapped=$(wrapped_command_for "echo hi")
assert_contains "normal command wrapped with pipe to redactor.sh" "$wrapped" "redactor.sh"
assert_contains "normal command wrapped preserves PIPESTATUS exit trick" "$wrapped" 'exit ${PIPESTATUS[0]}'

# --- quoting correctness: command with embedded quotes/metacharacters survives JSON round-trip ---
tricky='echo "a b" && echo '"'"'c'"'"' && echo $HOME'
wrapped_tricky=$(wrapped_command_for "$tricky")
assert_contains "tricky command's literal text preserved through JSON quoting" "$wrapped_tricky" 'echo "a b"'

# --- default path resolution is relative to the script, not hardcoded ---
wrapper_source=$(cat "$WRAPPER")
assert_not_contains "wrapper source contains no hardcoded /Users/... home path" \
  "$wrapper_source" "/Users/"

# --- TRANSCRIPT_REDACTOR_PATH override is honored ---
wrapped_override=$(wrapped_command_for "echo hi" "TRANSCRIPT_REDACTOR_PATH=/bin/cat")
assert_contains "override env var changes the redactor binary used" "$wrapped_override" "| /bin/cat;"

echo
echo "== invocation as a script through a symlink (not sourced, not run in-place) =="

SYMLINK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/redactor-test-symlink.XXXXXX")
trap 'rm -rf "$SYMLINK_DIR"' EXIT
ln -s "$WRAPPER" "$SYMLINK_DIR/redact-bash-output.sh"

resp_symlink=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}' | "$SYMLINK_DIR/redact-bash-output.sh")
assert_contains "invoked via symlink: still produces a wrapped command" "$resp_symlink" "updatedInput"
assert_contains "invoked via symlink: still finds the REAL sibling redactor.sh (not the symlink's dir)" \
  "$resp_symlink" "$SRC_DIR/redactor.sh"
assert_not_contains "invoked via symlink: did NOT resolve to the symlink's own directory" \
  "$resp_symlink" "$SYMLINK_DIR/redactor.sh"

report "test_wrapper_contract"
exit $FAIL_COUNT
