# Handoff: update-spec

Commit: 928fa1b54f57
Date: 2026-10-30
Spec: .jig/specs/update-root-specs.md

## Built
An amendment to the spec, following the owner's call on Oct 30 ("update should move it"). It supersedes the first handoff, `update-spec-2026-10-30.md`, on one point:
- An immediate subfolder of root `specs/` or `ledgers/` that holds any Markdown now moves whole under `.jig/`, its other files included.
- Each moved subfolder is warned by name, so the dry run exits 1 and the skill puts it to the user.
- A collision anywhere in a subfolder keeps all of it at the root, so it is never split.
- A subfolder with no Markdown, and top-level non-Markdown files, stay as before.

This supersedes `update.md`'s Oct 29 "moves only its Markdown" decision for subfolders. Spec only; no code changed.

## Done-when evidence
Spec-only handoff: the Done-when items are the build's, checked by `bash tests/smoke.sh` when the spec is built. Each new item names its fixture and expected result: nested Markdown, a collision inside a subfolder, a `ledgers/` subfolder. `.jig/scripts/check.sh` passed at `928fa1b`.

## Review
A fresh-context reviewer read the delta since the first handoff (`bf5bf01..9d9778b`). All findings were taken in `928fa1b`:
- B1, blocking: the whole-subfolder rule and the per-file collision rule disagreed, so a collision split the subfolder the other way round. Now a collision keeps the whole subfolder, and a smoke case covers it.
- S1: a repo's own test subfolder with a README would move silently, and its runner glob isn't stale while `specs/` remains. Moved subfolders are now warned by name, and the spec says how a glob is judged as a reference.
- S2: the spec now states that it supersedes update.md's Oct 29 decision. The filter alternative is qualified to the top level.
- S3: "Markdown marks task material" is now attributed to the owner, not tagged [seen].
- O1, O2: "immediate subfolder" is spelled out; there are cases for nested Markdown and for `ledgers/`.

No DEFERRED rows.

## Fold-in
- [x] no code changed — nothing to fold in

## Shared files changed
None.

## Test by hand
Nothing to click. Read the spec's table, row 2, and the Decisions section.

## Left
- Owner: open question 1 (should the stale-reference list be retrievable after the update commit?), and approval of the spec before any build.
- Build after lane `names` merges, in its words.
