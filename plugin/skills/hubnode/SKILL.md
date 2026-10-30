---
name: hubnode
description: Run the hubnode session for a repo with parallel lanes. Owns trunk, the board, worktrees, gates and merges. Use at the start of a hubnode session, or on "open a lane", "what's next", "gate X", "merge X".
---

Read `.jig/RULES.md` first. `jig` below is `python3 .jig/jig.py`.

You own trunk, the board, the worktrees, and the merges. You build no feature. Subnodes
message you at a handoff or when blocked.

## Every session

1. Confirm the trunk checkout is on trunk: `git status -sb`. If another session left a
   branch here, say which and stop — do not move their work.
2. `jig status`. Report as a numbered list: each lane, its state, distance from trunk,
   whether its worktree is dirty, whether a handoff waits.
3. `python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" update`, the dry run. Up to date:
   say nothing. A plan: one line, "the repo is behind the plugin's layout: run /jig:update".
   Refused or blocked: one line with its first reason.
4. `jig staging`: if anything is staged, one line with the count and kinds (`/jig:stage` resolves them).
5. In a pararepo (`.jig/para.json`), `jig para-sync`; report a newer release in one line.
6. Work in this order: open the lanes asked for, gate the handoffs waiting, sync the rest.

## Opening a lane

1. Read the brief. In a pararepo, refuse a lane whose spec cites a proposal `para-sync`
   reports as not released: it would build on a decision the metarepo hasn't made.
   Decide: name, branch, what it builds after, which existing files it
   `owns` (only this lane may touch) and which it `shares`, and whether it needs a reserved
   number.
2. `jig open <name> --brief "..." --owns <paths> --shares <paths> --after <lanes> --reserve schema`.
   It refuses an `owns` another open branch already touched — move those to `shares`.
3. Commit `jobs.json` on trunk. Give the printed kickoff to a subnode session, or paste it
   into a new one.

**Owns narrowly.** A file two live branches touch belongs in `shares` from the start.

## Gating a handoff

1. `jig mark <name> ready`, then `jig gate <name>`. It refuses on R8 and on a missing note.
2. Run the printed commands: the checks against the commit the note names, in a detached
   scratch checkout. Not the lane's worktree — the subnode may still be building there.
3. Read the note against the diff: every done-when item has evidence, shared files are
   explained, the review section is filled, and no fold-in line for code that runs on a
   board says "no page needed". A miss goes back to the subnode as a note, never
   as your own fix.
4. **Do not re-review the diff.** The subnode's adversarial review is the review. You are
   checking that it happened and that the result matches the spec.
5. `jig mark <name> gated`, commit `jobs.json`, then on the owner's word
   `jig merge <name> -m "shared files: ..."`. It merges the lane and deletes its entry in the
   same commit; the message records what it touched in shared files.

## After a merge

Run `jig sync` in every open lane's worktree that is clean. Say which lanes must sync
themselves.

## Never

Commit on a lane's branch. Edit a lane's feature files. Hand out a number outside the board.
Switch the trunk checkout off trunk.
