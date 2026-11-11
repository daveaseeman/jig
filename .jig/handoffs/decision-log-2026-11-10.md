# Handoff: decision-log

Commit: 09d28143658b3ed8bc13034e479810e2f8a6891e
Date: 2026-11-10
Spec: .jig/specs/decision-log.md
Review: tier 2, effort 2
Partial: yes (chunk 1 of 2: the log, release and checks; chunk 2 is the migration). This repo's installed jig has no `--partial`, so it is recorded here.
Ran: fresh Opus review of fbd990c (chunk 1): B1 an unnumbered D-? id released via the conflict path then froze merges, B2 numbering rewrote placeholder-shaped text with no entry (both reproduced); fixed in 09d2814: number only the merge's new ids, jig merge --number on the conflict path, M2 refuses D-? on trunk, release refuses it; S1 terms_changed +=, S2 old-shape repos keep CHANGELOG/register rules until .jig/decisions.md exists, S3 released change lines aren't pointers, O1 yanked pin warns, O3 merge message lists numbers. Hubnode reran the reviewer's repro on 09d2814: the unnumbered commit and the release are refused.

## Built
Every repo keeps `.jig/decisions.md` (`jig init` writes it): decision entries and Keep a Changelog
lines under `## Open`, `## Unreleased`, `## vX.Y.Z - date`.
- `jig release` in every repo names Unreleased for the version and adds an empty one above it.
- M2 checks entries in every repo. Released sections are frozen except ` [YANKED]` and one line.
- R3 lets any job add to the log. The log is always an append file.
- M3, M4, M6 and the tag check move to the log; old tags still validate from CHANGELOG.md.
- `jig merge` numbers `D-?<slug>` entries (`--number` on a conflicted merge), and trunk and the
  release refuse unnumbered ones. `jig decision <id>` prints the chain.
- Fold-in by id reads the log. Pararepos cache and cite `<meta>/.jig/decisions.md`. Staged
  decisions land in the log.
- A repo whose trunk has no log yet keeps the old CHANGELOG.md and register rules until chunk 2
  migrates it.

## Done-when evidence
- Smoke `decisions` (plain repo): init writes the preamble, ## Open and ## Unreleased, and
  `release --minor` makes `## v0.1.0 - <date>` with a new Unreleased: PASS.
- Smoke: M2 refuses a status in the heading, no status line, a supersedes to no id, and an open
  entry under a release: PASS.
- Smoke: an edit under `## v0.1.0` is refused and `[YANKED]` + one line passes; `jig decision
  D-001` names D-002: PASS.
- Smoke: a job with no `--shares` commits `D-?store-ro`; `jig merge` numbers it D-003 in the log
  and the page, in the merge commit: PASS.
- Smoke `metarepo`: M3 asks for a line in `.jig/decisions.md`; a pararepo's sync caches it and
  reports D-001 from it; a tag with only CHANGELOG.md still validates: PASS.
- `jig update` migration: chunk 2, not in this note.
- RULES.md has a Decision log section; M2, M3, M4 and M6 are updated. The `grep CHANGELOG.md
  plugin` item waits on chunk 2 (survey's `ROOT_DOCS` and adoption table remain).
- `bash tests/smoke.sh`: 825 PASS, 0 FAIL, exit 0. `claude plugin validate ./plugin`: passed.
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: nothing. `.jig/scripts/check.sh`: exit 0.

## Review
Reviewed by the hubnode's fresh review of fbd990c; all findings fixed in 09d2814:
- B1 (an unnumbered id released via the conflict path): fixed. Only the merge's new ids are
  numbered; `jig merge --number` covers the conflict path; M2 on trunk and the release refuse
  `D-?`.
- B2/O2 (placeholder-shaped text rewritten): fixed. Only ids with an entry are numbered.
- S1 (`terms_changed` dropped log ids): fixed (`+=`).
- S2 (old-shape metarepos broke): fixed. No log on trunk means the old rules; there is a
  smoke case.
- S3 (frozen change lines read as pointers): fixed in `pointers()` and `meta_citations`.
- O1 (yanked pin): sync and release warn.
- O3 (subjects with `D-?` not renumbered): deferred, row in `.jig/ledgers/DEFERRED.md`; the merge
  message lists each number.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Decision log, R3, M2–M6, Fold-in, Staging, Metarepo, Release, Commands), plus the hubnode, subnode, release and stage skills.

## Shared files changed
- `plugin/templates/jig/jig.py`: the log, its rules, release, merge numbering, `jig decision`,
  sync's cache and citations, staging. Kept in new functions where possible (`log_*`,
  `number_placeholders`, `released_lines`, `yanked_pin`, `resolve_register`).
- `plugin/templates/jig/RULES.md`: a new Decision log section, plus the R3, M2/M3/M4/M6, Fold-in,
  Staging, Metarepo, Release, Homes and Commands lines.
- `tests/smoke.sh`: new section `decisions`, plus metarepo, pararepo, staging and entry_globs
  rewritten for the log; helpers `ulog`, `dec`, `m2`.
- `plugin/templates/AGENTS.md`: one Workflow line.
- `.jig/ledgers/DEFERRED.md`: the O3 row.

## Test by hand
In a scratch repo: `jig init`, add an entry under Unreleased, release with `--minor`, then try to
edit the released line (refused) and `jig decision D-001`.

## Left
Chunk 2:
- `jig update` merges a root CHANGELOG.md and the decisions register into the log on a yes,
  removes both, and rewrites `entry_files`. It also writes the log into existing repos.
- The STAMP bump, survey/homes (`ROOT_DOCS`, the adoption table), and the update skill.
- The `grep CHANGELOG.md plugin` done-when.
- The request's appendix (its exact writing rules) wasn't reachable. RULES.md's "Writing it" is
  a draft to swap if the owner's text turns up.
