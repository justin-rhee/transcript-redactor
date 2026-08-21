# transcript-redactor

I went looking through my agent's saved transcripts and found four different live credentials in them. Every one had been written there by an ordinary command doing exactly what I asked

None of it was dramatic. An agent reads a config file to check a setting, or a script prints its own environment while failing, and the output goes into a session log that persists on disk. I wouldn't look at that file again for weeks. By the time I did, it had been backed up, synced, and copied into a second machine's history. The redaction list I already had was written before three of those four credential shapes existed, so it caught none of them, and it reported nothing at all while missing them.

If you let an agent run shell commands and you keep the transcripts, you have this too, whether or not you have gone looking yet.

So this is a hook that pipes every command's output through a redactor before the transcript records it, about 130 lines of bash.

## Use it if

- your agent runs shell commands and you keep the transcripts
- session logs get backed up, synced, or copied to a second machine
- you want a pattern list you can read in a minute, not a classifier
- your current redaction list predates half the credentials you now hold

## How it works

Every command is rewritten before it runs so that stdout and stderr pass through a single ordered `sed` filter, most specific pattern first. Credential shaped strings come out as typed placeholders like `[REDACTED:openrouter]`, and the original exit code is preserved, so a failing command still reports as failing.

The filter is a fixed pattern list, not a model and not an entropy heuristic. That's a deliberate limit. A classifier that decides whether a string "looks secret" is wrong in both directions at once: it leaks the credential shape nobody trained it on, and it corrupts ordinary output that happens to look random. A literal pattern is dumber, and you can read the whole thing in a minute and know exactly what it covers.

The list names its vendors openly rather than hiding behind generic regexes. If you can see that Anthropic, OpenAI, GitHub, GitLab, Slack, AWS, Figma, Firecrawl, Discord and OpenRouter are covered, you can also see who isn't.

```
$ echo "key is sk-or-v1-$(printf 'a%.0s' {1..64})" | ./src/redactor.sh
key is [REDACTED:openrouter]
```

## When it is not protecting you

If the redactor can't be found or isn't executable, for any reason at all, the hook returns a plain allow and your original command runs completely unwrapped. No redaction happens. Nothing errors, nothing warns, and nothing is logged.

From the outside that state is byte identical to "this command had no credentials in it". Both produce the same bare allow. There's no signal anywhere in the hook's output that distinguishes working normally from not running at all.

This is a deliberate trade. The alternative is a hook that can break your agent's shell tool whenever a path is wrong, and a security control that takes down the thing it protects gets uninstalled within a week. The cost of that choice is that a silent failure looks exactly like a quiet success.

Two things follow, and both are on you rather than on the tool. Confirm after installing that a wrapped command actually comes back wrapped, using the check under Install, because the file being in place doesn't mean it's being found. Then watch for the hook returning an allow with no rewritten command, which is the only observable difference between the two states.

The same shape exists in the sibling package `untrusted-read`, for a different underlying reason. If you run both, treat it as one property of your setup rather than two separate quirks.

## Try it before you install it

`src/redactor.sh` is a standalone filter. Pipe anything through it and see what survives:

```
$ printf 'ghp_%s\n' "$(printf 'a%.0s' {1..36})" | ./src/redactor.sh
[REDACTED:github-classic]
```

No install, no config, nothing written. If your own credential shape passes through unchanged, you have found a gap before it costs you anything.

## Install

It needs `bash`. Not `sh`, and the reason is under What it won't do.

Put both files somewhere stable, keep them side by side, and register `src/redact-bash-output.sh` as a PreToolUse hook on your agent's shell tool. The wrapper finds `redactor.sh` next to itself, following symlinks correctly, so installing the wrapper on your `PATH` as a symlink works. Set `TRANSCRIPT_REDACTOR_PATH` if you want them apart.

Confirm it took effect rather than assuming. Run any command that emits a credential shaped string, then read the transcript the run produced. If the placeholder is there, it's working. If the raw string is there, the wrapper is failing open and finding nothing.

## What it won't do

- see anything that doesn't pass through the wrapper, so a credential you paste into a
  chat turn by hand never touches it, which is how one of the four that prompted this
  package arrived
- be sufficient on its own, since every rule was added after a real credential of a
  shape the previous list missed turned up in real output, so treat the list as a
  maintenance commitment rather than a finished perimeter
- preserve the exit code under a POSIX `sh` that isn't bash, commonly `dash` on Linux,
  where it returns a wrong code rather than degrading visibly; on macOS `/bin/sh` is
  bash so this doesn't appear there
- keep protecting you when the redactor is missing, since it fails open

## How I tested it

47 assertions across 4 suites, all passing:

```
$ ./tests/run_tests.sh
TOTAL: 47 passed, 0 failed, across 4 suites
```

Every credential in the fixtures is synthetic, built from repeated characters and literal placeholders rather than copied from anything real.

The two protections most likely to break silently were each tested by breaking them. Disabling the fail open guard turns 47 passing into 44 passing and 3 failing. Reverting the symlink safe path resolution to the naive version turns it into 45 and 2. A test that still passes with the protection removed never tested the protection, so both numbers are in the suite's own history rather than in a claim.

The 20 patterns were also probed against the original implementation before any of this was extracted, and again afterward, matching 20 of 20 both times.

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md).

Design decisions and what changed while building it: [docs/ADR.md](docs/ADR.md).

---

This little tool is one of a handful I pulled out of my own day-to-day agent setup. I use them all myself, so when something breaks I usually notice fast. But if you run into any issues, or anything that looks off, open an issue. I read every one. More tools on my [GitHub profile](https://github.com/justin-rhee).
