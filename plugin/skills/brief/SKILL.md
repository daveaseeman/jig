---
name: brief
description: Turn a task request into specs/TASK.md before implementing. Use for anything bigger than a one-sentence diff.
---

Before writing code:

1. Restate the intent in one sentence. If you can't, ask — one question, the hard one, not the obvious one.
2. Copy `specs/_template.md` to `specs/<kebab-task-name>.md` and fill it. "Done when" must be checkable by running something.
3. List the files you expect to touch. If the list is long or you're unsure, inspect first and revise.
4. Show the spec. Proceed unless told otherwise.

Keep it short. A spec longer than the diff it describes is a smell.
