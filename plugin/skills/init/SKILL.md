---
name: init
description: Set up the jig system in the current repo. Copies AGENTS.md and CLAUDE.md to root and everything else (scripts, specs, docs, the two ledgers, optional HARDWARE.md) into one jig/ folder, and fills what can be inferred.
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

Templates live in `${CLAUDE_PLUGIN_ROOT}/templates/`. Everything jig adds lives in one folder,
`jig/`; only `AGENTS.md` and `CLAUDE.md` go at root, because tools look for them there. Copy,
**never overwriting** a file that already exists:

```
templates/jig/      → jig/        (checker, rulebook, docs, scripts, specs, ledgers)
templates/AGENTS.md → AGENTS.md
templates/CLAUDE.md → CLAUDE.md
```

Then run `python3 jig/jig.py init` — it writes the board and installs the git hooks that
enforce the rules. Those hooks are the real enforcement and work with or without any AI tool.
Lanes' worktrees go in `.git/jig/worktrees/`, so nothing needs gitignoring.

Then:

1. **Firmware?** If the repo has `sdkconfig`, `platformio.ini`, `idf_component.yml`, `west.yml`, `*.ino`, or a `main/` with C, keep `jig/docs/HARDWARE.md` and copy `templates/skill-template/` → `.claude/skills/_skill-template/`. Otherwise delete `jig/docs/HARDWARE.md` and the "Firmware" section from `AGENTS.md`. If unsure, ask one question.
2. `chmod +x jig/scripts/*.sh`.
3. **Fill what the code tells you.** In `AGENTS.md` Commands and `jig/scripts/check.sh`: detect the build system (`package.json`, `Cargo.toml`, `pyproject.toml`, `CMakeLists.txt`, `idf.py`, `platformio.ini`) and replace the matching `TODO` lines. Leave anything you can't infer as `TODO` — don't guess.
4. Write one sentence for the Project line in `AGENTS.md` from the README or the code. Mark it `(inferred)` so the user corrects it.
5. If the repo already has a `CLAUDE.md` with content, don't replace it; append `@AGENTS.md` and say so.
6. Report: files created, TODOs remaining, the git hooks installed, and that lanes are available (`/jig:hubnode`, `/jig:subnode`) but need no setup until a second session starts.

Keep `AGENTS.md` under 40 lines. If it's longer after filling, cut.
