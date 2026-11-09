---
name: spec
description: Turn a task request into .jig/specs/TASK.md before implementing. Use for anything bigger than a one-sentence diff.
---

Before writing code:

1. Restate the intent in one sentence. If you can't, ask — one question, the hard one, not the obvious one.
2. Copy the spec template to `.jig/specs/<kebab-task-name>.md` (create `.jig/specs/` if it isn't there yet) and fill it: the repo's `.jig/specs/_template.md` if it has one, else `${CLAUDE_PLUGIN_ROOT}/templates/specs/_template.md`. "Done when" must be checkable by running something.
3. If the repo has `.jig/roadmap.md`, replace the template's comment under `Source:` with a
   `Scope:` line naming the scopes this task takes, as `<phase>/<scope>` from it
   (`Scope: alpha/screen, alpha/battery`). A task that takes none (a bug fix, say) leaves the
   line out, and so does a repo with no roadmap: delete the comment either way.
   A scope the roadmap doesn't have is refused at commit: a new one is the owner's, proposed
   as a roadmap change (`/jig:stage`), never invented here.
4. List the files you expect to touch. If the list is long or you're unsure, inspect first and revise. In a pararepo, say whether any is a contract path (`.jig/para.json`): then the change needs a row in `.jig/ledgers/BUFFER.md` (or `meta: buffered <row id>` here), a metarepo proposal (`jig propose`), `meta: <name> pointers <branch>` (`jig propose --pointers`) when it only moves what metarepo pointers point at, or `meta: none — <reason>`. Working ahead of the metarepo while behavior settles is the buffer's job. In a metarepo, a spec that changes a claim lists every place that states it, found by meaning and not only by its words, and its done-when covers each one (RULES.md: Every copy). Each changed claim is stated only at its home, with a pointer everywhere else (RULES.md: What the metarepo holds): a contract lives in the metarepo, where a decision row and the pages citing it as their source are one home; a claim one pararepo owns lives in that pararepo.
5. Read the pages `python3 .jig/jig.py reading-list <those files>` prints. A page describes
   the code; where it disagrees, the code on trunk is reality and the page is stale. For each
   entry under a page's `## Undefined` that touches the task's files, say in the spec which
   it is: **adopt** (this task builds it; building it moves its content into the body and
   deletes the entry), **depart** (the task goes another way, and why), or **leave** (out of
   scope). Never add an Undefined entry unless the owner says to.
6. Fill `## Workflow` with `python3 .jig/jig.py workflow`'s output, as printed (add the
   heading if the template has none). If it exits non-zero, the config breaks a rule: stop
   and give the owner its refusal; write no Workflow lines. It's the repo's settings at writing time: never change a
   step for one task. A task that needs others is the owner's change to `.jig/config.json`.
7. Show the spec. Proceed unless told otherwise.

A file in `.jig/staging/` is context, not a decision: never cite it as decided.

Keep it short. A spec longer than the diff it describes is a smell.
