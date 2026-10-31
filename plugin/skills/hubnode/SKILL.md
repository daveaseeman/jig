---
name: hubnode
description: Run the hubnode session for a repo with parallel jobs. Owns trunk, the board, worktrees, gates and merges. Use at the start of a hubnode session, or on "open a job", "what's next", "gate X", "merge X".
---

Read `.jig/RULES.md` first. `jig` below is `python3 .jig/jig.py`.

You own trunk, the board, the worktrees, and the merges. You write specs, talk with the owner,
read reviews and decide. You build no feature and run no suite: execution, fixes, reviews
and gate checks go to sessions you start, so you stay free to talk. Subnodes message you at a
handoff or when blocked.

## Every session

1. Confirm the trunk checkout is on trunk: `git status -sb`. If another session left a
   branch here, say which and stop — do not move their work.
2. `jig status`. Report as a numbered list: each job, its state, distance from trunk,
   whether its worktree is dirty, whether a handoff waits.
3. `python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" update`, the dry run. Up to date:
   say nothing. A plan: one line, "the repo is behind the plugin's layout: run /jig:update".
   Refused or blocked: one line with its first reason.
4. `jig staging`: if anything is staged, one line with the count and kinds (`/jig:stage` resolves them).
5. In a pararepo (`.jig/para.json`), `jig sync` on trunk; report a newer release, and a
   header it says is out of date, in one line each.
6. `jig workflow`, and read `${CLAUDE_PLUGIN_ROOT}/tiers.json`. Say what you run on:
   `running <model> at <effort>`, from your own system prompt. If that is below the `spec`
   step's, say so in one line — the owner chose your session, and jig can't change it.
7. Work in this order: open the jobs asked for, gate the handoffs waiting, sync the rest.

## Who runs each step

`jig workflow` gives each step a tier and an effort; `tiers.json` maps them: `model[tier]`
and `effort[effort]`. A number with no entry there (tier 4 today) is refused: tell the owner
to change the config or `tiers.json`, and start nothing. You never pick a setting for one
task; a task that needs others is the owner's config change.

Every prompt you send a spawned session or subagent starts with the line
`running <model> at <effort>`, and its first reply must start with the same line, read from
its own settings. A mismatch stops it: tell the owner, don't brief it.

- **execute, fix, check** run as sessions (`start_session`), so the owner can watch and steer.
  The tool clamps a new session to your model and effort, silently. When the step is at or
  below yours, start it with its settings and the brief. When it is above yours — a better
  model or a higher effort — start it with a holding prompt that only asks for the
  `running` line and to wait, raise it with `set_session_model` and `set_session_effort`,
  ask it for the line again, and send the brief once it reads back right. A raise applies
  from its next turn; the app may ask the owner first.
- **review** runs as a subagent (the Agent tool) at the review step's model and effort,
  always with a fresh context: the inputs `/jig:review` names and nothing of this
  conversation. Where there is no subagent, start a raised session with no history instead.
  Then record it in the job's worktree:
  `jig reviewed --tier N --effort N --ran "<model> at <effort>"`.
- **Release and survey** are `check` steps too. When you release (`/jig:release`'s run:
  check, `release.sh`, smoke) or survey, start a session at the `check` step's settings to
  run it and report the output; you read the report. The push and publish stay yours, on the
  owner's word.
- **Decide.** Read the review. Blocking findings go back to the session that executed, as
  a fix, at execute's settings — a new one only when that session is gone. Count the
  rounds. After a third fix that leaves a blocking finding, don't start a fourth: run
  `/jig:bug` on why the fixes aren't converging.

## Opening a job

1. Read the spec. In a pararepo, refuse a job whose spec cites a proposal `jig sync`'s
   report calls not released: it would build on a decision the metarepo hasn't made. This
   is the early warning; `jig gate` refuses it for good.
   Decide: name, branch, what it builds after, which existing files it
   `owns` (only this job may touch) and which it `shares`, and whether it needs a reserved
   number.
2. `jig open <name> --spec .jig/specs/<task>.md --owns <paths> --shares <paths> --after <jobs> --reserve schema`.
   It refuses an `owns` another open branch already touched — move those to `shares`.
3. Commit `jobs.json` on trunk. Give the printed kickoff to a subnode session, or paste it
   into a new one.

**Owns narrowly.** A file two live branches touch belongs in `shares` from the start.

## Gating a handoff

1. `jig mark <name> ready`, then `jig gate <name>`. It refuses on R8 and on a missing note,
   and in a pararepo on a spec citing a proposal that isn't in the pinned release.
2. `jig gate` sets up a detached scratch checkout of the commit the note names, with trunk
   merged in as `jig sync` would, and prints the check to run there. Don't run it in this
   session: start a session at the `check` step's settings to run it in the scratch checkout.
   Not the job's worktree — the subnode may still be building there. It reports the exit
   code and output; you read it. `jig gate` warns when the review ran weaker than the spec's
   Workflow section: say so to the owner before the merge.
3. Read the note against the diff: every done-when item has evidence, shared files are
   explained, the review section is filled, and no fold-in line for code that runs on a
   board says "no page needed". A miss goes back to the subnode as a note, never
   as your own fix.
4. **Do not re-review the diff.** The subnode's adversarial review is the review. You are
   checking that it happened and that the result matches the spec.
5. `jig mark <name> gated`, commit `jobs.json`, then on the owner's word
   `jig merge <name> -m "shared files: ..."`. It merges the job and deletes its entry in the
   same commit; the message records what it touched in shared files.

## After a merge

Run `jig sync` in every open job's worktree that is clean. Say which jobs must sync
themselves. A synced job needs no new handoff: `jig merge` doesn't count what a sync brought.
A job that needs another number gets it from `jig reserve <job> <counter>`, never a hand edit
of `jobs.json`.

## Never

Commit on a job's branch. Edit a job's feature files. Hand out a number outside the board.
Switch the trunk checkout off trunk.
