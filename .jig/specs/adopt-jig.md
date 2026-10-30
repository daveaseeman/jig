# Adopt: jig runs on its own repo

## Intent
This repo is jig's source. After this, jig also *manages* it, the same way it manages any
repo: `.jig/` holds the installed checker, rulebook, board, scripts, specs and staging, and
the git hooks enforce the rules on every commit. `plugin/` stays the product — the code jig
ships — and never runs as the repo's checker. The installed copy moves forward by
`/jig:update` after a release, like any other repo's.

## Done when
- [ ] `.jig/` holds `jig.py`, `RULES.md`, `lanes.json`, `scripts/` and `staging/.gitignore`,
      copied from the installed plugin. The hooks are installed, and `python3 .jig/jig.py check`
      prints `ok`.
- [ ] Every spec in `jig/specs/` is at `.jig/specs/`, renamed (`R100`), and `jig/` is gone.
- [ ] `python3 .jig/jig.py survey` lists no homeless files: `plugin/**` is payload.
- [ ] `AGENTS.md` matches the "after" below and is under 40 lines.
- [ ] `/jig:stage` can find this repo: `jig repos` lists `jig` here, and `.jig/staging/` exists.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` still pass.

## Inventory
Tracked Markdown: 34 files. 25 are under `plugin/` and ship as code. 9 are specs, all in
`jig/specs/`. `marketing/` is gitignored and not counted.

| File | Lines | Verdict | Destination | Why |
|---|---|---|---|---|
| `AGENTS.md` | 30 | keep, edit | — | the rules for building jig; the edits are below |
| `CLAUDE.md` | 1 | keep | — | `@AGENTS.md` already |
| `README.md` | — | keep | — | for outsiders |
| `jig/specs/*.md` (9) | — | move | `.jig/specs/` | tasks in flight and done; jig's home for specs |
| `plugin/**` (25 `.md`) | — | payload | board `payload: ["plugin/**"]` | skills and templates ship as code; they aren't documents looking for a home |
| `marketing/FEATURES.md`, `DIFFERENCES.md` | — | keep, untracked | — | the repo's own; nothing in `plugin/` references them |

## AGENTS.md before/after
Kept as written except:
- **Removed:** "This repo does not run jig on itself yet. When it does, `/jig:init` sets that up;
  don't hand-place its files." It is no longer true, and leaving it would be a forwarding
  address.
- **Added under Project:** "`.jig/` is jig running on this repo — the installed release.
  `plugin/` is the product. Edit `plugin/`; `.jig/` changes only by `/jig:update`."
- **Added under Commands:** `check: .jig/scripts/check.sh` (the validator and a syntax check of
  `jig.py`; the full smoke runs at the gate).
- **Changed under Workflow:** `jig/specs/<task>.md` becomes `.jig/specs/<task>.md`.

The file ends at 32 lines.

## Gaps
`init` adds what's missing: `.jig/jig.py`, `RULES.md`, `lanes.json`, the three scripts,
`staging/.gitignore` and the hooks. The ledgers and the spec template stay lazy.

## Docmap
None yet. There is no `docs/`: `README.md` and `RULES.md` describe the system. Fold-in will
list changed source files as UNOWNED until pages exist. That is honest, and the plan names it
rather than inventing pages.

## Stages
Each stage is one commit on `main`. There are no lanes, worktrees or other hooks, so none of
the migration stages (6.1–6.5) apply.
0. **Commit the uncommitted product work**: the `.jig/` move and the `jig repos` kinds.
   `.jig/` must not land on top of uncommitted changes to the checker it installs.
1. **Install.**
   - Copy the plugin's `templates/jig/` to `.jig/` and run `chmod +x`.
   - Run `python3 .jig/jig.py init`, which writes the board (`name: jig`) and the hooks.
   - Set the board's `payload: ["plugin/**"]`.
   - Fill `check.sh` with `claude plugin validate ./plugin` and `python3 -m py_compile
     plugin/templates/jig/jig.py`.
   - Leave `setup.sh` with no steps: the repo is stdlib Python and needs no install.
2. **Move the specs**: `git mv jig/specs/*.md .jig/specs/`. Their references to each other as
   `jig/specs/x.md` stay as written. They are history, and a search still finds them.
3. **Make the `AGENTS.md` edits** above.

## Decisions
- **The repo's `AGENTS.md` wins over the template.** Its rules (propose before changing, a
  FEATURES row before a feature, nothing Claude-specific in the templates) are stated and dated,
  and they are what building jig needs. The template's lines are for a repo that *uses* jig, so
  none of them are copied in.
- **The check stays fast; smoke stays at the gate.** The Stop hook runs `check.sh` on every
  stop with a 300s limit, and smoke takes one to two minutes.

## Risks
- **R7 will fire on jig's own source.** The rule refuses a commit that adds a `WORKAROUND:`
  line to code unless the ledger row is staged too. `jig.py`, `smoke.sh` and two skills contain
  the literal text, as rule messages and test fixtures. Any commit that adds or changes such a
  line will be refused, and payload doesn't exempt code from R7. The options:
  - Split the literal in the source (`"WORK" "AROUND:"`). This is a product change, proposed
    separately.
  - Stage a ledger row that says why. That is wrong, since these aren't workarounds.
  - Commit those lines with `--no-verify`. The workflow rule says never.

  Recommended: the first, as its own proposal before stage 1.
- **The hooks run the installed release, not the branch.** A change to `plugin/templates/jig/jig.py`
  is checked by the old copy in `.jig/` until it's released and `/jig:update` runs. That is the
  intended split, but it is easy to forget mid-change.
- **Smoke builds its fixtures from this repo's git history.** Nothing here changes that history.
