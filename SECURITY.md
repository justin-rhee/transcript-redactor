# Security policy. transcript-redactor

## Posture

transcript-redactor is provided as-is, with NO WARRANTY (see LICENSE). Use it as one
control among several, never as a sole guarantee.

If this is a security-oriented tool, the honest ceiling applies: it **reduces,
does not eliminate**, the risk it addresses. Behavioral rules are defense-in-depth
on top of a structural limit, and the structural limit only holds if the host
environment actually enforces it (e.g. actually withholds the tools/permissions
the design assumes are withheld). State that assumption; do not let it read as a
promise the code can't keep.

## Validation status

I have run the offline test suite. 52 assertions pass across 4 suites, with 0 failures. Run it with `./tests/run_tests.sh`. Every key in it is synthetic. The tests do not cover live Claude Code behavior: I have not run the hook inside Claude Code, so I have not confirmed how it handles a rewrite that carries no permission decision. They also do not cover real credentials, a red-team corpus of unseen secret formats, or shells other than bash (a POSIX sh such as dash breaks exit-code preservation).

## Reporting a vulnerability

Report privately to https://github.com/justin-rhee. Please do not open a public issue for a
suspected vulnerability. give a reasonable window for a fix first.
