# Bug: a hubnode's effort clamp, and R2 on a metarepo's proposal branch

Source: Daisy hubnode session / 2026-11-18 / the owner (Dave Seeman) (staged as feedback-Daisy-2026-11-18-hubnode-effort-clamp.md): "a fable hubnode on low couldn't start opus subnodes on high. any tier 1 model at any effort should read as higher than the next tier even at it's highest effort, and therefore be allowed to start them."
Source: Maige-OS hubnode session, 2026-11-18, on Dave's word ("The jig gap: file the feedback note.") (staged as r2-refuses-propose-branch.md): "R2 branch propose/Maige-OS-buffer-b5-b7 is on no job. Ask the hubnode to open one, or work on main", refused by the metarepo's `jig check` and pre-commit hook on the branch `jig propose` made, while the metarepo had a job open.

## Intent
Two refusals that the rules didn't intend, fixed together. A hubnode compares a role's model
and effort with its own one setting at a time, and jig works out that comparison, so a hubnode
on a better tier at a lower effort starts the role and then raises the effort itself. Sessions
rank by tier first, then effort, and `tiers.json` names the tier-1 model in use today. And in
a metarepo, a commit on a `propose/` branch passes R2 while jobs are open, as it does when none
are: it is the one branch RULES.md sends a pararepo to, and it is on no job by design.

## Investigation

### From bug-hubnode-effort-clamp

**Why**
1. Why did the work sessions come up at `low`? The host's `start_session` takes an effort "at or below yours" and clamps a higher one. The hubnode was at `low`.
2. Why no holding prompt and raise? The hubnode read "above yours" as one joint comparison and saw a tier-2 role as below its tier-1 model.
3. Why could it read it that way? The skill gives one test for two settings the host clamps separately. Trunk's wording ("a role at or below yours") is vaguer than the text it read.

**Givens**
- [seen] The report's quotes of the skill ("When it is above yours — a better model or a higher effort — …", "if your own model or effort differs …", "Only a value it read and that differs is a mismatch") are `v0.12.2`'s `plugin/skills/hubnode/SKILL.md` and role briefs, word for word. They are not in `v0.13.0` or later.
- [seen] The report's `jig_version` `f0005adc5fe4` is the blob of `plugin/templates/jig/jig.py` at `51b139d` (2026-11-16), which already holds `a3e9c67`. So the repo's `.jig/` was newer than the skill text the Daisy sessions quoted.
- [seen] Trunk, `plugin/skills/hubnode/SKILL.md`, Assigning a step: "The tool clamps a new session to your model and effort, silently. A role at or below yours starts with its settings and the brief. One above yours starts with a holding prompt …". One test for both settings, and no longer the "a better model or a higher effort" gloss.
- [seen] Trunk already settles issue 2 (since `a3e9c67`, in `v0.13.0`): briefs say "If your own model differs"; a session's first line is `running <model>` with no effort; "You check the effort with the host's readout"; "A self-read the host contradicts is never a mismatch". The raise paragraph still says "send the brief once it reads back right", which doesn't say which source reads back the effort.
- [seen] The host's `start_session` schema (from the report): `effort` "at or below yours", `model` "same family or cheaper than yours; anything higher is ignored". The raise (`set_session_effort`) worked: the host's record showed `medium`.
- [seen] `plugin/tiers.json`: tier 1 `claude-fable-5-1`. This environment lists `claude-fable-5-2` as the current Fable model, and the Daisy hubnode ran `claude-fable-5-2` (report).
- [seen] `jig roles` defaults: no role is tier 1. `RULES.md`'s own override example is `"review": {"tier": 1, "effort": 0, …}`.
- [seen] `HUBNODE_FLOOR = {"tier": 2, "effort": 1}` in `jig.py` is used nowhere in code; the floor lives in the hubnode skill's step 6 ("If that is below tier 2, effort 1, say so") and RULES.md's hubnode row ("tier 2, effort 1 or better"). Neither says how a better tier at a lower effort ranks.
- [seen] `jig gate`'s review-line warning compares tier and effort apart (`got tier > asked tier or got effort > asked effort`).
- [assumed] The Daisy sessions ran plugin `v0.12.2` (the quotes match it, and the two work sessions replied with an effort in their line, as `v0.12.2`'s briefs asked). Not confirmed: which plugin copy that app session loaded isn't visible from here. This session loads `0.14.0`.
- [assumed] A subagent's effort is clamped the same way. Not confirmed (the report says so too), and there is no raise for a subagent.

**One layer up**
- The model half works: a tier-1 hubnode starts tier-2 and tier-3 sessions with no raise. Only the effort half is clamped against a hubnode on a better tier, which is exactly where a joint "is this role above me?" answers no.
- A hubnode at `high` starts `medium` work with no raise; the Daisy hubnode did that the same morning. A hubnode at `low` meets this on every work, review, spec and bug start (all `medium` or above by default).
- The pattern that solves it is already there: the holding prompt, `set_session_effort`, the host's readout. It was skipped because its condition didn't fire.
- The `tiers.json` mismatch: with tier 1 as `claude-fable-5-1`, every session started for a tier-1 role (a repo's override, or the review subagent under one) gets a brief saying `running claude-fable-5-1`, replies `running claude-fable-5-2`, stops, is retried, and goes to the owner. And a hubnode on `claude-fable-5-2` can't find its own tier in `tiers.json`, so the comparison above has nothing to compare. Default roles flag nothing today, since none is tier 1.

**Correction**
A correction, in three places:
- jig works out the comparison. `jig roles --from <tier>,<effort>` (the hubnode's own numbers, mapped from `tiers.json`; jig can't see a session's model) prints, after each role's line, how to start it from those settings: with its settings, or then raise effort, or then raise model, or both, compared one setting at a time. It also prints, once, whether those settings are below the hubnode floor, ranked tier first, then effort, so `HUBNODE_FLOOR` is used where it is defined.
- The hubnode skill: step 6 maps its model to a tier with `tiers.json` (a model `tiers.json` doesn't name: say so, `tiers.json` is stale, and start nothing above tier 3's model until the owner answers) and runs `jig roles --from`; Assigning a step follows that output and says the two settings are compared apart, a better model never excuses a lower effort, and after a raise the brief goes out once the session's line names the role's model and the host's readout shows the role's effort.
- `tiers.json`: tier 1 is `claude-fable-5-2`.

What only the host can change: `start_session` clamps effort to the hubnode's whatever the model. jig can't make a tier-1 hubnode at `low` start a session at `high` in one call; it can make the hubnode start it and raise it without asking the owner. Whether the host asks the owner before a raise is the host's.

Issue 2 of the report (a raised session's stale self-read stopping it for good) is already fixed on trunk by `a3e9c67`, in `v0.13.0`: the brief asks for the model only, the effort is the host's readout, and a self-read the host contradicts is never a mismatch. On trunk's plugin the second stop would not have happened.

### From bug-r2-propose-branch

**Why**
- Why was the proposal's commit refused? `cmd_check` refuses any branch other than trunk that is on no job while the board has an open job (jig.py 617–621).
- Why is the proposal's branch on no job? `jig propose` makes it in the metarepo without touching the metarepo's board or checkout: RULES says "A pararepo writes the metarepo only by branch, via `jig propose`".
- Root: R2's no-job clause (from 2026-10-30) predates proposals (2026-11-02) and was never told about them. No other branch jig makes is on no job.

**Givens**
- `[seen]` Report header: `kind: feedback`, but `destination:` names a spec, and `jig_version` gives release numbers (0.14.0 metarepo, 0.13.0 pararepo), not a hash. Judged on content; the clause is unchanged on trunk (`a9ce86b`).
- `[seen]` Reproduced with trunk's `plugin/templates/jig/jig.py`, in a throwaway metarepo `docs` (`init --meta`, released v0.1.0) and pararepo `pr` (`init --para docs`). `jig propose .jig/specs/x.md fmt` made `propose/pr-fmt`. In `git -C <meta> worktree add <dir> propose/pr-fmt`, with `docs/fmt.md` staged:
  - no job open: `jig check` prints `ok`;
  - after `jig open other-job --owns docs/other.md` on the metarepo's trunk: `jig check` exits 1 with `R2 branch propose/pr-fmt is on no job. Ask the hubnode to open one, or work on main`, and `git commit` is refused by the hook with the same line.
- `[seen]` The refusal's advice can't be followed from the pararepo's side: "work on main" breaks rule 1, and opening a job is the metarepo's hubnode's step.
- `[seen]` Stopgap that works today: the metarepo's hubnode adopts the branch, `jig open <job> --branch propose/pr-fmt --worktree <dir> --owns docs/fmt.md`; then `jig check` there prints `ok`. Without `--worktree` it refuses: "branch propose/pr-fmt is checked out somewhere already".
- `[seen]` Nothing else in jig.py makes a branch: `git branch` appears only in `open_proposal`, and worktree adds only in `cmd_open`.
- `[seen]` `.jig/meta.json`'s `pararepos` is `[]` after `init --meta`, and `init --para` doesn't add to it.
- `[seen]` RULES.md never states the no-job clause: R2 reads "A job is built in its own worktree", and "Working alone?" says R1–R5 go quiet with no jobs open.
- `[seen]` RULES.md, Overlapping specs: a metarepo takes proposals into a job through a consolidated spec's `## Proposals`, merged into the job's branch; the smoke's `sbland` merges one straight into trunk with no job open.
- `[assumed]` A proposal merged into a job's branch is judged there by that job's R3 (the merge's paths against trunk), so skipping R2 on the proposal branch doesn't skip ownership. Not tested; the fix doesn't depend on it, but it is why skipping R2 here is safe.

**One layer up**
- Sibling: R1 also refuses with jobs open, but only for the trunk checkout itself, and `jig propose` says to use a worktree, so it doesn't fire here and stays as is.
- No other non-job branch exists to compare: `propose/` is the only one jig makes. The pattern already in use is the name form: `proposal_branches()` reads `propose/…`, and the hubnode lists `git branch --list 'propose/<pararepo>-*'`.

**Workaround or correction**
Correction: R2's no-job clause learns the branch RULES already designates. A workaround (always adopting) would put a hubnode step in front of every proposal and fold proposals into jobs before the `## Proposals` merge that's meant to take them in.

## Done when
From bug-hubnode-effort-clamp:
- [ ] `jig roles --from 1,4` (smoke) prints `work: tier 2, effort 3` followed by "start, then raise effort", spec, review and bug likewise, and check (tier 3, effort 4) as "start with its settings"; nothing about the floor.
- [ ] `jig roles --from 2,4` prints the same raises and "below the hubnode floor (tier 2, effort 1)"; `--from 3,0` says below the floor; `--from 1,4` and `--from 2,1` don't.
- [ ] `jig roles --from 3,4` prints "then raise model and effort" for work; `--from 2,3` prints "start with its settings" for work and "then raise effort" for review.
- [ ] `jig roles --from x` and `--from 0,1` are refused with the usage line; `jig roles` with no flag prints exactly what it does today.
- [ ] `plugin/skills/hubnode/SKILL.md` names `jig roles --from` in step 6 and Assigning a step, says the two settings are compared apart, and says the brief after a raise waits for the session's model line and the host's effort readout; it no longer says "a role at or below yours".
- [ ] RULES.md says a setting ranks by tier first, then effort (a better tier at any effort ranks above a worse tier), and the hubnode row's "or better" follows it; it names no model and no host tool.
- [ ] `plugin/tiers.json` maps tier 1 to `claude-fable-5-2`.
- [ ] The report's symptom no longer happens: a hubnode on `claude-fable-5-2` at `low`, following the skill, starts a work session, raises it to `medium`, and briefs it only once the host's readout shows `medium`; the session is not stopped for its effort and does the work. (Run once by hand in a throwaway repo with the hubnode at `low`; the transcript is the evidence.)
- [ ] `marketing/FEATURES.md` has the row for `jig roles --from`.

From bug-r2-propose-branch:
- [ ] Smoke, symptom gone (`sec_pararepo`, after the `propose` case): with a job open in the metarepo, a worktree of `propose/pr-fmt` with a file staged passes `jig check` (`ok`) and `git commit`; the output has no `R2`.
- [ ] Smoke, fix fires only where it should: with the same job open, the hook still refuses with `R2 … is on no job`
  - on a plain branch in the metarepo (`git worktree add -b scratch`);
  - on a `propose/x` branch in a repo that isn't a metarepo.
- [ ] Smoke: the metarepo's trunk checkout switched to `propose/pr-fmt`, with a job open, is still refused with `R1`.
- [ ] RULES.md states the clause: off trunk, a branch on no job is refused while jobs are open, except a `propose/` branch in a metarepo.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.
- [ ] `grep -rnE 'Maige|maige|Daisy|daisy' plugin tests` finds nothing new.

## Out of scope
From bug-hubnode-effort-clamp:
- The host's clamp itself: `start_session` takes an effort at or below the caller's. jig can't change it, and this spec promises no one-call start above the hubnode's effort.
- `jig gate`'s review-line warning keeps comparing tier and effort apart. The owner's words are about which sessions a hubnode may start; whether a review at a better tier and a lower effort meets a spec's review line is a different question, left for the owner to raise.
- A subagent at a clamped effort (review's subagent from a hubnode at `low`): there is no raise for one, and the clamp is [assumed]. The review skill already checks with the host's readout where there is one. A follow-up if it's confirmed.
- A plugin older than the repo's `.jig/`: the Daisy sessions appear to have run `v0.12.2`'s skills against a `.jig/` from after `v0.13.0`, and nothing in jig notices that direction (step 6 catches only `.jig/` older than the plugin). A separate cause, [assumed] here; worth its own bug if the owner confirms which plugin the Daisy session loaded.
- Matching models by family (any `claude-fable-*` is tier 1): see Alternatives.

From bug-r2-propose-branch:
- R3/R4 for a proposal: ownership is judged where the metarepo takes the proposal in (a job's merge, or the trunk merge with no job open), not on the proposal branch.
- Registering pararepos in `meta.json`. It's only needed for the tighter alternative.
- Maige-OS's staged proposal: it commits once this lands, or on the owner's word sooner by the adopt stopgap above.

## Touches
- `plugin/templates/jig/jig.py`: `cmd_roles`, the `roles` parser and `HUBNODE_FLOOR`'s comment (effort clamp); `cmd_check`'s R2 no-job clause (617–621), skipping it for a propose/ branch when the repo is a metarepo (`load_meta(trunk)` is already read above it) (R2).
- `plugin/templates/jig/RULES.md`: the hubnode row, the tier/effort paragraph and the command list (effort clamp); R2's line in The rules (the no-job clause and its propose/ exception), and a clause in Metarepo and pararepos rule 1 (R2).
- `plugin/skills/hubnode/SKILL.md` (step 6, Assigning a step)
- `plugin/tiers.json`
- `tests/smoke.sh`: the roles cases in `sec_workflow` (effort clamp); `sec_pararepo` (R2).
- `marketing/FEATURES.md` (main checkout only): the row for `jig roles --from` (effort clamp); the R2 row (R2).

The two parts share four files and no section of any: in jig.py they change different
functions (`cmd_roles` and its parser; `cmd_check`'s no-job branch), in RULES.md different
sections (The rules' R2 line and Metarepo and pararepos rule 1; the Workflow roles table, the
settings paragraph and Commands), in the smoke different sections (`sec_workflow`;
`sec_pararepo`), and in FEATURES.md different rows. Neither changes a claim the other states.

## Alternatives considered
From bug-hubnode-effort-clamp:
- Skill text only, spelling out the two tests — rejected because `v0.12.2`'s text already said "a better model or a higher effort", and a tier-1 hubnode at `low` still read a tier-2 role as below it — this reason is [seen].
- Tell the owner to keep the hubnode at `high` or above — rejected because the owner chose the hubnode's effort for talking, and his rule is that a tier-1 hubnode at any effort may start tier-2 work — this reason is [seen].
- Start every session with the holding prompt — rejected because it costs a turn on every start, and most starts need no raise — this reason is [assumed].
- Rank sessions per setting (the floor and the starts both componentwise) — rejected because the owner said in words that a better tier at any effort reads as higher — this reason is [seen].
- Match tier models by family (`claude-fable-*`), so a point release never stales `tiers.json` — rejected because the brief's `running` line and its mismatch test compare exact model ids, and a family rule would need its own matching in every role skill — this reason is [assumed].
- Leave `tiers.json` for its own job — rejected because the ranking needs the hubnode to find its own tier there, and `claude-fable-5-2` isn't listed — this reason is [seen].

From bug-r2-propose-branch:
- `jig propose` records the branch on the metarepo's board — rejected because the board changes on trunk only (R5), and propose leaves the metarepo's trunk untouched by design ("main is untouched", in code and in smoke) — this reason is [seen].
- Exempt only `propose/<p>-*` for a registered pararepo `<p>` (option b) — rejected as the default because `pararepos` is empty after `init --meta`/`--para`, so every metarepo would first need its pararepos registered, and today nothing does that — this reason is [seen].
- Adopt every proposal as a metarepo job (option c) — rejected because it puts a hubnode step in front of each proposal, and RULES takes proposals into a job by `## Proposals` merge, not as jobs of their own; the pararepo still can't write until that happens, and the refusal would have to name it — this reason is [seen].
- Exempt any `propose/` branch in any repo — rejected because only a metarepo receives proposals; elsewhere the name would only be a way past R2 — this reason is [seen].

## Decisions
From bug-hubnode-effort-clamp:
- Issues 1 and 2 stay in one spec but only issue 1 is built: issue 2 is already fixed on trunk (`a3e9c67`), so there is nothing to separate.
- The comparison is jig's (a flag on `jig roles`), not the skill's alone: the misreading happened on text that said it right.

From bug-r2-propose-branch:
- The owner, 2026-11-18, on how R2 recognises a proposal branch: "Accept both" (option a: in a metarepo, a branch starting `propose/` passes R2's no-job clause). As recommended with it: a metarepo is one with `.jig/meta.json` on trunk; every other check that runs on a non-job branch still runs; R1 still refuses the trunk checkout on it; a `propose/` branch in a repo that isn't a metarepo is refused as today.

The group:
- The owner, 2026-11-18, on the group: "Accept both" (one job).

## Roles
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
