# Bug: a better-model hubnode at a low effort starts a role's session without raising its effort

Source: Daisy hubnode session / 2026-11-18 / the owner (Dave Seeman) (staged as feedback-Daisy-2026-11-18-hubnode-effort-clamp.md): "a fable hubnode on low couldn't start opus subnodes on high. any tier 1 model at any effort should read as higher than the next tier even at it's highest effort, and therefore be allowed to start them."

## Intent
A hubnode compares a role's model and effort with its own one setting at a time, and jig
works out that comparison, so a hubnode on a better tier at a lower effort starts the role
and then raises the effort itself. Sessions are ranked by tier first, then effort, as the owner
asked: a better tier at any effort ranks above a worse one. `tiers.json` names the tier-1 model
in use today.

## 1. Why
1. Why did the work sessions come up at `low`? The host's `start_session` takes an effort "at or below yours" and clamps a higher one. The hubnode was at `low`.
2. Why no holding prompt and raise? The hubnode read "above yours" as one joint comparison and saw a tier-2 role as below its tier-1 model.
3. Why could it read it that way? The skill gives one test for two settings the host clamps separately. Trunk's wording ("a role at or below yours") is vaguer than the text it read.

## 2. Givens
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

## 3. One layer up
- The model half works: a tier-1 hubnode starts tier-2 and tier-3 sessions with no raise. Only the effort half is clamped against a hubnode on a better tier, which is exactly where a joint "is this role above me?" answers no.
- A hubnode at `high` starts `medium` work with no raise; the Daisy hubnode did that the same morning. A hubnode at `low` meets this on every work, review, spec and bug start (all `medium` or above by default).
- The pattern that solves it is already there: the holding prompt, `set_session_effort`, the host's readout. It was skipped because its condition didn't fire.
- The `tiers.json` mismatch: with tier 1 as `claude-fable-5-1`, every session started for a tier-1 role (a repo's override, or the review subagent under one) gets a brief saying `running claude-fable-5-1`, replies `running claude-fable-5-2`, stops, is retried, and goes to the owner. And a hubnode on `claude-fable-5-2` can't find its own tier in `tiers.json`, so the comparison above has nothing to compare. Default roles flag nothing today, since none is tier 1.

## 4. Correction
A correction, in three places:
- jig works out the comparison. `jig roles --from <tier>,<effort>` (the hubnode's own numbers, mapped from `tiers.json`; jig can't see a session's model) prints, after each role's line, how to start it from those settings: with its settings, or then raise effort, or then raise model, or both, compared one setting at a time. It also prints, once, whether those settings are below the hubnode floor, ranked tier first, then effort, so `HUBNODE_FLOOR` is used where it is defined.
- The hubnode skill: step 6 maps its model to a tier with `tiers.json` (a model `tiers.json` doesn't name: say so, `tiers.json` is stale, and start nothing above tier 3's model until the owner answers) and runs `jig roles --from`; Assigning a step follows that output and says the two settings are compared apart, a better model never excuses a lower effort, and after a raise the brief goes out once the session's line names the role's model and the host's readout shows the role's effort.
- `tiers.json`: tier 1 is `claude-fable-5-2`.

What only the host can change: `start_session` clamps effort to the hubnode's whatever the model. jig can't make a tier-1 hubnode at `low` start a session at `high` in one call; it can make the hubnode start it and raise it without asking the owner. Whether the host asks the owner before a raise is the host's.

Issue 2 of the report (a raised session's stale self-read stopping it for good) is already fixed on trunk by `a3e9c67`, in `v0.13.0`: the brief asks for the model only, the effort is the host's readout, and a self-read the host contradicts is never a mismatch. On trunk's plugin the second stop would not have happened.

## Done when
- [ ] `jig roles --from 1,4` (smoke) prints `work: tier 2, effort 3` followed by "start, then raise effort", spec, review and bug likewise, and check (tier 3, effort 4) as "start with its settings"; nothing about the floor.
- [ ] `jig roles --from 2,4` prints the same raises and "below the hubnode floor (tier 2, effort 1)"; `--from 3,0` says below the floor; `--from 1,4` and `--from 2,1` don't.
- [ ] `jig roles --from 3,4` prints "then raise model and effort" for work; `--from 2,3` prints "start with its settings" for work and "then raise effort" for review.
- [ ] `jig roles --from x` and `--from 0,1` are refused with the usage line; `jig roles` with no flag prints exactly what it does today.
- [ ] `plugin/skills/hubnode/SKILL.md` names `jig roles --from` in step 6 and Assigning a step, says the two settings are compared apart, and says the brief after a raise waits for the session's model line and the host's effort readout; it no longer says "a role at or below yours".
- [ ] RULES.md says a setting ranks by tier first, then effort (a better tier at any effort ranks above a worse tier), and the hubnode row's "or better" follows it; it names no model and no host tool.
- [ ] `plugin/tiers.json` maps tier 1 to `claude-fable-5-2`.
- [ ] The report's symptom no longer happens: a hubnode on `claude-fable-5-2` at `low`, following the skill, starts a work session, raises it to `medium`, and briefs it only once the host's readout shows `medium`; the session is not stopped for its effort and does the work. (Run once by hand in a throwaway repo with the hubnode at `low`; the transcript is the evidence.)
- [ ] `marketing/FEATURES.md` has the row for `jig roles --from`.

## Out of scope
- The host's clamp itself: `start_session` takes an effort at or below the caller's. jig can't change it, and this spec promises no one-call start above the hubnode's effort.
- `jig gate`'s review-line warning keeps comparing tier and effort apart. The owner's words are about which sessions a hubnode may start; whether a review at a better tier and a lower effort meets a spec's review line is a different question, left for the owner to raise.
- A subagent at a clamped effort (review's subagent from a hubnode at `low`): there is no raise for one, and the clamp is [assumed]. The review skill already checks with the host's readout where there is one. A follow-up if it's confirmed.
- A plugin older than the repo's `.jig/`: the Daisy sessions appear to have run `v0.12.2`'s skills against a `.jig/` from after `v0.13.0`, and nothing in jig notices that direction (step 6 catches only `.jig/` older than the plugin). A separate cause, [assumed] here; worth its own bug if the owner confirms which plugin the Daisy session loaded.
- Matching models by family (any `claude-fable-*` is tier 1): see Alternatives.

## Touches
- `plugin/templates/jig/jig.py` (`cmd_roles`, the `roles` parser, `HUBNODE_FLOOR`'s comment)
- `plugin/templates/jig/RULES.md` (the hubnode row, the tier/effort paragraph, the command list)
- `plugin/skills/hubnode/SKILL.md` (step 6, Assigning a step)
- `plugin/tiers.json`
- `tests/smoke.sh` (the roles section)
- `marketing/FEATURES.md`

## Alternatives considered
- Skill text only, spelling out the two tests — rejected because `v0.12.2`'s text already said "a better model or a higher effort", and a tier-1 hubnode at `low` still read a tier-2 role as below it — this reason is [seen].
- Tell the owner to keep the hubnode at `high` or above — rejected because the owner chose the hubnode's effort for talking, and his rule is that a tier-1 hubnode at any effort may start tier-2 work — this reason is [seen].
- Start every session with the holding prompt — rejected because it costs a turn on every start, and most starts need no raise — this reason is [assumed].
- Rank sessions per setting (the floor and the starts both componentwise) — rejected because the owner said in words that a better tier at any effort reads as higher — this reason is [seen].
- Match tier models by family (`claude-fable-*`), so a point release never stales `tiers.json` — rejected because the brief's `running` line and its mismatch test compare exact model ids, and a family rule would need its own matching in every role skill — this reason is [assumed].
- Leave `tiers.json` for its own job — rejected because the ranking needs the hubnode to find its own tier there, and `claude-fable-5-2` isn't listed — this reason is [seen].

## Decisions
- Issues 1 and 2 stay in one spec but only issue 1 is built: issue 2 is already fixed on trunk (`a3e9c67`), so there is nothing to separate.
- The comparison is jig's (a flag on `jig roles`), not the skill's alone: the misreading happened on text that said it right.

## Roles
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
