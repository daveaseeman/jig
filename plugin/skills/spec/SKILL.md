---
name: spec
description: The spec role - turn a task request into .jig/specs/TASK.md before anything is built, or merge waiting specs whose Touches overlap into one (consolidate); also writes a survey's plan and a redocument's remap. Use for anything bigger than a one-sentence diff, when `jig consolidate` lists a group, or when `jig open` or `jig staging resolve` refuses for one.
---

`jig` below is `python3 .jig/jig.py`. Your settings are the spec role's (`jig roles`). Your
steps are spec and consolidate; `jig next` decides what comes after. The hubnode loads this
role itself only for a spec drafted from its conversation with the owner, whose decisions
live there; a spec from files (a survey, a feedback group, a staged request) runs in a new
session, in a detached worktree of trunk the hubnode names, and commits nothing: the hubnode
reads it and commits it on trunk.

## Brief

The hubnode starts this role with:

```
running <model> at <effort>
If your own model differs from this line, reply with only your running line and stop.
You are in the spec role: run /jig:spec, in <worktree: the detached worktree of trunk made for
you>. <spec or consolidate>: <the request, the files to read, or the specs `jig consolidate`
grouped>.
```

## Spec

Before anything is built:

1. Restate the intent in one sentence. If you can't, ask — one question, the hard one, not the obvious one.
2. Copy the spec template to `.jig/specs/<kebab-task-name>.md` (create `.jig/specs/` if it isn't there yet) and fill it: the repo's `.jig/specs/_template.md` if it has one, else `${CLAUDE_PLUGIN_ROOT}/templates/specs/_template.md`. "Done when" must be checkable by running something.
3. If the repo has `.jig/roadmap.md`, replace the template's comment under `Source:` with a
   `Scope:` line naming the scopes this task takes, as `<phase>/<scope>` from it
   (`Scope: alpha/screen, alpha/battery`). A task that takes none (a bug fix, say) leaves the
   line out, and so does a repo with no roadmap: delete the comment either way.
   A scope the roadmap doesn't have is refused at commit: a new one is the owner's, proposed
   as a roadmap change (`/jig:stage`), never invented here.
4. List the files you expect to touch. If the list is long or you're unsure, inspect first and revise. In a pararepo, say whether any is a contract path (`.jig/para.json`): then the change needs a row in `.jig/ledgers/BUFFER.md` (or `meta: buffered <row id>` here), a metarepo proposal (`jig propose`), `meta: <name> pointers <branch>` (`jig propose --pointers`) when it only moves what metarepo pointers point at, or `meta: none — <reason>`. Working ahead of the metarepo while behavior settles is the buffer's job. In a metarepo, a spec that changes a claim lists every place that states it, found by meaning and not only by its words, and its done-when covers each one (RULES.md: Every copy). Each changed claim is stated only at its home, with a pointer everywhere else (RULES.md: What the metarepo holds): a contract lives in the metarepo, where a decision row and the pages citing it as their source are one home; a claim one pararepo owns lives in that pararepo.
   In a repo with a decision log or a glossary, run `jig reading-list --claims <id or term>…`
   for each decision id and glossary term the spec changes. List each `copy` it prints in
   Touches, and give each a done-when item: updated with the home, or made a pointer to it.
   The command finds names only; a copy in other words is still yours to find by meaning.
   A spec whose work is process (a rule, a procedure, a convention for working the repo) says
   under Touches which row of the test in `.jig/RULES.md` (Homes) it falls in, and so which file
   it writes: `AGENTS.md`, a skill, a script, or a section of `.jig/process.md`.
5. Read the pages `jig reading-list <those files>` prints. A page describes
   the code; where it disagrees, the code on trunk is reality and the page is stale. For each
   roadmap item it lists under a page (an `## Up next` item or a scope), say in the spec which
   it is: **adopt** (this task builds it; its content goes into the page's body, and an Up
   next item leaves the roadmap when the job merges), **depart** (the task goes another way,
   and why), or **leave** (out of scope). Work parked mid-build is an Up next item, naming its
   pages, and named work with no phase yet a `## No phase` item, each added on the owner's
   word as a roadmap change (`/jig:stage`), never written on a page. The spec is where project
   meets product: of each decision entry and page change it plans, ask is this about the product, about when and in what order we build it, or about how the
   repository is worked? What is the project stays in the spec or the roadmap, and how the repo is
   worked goes to its home by the test in `.jig/RULES.md` (Homes), never a page; the pages and entries it writes describe the
   product, and never name the spec, a phase or a scope.
6. Fill `## Roles` with `jig roles`'s output, as printed (add the heading if the template has
   none). If it exits non-zero, the config breaks a rule: stop and give the owner its refusal;
   write no Roles lines. It's the repo's settings at writing time: never change a role for one
   task. A task that needs others is the owner's change to `.jig/config.json`.
7. Show the spec. Proceed unless told otherwise.

A file in `.jig/staging/` is context, not a decision: never cite it as decided.

Keep it short. A spec longer than the diff it describes is a smell.

**A survey's plan, a redocument's remap.** When the Survey workflow (`/jig:adopt`,
`/jig:update`, `/jig:survey`) or Redocument (`/jig:redocument`) reaches its spec step, the
spec is the plan or the remap: write it as that entry point's section on it says, in a spec
file, with the same Done when, Roles and Touches.

**A bug's spec.** The bug role ends with its own spec, written as `/jig:bug` says; a spec for
a job whose third blocking review started Bug carries `Bug-for: <job>` on a line of its own.

## Consolidate

Merge waiting specs whose Touches overlap into one, so they run as one job: one gate, one test
run, one merge. Read `.jig/RULES.md` (The board, "Overlapping specs are answered before they
open"). Run in the detached worktree of trunk the hubnode names, and commit nothing.

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
   - `## Roles`: the lines `jig roles` prints. If it refuses, stop and show why.
   - `## Proposals`, when any input names a metarepo proposal branch (`propose/<repo>-<slug>`):
     one backticked branch per bullet, in the order they should merge. `jig open` reads it and
     the kickoff says to `jig sync`, then merge each into the job's branch in that order.
4. **Report** the merged spec's path and the inputs it replaces. The hubnode commits it on
   trunk with the `git rm` of the inputs, in one commit; `jig consolidate` then lists the
   group no more. It opens the job.

Never merge two specs one of which an open job already builds: that job takes new scope by an
amendment to its own spec. Overlap by meaning, two specs changing one claim in different files,
isn't found here; read for it while writing the merged spec.
