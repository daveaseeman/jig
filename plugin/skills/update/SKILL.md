---
name: update
description: Bring a repo already running jig to the current layout - move jig's files from old paths, rewrite the board, replace the tool files, reinstall the hooks. Shows the plan and asks before applying; never edits the repo's own files without a yes.
disable-model-invocation: true
---

Run the plugin's copy, not the repo's — the repo's is older and may have no `update`:

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" update
```

That is a dry run. It changes nothing, and its exit code says what you have:

- **0, "up to date".** Say so and stop.
- **0, a plan.** Show the plan: moves, files written from jig, board edits, git state. Ask.
  On a yes, run it again with `--apply`.
- **1, warnings.** Show each warning and what it means for the repo, and ask whether to go
  ahead. A warning is something `update` can leave as it is and still produce a working
  repo: a file at an old path, an unknown board key, a hook jig didn't write, code that names
  a moved path.
- **2, refused or blocked.** A refusal has a fix the user knows: merge or close the open
  lanes, remove the extra worktrees, or update the plugin. A block means the layout is one
  jig doesn't recognize. Say why the update would fail, then draft the change to jig that
  would recognize it — which `LAYOUT` row, board default or `STEPS` entry to add, with a
  done-when the plugin owner can test — written the way `/jig:feedback` writes its report,
  to the same temporary path. Apply nothing, and stop.

**Repo files to review** are the repo's own files an old convention left behind. Show each
one's proposed edit and ask about each; make it only on a yes. `--apply` never touches them.

## After `--apply`

`update` stages its changes, commits nothing, and runs `.jig/scripts/check.sh`. Then:

1. Fix the stale references in code with the user, in the same uncommitted change, until the
   check passes. Those are the repo's files: you edit them with the user; `jig.py` never does.
   Stale references in Markdown are worth fixing too — offer the list, don't sweep it unasked.
2. If `update` added `.jig/scripts/setup.sh`, fill it the way `/jig:init` does. Then name
   anything in the repo that already does its job by hand — a check script that borrows the
   main checkout's environment, `ln -s` steps in a skill — and offer to remove each once
   `setup.sh` covers it.
3. Commit on trunk. The hooks read trunk's `.jig/jig.py`. Coming from `jig/` or `.aidev/`,
   it exists only once this commit lands, so this one commit goes unchecked. Coming from the
   first `.jig/` layout (root `specs/` and `ledgers/`), trunk's old checker judges it and
   refuses the new `jig.py` under R7, because that copy checks jig's own file: if R7 on
   `.jig/jig.py` is its only refusal, commit this one with `--no-verify` and say why. The
   next commit is checked by the new copy.
