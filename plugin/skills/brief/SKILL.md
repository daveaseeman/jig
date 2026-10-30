---
name: brief
description: Turn a task request into .jig/specs/TASK.md before implementing. Use for anything bigger than a one-sentence diff.
---

Before writing code:

1. Restate the intent in one sentence. If you can't, ask — one question, the hard one, not the obvious one.
2. Copy the spec template to `.jig/specs/<kebab-task-name>.md` (create `.jig/specs/` if it isn't there yet) and fill it: the repo's `.jig/specs/_template.md` if it has one, else `${CLAUDE_PLUGIN_ROOT}/templates/specs/_template.md`. "Done when" must be checkable by running something.
3. List the files you expect to touch. If the list is long or you're unsure, inspect first and revise. In a pararepo, say whether any is a contract path (`.jig/para.json`): then the spec needs a metarepo proposal (`jig para-propose`) or `meta: none — <reason>`.
4. Show the spec. Proceed unless told otherwise.

A file in `.jig/staging/` is context, not a decision: never cite it as decided.

Keep it short. A spec longer than the diff it describes is a smell.
