---
name: rig
description: Show the repo's picture - what can start now, what waits on what, what waits on the owner, the roadmap's next step - then put one batch of decisions to the owner, and act on the answers. Run only when invoked by name as /jig:rig, /jig:rig fresh or /jig:rig auto, in the hubnode's session.
---

Read `.jig/RULES.md` first (Workflow: `jig rig`). `jig` below is `python3 .jig/jig.py`. You
are the hubnode, in the trunk checkout: rig's actions (a spec written, a job opened) are
yours, done the way `/jig:hubnode` does them.

`jig rig` computes the state, its order and its groups. You add only the judgments it can't
make, store them, and draw what it printed. Never reorder, regroup or reword its picture.

## 1. Judge what isn't judged

`/jig:rig fresh` starts with `jig rig --fresh`, which forgets every stored judgment. Then
`jig rig --json`. Each item has a `kind` (`spec`, `staged`, `next-step`), a `state`, what it
`waits_on`, its `group`, and `judged`: the judgment stored for it, or null when there is none
or its item or the board changed since.

For each staged file, and each next-step item whose `state` is `open`, whose `judged` is null
(a next-step item whose `state` is `taken` is already under way: it is listed under Waiting on,
and gets no judgment and no question):

- **A staged file:** read it whole. Call it `ready` when a spec can be written from it as it
  is, with no answer from the owner; `open` when it can't. An open file gets the questions the
  owner must answer, each with two to four options, one recommended, from what the file and
  the repo say. A ready file gets its recommendation: the spec it becomes, in one line.
- **The next step** (the open one): its question: take it now (a spec for it), or leave it where it is, with
  one recommended and why.

Store each: `jig rig --store-put <path>` with a JSON object on stdin,
`{"call": "ready"|"open", "about": "…", "context": "…", "questions": [{"ask": "…", "options": ["…"], "recommended": 0}], "recommend": "…"}`.
An item whose `judged` isn't null is replayed as stored: never judge it again in this run.
Then `jig rig --json` once more: ready staged files now sit in its groups.

## 2. The picture

Draw it from that last output, in this order, the same every run. Where the host can draw an
inline visual, it may; the sections and their contents stay these.

1. The count line: how many things wait on the owner's answers, and how many can start now.
2. **Can start now:** each `group`, its items in the order given, each with what it comes
   after, and each overlapping pair the group's `overlaps` names.
3. **Waiting on:** each item and what it waits for: a job, a spec or a staged file.
4. **Waiting on you:** the open staged files and the next step whose `state` is `open`.
5. **Running:** each open job with its step, who takes it, and whether it continues a session
   or starts one, as `jig rig` printed it from `jig next`.

## 3. The decisions

Load `/jig:decision-cards` and put every decision in one batch, drawn as it says. The blocks,
in this order:

1. Each open staged file's questions, from its stored judgment.
2. The next step whose `state` is `open`.
3. Each ready staged file: write its spec? The stored recommendation is the recommended option.
4. Each spec whose `opens` is `now`: start it as a job? A staged file is never opened as a
   job: block 3 writes its spec, and the next run offers that spec.
5. Each pair in a group's `overlaps`, whatever its items' `opens`, one of them perhaps a
   waiting spec outside the group: merge them into one spec (the spec role's consolidate), or
   keep one apart (`Kept separate from <spec>: <reason>`). Only an overlap gets this block.
   An item whose `opens` is `after` gets no other: it builds after another item in its group,
   and once that opens as a job, it waits on that job.
6. Each dependency cycle named under Waiting on: which item goes first?

Every block has "not now". It is an answer: the item stays as it is and comes back next run.
Nothing is ever dropped for it.

## 4. Act on the answers

- **An open file's answers:** append them to the staged file under `## Owner's answers`, dated,
  in the owner's words. The file changed, so the next run judges it again.
- **Write a spec:** resolve the staged file as `/jig:stage` says (a request or story is
  interpreted into a spec, with the spec role where the hubnode's rules say). Its `after:`
  header becomes a `` Build after `<spec>` `` line in that spec, naming the spec each file it
  waited for became, so the order survives the staging file.
- **A cycle's answer:** the item chosen to go first stops building after the ring member it
  names, so it has nothing left to wait for in the ring, however many items the ring holds. In
  a spec, remove that name from its own `Build after` line. In a staged file, the header is
  its own text: record the answer under `## Owner's answers`, and the spec written from it
  leaves that name out of its `Build after` line.
- **Start a job:** open it and start its subnode as `/jig:hubnode` says (Assigning a step).
- **The next step taken:** a spec for it, with the spec role. The roadmap itself is the
  owner's to edit: never change it here.

Then `jig rig --json` again. Opening a job changes the board, and a changed board voids every
stored judgment, so judge each item whose `judged` is null as in step 1 before drawing. Then
show the new picture, so the owner sees items move from open to ready to running.

## `/jig:rig auto`

The same run, without asking for what needs no answer: write a spec from every ready staged
file, then run `jig rig --json` again (judging what comes back null, as in step 1) and open and
start every spec whose `opens` is `now` in that output. An overlapping pair needs the owner's
answer, and an item that comes `after` another waits for that job, so neither starts. Answer
no open question, break no cycle and take no roadmap step: those are proposed, as blocks, for
the owner. End with the picture and a short list of what
you did.

## Never

Run on a phrase: only `/jig:rig` by name starts it. Change `jig next`, the roadmap or a staged
file's own text above `## Owner's answers`.
