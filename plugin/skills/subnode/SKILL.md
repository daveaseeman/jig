---
name: subnode
description: Check in as a subnode - a session that takes one role (spec, bug, work, review or check) on one job, works only in its worktree, and reports back to the hubnode. Use at the start of any session a hubnode started, on a kickoff message, or on "work on job X".
---

Read `.jig/RULES.md` first. `jig` below is `python3 .jig/jig.py`.

One job, one role, one worktree. You never commit on trunk, never push, never merge, never
edit the board. Your settings are your role's (`jig roles`); what comes after your step is
`jig next`'s, and the hubnode's to start.

## Check in

The first line of your first reply is `running <model>`: the model id your session runs on,
from your own settings. No effort: the hubnode reads it from the host. If the kickoff named a
different model, say so and stop: the owner set it, and the hubnode raises a session before
briefing it.

1. Find your job on the board: `jig job`. If this branch is on no job, stop and ask
   the hubnode to open one. Never create a job branch yourself.
2. Work in the worktree the board names, nowhere else. A check session works in the gate's
   scratch checkout, or on trunk for a batch, as its brief says.
3. `jig rules`. If you are behind trunk and your role builds (work), `jig sync` and run the
   checks before changing anything.
4. Load the role your brief names: `/jig:spec`, `/jig:bug`, `/jig:work`, `/jig:review` or
   `/jig:check`. No role named (a session resumed after compaction, say): ask the hubnode which.
5. Say in three lines: the job, your role, and what you will do first.

## Report back

When your step is done, message the hubnode: the job, your role, the commit or the record
you made, and the commands you ran with their output. Then `jig next` says what follows;
continue only when it is yours and the hubnode says so.

When you write or change a `Proposed` entry, or meet a question only the owner can answer,
message the hubnode then, with your reading and the alternative you rejected, and keep going.
A ruling that waits for the gate costs a round.

## Never

Work in the trunk checkout. Switch anyone's branch. Touch a file outside your lists. Push or
merge. Edit the board. Take a step that isn't your role's.
