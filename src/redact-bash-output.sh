#!/bin/bash
# PreToolUse Bash hook — wraps every Bash command in a credential-redactor pipe.
# Goal: credential-shaped strings never enter a persisted session transcript.
# Strategy: rewrite tool_input.command via updatedInput so that the command's
# stdout+stderr are piped through redactor.sh before returning.
#
# Exit code is preserved via ${PIPESTATUS[0]} so commands that fail still
# fail. This relies on the shell that ultimately RUNS the wrapped command
# being bash (macOS's /bin/sh qualifies — it is bash). Under a POSIX sh that
# is not bash (e.g. dash, the default /bin/sh on Debian/Ubuntu), the
# `${PIPESTATUS[0]}` array reference is a syntax error, and exit-code
# preservation silently breaks instead of degrading gracefully — see the
# project notes before assuming this is safe on a non-bash Linux runner.
#
# FAIL-OPEN BY DESIGN: if redactor.sh can't be found or isn't executable,
# this hook allows the ORIGINAL command through completely unmodified — no
# redaction pipe at all, not a degraded one. A missing/broken redactor means
# zero redaction, silently, not an error. This favors "never break the
# agent's Bash tool" over "never leak a credential". Read the project notes
# before relying on this in a context where that trade-off matters, and
# consider monitoring for this hook falling back to plain "allow" (no
# updatedInput) as a signal that the redactor stopped being found.

set -u

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("tool_name",""))' 2>/dev/null)
ORIG_CMD=$(printf '%s' "$INPUT" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("tool_input",{}).get("command",""))' 2>/dev/null)

if [ "$TOOL_NAME" != "Bash" ] || [ -z "$ORIG_CMD" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
fi

# Resolve this script's own directory, following symlinks all the way to the
# real file, so the sibling redactor.sh can be found even when this script is
# invoked through a symlink (e.g. installed on PATH as a symlink pointing
# into a checkout of this package). A naive `dirname "${BASH_SOURCE[0]}"`
# would resolve to the symlink's directory instead, not the package's.
resolve_script_dir() {
  local src="${BASH_SOURCE[0]}"
  while [ -h "$src" ]; do
    local dir
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    case "$src" in
      /*) ;;                # absolute symlink target, use as-is
      *) src="$dir/$src" ;; # relative symlink target, resolve against link's dir
    esac
  done
  cd -P "$(dirname "$src")" && pwd
}
SCRIPT_DIR="$(resolve_script_dir)"

# Default to the sibling redactor.sh next to this script; override with
# TRANSCRIPT_REDACTOR_PATH if redactor.sh is installed somewhere else.
REDACTOR="${TRANSCRIPT_REDACTOR_PATH:-$SCRIPT_DIR/redactor.sh}"

# Skip wrapping if the redactor script is missing (fail open, not closed —
# don't break Bash). See the FAIL-OPEN note above: this is silent.
if [ ! -x "$REDACTOR" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
fi

# Build the wrapped command via Python so we get correct JSON quoting on $ORIG_CMD
# which may contain shell metacharacters, quotes, here-docs, etc.
WRAPPED=$(ORIG_CMD="$ORIG_CMD" REDACTOR="$REDACTOR" python3 -c '
import json, os
orig = os.environ.get("ORIG_CMD", "")
red = os.environ.get("REDACTOR", "")
# Wrap in parens so multi-statement commands stay one pipeline.
# Pipe combined stdout+stderr through redactor; preserve inner exit code.
wrapped = "( " + orig + " ) 2>&1 | " + red + "; exit ${PIPESTATUS[0]}"
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "updatedInput": {"command": wrapped},
    }
}))
' 2>/dev/null)

if [ -z "$WRAPPED" ]; then
  # Fallback if wrapping failed: allow original command unchanged rather than break Bash
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
fi

echo "$WRAPPED"
