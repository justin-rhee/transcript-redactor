# transcript-redactor

[![tests](https://github.com/justin-rhee/transcript-redactor/actions/workflows/test.yml/badge.svg)](https://github.com/justin-rhee/transcript-redactor/actions/workflows/test.yml) [![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) ![shell](https://img.shields.io/badge/shell-bash-blue.svg) ![zero dependencies](https://img.shields.io/badge/dependencies-0-brightgreen.svg)

Blanks out API keys and tokens in command output before your agent's session log saves them.

```sh
printf 'ghp_%s\n' "$(printf 'a%.0s' {1..36})" | ./src/redactor.sh
[REDACTED:github-classic]
```

I went through my agent's saved transcripts and found four live credentials, each written there by an ordinary command doing what I asked. My redaction list predated three of those four key formats, so it caught none of them and reported nothing while missing them. If you let an agent run shell commands and keep the transcripts, you have this too, whether or not you've looked.

## Use it if

- your agent runs shell commands, and the transcripts get backed up, synced or copied elsewhere
- you want a pattern list you can read in a minute, not a classifier
- your current redaction list predates half the credentials you now hold

## Install

About 130 lines of bash in two files. Keep them side by side and register `src/redact-bash-output.sh` as a PreToolUse hook on your agent's shell tool. It needs `bash`, not `sh`.

```sh
git clone https://github.com/justin-rhee/transcript-redactor
```

Then check it took effect: run a command that prints a key-shaped string and read the transcript. A placeholder means it's working; the raw string means it's failing open.

## How it works

Every command is rewritten so its output passes through one ordered filter, most specific pattern first. Keys come out as typed placeholders like `[REDACTED:openrouter]`, and the exit code is kept, so a failing command still fails. The list names its vendors (Anthropic, OpenAI, GitHub, GitLab, Slack, AWS, Figma, Firecrawl, Discord and OpenRouter), so you can see who isn't covered.

## Why not a classifier?

One that guesses whether a string looks secret is wrong both ways at once: it leaks the key format nobody trained it on, and mangles ordinary output that happens to look random.

## What it won't do

- see anything that doesn't pass through the wrapper, so a key pasted into chat by hand never touches it, which is how one of the four arrived
- be finished, since every rule was added after a new key format turned up, so the list is a maintenance commitment
- keep the exit code under a POSIX `sh` that isn't bash, commonly `dash` on Linux, where it returns a wrong code without warning
- keep protecting you if the redactor goes missing, since it fails open on purpose: a control that can break the shell tool gets uninstalled within a week, so do the install check above

The sibling [untrusted-read](https://github.com/justin-rhee/untrusted-read) fails open the same way, for a different reason.

## How I tested it

- 52 assertions across 4 suites, every key synthetic: `./tests/run_tests.sh`
- disabling the fail-open guard turns 3 red, and reverting the symlink-safe path resolution turns 2 red
- all 20 patterns matched before extraction and again after; design decisions are in [docs/ADR.md](docs/ADR.md)

## Contributing

Missing a key format you hold? A pull request with the pattern and a synthetic fixture is the fastest way in.

## License

MIT. See [LICENSE](LICENSE). No warranty. Security notes and how to report a problem: [SECURITY.md](SECURITY.md).

<!-- related:start -->
## Related

- [untrusted-read](https://github.com/justin-rhee/untrusted-read): stops instructions hidden in shared notes from steering an agent
- [path-fence](https://github.com/justin-rhee/path-fence): refuses credential-shaped file reads before they happen

Part of a small set of tools I pulled out of my own agent harness. I use them myself and read every issue. More on my [GitHub profile](https://github.com/justin-rhee).
<!-- related:end -->
