# Everything jig puts in a repo lives under `jig/`

## Intent
A repo's root holds only what is for that repo. After `/jig:init`, the only files jig adds
at root are `AGENTS.md` and `CLAUDE.md` (tools look for them there). Everything else jig
creates or manages — the checker, rulebook, board, handoffs, worktrees, ledgers, specs, docs
shape, check/format scripts, hardware notes — sits in one visible folder, `jig/`. This
applies to the jig repo itself once it runs `/jig:init`.

## Done when
- [ ] `tests/smoke.sh` passes with the new layout (it sets up a repo by copying templates, so it
      is the first thing to update).
- [ ] `claude plugin validate ./plugin` passes.
- [ ] In a fresh scratch repo, `/jig:init` leaves at root exactly: `AGENTS.md`, `CLAUDE.md`,
      `jig/`, `.gitignore` (with `jig/worktrees/`), `.claude/skills/` only if firmware.
- [ ] `grep -rn '\.jig/' plugin tests README.md AGENTS.md` returns nothing.
- [ ] `grep -rnE '(^|[^/])(ledgers|specs|docs|scripts)/' plugin/templates/jig/jig.py plugin/skills plugin/templates/AGENTS.md plugin/templates/jig/RULES.md`
      returns only `jig/`-prefixed paths (or paths inside a `.claude/` or firmware context).
- [ ] The plugin's `scripts/check.sh` and `format.sh` delegate to `jig/scripts/<same>` and
      still exit 0 silently in a repo without the `.git/jig/enabled` marker.
- [ ] The git hook template reads `git show <trunk>:jig/jig.py`.
- [ ] A survey on the scratch repo reports no homeless files and lists `jig/` homes.

## Out of scope
- `AGENTS.md`, `CLAUDE.md`, `.claude/skills/` stay where they are.
- No rule changes. R1–R8 unchanged in meaning; only paths move.
- Adopting an existing repo whose files are at the old paths (Daisy): a separate spec.
  Note it under Decisions if `adopt` needs a mapping line.

## Touches
- `plugin/templates/jig/jig.py`: `DIR = "jig"`; `BOARD`; `HOMES` / `HOME_DIRS` (every home
  except `AGENTS.md`, `CLAUDE.md`, `README.md`, `.claude/skills/` moves under `jig/`);
  `TOOL_DIRS` (drop `.jig/`, add `jig/`? — no: `jig/` is a home now, not a tool dir to skip);
  R7's ledger path; `init`'s `.gitignore` line, `common`, `append_files`; `HOOK` template;
  `install-hooks` marker dir stays `.git/jig/`; survey's `present` list; `reading-list`'s
  core files; handoff note path; `cmd_handoff`/`cmd_gate` note lookup; `SRC_EXT` filter
  that excludes `scripts/` must now exclude `jig/scripts/`.
- `plugin/templates/`: move `docs/`, `scripts/`, `specs/`, `ledgers/`, `jig/` under one
  `templates/jig/` tree so init copies a single folder: `templates/jig/{jig.py, RULES.md,
  docs/, scripts/, specs/, ledgers/}`. `templates/AGENTS.md`, `templates/CLAUDE.md`,
  `templates/skill-template/` stay beside it.
- `plugin/scripts/check.sh`, `format.sh`: delegate to `jig/scripts/<name>`.
- `plugin/skills/*/SKILL.md`: every path. `init` copies `templates/jig/` → `jig/` then
  `AGENTS.md`/`CLAUDE.md` to root. `survey`'s "homes" prose. `adopt`'s homes table and §4.
  `hubnode`/`subnode` command paths (`python3 jig/jig.py`). `retro`, `verify`, `review`,
  `bug`, `brief`, `feedback`, `esp-idf-esp32s3` (`jig/docs/HARDWARE.md`).
- `plugin/templates/AGENTS.md`, `plugin/templates/jig/RULES.md`, `adopt/MIGRATION.md`.
- `tests/smoke.sh`, `README.md`, `AGENTS.md` (this repo), `marketing/FEATURES.md` row.

## Alternatives considered
- Keep `docs/` and `scripts/` at root as "the repo's own". Rejected by the owner: the root
  should hold only what is for the repo, and these are jig-shaped — reason `[seen]`, stated.
- Hidden `.jig/` instead of visible `jig/`. Rejected: a folder holding the rulebook, specs
  and ledgers is read by people, not only tools — `[seen]`, stated in the same conversation.

## Decisions
- `.git/jig/` (enabled marker, review markers) stays: it is git state, not repo content.
- `jig/worktrees/` is gitignored; `jig/handoffs/` is committed, as before.
- Whether `adopt` gets a "root-level `WORKAROUNDS.md` → `jig/ledgers/`" mapping line: decide
  while doing it and record here.
