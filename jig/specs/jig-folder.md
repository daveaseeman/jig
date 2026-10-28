# Everything jig puts in a repo lives under `jig/`

## Intent
A repo's root holds only what is for that repo. After `/jig:init`, the only files jig adds
at root are `AGENTS.md` and `CLAUDE.md` (tools look for them there). Everything else jig
creates or manages — the checker, rulebook, board, handoffs, ledgers, specs, docs shape,
check/format scripts, hardware notes — sits in one visible folder, `jig/`. Worktrees are git
state, not content: they live in `.git/jig/worktrees/`. This applies to the jig repo itself
once it runs `/jig:init`.

## Done when
- [x] `tests/smoke.sh` passes with the new layout (it sets up a repo by copying templates, so it
      is the first thing to update).
- [x] `claude plugin validate ./plugin` passes.
- [x] In a fresh scratch repo, `/jig:init` leaves at root exactly: `AGENTS.md`, `CLAUDE.md`,
      `jig/`, `.claude/skills/` only if firmware. No `.gitignore` line is needed.
- [x] `jig open` creates the worktree at `.git/jig/worktrees/<lane>`, and trunk's
      `git status` stays clean.
- [ ] A Claude Code subnode session edits a file in that worktree without a permission
      prompt. If it can't, worktrees go to `jig/.worktrees/` instead (gitignored; the leading
      dot is what pytest, jest and most globbers skip) and this item is amended.
- [x] `grep -rn '\.jig/' plugin tests README.md AGENTS.md` returns nothing.
- [x] `grep -rnE '(^|[^/])(ledgers|specs|docs|scripts)/' plugin/templates/jig/jig.py plugin/skills plugin/templates/AGENTS.md plugin/templates/jig/RULES.md`
      returns only `jig/`-prefixed paths (or paths inside a `.claude/` or firmware context, or
      survey's list of other tools' layouts it looks for: `docs/adr`, `docs/CODEOWNERS`, …).
- [x] The plugin's `scripts/check.sh` and `format.sh` run `jig/scripts/<same>`, else the old
      `scripts/<same>`, so a repo initialized before this change keeps its checks. Both still
      exit 0 silently in a repo without the `.git/jig/enabled` marker.
- [x] The git hook template reads `git show <trunk>:jig/jig.py`.
- [x] A survey on the scratch repo reports no homeless files, lists `jig/` homes, and does
      not count `jig/jig.py` as source.
- [x] A handoff on a branch that changed `jig/jig.py` lists no `UNOWNED jig/jig.py` line.

## Out of scope
- `AGENTS.md`, `CLAUDE.md`, `.claude/skills/` stay where they are.
- No rule changes. R1–R8 unchanged in meaning; only paths move.
- Adopting an existing repo whose files are at the old paths (Daisy): a separate spec.
  Note it under Decisions if `adopt` needs a mapping line. Until it lands, the plugin's
  scripts fall back to the old path (Done when).
- Keeping this repo's installed `jig/jig.py` in step with its source
  `plugin/templates/jig/jig.py`. Its own spec, before this repo runs `/jig:init`: hooks run
  trunk's installed copy, so drift means the rules enforced here aren't the ones shipped.

## Touches
- `plugin/templates/jig/jig.py`: `DIR = "jig"`; `BOARD`; `HOMES` / `HOME_DIRS` (every home
  except `AGENTS.md`, `CLAUDE.md`, `README.md`, `.claude/skills/` moves under `jig/`);
  `TOOL_DIRS` drops `.jig/` and does not gain `jig/` — `jig/` is a home now, not a tool dir;
  R7's ledger path; `init` drops its `.gitignore` line, updates `common`, `append_files`;
  worktree path → `.git/jig/worktrees/` (`cmd_open`, the R1/R2 messages); `HOOK` template;
  `install-hooks` marker dir stays `.git/jig/`; survey's `present` list; `reading-list`'s
  core files; handoff note path; `cmd_handoff`/`cmd_gate` note lookup. Two source filters
  skip `.jig/` today by its leading dot and must skip `jig/` explicitly: survey's `src`
  list (`scripts/` → `jig/scripts/` too) and `foldin_lines`.
- `plugin/templates/`: move `docs/`, `scripts/`, `specs/`, `ledgers/`, `jig/` under one
  `templates/jig/` tree so init copies a single folder: `templates/jig/{jig.py, RULES.md,
  docs/, scripts/, specs/, ledgers/}`. `templates/AGENTS.md`, `templates/CLAUDE.md`,
  `templates/skill-template/` stay beside it.
- `plugin/scripts/check.sh`, `format.sh`: delegate to `jig/scripts/<name>`, falling back to
  `scripts/<name>`.
- `plugin/skills/*/SKILL.md`: every path. `init` copies `templates/jig/` → `jig/` then
  `AGENTS.md`/`CLAUDE.md` to root. `survey`'s "homes" prose. `adopt`'s homes table and §4.
  `hubnode`/`subnode` command paths (`python3 jig/jig.py`). `retro`, `verify`, `review`,
  `bug`, `brief`, `feedback`, `esp-idf-esp32s3` (`jig/docs/HARDWARE.md`).
- `plugin/templates/AGENTS.md`, `plugin/templates/jig/RULES.md`, `adopt/MIGRATION.md`.
- `tests/smoke.sh`, `README.md`, `AGENTS.md` (this repo), `marketing/FEATURES.md` row.
- This repo's `specs/` → `jig/specs/` (`git mv`), and `AGENTS.md`'s `specs/<task>.md` line.

## Alternatives considered
- Keep `docs/` and `scripts/` at root as "the repo's own". Rejected by the owner: the root
  should hold only what is for the repo, and these are jig-shaped — reason `[seen]`, stated.
- Hidden `.jig/` instead of visible `jig/`. Rejected: a folder holding the rulebook, specs
  and ledgers is read by people, not only tools — `[seen]`, stated in the same conversation.
- `jig/worktrees/`. Rejected: tools that skip dot-folders by default (pytest's
  `norecursedirs`, many globbers) would walk every open lane's full copy of the repo — two
  lanes, tests collected three times — `[assumed]` for jest/CMake, `[seen]` for pytest's default.

## Decisions
- `.git/jig/` (enabled marker, review markers, worktrees) is git state, not repo content.
  Tested: `git worktree add .git/jig/worktrees/L1` works and trunk's status stays clean.
- `jig/handoffs/` is committed, as before.
- `payload` needs no entry for `jig/`: it is a home, so survey never looks for one.
- `adopt` gets no old-path mapping line here. Moving a repo set up at the old paths is the
  separate adopt spec; until then the plugin's scripts fall back to `scripts/`.
- `HARDWARE.md` ships inside `templates/jig/docs/` so init copies one folder; init deletes it
  for a repo that isn't firmware, as it already deletes the AGENTS.md Firmware section.
- The board's `common` is `AGENTS.md` + `jig/**`: specs, ledgers and docs are all under `jig/`.
- `gate`'s scratch checkout moves with the worktrees, to `.git/jig/worktrees/gate-<lane>`.
- "Don't patch it; it's the tool's" (RULES.md, `/jig:feedback`) narrows from `.jig/` to
  `jig/jig.py` and `jig/RULES.md`: `jig/` now also holds the repo's own specs, docs, ledgers.
- The scratch-repo items are checked by `tests/smoke.sh`, which copies the templates the way
  the init skill says, not by running `/jig:init` itself. The permission-prompt item needs a
  real subnode session and is still open.
- Permission item, partial evidence (Oct 28): in this repo, an Edit to a file in a throwaway
  worktree at `.git/jig/worktrees/permtest` succeeded with no refusal and no prompt. That
  session ran in auto mode, which may approve what default or accept-edits mode would ask
  about, so it rules out a hard block but not a prompt. Still open until a subnode in default
  mode tries it.

## Deferred (no `ledgers/` here until adopt)
- optional: `gate` prints `./jig/scripts/check.sh` while the plugin hooks fall back to
  `scripts/`. A repo on the old layout still runs its old `jig.py`, which prints the old path,
  so the two can't meet until that repo is migrated — `[seen]`, the gate text comes from the
  repo's own copy.
- optional: no smoke case for the plugin scripts' `scripts/` fallback. Checked by hand in a
  scratch repo (marker + only `scripts/check.sh` → it ran, exit 2); the plugin scripts live
  outside the template the smoke repo is built from — `[seen]`.
