---
name: spec
description: Turn a task request into .jig/specs/TASK.md before implementing. Use for anything bigger than a one-sentence diff.
---

Before writing code:

1. Restate the intent in one sentence. If you can't, ask — one question, the hard one, not the obvious one.
2. Copy the spec template to `.jig/specs/<kebab-task-name>.md` (create `.jig/specs/` if it isn't there yet) and fill it: the repo's `.jig/specs/_template.md` if it has one, else `${CLAUDE_PLUGIN_ROOT}/templates/specs/_template.md`. "Done when" must be checkable by running something.
3. List the files you expect to touch. If the list is long or you're unsure, inspect first and revise. In a pararepo, say whether any is a contract path (`.jig/para.json`): then the change needs a row in `.jig/ledgers/BUFFER.md` (or `meta: buffered <row id>` here), a metarepo proposal (`jig propose`), or `meta: none — <reason>`. Working ahead of the metarepo while behavior settles is the buffer's job. In a metarepo, a spec that changes a claim lists every place that states it, found by meaning and not only by its words, and its done-when covers each one (RULES.md: Every copy).
4. Fill `## Workflow` with `python3 .jig/jig.py workflow`'s output, as printed (add the
   heading if the template has none). If it exits non-zero, the config breaks a rule: stop
   and give the owner its refusal; write no Workflow lines. It's the repo's settings at writing time: never change a
   step for one task. A task that needs others is the owner's change to `.jig/config.json`.
5. Show the spec. Proceed unless told otherwise.

A file in `.jig/staging/` is context, not a decision: never cite it as decided.

Keep it short. A spec longer than the diff it describes is a smell.
