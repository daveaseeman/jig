# Handoff: rig-and-versioning

Commit: 67d3518ccfb87aed710c3646c7156bf21919f5e7
Date: 2026-11-18
Spec: .jig/specs/rig-and-versioning.md
Partial: yes
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
Parts 1 and 2 of rig-and-versioning, with bug-rav-staged-drops (`Bug-for: rig-and-versioning`); part 3 (versioning, pin-bump) follows in this job.
- Merged jobs leave nothing in flight: a merge (clean, or at `jig merge --number` after a conflict) removes the job's spec and its `Bug-for:` specs, keeping each spec's `Scope:` and its staged files' `Source: … (staged as …)` lines on the completing note's header; the roadmap reads a closed spec's scopes from its note, and the hook guards a note's `Scope:` as a spec's. `jig rig --close` closes what merges left in one commit and lists it under a new Finished part; `jig open` refuses a name whose earlier `Bug-for:` spec is still on trunk. A pararepo spec naming a proposal or pointers branch, or one a cached metarepo pointer names, is kept. `jig merge` prints `close the sessions that worked on <job>`; the hubnode and rig skills archive them.
- Rig's batching: a staged decisions file's Touches are its entries' Touches plus the log; each group with an overlap is one question ("group N: one job for K items, or keep some apart"), with per-member shared Touches and an `append_only` flag; a staged file a spec in flight carries is `taken`, never offered again.
- In the jig repo, staged feedback is a `feedback` item: rig starts `/jig:fix` on it and stores `fixing` (keyed on the report alone), or `concluded` when `/jig:fix` leaves it staged.
- Staging's one exit is `resolve` or a hand `drop` (the owner: "Only via resolve"): nothing at a merge or a close deletes a staged file. A carried story, request or report whose spec closed is `built` and `jig rig --close` resolves it (`carried by <note>`); a carried decisions file is `noted`, the hubnode's step (the owner: "Ya just make it the hubnodes job"); taken, built and noted items take no judgment.
- Text: RULES (merge step 3, the `jig rig` paragraph, Staging, Roadmap, Homes, Commands, the Feedback row), rig, hubnode, spec and fix skills, AGENTS.md (the release-time archiving sentence dropped).

## Done-when evidence
- `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` → exit 0; `claude plugin validate ./plugin` → Validation passed.
- `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh close rig rig_batch staging roadmap merge_derived next workflow pararepo staging_batches consolidate decisions sync_buffer buffer_answered pararepo_commands` → 596 PASS, 0 FAIL at 6397c20.
- Smoke `close` (47 cases): merge-time closing of a spec and its `Bug-for:` spec, the note's `Scope:` and marks, the close-sessions line, roadmap fresh with the note link, a second open job's spec kept, a partial note's spec kept and its file `taken`, a reopened name's strike limit held, a note's dropped scope refused and re-pointed, `finished` and `--close` (one commit, refusals off trunk and on a dirty tree), the conflicted and derive-stop paths, a built request resolved by `--close`, a noted decisions file left, a refusal named while `--close` goes on, every reviewer repro below, doc updates landing with their mark anywhere.
- Smoke `rig_batch` (19 cases): Part A touches, Part B one group line, Part C taken by a spec and by a job, the batch's rounds 1 and 2, determinism, feedback in and out of the jig repo, `fixing` and `concluded`.
- Smoke `rig` c7 rewritten for one line per group. On this repo's trunk `jig rig --json` listed 94 finished specs (the spec's estimate ~95).
- Repro scripts (all pass at 6397c20): /private/tmp/claude-501/-Users-daveseeman-Documents-GitHub-jig/89e42143-af29-4fe8-b329-f482cf80befe/scratchpad/rv-rav12-a12af04/ (repro.sh, repro2.sh), /private/tmp/claude-501/-Users-daveseeman-Documents-GitHub-jig/89e42143-af29-4fe8-b329-f482cf80befe/scratchpad/rc-rav2-64a8fd3/repro3.sh, /private/tmp/claude-501/-Users-daveseeman-Documents-GitHub-jig/89e42143-af29-4fe8-b329-f482cf80befe/scratchpad/rc-rav3-205589b/ (mine.sh, mine2.sh), /private/tmp/claude-501/-Users-daveseeman-Documents-GitHub-jig/89e42143-af29-4fe8-b329-f482cf80befe/scratchpad/rc-rav4-c951bdf/ (edges.sh, edges2.sh, edges3.sh), /private/tmp/claude-501/-Users-daveseeman-Documents-GitHub-jig/89e42143-af29-4fe8-b329-f482cf80befe/scratchpad/rc-rav5-28990e4/noted.sh, /private/tmp/claude-501/-Users-daveseeman-Documents-GitHub-jig/89e42143-af29-4fe8-b329-f482cf80befe/scratchpad/rc-rav6-4c0292d/ (mine.sh, mine2.sh).

## Review
- review-work of main...d8b8fa8 (recorded at ec64582): B1 blocking (a conflicted merge left the `Bug-for:` spec, lifting a reopened job's strike limit) — strike 1. Fixed at a12af04 (close at `--number`; `jig open` refuses the old name); S1, S2 and O1–O4 taken, O3 deferred.
- review of main...a12af04 (parts 1 and 2): B1 (a stopped merge's staged file never named) and B2 (a partial note's file offered again) — strike 2. Fixed at 64a8fd3; S1 (`concluded`), O1–O3, O6, O7 taken; O4 (part), O5 deferred.
- review-change of a12af04..64a8fd3: F1 blocking (history read as closes deleted unbuilt files), F2 should-fix — strike 3. Bug ran: bug-rav-staged-drops at 7bc141b. The owner: "Only via resolve" (option (a)).
- review-change of 64a8fd3..205589b: B1 (`--close` resolved taken and unbuilt files), B2 (a title-only match lost a decisions file); S1, S2. Fixed at c951bdf; O1, O3 taken; O2, O4 (part) deferred.
- review-change of 205589b..c951bdf: B1 (renumbered and settled entries missed). The owner: "Ya just make it the hubnodes job". S1 (one mark test) fixed at d5e378b; the ruling built at 28990e4.
- review-change of c951bdf..28990e4: B1 (a noted file could be judged ready), B2 (the merged spec's done-when); S1–S3, O1–O4. Fixed at 4c0292d.
- review-change of 28990e4..4c0292d: B1 (doc updates lost their substring landing); S1, S2, O1–O3. Fixed at 6397c20.
- review-change of 4c0292d..6397c20: clean, blocking 0. S-1 and O-a–O-e are DEFERRED rows (67d3518).

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's documentation is `plugin/templates/jig/RULES.md`, updated here (Handoff, gate, merge step 3; Workflow: the `jig rig` paragraph and the Feedback row; Staging; Roadmap; Documentation § Homes; Commands).

## Shared files changed
- `plugin/templates/jig/jig.py`: merge, rig, roadmap, staging resolve, P2's spec read at a merge commit — the code of every part.
- `plugin/templates/jig/RULES.md`: the rules those commands enforce.
- `tests/smoke.sh`: new sections `rig_batch` and `close` (added to UNITS), `rig` c7 rewritten.
- `plugin/skills/hubnode/SKILL.md` (Merging: closed specs, sessions, the noted step), `plugin/skills/stage/SKILL.md` (not touched in parts 1–2).
- `AGENTS.md`: the release-time archiving sentence dropped.

## Test by hand
- On this repo's trunk after the merge: `python3 .jig/jig.py rig` lists the finished specs under Finished; `python3 .jig/jig.py rig --close` removes them in one commit (about 95), keeping each scope on its note; `jig roadmap` reports the same states before and after.

## Left
- Part 3 (versioning and the pin-bump request), re-applied from the saved patches, then its own review and the final handoff.
- DEFERRED rows for this part: O3 of the first review, O4 (part)/O5, O2/O4 (part) of 205589b's review, S-1 and O-a–O-e of the clean review.
