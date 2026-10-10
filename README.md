# transcript-redactor

[![tests](https://github.com/justin-rhee/transcript-redactor/actions/workflows/test.yml/badge.svg)](https://github.com/justin-rhee/transcript-redactor/actions/workflows/test.yml)

One small bash hook for agent session logs: **redact credential shaped strings from every command's output**, **preserve the original exit code**, and **name the vendors it covers so you can see who isn't**. About 130 lines of bash, two files, one hook to register.

It exists because I went looking through my agent's saved transcripts and found four different live credentials, every one written there by an ordinary command doing exactly what I asked: a config read, a script printing its own environment while failing. The redaction list I already had was written before three of those four credential shapes existed, so it caught none of them, and it reported nothing at all while missing them. If you let an agent run shell commands and you keep the transcripts, you have this too, whether or not you have gone looking yet.

## Use it if

- your agent runs shell commands and you keep the transcripts, and the logs get backed up, synced, or copied to a second machine
- you want a pattern list you can read in a minute, not a classifier
- your current redaction list predates half the credentials you now hold

## How it works

Every command is rewritten before it runs so that stdout and stderr pass through a single ordered `sed` filter, most specific pattern first. Credential shaped strings come out as typed placeholders like `[REDACTED:openrouter]`, and the original exit code is preserved, so a failing command still reports as failing.

The filter is a fixed pattern list, not a model and not an entropy heuristic, and that's a deliberate limit: a classifier that decides whether a string "looks secret" is wrong in both directions at once, leaking the credential shape nobody trained it on and corrupting ordinary output that happens to look random. The list names its vendors openly, so if you can see that Anthropic, OpenAI, GitHub, GitLab, Slack, AWS, Figma, Firecrawl, Discord and OpenRouter are covered, you can also see who isn't. You can try the filter before you install anything:

```sh
printf 'ghp_%s\n' "$(printf 'a%.0s' {1..36})" | ./src/redactor.sh
[REDACTED:github-classic]
```

## Install

It needs `bash`, not `sh`, and the reason is under What it won't do. Put both files somewhere stable, keep them side by side, and register `src/redact-bash-output.sh` as a PreToolUse hook on your agent's shell tool. The wrapper finds `redactor.sh` next to itself, following symlinks correctly, so installing the wrapper on your `PATH` as a symlink works. Set `TRANSCRIPT_REDACTOR_PATH` if you want them apart.

```sh
git clone https://github.com/justin-rhee/transcript-redactor
```

Verify it took effect rather than assuming: run any command that emits a credential shaped string, then read the transcript the run produced. The placeholder being there means it's working; the raw string being there means the wrapper is failing open and finding nothing.

## What it won't do

- see anything that doesn't pass through the wrapper, so a credential you paste into a chat turn by hand never touches it, which is how one of the four that prompted this package arrived
- be sufficient on its own: every rule was added after a real credential of a shape the previous list missed turned up in real output, so treat the list as a maintenance commitment rather than a finished perimeter
- preserve the exit code under a POSIX `sh` that isn't bash, commonly `dash` on Linux, where it returns a wrong code rather than degrading visibly; on macOS `/bin/sh` is bash so this doesn't appear there
- keep protecting you when the redactor is missing, since it fails open: if the redactor can't be found or isn't executable, the hook returns a plain allow, the command runs completely unwrapped, and from the outside that state is byte identical to a command with no credentials in it. That trade is deliberate, because a security control that can take down the shell tool gets uninstalled within a week, but a silent failure looks exactly like a quiet success, so do the install check above and watch for an allow with no rewritten command. The sibling package `untrusted-read` has the same shape for a different reason; if you run both, treat it as one property of your setup

## How I tested it

47 assertions across 4 suites, all passing:

```sh
./tests/run_tests.sh
TOTAL: 47 passed, 0 failed, across 4 suites
```

Every credential in the fixtures is synthetic, built from repeated characters and literal placeholders rather than copied from anything real. The two protections most likely to break silently were each tested by breaking them: disabling the fail open guard turns 47 passing into 44 passing and 3 failing, and reverting the symlink safe path resolution to the naive version turns it into 45 and 2. A test that still passes with the protection removed never tested the protection, so both numbers are in the suite's own history rather than in a claim. The 20 patterns were also probed against the original implementation before any of this was extracted, and again afterward, matching 20 of 20 both times.

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md). Design decisions and what changed while building it: [docs/ADR.md](docs/ADR.md).

This little tool is one of a handful I pulled out of my own day-to-day agent setup. I use them all myself, so when something breaks I usually notice fast. But if you run into any issues, or anything that looks off, open an issue. I read every one. More tools on my [GitHub profile](https://github.com/justin-rhee).
