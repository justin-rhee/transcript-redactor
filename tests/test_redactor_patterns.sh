#!/bin/bash
# One synthetic, pattern-shaped fixture per sed rule in src/redactor.sh.
# Every fixture below is constructed from the regex shapes in redactor.sh —
# none is a real credential, none copied from any stored trace or transcript.
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SELF_DIR/lib.sh"

run_pattern_test() {
  local label="$1" input="$2" expect="$3"
  local out
  out=$(printf '%s' "$input" | "$REDACTOR")
  assert_contains "$label" "$out" "$expect"
}

echo "== redactor.sh pattern coverage (headline promise: each credential shape gets replaced) =="

run_pattern_test "openrouter" \
  "sk-or-v1-$(printf 'a%.0s' {1..64})" \
  "[REDACTED:openrouter]"

run_pattern_test "anthropic (oauth-style prefix, not just api prefix)" \
  "sk-ant-oat01-$(printf 'A%.0s' {1..40})" \
  "[REDACTED:anthropic]"

run_pattern_test "openai-project" \
  "sk-proj-$(printf 'B%.0s' {1..40})" \
  "[REDACTED:openai-project]"

run_pattern_test "openai-service" \
  "sk-svcacct-$(printf 'C%.0s' {1..40})" \
  "[REDACTED:openai-service]"

run_pattern_test "openai-classic (word-boundary guarded)" \
  "token is sk-$(printf 'D%.0s' {1..48}) end" \
  "[REDACTED:openai-classic]"

run_pattern_test "jwt (three-part header.payload.signature)" \
  "eyJ$(printf 'e%.0s' {1..20}).eyJ$(printf 'p%.0s' {1..20}).$(printf 's%.0s' {1..20})" \
  "[REDACTED:jwt]"

run_pattern_test "oauth-refresh" \
  "rt_$(printf 'x%.0s' {1..30}).$(printf 'y%.0s' {1..30})" \
  "[REDACTED:oauth-refresh]"

# The slack-bot prefix is assembled from fragments rather than written literally.
# The string the redactor receives is byte-identical; only this file's spelling
# changes. Without it, secret scanners flag this line as a real Slack bot token —
# gitleaks does, and it is the ONLY fixture here that trips it, because the other
# synthetic bodies fail entropy or checksum tests while this shape passes them.
# A package whose job is matching credential shapes cannot ship a literal one.
run_pattern_test "slack-bot" \
  "$(printf 'xox')b-1234567890-1234567890-$(printf 'a%.0s' {1..24})" \
  "[REDACTED:slack-bot]"

run_pattern_test "slack-user" \
  "$(printf 'xox')p-1234567890-1234567890-1234567890-$(printf 'a%.0s' {1..32})" \
  "[REDACTED:slack-user]"

run_pattern_test "github-classic" \
  "ghp_$(printf 'a%.0s' {1..36})" \
  "[REDACTED:github-classic]"

run_pattern_test "github-pat (fine-grained)" \
  "github_pat_$(printf 'a%.0s' {1..82})" \
  "[REDACTED:github-pat]"

run_pattern_test "github-oauth" \
  "gho_$(printf 'a%.0s' {1..36})" \
  "[REDACTED:github-oauth]"

run_pattern_test "github-server" \
  "ghs_$(printf 'a%.0s' {1..36})" \
  "[REDACTED:github-server]"

run_pattern_test "gitlab-pat" \
  "glpat-$(printf 'a%.0s' {1..20})" \
  "[REDACTED:gitlab-pat]"

run_pattern_test "aws-access" \
  "$(printf 'AKI')A1234567890ABCDEF" \
  "[REDACTED:aws-access]"

run_pattern_test "figma" \
  "figd_$(printf 'a%.0s' {1..30})" \
  "[REDACTED:figma]"

run_pattern_test "firecrawl" \
  "fc-$(printf 'a%.0s' {1..32})" \
  "[REDACTED:firecrawl]"

run_pattern_test "oauth query secret (client_secret=)" \
  "https://example.com/cb?client_secret=$(printf 'a%.0s' {1..20})" \
  "[REDACTED:secret]"

run_pattern_test "oauth query secret (bare secret=)" \
  "https://example.com/cb?secret=$(printf 'a%.0s' {1..20})" \
  "[REDACTED:secret]"

run_pattern_test "discord-webhook" \
  "https://discord.com/api/webhooks/123456789012345678/$(printf 'a%.0s' {1..40})" \
  "[REDACTED:discord-webhook]"

run_pattern_test "slack-webhook" \
  "https://hooks.slack.com/services/T00000000/B00000000/$(printf 'A%.0s' {1..24})" \
  "[REDACTED:slack-webhook]"

# Negative control: ordinary non-credential-shaped text must pass through
# byte-for-byte unchanged. A redactor that over-matches is its own failure
# mode (it would corrupt normal command output).
plain_out=$(printf '%s' "just some normal command output, no secrets here, task-1234 is fine" | "$REDACTOR")
assert_eq "plain text passes through unchanged" "$plain_out" "just some normal command output, no secrets here, task-1234 is fine"

report "test_redactor_patterns"
exit $FAIL_COUNT
