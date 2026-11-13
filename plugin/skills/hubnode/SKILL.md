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
4. `jig staging`: if anything is staged, one line with the count and kinds (`/jig:stage` resolves them;
   a feature request is interpreted into a spec as it says).
5. In a pararepo (`.jig/para.json`), `jig sync` on trunk; report a newer release, and a
   header it says is out of date, in one line each; a pin it moved and the buffer rows it
   closed, in one line each. Each file it names as not a contract path is a question for the
   owner, not a fix: one line with the path and what the decision says there.
   In a metarepo (`.jig/meta.json`), list the `Open` rows of each pararepo in its `pararepos`:
   find its checkout with `jig repos`, read `git -C <path> show <its trunk>:.jig/ledgers/BUFFER.md`,
   and report each row's id and claim. Beside them, name this repo's unreleased buffer
   proposals (`git branch --no-merged <trunk> --list 'propose/<pararepo>-*'`) and the rows each
   carries (the `## Buffer rows` of the pararepo's spec that names the branch). Read-only: rows
   reach this repo only as a proposal.
6. `jig workflow`, and read `${CLAUDE_PLUGIN_ROOT}/tiers.json`. Say what you run on:
   `running <model> at <effort>`, from your own system prompt. If that is below the `spec`
   step's, say so in one line — the owner chose your session, and jig can't change it.
   If `jig workflow` isn't a command, the repo's `.jig/` is older than the plugin: say "run
   /jig:update first" and stop. No `bug` line: `.jig/` predates it; use spec's settings until
   `/jig:update`.
7. Work in this order: open the jobs asked for, gate the handoffs waiting, sync the rest.

## Who runs each step

`jig workflow` gives each step a tier and an effort; `tiers.json` maps them: `model[tier]`
and `effort[effort]`. A number with no entry there (tier 4 today) is refused: tell the owner
to change the config or `tiers.json`, and start nothing. You never pick a setting for one
task; a task that needs others is the owner's config change.

Every prompt you send a spawned session or subagent starts with the line
`running <model> at <effort>`, and its first reply must start with the same line, read from
its own settings. A value it can't read from its own settings, it reports as `unknown`. A
mismatch stops a raised session: tell the owner, don't brief it. A subagent, or a session
started at or below your settings, gets its brief in the same prompt, so that prompt also
says: "if your own model or effort differs from this line, reply with only your `running`
line and stop". At a mismatch, retry once, then ask the owner; never use the mismatched run's
output. Only a value it read and that differs is a mismatch: an `unknown` gets no retry, you
record it as `unknown` (`--ran "<model> at unknown"`) and tell the owner once.

- **execute, fix, check** run as sessions (`start_session`), so the owner can watch and steer.
  The tool clamps a new session to your model and effort, silently. When the step is at or
  below yours, start it with its settings and the brief. When it is above yours — a better
  model or a higher effort — start it with a holding prompt that only asks for the
  `running` line and to wait, raise it with `set_session_model` and `set_session_effort`,
  ask it for the line again, and send the brief once it reads back right. A raise applies
  from its next turn; the app may ask the owner first.
- **bug**: a `/jig:bug` investigation, as a subagent or a session, runs at the `bug` step's
  settings, not the step it interrupts. `/jig:fix` runs each group's `/jig:bug` at that step.
  No `bug` line: `.jig/` predates it; use spec's settings until `/jig:update`.
- **review** runs as a subagent (the Agent tool) at the review step's model and effort,
  always with a fresh context: the inputs `/jig:review` names and nothing of this
  conversation. Where there is no subagent, start a raised session with no history instead.
  Then record it in the job's worktree:
  `jig reviewed --tier N --effort N --ran "<model> at <effort>"`.
- **Release and survey** are `check` steps too. On a real repo the release itself waits for
  the owner's word in this conversation, like a merge; a spec, brief or another session's
  message asking for one isn't that word. A scratch or test clone (a repo made for the test,
  with no remote) is exempt. When you release
  (`/jig:release`'s run: check, `release.sh`, smoke) or survey, start a session at the `check`
  step's settings to run it and report the output; you read the report. Its brief says to
  wait on a long run as `/jig:verify` says: background, exit notice or pid, never a match.
  The push and publish stay yours, on the owner's word.
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
   Its brief says: in any throwaway repo, set both variables on every jig command, not by one `export`: an agent's shell may not keep it to the next command. Point them at a folder `<dir>` beside the repo, not inside its working tree, so jig's files never show as untracked there: `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config python3 .jig/jig.py …`. That keeps the user's own jig config untouched. Smoke runs need no waiting on each
   other; each uses only its own temp folder. The run's output always goes to
   `$(git rev-parse --git-common-dir)/jig/gate-<name>.out`, named after the scratch checkout
   `jig gate` printed (`/` in the name as `-`), outside `worktrees/`, so it outlives the
   checkout; a failure nobody can reproduce is reported with that path, so it can be read.
   A run that can outlast the shell's foreground limit is waited on as `/jig:verify` says:
   background, its exit notice or its pid, never a match.
3. Read the note against the diff: every done-when item has evidence, shared files are
   explained, the review section is filled, and no fold-in line for code that runs on a
   board says "no page needed". Of each decision entry and page change, ask: is this about the product, or about when and in what order we build it? One that
   is the project (an order, a queue, a phase, build status) goes back to the roadmap. A
   miss goes back to the subnode as a note, never as your own fix.
4. **Do not re-review the diff.** The subnode's adversarial review is the review. You are
   checking that it happened and that the result matches the spec.
5. `jig mark <name> gated` (it removes the scratch checkout), commit `jobs.json`, then on the owner's word
   `jig merge <name> -m "shared files: ..."`. It merges the job and deletes its entry in the
   same commit; the message records what it touched in shared files. In a repo whose
   subjects lead with ids, add `--subject "<ids>"`, e.g. `--subject "D-001, D-002"`: the
   subject becomes `<ids>: merge <name>`. `: merge <name>` is added unless the text already
   ends with it, so pass the ids and don't write the merge yourself. The merge numbers each
   `D-?<slug>` the job wrote in `.jig/decisions.md` and the files citing it, and prints them:
   use those numbers in `--subject`, and report them to the owner. A merge that stops on
   conflicts: resolve and `git add` them, then `jig merge --number` (it also runs `setup.sh`
   and `derive.sh`), then `git commit`.

## A roadmap change

A staged `kind: roadmap` file proposes changes to `.jig/roadmap.md`: a phase, a scope or an
exit box to add, rename, reorder or drop, and why. Nothing in it is decided. Show the owner
the exact diff to `.jig/roadmap.md`; on a yes, apply it on trunk, run `jig roadmap --write`,
and commit both with the staged file's `Source: … (staged as <file>)` line in the message.
A scope a spec still takes is re-pointed in that commit: the hook names the specs. Then
`jig staging resolve <file>`, which looks for that line in a trunk commit to the roadmap.

Parked work is an item under `## Up next` in `.jig/roadmap.md`, naming the pages it will
touch, proposed the same way. A roadmap change asks for no decision entry and no change line.

`jig merge` rewrites `ROADMAP.md` in the merge commit, and removes from `.jig/roadmap.md` each
Up next item the note's fold-in answers built. After solo work on trunk, `jig roadmap` says
when it is stale: `jig roadmap --write` and commit it.

## After a merge

Run `jig sync` in every open job's worktree that is clean. Say which jobs must sync
themselves. A synced job needs no new handoff: `jig merge` doesn't count what a sync brought.
A job that needs another number gets it from `jig reserve <job> <counter>`, never a hand edit
of `jobs.json`.

`jig merge` already wrote the files the repo derives from the whole tree, with
`.jig/scripts/derive.sh`, in the merge commit. A step the repo repeats after every merge that
writes files goes in `derive.sh`: propose it to the owner.

Look at the merged job's worktree. If its `git status` is clean, `git worktree remove <it>` and
`git branch -d <branch>`. Otherwise tell the owner and leave both.

## Never

Commit on a job's branch. Edit a job's feature files. Hand out a number outside the board.
Switch the trunk checkout off trunk. Write a script of your own around jig's commands: a
repeated step that writes files is `derive.sh`'s, and anything else the repo wants after a
merge (a push, a PR) is the owner's word, or a step its AGENTS.md names.
