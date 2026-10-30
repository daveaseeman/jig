---
name: init
description: Set up the jig system in the current repo. Copies AGENTS.md and CLAUDE.md to root and jig's checker, rulebook and scripts into one hidden .jig folder, and fills what can be inferred.
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

Templates live in `${CLAUDE_PLUGIN_ROOT}/templates/`. Everything jig makes lives in one hidden
folder, `.jig/`, so every visible folder stays the repo's own. `AGENTS.md` and `CLAUDE.md` go
at root, because tools look for them there. The repo's own `docs/` and `.claude/` get nothing.
Copy, **never overwriting** a file that already exists:

```
templates/jig/      → .jig/       (checker, rulebook, scripts, staging/.gitignore)
templates/AGENTS.md → AGENTS.md
templates/CLAUDE.md → CLAUDE.md
```

Nothing else. The spec template and the two ledgers stay in the plugin until first used:
`/jig:brief` copies the template, and the first ledger row creates its ledger.

Then run `python3 .jig/jig.py init` — it writes the board and installs the git hooks that
enforce the rules. Those hooks are the real enforcement and work with or without any AI tool.
Lanes' worktrees go in `.git/jig/worktrees/`, so nothing needs gitignoring.

Then:

1. **Firmware?** If the repo has `sdkconfig`, `platformio.ini`, `idf_component.yml`, `west.yml`, `*.ino`, or a `main/` with C, keep the "Firmware" section of `AGENTS.md` and copy nothing else for it: when a board is ready to spec, `/jig:hardware` writes its page from a definition the user gives, and installs the skills it lists. Otherwise delete the "Firmware" section. If unsure, ask one question.
2. `chmod +x .jig/scripts/*.sh`.
3. **Fill what the code tells you.** In `AGENTS.md` Commands and `.jig/scripts/check.sh`: detect the build system (`package.json`, `Cargo.toml`, `pyproject.toml`, `CMakeLists.txt`, `idf.py`, `platformio.ini`) and replace the matching `TODO` lines. Leave anything you can't infer as `TODO` — don't guess.
   In `.jig/scripts/setup.sh`, install from what is there, and leave a TODO for anything else:
   `uv.lock` → `uv sync`; `poetry.lock` → `poetry install`; `requirements*.txt` → a venv and
   `pip install -r`; each `package-lock.json`, `pnpm-lock.yaml` or `yarn.lock` → that tool's
   install in its directory; `.gitmodules` → `git submodule update --init --recursive`; a
   gitignored `.env` in the main checkout → the copy line. Install, never link, unless the
   user asks: a linked environment hides an undeclared dependency from the gate.
4. Write one sentence for the Project line in `AGENTS.md` from the README or the code. Mark it `(inferred)` so the user corrects it.
5. If the repo already has a `CLAUDE.md` with content, don't replace it; append `@AGENTS.md` and say so.
6. Offer to register the repo with `/jig:repos add repo` (or `add meta` / `add para`), so a chat can find its `.jig/staging/`.
7. Report: files created, TODOs remaining, the git hooks installed, and that lanes are available (`/jig:hubnode`, `/jig:subnode`) but need no setup until a second session starts.

Keep `AGENTS.md` under 40 lines. If it's longer after filling, cut.
