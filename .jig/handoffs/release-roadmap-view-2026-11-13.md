# Handoff: release-roadmap-view

Commit: 34840e0cbd83ba49135f3cc45b97a745a9af4eea
Date: 2026-11-13
Spec: .jig/specs/bug-release-roadmap-view.md
Review: tier 2, effort 2

## Built
`meta_problems`, the check shared by `jig release` and pre-push in a metarepo, now accepts a
first-parent trunk commit of `ROADMAP.md` where the commit or its parent keeps
`.jig/roadmap.md`, as M4 does when the commit is made. A metarepo that commits its roadmap view
on trunk, as the hubnode is told to, can release and push again.

## Done-when evidence
- Reported symptom: `bash tests/smoke.sh roadmap` → PASS "in a metarepo, pre-push passes that
  trunk commit of ROADMAP.md as M4 did" and PASS "and release accepts it, and tags". In a scratch
  metarepo with the same history, trunk's unfixed `jig.py` prints "refused: 05a043726d57 is on
  main without a reviewed merge (GLOSSARY: roadmap view)".
- Fires only where M4's does: PASS "in a metarepo with no roadmap at that commit, a ROADMAP.md
  commit made with hooks off is still refused by release".
- Dropping the roadmap and its view together: PASS "dropping the roadmap and its view in one
  commit passes the hook and release". Trunk's unfixed copy refuses that commit.
- `.jig/scripts/check.sh` exit 0 (validator and syntax). Full smoke, the validator and the
  remnants grep run at the gate.

## Review
Fresh Opus review of da9b0f1: no blocking findings.
- should-fix 1: the roadmap was read only at the commit, while M4 also counts trunk before
  it. Fixed: the check reads the commit and its parent.
- should-fix 2: a commit removing the roadmap and its view was refused. That's fixed by the
  same change, with a smoke case. M4's wider blindness to deletions is a DEFERRED row.
- should-fix 3: the pre-push case ran after the tag, so it judged an empty range. Fixed: the
  push now runs before the release.
- optional: an [assumed] tag on a rejection reason. A DEFERRED row.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is
  `plugin/templates/jig/RULES.md`, which already says M4 lets the hubnode commit `ROADMAP.md`
  on trunk (the roadmap's R5 paragraph). The release check now matches it, so no sentence went
  stale.

## Shared files changed
- `plugin/templates/jig/jig.py`: the fix, in `meta_problems`.
- `tests/smoke.sh`: five cases in the `roadmap` section's `rm-meta` repo.

## Test by hand
None needed: the smoke cases run the release and the push in a real metarepo.

## Left
Nothing on this job. The release is 0.12.1, on the owner's mark, after the other hubnode's two
open jobs.
