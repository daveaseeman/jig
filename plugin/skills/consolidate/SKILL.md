---
name: consolidate
description: Merge waiting specs whose Touches overlap into one spec, so they run as one job - one gate, one test run, one merge. Use when `jig consolidate` lists a group, when `jig open` or `jig staging resolve` refuses for one, or on "consolidate these specs".
---

Read `.jig/RULES.md` (The board, "Overlapping specs are answered before they open"). `jig` below
is `python3 .jig/jig.py`. Run on trunk, in the hubnode's checkout.

1. **List.** `jig consolidate`. Each group is specs no job has taken whose `## Touches` meet,
   with the paths they share. None listed: stop, each spec opens as its own job.
2. **Decide, per group, with the owner.** One job is the default: the specs change the same
   files, so separate jobs pay for the same gate, test run and merge more than once and collide
   on the way. Keep a pair apart only for a reason the owner gives (one must ship first, they
   need different reviewers): add `Kept separate from <other spec>: <reason>` to either spec.
   A group can split: merge some, keep others apart, one line per pair kept.
3. **Write the merged spec** at `.jig/specs/<name>.md`, from the template's headings:
   - Title and `## Intent`: one intent covering every input. Show it to the owner.
   - Every input's `Source:` lines, unchanged, at the top: they are how `jig staging resolve`
     finds the spec carrying a report, and the record of who asked.
   - `## Done when`: each input's items as a labelled group (`From <input>:`), wording kept.
     Drop an item only when another input's item states it; say which.
   - `## Out of scope`, `## Alternatives considered` and `## Decisions`: each input's entries,
     kept. Two that contradict are a question for the owner, not a pick.
   - `## Touches`: the union of the inputs', each path once.
   - `## Workflow`: the lines `jig workflow` prints. If it refuses, stop and show why.
   - `## Proposals`, when any input names a metarepo proposal branch (`propose/<repo>-<slug>`):
     one backticked branch per bullet, in the order they should merge. `jig open` reads it and
     the kickoff says to `jig sync`, then merge each into the job's branch in that order.
4. **Delete the inputs** (`git rm`) and add the merged spec in the same commit. Run
   `jig consolidate` again: the group is gone.
5. Open the job from the merged spec as the hubnode skill says.

Never merge two specs one of which an open job already builds: that job takes new scope by an
amendment to its own spec. Overlap by meaning, two specs changing one claim in different files,
isn't found here; read for it while writing the merged spec.
