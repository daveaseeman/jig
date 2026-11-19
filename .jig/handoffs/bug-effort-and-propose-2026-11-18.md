# Handoff: bug-effort-and-propose

Commit: 2626367a21629b2593ebfa4702913e33f2401fa3
Date: 2026-11-18
Spec: .jig/specs/bug-effort-and-propose.md
Source: Daisy hubnode session / 2026-11-18 / the owner (Dave Seeman) (staged as feedback-Daisy-2026-11-18-hubnode-effort-clamp.md): "a fable hubnode on low couldn't start opus subnodes on high. any tier 1 model at any effort should read as higher than the next tier even at it's highest effort, and therefore be allowed to start them."
Source: Maige-OS hubnode session, 2026-11-18, on Dave's word ("The jig gap: file the feedback note.") (staged as r2-refuses-propose-branch.md): "R2 branch propose/Maige-OS-buffer-b5-b7 is on no job. Ask the hubnode to open one, or work on main", refused by the metarepo's `jig check` and pre-commit hook on the branch `jig propose` made, while the metarepo had a job open.
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
- `jig roles --from TIER,EFFORT`: under each role's line, how a session at those settings starts it ("start with its settings", or "start, then raise model|effort|model and effort"), compared one setting at a time as the tool clamps them; and a line when those settings rank below the hubnode floor, tier first, then effort (`HUBNODE_FLOOR` is now used). Bad input is refused with the usage line; plain `jig roles` is unchanged.
- R2: in a metarepo (`.jig/meta.json` on trunk), a `propose/` branch passes the no-job clause while jobs are open. Every other check still runs on it; R1 still keeps the trunk checkout off it; a `propose/` branch elsewhere is refused as before.
- RULES.md: R2's line states the no-job clause and its exception; Metarepo rule 1 says so; a "Ranking settings" paragraph (tier-first for the floor only; starts and the gate's warning compare apart); the hubnode row; the Commands line.
- Hubnode skill: step 6 maps the hubnode's own settings with `tiers.json` and runs `jig roles --from` (unknown effort, unlisted model, each with what to pass); Assigning a step follows its line, compares the settings apart, and briefs a raised session once its model line and the host's effort readout match (no readout: once the model line is right, telling the owner).
- `tiers.json`: tier 1 is `claude-fable-5-2`.
- `.jig/decisions.md`: three lines under Unreleased › Fixed.

## Done-when evidence
- `--from 1,4`, `2,4`, `3,0`, `2,1`, `3,4`, `2,3`, `x`, `0,1`, plain `roles`: `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh workflow pararepo` → 129 PASS, 0 FAIL, including
  `PASS  roles --from 1,4: a better tier at low starts tier-2 roles and raises effort; check as is; no floor line`,
  `PASS  roles --from 2,4: the same raises, and below the hubnode floor`,
  `PASS  roles --from: tier first, then effort: 3,0 is below the floor, 2,1 is not`,
  `PASS  roles --from 3,4 raises model and effort for work; 2,3 starts work as is and raises review's effort`,
  `PASS  roles --from x and 0,1 are refused with the usage line; plain roles prints only the role lines`.
- Hubnode skill names `jig roles --from` in step 6 and Assigning a step, compares the settings apart, waits for the model line and the host's readout: `grep -n "roles --from\|at or below" plugin/skills/hubnode/SKILL.md` → steps 6 and Assigning; no "at or below".
- RULES ranks tier first, then effort, names no model or host tool: "Ranking settings" paragraph; `grep -nE 'fable|opus|sonnet|haiku|set_session' plugin/templates/jig/RULES.md` → only "octopus" lines.
- `plugin/tiers.json`: `"1": "claude-fable-5-2"`.
- The symptom run by hand: not run here; see Test by hand.
- `marketing/FEATURES.md` row: the hubnode's (gitignored), per the brief.
- R2 smoke (`sec_pararepo`): `PASS  R2: with a metarepo job open, a propose/ branch passes jig check and commits, with no R2`; `PASS  R2: with the same job open, a plain branch in the metarepo is still on no job`; `PASS  R2: a propose/ branch in a repo that isn't a metarepo is on no job, as any other branch`; `PASS  R2: the metarepo's trunk checkout on propose/pr-fmt is still refused, naming R1`.
- RULES states the clause: R2's line in The rules, and Metarepo rule 1.
- `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` → exit 0; `claude plugin validate ./plugin` → `✔ Validation passed`. Full smoke: the check role's (the review-work ran it: 241 of 241).
- `grep -rnE 'Maige|maige|Daisy|daisy' plugin tests` → only the two existing guard lines in `tests/smoke.sh`.

## Review
- review-work 813835e: 1 blocking. B1 (the by-hand item had no evidence) → reworded as a run after merge (32320af). S1 (ranking stated generally against the gate's warning) → scoped. S2 (unknown effort, unlisted model, no readout) → a line each. O1 (unmapped numbers) deferred, O2 (R6 on a proposal) deferred, O3 (R4 on a proposal) rejected as a note: DEFERRED rows.
- review-change 32320af: 1 blocking. B1 (the by-hand run can't happen before the release is installed) → reworded to start once the release is installed, under Test by hand (79647e2). S1 (the scoping sentence's contrast) and S2 (the unlisted model's floor guess) → taken as worded. O1–O3 (the `low` wording, the cross-reference, the Interpreted label) → taken.
- review-change 05a0594: clean, blocking 0, no should-fix. Its three optional findings are one DEFERRED row (2626367).

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (The rules: R2; Workflow: hubnode row, Ranking settings; Metarepo and pararepos rule 1; Commands), with the hubnode skill.

## Shared files changed
- `plugin/templates/jig/jig.py`: `cmd_roles` and its parser (`--from`), `HUBNODE_FLOOR`'s comment; `check_rules`' R2 no-job clause. Both are the spec's fixes.
- `plugin/templates/jig/RULES.md`: the sections listed under Fold-in, where the rules are stated.
- `tests/smoke.sh`: `sec_workflow` (roles --from) and `sec_pararepo` (R2), the evidence.
- `plugin/skills/hubnode/SKILL.md`: step 6 and Assigning a step, where the hubnode follows `--from`.
- `.jig/decisions.md` (Unreleased) and `.jig/ledgers/DEFERRED.md` (four rows): any job may add.

## Test by hand
- Who: the owner, or a hubnode on `claude-fable-5-2` at `low`. When: once the release carrying this is installed (plugin updated, `/reload-plugins`). In a throwaway repo set up with `/jig:init`, with a small spec and a job opened (`jig open`): the hubnode runs `jig roles --from 1,4`, starts the work session as its line says, raises it to `medium`, and briefs it only once the host's readout shows `medium`; the session is not stopped for its effort and does the work. The transcript is the evidence. The hubnode keeps it as an Up next item after the merge.

## Left
- The by-hand run above, after the release.
- `marketing/FEATURES.md` rows for `jig roles --from` and the R2 exception: the hubnode's.
