# Handoff: roadmap-no-phase

Commit: b5eec5dd7c7309aae86bbefd4264895eb348d45d
Date: 2026-11-13
Spec: .jig/specs/bug-roadmap-no-phase.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 (hubnode read of the conflict resolution only)

## Built
- `## No phase`, the roadmap's second reserved section: named work with no phase yet, in no
  order, `` - `<id>`: <what it is> `` per item, naming no pages. It is not in the phase line,
  has no state and is never current. The hook refuses, each by line, an item that names pages
  (pointing at Up next), a duplicate id, a line that isn't an item, and a phase already called
  `No phase` (the name is reserved). A spec can't take one, since it is not a scope.
- A phase's note, the prose under its heading up to its first list item or box (code fences
  kept), is printed under the phase heading in `ROADMAP.md` and by `jig roadmap`.
- `ROADMAP.md` prints No phase after Up next, with the line `_No phase set, in no order._`.
  `jig roadmap` lists it apart from the phases.
- RULES.md (Roadmap; Documentation), and the hubnode, review and spec skills, send work parked
  mid-build to Up next with its pages and named work with no phase to `## No phase`.

## Done-when evidence
- Fix fires: `bash tests/smoke.sh roadmap` printed `PASS  no phase: a roadmap with a ## No phase section commits, and the section is no phase`, `PASS  no phase: the view's phase line holds only the phases, and No phase follows them with its items, unstated` (phase line exactly `**alpha** (current) → beta`) and `PASS  no phase: jig roadmap prints the note under its phase and lists No phase apart from the phases`.
- Never current: `PASS  no phase: with every phase done, No phase never becomes current` (view has `alpha ✓ → beta ✓`, no `current`).
- Refusals: `PASS  no phase: an item naming pages is refused by line, pointing at Up next`; `… a duplicate item id is refused by line`; `… a line that isn't an item is refused by line`; `… a spec can't take a No phase item: it is no scope, and the refusal says so`.
- Notes: `PASS  no phase: a phase's note is printed under its heading, before Exit when, in order`. The existing roadmap and up-next view assertions pass unchanged.
- Symptom gone: in scratch repo `/private/tmp/claude-501/rm-nophase/repo`, the report's shape rewritten with `## No phase` gave a view with the phase line `**alpha** (current) → beta`, no `stage-not-set`, and alpha's note under `## alpha (current)`.
- `bash tests/smoke.sh`: `exit=0`, 1240 PASS, no FAIL lines. `claude plugin validate ./plugin`: `✔ Validation passed`. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: no output.

## Review
Hubnode review of 89b1790..4892202 at tier 2, effort 2. Nothing blocking. All fixed in 1bacf65:
1. Should-fix: review/SKILL.md:62-63, spec/SKILL.md:22 and RULES.md:225 still sent "not built
   yet" and phase content only to Up next. Fixed: each now says work parked mid-build goes in Up
   next with its pages, and named work with no phase in `## No phase`. Smoke greps all three.
2. Should-fix: the note took everything before the first list, an early `- [ ] boots`
   included, which then showed unticked under a done phase. Fixed: the note ends at the first
   list item or box, and lines after that are parsed as before. Smoke: a box before
   `Exit when:` in a done phase is absent from the view.
3. Optional, all taken:
   - A phase already named `No phase` now gets "## No phase is a reserved section, not a phase:
     rename the phase…". Smoke case.
   - Code fences inside a note are kept. Smoke case.
   - The spec-refusal case checks for the "doesn't have" message.
   - A case with both Up next and No phase checks that Up next prints first.
4. Sync b5eec5d (trunk 084d212) resolved the conflicts with project-sweep-noise in `plugin/skills/review/SKILL.md` (step 9) and `plugin/templates/jig/RULES.md` (Documentation), keeping both sides' text. The hubnode read it and recorded the review on b5eec5d.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Roadmap: the No phase bullet, phase notes, the view; Documentation: where unstaged work goes).

## Shared files changed
- `plugin/templates/jig/jig.py`: the roadmap parser, view and `jig roadmap`, and the hook's roadmap check.
- `plugin/templates/jig/RULES.md`: Roadmap section, and the Documentation line on where unstaged work goes (review finding 1).
- `plugin/skills/hubnode/SKILL.md`: one clause on `## No phase`, beside parked work.
- `tests/smoke.sh`: the `no phase:` cases at the end of `sec_roadmap`.
- Added to shares after review (finding 1), only the lines named there:
  - `plugin/skills/review/SKILL.md` (step 9, lines 62-63)
  - `plugin/skills/spec/SKILL.md` (step 5, line 22)

## Test by hand
In a scratch repo, write `.jig/roadmap.md` with two phases (one with a note) and a `## No phase`
section, commit, run `jig roadmap --write`, and read `ROADMAP.md`. The phase line names only the
two phases, the note sits under its phase, and No phase comes last as an unordered list.

## Left
Nothing. Adopting repos move a holding phase's scopes to `## No phase` on their own trunk after
`/jig:update`. A view with phase notes reads as stale once, and `jig roadmap --write` fixes it.
`marketing/FEATURES.md` is the hubnode's (row already written).
