#!/bin/bash
# Credential redactor — reads stdin, writes stdout with credential-shaped
# strings replaced by typed placeholders (e.g. [REDACTED:anthropic]).
#
# Invoked by the accompanying redact-bash-output.sh wrapper in this package,
# which pipes a command's combined stdout+stderr through this script before
# the output is recorded anywhere persistent (a session transcript, a log).
#
# Patterns are ordered most-specific-first so a broad pattern can't shadow a
# narrower one that should have matched first (e.g. the OpenAI "classic" key
# pattern is broad enough that it must run after the more specific OpenAI
# prefixes, or it would partially match them).
#
# This pattern set grew in four increments, each one added after a credential
# of a shape the existing patterns didn't cover turned up in real output:
# an OAuth-token prefix distinct from the API-key prefix it was confused with,
# a JWT, an OAuth refresh token, a vendor personal-access-token format, an
# OAuth query-string secret, and a second vendor's API key format. None of
# those were hypothetical — each was a real value seen in real output before
# its pattern was added. Treat this list as necessary but not sufficient: new
# vendors and new token shapes will keep appearing.

exec sed -E \
  -e 's/sk-or-v1-[a-fA-F0-9]{64}/[REDACTED:openrouter]/g' \
  -e 's/sk-ant-[a-z]+[0-9]*-[A-Za-z0-9_-]{40,}/[REDACTED:anthropic]/g' \
  -e 's/sk-proj-[A-Za-z0-9_-]{40,}/[REDACTED:openai-project]/g' \
  -e 's/sk-svcacct-[A-Za-z0-9_-]{40,}/[REDACTED:openai-service]/g' \
  -e 's/(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{48}([^A-Za-z0-9]|$)/\1[REDACTED:openai-classic]\2/g' \
  -e 's/eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/[REDACTED:jwt]/g' \
  -e 's/rt_[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{30,}/[REDACTED:oauth-refresh]/g' \
  -e 's/xoxb-[0-9]+-[0-9]+-[A-Za-z0-9]{24,}/[REDACTED:slack-bot]/g' \
  -e 's/xoxp-[0-9]+-[0-9]+-[0-9]+-[A-Za-z0-9]{32,}/[REDACTED:slack-user]/g' \
  -e 's/ghp_[A-Za-z0-9]{36,}/[REDACTED:github-classic]/g' \
  -e 's/github_pat_[A-Za-z0-9_]{82,}/[REDACTED:github-pat]/g' \
  -e 's/gho_[A-Za-z0-9]{36,}/[REDACTED:github-oauth]/g' \
  -e 's/ghs_[A-Za-z0-9]{36,}/[REDACTED:github-server]/g' \
  -e 's/glpat-[A-Za-z0-9_-]{20,}/[REDACTED:gitlab-pat]/g' \
  -e 's/AKIA[0-9A-Z]{16}/[REDACTED:aws-access]/g' \
  -e 's/figd_[A-Za-z0-9_-]{30,}/[REDACTED:figma]/g' \
  -e 's/fc-[A-Za-z0-9]{32,}/[REDACTED:firecrawl]/g' \
  -e 's/([?&](client_)?secret=)[A-Za-z0-9._~-]{20,}/\1[REDACTED:secret]/g' \
  -e 's|https://discord\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+|[REDACTED:discord-webhook]|g' \
  -e 's|https://hooks\.slack\.com/services/[A-Z0-9]+/[A-Z0-9]+/[A-Za-z0-9]+|[REDACTED:slack-webhook]|g'
