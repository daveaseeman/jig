# Handoff: stage-ask-access

Commit: 780479c35ea06a5b0283d1eb8d3165f825cc0502
Date: 2026-11-10
Spec: .jig/specs/stage-ask-access.md
Review: tier 2, effort 3
Ran: fresh Opus review (lighter, skill text) of dac7fb2: no blocking; S1 ~/.config/jig/ access and the feedback folder, O1 missing .jig/staging/ suggests /jig:update, fixed in 780479c; O2 hubnode git -C access deferred. Hubnode checked 780479c by diff.

## Built
The stage skill (Staging a file) and the feedback skill (step 2) now say how to get access: request `~/.config/jig/` if unreadable, then exactly `<repo>/.jig/staging/`, with the host's folder-access tool (`request_directory` in the desktop app); else ask the user to add the folder; never stop at "no access". A registered repo with no `.jig/staging/` gets "say so, suggest /jig:update". Skill text only.

## Done-when evidence
- `grep -n request_directory` on both skills: found in both.
- `grep -n 'no access'` on both skills: the never-stop clause in both.
- `grep -rn request_directory plugin/templates`: nothing.
- `claude plugin validate ./plugin`: passed. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: nothing.

## Review
Opus review of dac7fb2, nothing blocking. S1 (also request `~/.config/jig/` and the feedback folder) and O1 (no staging folder -> /jig:update) taken in 780479c. O2 (hubnode skill's `git -C` read has no access line) deferred, row in DEFERRED.md.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] no code changed — nothing to fold in (skill text only; no docs page covers these sentences)

## Shared files changed
`plugin/skills/stage/SKILL.md` (shared with decision-log, already merged). `.jig/ledgers/DEFERRED.md`: one appended row for O2.

## Test by hand
Ask a session with no access to another repo to stage a file there; it should request the folder (or ask you to add it) instead of stopping.

## Left
Nothing on this job.
