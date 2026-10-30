# Everything jig makes lives in `.jig/`

Source: owner, Oct 29, reversing `jig/specs/jig-folder.md`'s "visible `jig/`" decision.

## Intent
In a repo jig manages, every folder except one is the repo's own content: what is being built
or documented. jig's files — checker, rulebook, board, scripts, specs, ledgers, handoffs,
staging — all live in a hidden `.jig/`, so neither a person nor an agent mistakes jig's work for
the repo's. People still reach them by asking for them or listing hidden files. At the same
time, `init` copies only what something needs before first use; the rest arrives when it's
first used, the way board pages and hardware skills already do.

## Done when
- [x] `init` creates `.jig/` holding `jig.py`, `RULES.md`, the board, `scripts/check.sh`,
      `format.sh`, `setup.sh` and `staging/.gitignore` — nothing else. Root gains only
      `AGENTS.md`, `CLAUDE.md` and `.jig/`. (smoke)
- [x] Lazy, each created by its first use (smoke):
  - `.jig/specs/_template.md` is not copied; `/jig:brief` uses the repo's if one exists, else
    the plugin's.
  - `.jig/ledgers/WORKAROUNDS.md` and `DEFERRED.md` are not copied; the first row creates
    each (R7 still demands the WORKAROUNDS row in the same commit, and says where).
  - survey no longer lists those three as missing pieces.
- [x] Hooks run `trunk:.jig/jig.py`; the plugin's Stop hook finds `.jig/scripts/check.sh`
      first. (smoke)
- [x] `update` takes every older layout to `.jig/` (smoke, the five fixtures):
  - `jig/` (62c8d9f onward, and every repo set up by 0.2.x) → `.jig/`
  - `.aidev/` → `.jig/`
  - eaec973 / 66a044c: `.jig/` already, with root `specs/`, `ledgers/`, `scripts/check.sh`
    → under `.jig/`
  - each ends with the same tracked paths and board keys; board globs still cover their files.
- [x] `grep -rnE '(^|[^.a-z])jig/(jig\.py|RULES|lanes|specs|ledgers|scripts|staging|handoffs)' plugin tests README.md`
      finds nothing but `update`'s old-path rows and their smoke fixtures.
- [x] Smoke passes and `claude plugin validate ./plugin` passes. No version bump or release: the owner cuts that separately.

## Out of scope
- `docs/`: the repo's, and visible, as before.
- Worktrees: still `.git/jig/worktrees/` (git state, not content).
- The plugin's own folder name, `plugin/templates/jig/`. It is the plugin's, not a repo's;
  init copies it to `.jig/`.
- This repo's own `jig/specs/`. It moves when this repo runs init or update, like any repo.

## Touches
- `marketing/FEATURES.md`: the jig-folder row rewritten for `.jig/`, and a copy-on-use row,
  before code.
- `plugin/templates/jig/jig.py`:
  - `DIR = ".jig"`; every path built from it follows.
  - `LAYOUT`: `jig/…` becomes an old path for each row; `.aidev/…` stays; eaec973's root
    `specs/`, `ledgers/`, root ledgers and `scripts/check.sh` move under `.jig/`.
  - Telling eaec973's `.jig/` from the new one: a board at `.jig/` with `version` below 3 is
    the old layout, whose root `specs/` and `ledgers/` were jig's. The one place `update`
    reads the version for anything but the "ahead" refusal; see Decisions.
  - `OLD_DIRS` becomes `jig/` and `.aidev/`; `.jig/worktrees/` stops being an old ignore line
    only when the board is current (it's harmless either way).
  - survey: `.jig/` is a home; its `present` list drops the lazy files.
  - `STAMP` 6.
- `plugin/templates/jig/ledgers/`, `specs/_template.md`: move out of what init copies (kept in
  the plugin, under `templates/`, for brief and the first ledger row).
- `plugin/scripts/check.sh`: `.jig/scripts/check.sh` first.
- Every `jig/…` path in `RULES.md`, the `AGENTS.md` template, the skills, `README.md`, smoke.
- `/jig:brief`, `/jig:retro`, `/jig:review` (DEFERRED row), R7's message: create the file on
  first row from the plugin's template.

## Alternatives considered
- Keep visible `jig/`. Reversed by the owner: a visible `jig/` beside the repo's folders reads
  as content, to people and to agents. `[seen]`, Oct 29.
- Split: hidden `.jig/` for the tool, visible `jig/` for records. Rejected: two folders at
  root, and the line between them is the one the owner wants gone. `[seen]`, Oct 29.
- Key the eaec973 case on something visible instead of `version`: a root `specs/` beside
  `.jig/` with no `.jig/specs/`. Rejected: with the template now lazy, a fresh repo has no
  `.jig/specs/` either, and its own root `specs/` would be moved. `[seen]`, by this spec.

## Decisions
- `jig-folder.md` is superseded on where jig's folder lives; its other decisions (docs stay
  the repo's, worktrees in `.git/`) stand.
- The version check for eaec973 is the exception to "steps key on what they can see": the
  layout it detects is otherwise indistinguishable from a new repo with its own `specs/`.
- Build, Oct 29. Done as written, with these changes and additions:
  - The spec template and ledgers live in the plugin at `templates/specs/_template.md` and
    `templates/ledgers/`; `init` copies `templates/jig/` whole, which no longer holds them.
    `jig init` no longer makes an empty `handoffs/` (`jig handoff` makes it).
  - `jig/` rows apply only while the board is at `jig/lanes.json`. Beside a board at `.jig/`,
    a `jig/` folder is the repo's own (a Python package named `jig`), the same way root
    `specs/` is the repo's once jig left it. So this repo's own `jig/specs/` is not moved by
    `init`; it moves by hand, or by `update` before this repo gets a `.jig/` board.
  - `update` also moves a 0.2.x repo's untracked `jig/staging/` and `jig/meta-cache/` files and
    rewrites the `jig/meta-cache/` ignore line, since no `git mv` reaches them. Steps check the
    tracked paths after the moves, so a moved `setup.sh` or staging `.gitignore` isn't re-added.
  - R7 skips `.jig/jig.py`. Now that the checker stays at one path, the previous checker judges
    every update of it, and jig.py quotes the marker. The first `.jig/` layout's checker
    predates this, so its update commit is refused on R7 alone; the update skill says to
    commit that one with `--no-verify`, and smoke asserts R7 is the only refusal.
  - `para-sync` no longer counts a file under `.jig/` as the repo using a term: `RULES.md`
    quotes `D-001` as an example.
  - `forward` says "run `jig update` there" when the target still has `jig/lanes.json`.
  - Smoke: a fifth fixture, 5d955a2 (0.2.x `jig/`, docs at root), plus cases for the lazy
    files, the R7 message, the Stop hook's order, and the untracked staging move.
- Running list for the staged doc, unchanged by this: `add this` as a synonym for `add repo`;
  `update` on a repo that never ran jig points to init/adopt; survey's stray "no board" line.
- Review, Oct 29 (fresh context). Nothing blocking. Taken:
  - `jig repos add` no longer replaces another checkout's entry of the same name, silently.
  - `rename` with no argument now says how to use it.
  - The stage skill still said `<repo>/jig/staging/`; it now says `.jig/`.
  - The done-when grep's character class is fixed, so a path after a slash no longer slips
    past it.
  - Brief says to create `.jig/specs/` when it's missing.
  - A malformed `repos.json` entry is skipped rather than crashing.

