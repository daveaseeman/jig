---
name: init
description: Set up the jig system in the current repo. Copies the project-side files (AGENTS.md, scripts, specs, docs, the two ledgers, optional docs/HARDWARE.md) and fills what can be inferred.
disable-model-invocation: true
---

## Before copying anything

`init` is for a repo with nothing to reconcile. Stop and recommend `/jig:adopt` instead
when the repo already has a shape of its own — any of:

- an `AGENTS.md` or `CLAUDE.md` with real content
- any way of coordinating parallel work already: `CODEOWNERS`, a PR template, husky or pre-commit hooks, hooks in `.git/hooks`, worktrees, or a homebrew board
- more than a handful of markdown files outside `README.md`

Run `python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" survey` to see which apply; it
installs nothing. If any do, name the conflicts you'd expect (a rule that contradicts the
template, a docs layout that differs, a second set of hooks) and stop. Adopt is user-invoked,
so say that they run it, and offer to copy the files anyway if they'd rather.

## Copy

Templates live in `${CLAUDE_PLUGIN_ROOT}/templates/`. Copy into the repo root, **never overwriting** a file that already exists:

```
AGENTS.md  CLAUDE.md  ledgers/  docs/README.md  specs/_template.md
scripts/check.sh  scripts/format.sh  .jig/jig.py  .jig/RULES.md
```

Then run `python3 .jig/jig.py init` — it writes the board, adds `.jig/worktrees/` to
`.gitignore`, and installs the git hooks that enforce the rules. Those hooks are the real
enforcement and work with or without any AI tool.

Then:

1. **Firmware?** If the repo has `sdkconfig`, `platformio.ini`, `idf_component.yml`, `west.yml`, `*.ino`, or a `main/` with C, also copy `docs/HARDWARE.md` and `templates/skill-template/` → `.claude/skills/_skill-template/`. Otherwise delete the "Firmware" section from `AGENTS.md`. If unsure, ask one question.
2. `chmod +x scripts/*.sh`.
3. **Fill what the code tells you.** In `AGENTS.md` Commands and `scripts/check.sh`: detect the build system (`package.json`, `Cargo.toml`, `pyproject.toml`, `CMakeLists.txt`, `idf.py`, `platformio.ini`) and replace the matching `TODO` lines. Leave anything you can't infer as `TODO` — don't guess.
4. Write one sentence for the Project line in `AGENTS.md` from the README or the code. Mark it `(inferred)` so the user corrects it.
5. If the repo already has a `CLAUDE.md` with content, don't replace it; append `@AGENTS.md` and say so.
6. Report: files created, TODOs remaining, the git hooks installed, and that lanes are available (`/jig:hubnode`, `/jig:subnode`) but need no setup until a second session starts.

Keep `AGENTS.md` under 40 lines. If it's longer after filling, cut.
