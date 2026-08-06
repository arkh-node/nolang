# Anchors — digests published where someone other than us can see them

A subject chain proves that forgery is **never local**: altering one record breaks the next link.
It cannot prove that the *whole* chain was not rebuilt — whoever holds it from the first link can
construct another, equally consistent one. That is not a weakness of the hash. *"This history was
not rewritten"* is a claim about the **world**, and no computation proves it from the inside.

The only remedy is a **witness**: put the digest somewhere we do not control, and rewriting the
past now means contradicting someone else's copy.

This file is that somewhere. Its own history in the public repository — mirrored by every clone,
fork and cache — is the witness. Class: **`:witnessed`** (see `src/anchor.lisp`). Not `:notarised`:
git timestamps are written by the committer, so this file carries **no independent evidence of
time**. What it carries is independent evidence of *content*.

## How to verify (any third party, no trust in us required)

```bash
git clone https://github.com/arkh-node/nolang.git && cd nolang
./anchor_verify.sh
```

The script recomputes the digest from the sources in *your* clone and compares it with the value
recorded below. It passes only if they are identical. `test/D7_anchored.sh` runs the same check
inside the battery, so a silent drift cannot survive a test run.

**What a mismatch means, precisely:** the recorded subject is no longer reproducible from the
current tree. That is either a rewritten past or an honest change to the language. The script
cannot tell those apart and does not pretend to — it reports the divergence and stops. Honest
changes are handled by **appending a new anchor**, never by editing an old one: the point of the
row below is that it is fixed in a history we cannot quietly rewrite.

## Anchors

| # | date | subject | digest | channel | class |
|---|---|---|---|---|---|
| 1 | 2026-08-06 | `test/subject/` — scene `scene.nolp` + trace `trace.nol`, carrier `:морф` | `sha256:c62bae8f66ffd48fde4700535aa5582c79140473391f670b37d76d02902dbba5` | `:public-repo` — this file, `arkh-node/nolang` | `:witnessed` |

Scene digest of anchor 1 (what was judged by, independently of what was judged):
`sha256:7977d0a8fbb43e088bdd76a6242b5155ccc81e0781ac535b49569be398058a76`

### What anchor 1 covers, and what it does not

**Covers:** the demonstration subject — its scene (horizon, lattices, sources with their
fingerprints), its trace, and the ledger produced by running it. Change any of them and the digest
moves.

**Does not cover:** everything committed after this line. An anchor witnesses the past, not the
future; the segment after the last anchor still rests on *"forgery is never local"* alone.
`chain-anchored-prefix` reports that boundary as a count rather than a caveat.

**Also does not cover:** *when* this was written. See the note on `:notarised` above.
