# Handoff: cheaper-rounds

Commit: d11522d84abb0705f88afbe2393f43ef1e920a4e
Date: 2026-11-13
Spec: .jig/specs/cheaper-rounds.md
Source: maige-ecosystem hubnode session / 2026-11-13 / Dave (staged as feedback-maige-ecosystem-2026-11-13-job-flow-speed.md): "why are these taking so long?"
Source: adventure-studio hubnode session / 2026-11-13 / Dave (staged as feedback-adventure-studio-2026-11-13-job-speed-local-checks.md): "`cp` part 1 was built, reviewed and gated three times."
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown (full review of 8754781; recheck of 8754781..915e427; resolution review of fdfd3e4; findings of each taken)

## Built
After a job's first full review, each later round costs what it changed:
- A `recheck` workflow step, at review's settings unless overridden. `jig reviewed --recheck` records it, refused without a full review of the job on HEAD's chain. The note carries `Recheck:` beside `Review:`, and `jig gate` warns when either falls short of the spec.
- `jig handoff` accepts a clean `jig sync` of a reviewed commit with no new review. A fix or a hand-resolved sync is refused, naming the files and `jig reviewed --recheck`. Working alone, a recheck leans only on a full review since the last handoff note.
- `changed_since` judges DEFERRED.md by its net change; only a line the job deletes, and trunk didn't, counts.
- The gate's pair refusal says to answer each pair in the note and commit it, syncing only when the merge needs a hand. The gate warns of each Proposed entry the job adds or changes.
- The commit hook refuses the job's own note when a pair line has no agrees / narrows: / conflicts: answer, naming the line.
- `jig merge` names each open job holding a later number of a counter the merged job used (on the conflict path too).
- Kickoff text, RULES.md (Fold-in, Handoff, Workflow, Commands), and the subnode, hubnode (rulings, recheck, and a recheck brief in ## Briefs) and review (## Recheck) skills.

## Done-when evidence
Smoke, `bash tests/smoke.sh cheaper_rounds workflow touches check_levels role_line consolidate` on fdfd3e4: 168 PASS, 0 FAIL. After the resolution review's text fixes, `bash tests/smoke.sh cheaper_rounds` on d11522d: 23 PASS, 0 FAIL. `.jig/scripts/check.sh`: rc 0. `claude plugin validate ./plugin`: Validation passed. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: nothing.
- [x] Pair refusal wording + answered-note-only gate passes: cheaper_rounds "a pair found at the gate says to answer it…" and "the answered note alone, no sync and no new review, passes the gate" (also checks one commit after the tip).
- [x] Clean sync hands off without `jig reviewed`; hand-resolved sync refused naming `reviewed --recheck`: two cheaper_rounds cases.
- [x] DEFERRED net: "edited and restored later … merges with no new handoff" and "a line the net change deletes still counts".
- [x] `jig workflow` recheck: default, review override, recheck override (three cases); sec_workflow step order updated.
- [x] `reviewed --recheck` refused without a full review; note carries Recheck; gate warns on recheck below spec's line; solo cases (note commit hands off, new task's recheck refused, same-commit recheck keeps the full review's line). The full-review warning is unchanged and still covered by sec_workflow.
- [x] Review skill ## Recheck: the delta against previous findings, stops for a full review, never reruns a check the builder's report shows.
- [x] Hook refuses an unanswered pair line naming it; a sync bringing in another's unanswered note is not refused.
- [x] Gate warns (rc 0) of a Proposed entry, naming it.
- [x] Subnode skill, kickoff (case "the kickoff jig open prints…") and hubnode skill (Rulings bullet).
- [x] `jig merge` later-number notice: case "jig merge names the open job holding a later number…". The conflict path prints it too; that path has no smoke case.
- [x] RULES.md § Workflow names recheck, the clean-sync allowance and the net DEFERRED rule.
- [ ] Full `bash tests/smoke.sh`: the check step's, at the gate. Not run here.

## Review
Three fresh Opus subagents (each read its effort as unknown), each given only its diff, the spec and AGENTS.md.
1. Full review of 8754781:
   - B1, solo recheck could lean on another task's review: fixed in job_chain, with smoke.
   - B2, § Workflow didn't name the clean sync or net DEFERRED: fixed.
   - S1, the hook refused a sync bringing in another note: fixed (own notes only), with smoke.
   - S2, the merge notice was lost on conflicts: fixed.
   - O1 (per-kind records, with smoke), O2 (`\b` match) and O3 (docstring): fixed.
   - O4, pre-upgrade log lines: deferred, with a DEFERRED.md row.
2. Recheck of 8754781..915e427: nothing blocking.
   - SF1, solo fix after a note needs a full review: RULES now says so. A handoff from the note commit itself works again, with smoke.
   - O-a and O-b (renames, merges ending a solo task): fixed with -M and --no-merges.
   - The B1 test was dependent on O1's setup: it now has its own.
   - S2's conflict path still has no smoke case: left.
3. Resolution review of fdfd3e4: both sides kept. Should-fix:
   - the recheck brief's delta for a sync is now the remerge-diff;
   - a recheck that needs widening stops for the review brief at review's settings;
   - the brief now runs /jig:review.
   The same wording went into the review skill, RULES and the handoff refusal text.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig.py is documented by the RULES.md template that ships beside it, updated here (Fold-in, Handoff, Workflow, Commands)

## Shared files changed
- `plugin/templates/jig/jig.py`: the spec's functions (workflow_steps, cmd_reviewed and new review_log/job_chain/last_review, cmd_handoff, changed_since and new deferred_deleted, review_shortfall, cmd_gate and new proposed_added, cmd_merge, check_rules' note check, cmd_open's kickoff).
- `plugin/templates/jig/RULES.md`: § Fold-in, § Handoff, gate, merge, § Workflow, § Commands.
- `plugin/skills/{hubnode,subnode,review}/SKILL.md`: as the spec lists. Hubnode's recheck brief is in checks-and-briefs' ## Briefs.
- `tests/smoke.sh`:
  - a new `sec_cheaper_rounds`, added to UNITS;
  - `sec_workflow`'s step-order case now includes recheck;
  - `sec_touches`: three commits (`TOOL: note lock`, `answer lock`, `reshape lock`) now commit with the hook off, each commented. They commit unanswered or reshaped pair lines on purpose to test the gate, and the new hook would refuse them at commit. They stand for a note the hook never checked. checks-and-briefs also edits smoke cases, so this is flagged.
- `.jig/ledgers/DEFERRED.md`: one row (O4). `.jig/specs/cheaper-rounds.md`: two Interpreted lines the hubnode accepted.

## Test by hand
Nothing to click. In a job: review, let trunk move, `jig sync`, then `jig handoff` with no new review. Then fix a file, see `jig handoff` refuse naming `--recheck`, record `jig reviewed --recheck --tier N --effort N`, and hand off.

## Left
Nothing on the spec. Not run here: the full suite (the gate's), and `report_fixes` and `merge_after_sync`, which exercise changed_since and the merge but weren't sections I touched. marketing/FEATURES.md rows are the hubnode's (gitignored).
