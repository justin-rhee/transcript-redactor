# Architecture Decision Records (ADRs)

Why this hook fails open, why one of its own test fixtures is spelled in pieces, and what the pattern list is actually a record of.

## I found four live credentials in my own saved transcripts, and the redaction list I already had caught none of them

None of it came from anything unusual. An agent read a config file to check a setting, or a script printed its own environment while failing, and the output landed in a session log that sits on disk, gets backed up, gets synced to a second machine. The list I had was written before three of those four shapes existed, and it said nothing while missing all three.

Each addition to the pattern list traces to one of those incidents, not to a hardening pass done in advance. An OAuth-token prefix from a vendor already covered by an API-key pattern showed up unmatched, since the old rule only covered the API-key form, so it was generalized to the prefix family. A JWT and a refresh token from a second vendor turned up in the same incident unmatched by anything, so both were added, plus two more Git-hosting token forms. A PAT and an OAuth query-string secret turned up later in stored traces rather than live output, which is what pushed the capture step itself to pipe through the same redactor at write time, not just command output. A fourth vendor's key arrived pasted into chat text during onboarding, never touched by this tool at all, and got rotated immediately regardless. The list is twenty patterns now, necessary without being sufficient, and a fifth vendor will turn up eventually. That's a property of the maintenance model, not a defect in this version of it.

## One test fixture spells its prefix in two pieces, and that split stays

The fixture for the Slack bot-token pattern builds the string as `$(printf 'xox')b-...` instead of writing `xoxb-...` directly. The redactor receives the same bytes either way; only the test file's own spelling changes. Without the split, a secret scanner flags that line as a real Slack token, and gitleaks does, the only fixture in the suite it trips, because the other synthetic bodies here fail entropy or checksum checks that this shape happens to pass. A package whose entire job is matching credential shapes cannot itself contain a shape that reads as a live one to the tools guarding the repo it publishes to. The fragments stay fragments.

## It fails open, which I decided on deliberately after watching a strict guard get uninstalled

If `redactor.sh` cannot be found or is not executable, the hook returns a plain allow and the original command runs completely unwrapped, no redaction pipe at all. From the caller's side that state is identical to "nothing in this command needed redacting." The alternative is a hook that can break the agent's shell tool the moment a path is wrong, and I'd rather a check fail silently than take down the tool it guards. The cost is real: nothing in the hook's own output distinguishes a working redactor from a missing one, so watch for a bare allow with no rewritten command as the signal that it stopped being found.

## Making the path portable created a bug that the hardcoded version never had a chance to have

The original hardcoded an absolute path to `redactor.sh`, so there was no self-referential lookup to get wrong. Publishing meant the path could no longer point at one machine's home directory, which meant resolving it relative to the wrapper's own location instead, and that is where the new failure mode opened up. A naive `dirname` of the script resolves to a symlink's directory when the wrapper is invoked through one, not the package's directory, which is how a wrapper installed on `PATH` the normal way, as a symlink, would silently take the fail-open branch on every invocation. The fix is a symlink-following loop that works on bash 3.2, since `readlink -f` isn't available on stock macOS.

## The exit-code trick is a bash-ism I inherited and left alone

Exit-code preservation depends on `${PIPESTATUS[0]}`, which works on macOS because `/bin/sh` there is bash, but breaks under a POSIX shell that isn't bash, commonly `dash` on Linux. A standalone probe sent a command with a real exit code of 37 through the wrapper under such a shell and got back 2, the shell's own parse-error code, a wrong and misleading result rather than a clean failure. I didn't change the mechanism, since replacing it is a real behavior change outside a surgical extraction of what already existed. It stays documented loudly in the wrapper's header, and belongs in a requires-bash line anywhere this lands on a Linux runner shelling out through something other than bash.
