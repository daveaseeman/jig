# `jig update`: bring a repo to the current jig convention

## Intent
When a spec changes where jig puts files or what the board holds, every repo already running
jig is left on the old convention. `jig update` brings it to the current one in one step,
from wherever it is. It holds one table of jig's own files, giving where each lives now and
where it used to, and it moves whatever it finds at an old path. Missing board keys get
init's defaults. It also replaces the tool files, rewrites the board's paths, reinstalls the
hooks, and runs the repo's check.

When `update` finds something in jig's territory it doesn't recognize, it flags it. A
blocker says why the update would fail, and the skill drafts the change to jig that would
recognize the pattern. A warning is shown, and the user decides whether to go ahead.

Dry-run by default; nothing moves without `--apply`. It commits nothing. A repo already
current prints "up to date" and exits 0.

## Done when
- [ ] `tests/smoke.sh`: four old layouts are set up, each with a `reserve` counter on
      `docs/systems/**` and a `docmap` page:
      - the three in this repo's history (`eaec973`, `66a044c`, `62c8d9f`), each as that
        commit's init skill says;
      - an ai-dev layout built from `eaec973` the way ai-dev named things: `.aidev/aidev.py`,
        the ledger at root, `# aidev hook`, `.git/aidev/enabled`.

      The current template's `jig.py update --apply` takes all four to the same result:
      - the same tracked paths and the same board keys
      - hooks that read `trunk:jig/jig.py`
      - `.git/jig/enabled`, and no `.git/aidev/`

      After a commit, survey reports no homeless files.
- [ ] Every board glob that matched a tracked file before the update matches one after it:
      `common`, `append_files`, `payload`, `reserve.*.files`, `docmap` keys and values, each
      lane's `owns` and `shares`. None silently matches nothing, and `scripts/**` is left
      alone.
- [ ] The repo's own files are renamed, not edited: each one that moved shows as `R100` in
      `git diff --cached -M --name-status`. The only other entries are the board, `jig.py`,
      `RULES.md`, and `.gitignore` losing exactly the old worktrees line (`.jig/worktrees/`
      or `.aidev/worktrees/`).
- [ ] A second `update --apply` prints "up to date" and leaves `git status --porcelain` as it was.
- [ ] Without `--apply`, nothing changes: `git status --porcelain` and `.git/` are the same
      before and after. The plan prints:
      - each move and each board edit
      - each warning and blocker
      - the stale references, grouped by file with a count, with the lines shown for files
        that aren't Markdown
      - the `AGENTS.md` diff against the template
- [ ] Unrecognized patterns, one smoke case each:
      - Blocked: two boards, at `jig/lanes.json` and `.jig/lanes.json`. `update` names both,
        and `--apply` changes nothing.
      - Blocked: no board at any path in the table. `update` names any board-like JSON in a
        root dot-folder (smoke: `.other/lanes.json`), and the foreign hooks.
      - Warning: an extra file in `.jig/`. `--apply` proceeds, and the file and `.jig/` stay.
      - Warning: a board key jig doesn't know. It is kept and named.
      - Warning: a `.py` file that names `.jig/lanes.json`.
- [ ] After `--apply`, `update` runs `jig/scripts/check.sh` and prints whether it passed. A
      failing check undoes nothing.
- [ ] Exit codes: 0 when up to date, applied, or the plan is clean; 1 when the plan has
      warnings; 2 when it is blocked or refused.
- [ ] A board stamped above the plugin's `STAMP` refuses: "repo is ahead; update the plugin".
- [ ] With any lane open, or any worktree besides the main checkout, `update` refuses and names
      them. These checks read the board `update` found, and there is no `--force`.
- [ ] Same stamp, different `jig.py` or `RULES.md`: `--apply` replaces both and reinstalls
      the hooks, and nothing moves.
- [ ] Daisy, for real. Once `update` is built, run its dry run on the scratch copy. It must
      match the hand-written list under Decisions: no blocker, and three code warnings. The
      real repo is not touched.
- [ ] `claude plugin validate ./plugin` passes.

## Out of scope
- Updating the plugin itself (that is `claude plugin update`).
- Editing the repo's own files: `AGENTS.md`, `CLAUDE.md`, docs, specs, ledgers, code.
  `update` moves jig's files and reports stale references; the skill and the user fix them.
- Adding template files a repo never had. A change that needs one adds a step;
  `jig/specs/worktree-setup.md` adds the first, for `jig/scripts/setup.sh`.
- Fixing an unrecognized pattern from inside `update`. The fix is a change to jig, proposed
  to the plugin and made there.
- Repos with open lanes: adopt carries lanes over, and `update` refuses.
- Repos that never ran jig (`init`) or ran another tool (`adopt`).
- Other tools' archives that sit beside jig's, such as `.claude/claude-lane/`. They aren't
  jig's territory, so `update` leaves them alone.

## Touches
- `marketing/FEATURES.md`: the `update` row, before any code. Why: a convention change like
  jig-folder otherwise strands every repo already on jig, with its hooks and board globs
  pointing at paths that moved. Not: a plugin updater, or a sync of the repo's own files to
  the templates.
- `plugin/templates/jig/jig.py`:
  - `LAYOUT`: ordered rows of `(current path, [old paths])`.

    | now | used to be |
    |---|---|
    | `jig/lanes.json` | `.jig/lanes.json`, `.aidev/lanes.json` |
    | `jig/jig.py` | `.jig/jig.py`, `.aidev/aidev.py` |
    | `jig/RULES.md` | `.jig/RULES.md`, `.aidev/RULES.md` |
    | `jig/handoffs/` | `.jig/handoffs/`, `.aidev/handoffs/` |
    | `jig/specs/` | `specs/` |
    | `jig/ledgers/WORKAROUNDS.md`, `jig/ledgers/DEFERRED.md` | `ledgers/…`, then root `WORKAROUNDS.md`, `DEFERRED.md` |
    | `jig/scripts/check.sh`, `jig/scripts/format.sh` | `scripts/…` |
    | `docs/` | `jig/docs/` (only `62c8d9f` put docs there) |

  - The tool rows (`jig.py`, `RULES.md`) remove the old file and write the current one.
    Since the content is replaced anyway, they are never a rename.
  - The board rewrite uses the same rows. A folder row rewrites globs under its prefix. A
    file row rewrites only that exact path, so `scripts/**` still means the repo's own
    scripts.
  - Old git state jig cleans up:
    - the `.gitignore` lines `.jig/worktrees/` and `.aidev/worktrees/`
    - the hook markers `# jig hook` and `# aidev hook`: `cmd_install_hooks` treats both as
      its own and rewrites the hook in place instead of keeping it as `.local`
    - `.git/aidev/`, which is removed: `install-hooks` writes `.git/jig/enabled`, and its
      `reviewed/` markers belong to merged lanes
  - `BOARD_DEFAULTS`: init's board, factored out so `init` and `update` share it. A key
    missing from the board gets its default.
  - `STAMP = 3`, written to the board's `version` by `init` and `update`. Any spec that adds
    a row, a default or a step bumps it. Nothing branches on it except the "ahead" refusal.
  - `STEPS`: coded changes that aren't a move or a missing key. Each is keyed on a condition
    it can see in the repo, not on a version. Empty when `update` lands;
    `worktree-setup.md` adds the first.
  - `cmd_update` runs in order:
    1. Find the board: the first existing path in its row. Finding none, or two, is a
       blocker.
    2. Refusals, read from that board: it's ahead, a lane is open, or a worktree besides the
       main checkout exists.
    3. The plan: moves, board edits, steps, warnings, blockers.
    4. With `--apply` and no blockers: the moves, the steps, a copy of the running `jig.py`
       and the `RULES.md` beside it into `jig/`, the stamp, and `install-hooks`.
    5. Run `jig/scripts/check.sh`, and report the stale references, the `AGENTS.md` diff,
       the warnings again, and whether the check passed.
  - What it flags, beyond the rows:
    - Blockers, where the repo wouldn't work afterwards: no board, an invalid board, two
      boards. With no board, it names any board-like JSON in a root dot-folder (the same
      check survey uses), and any foreign hooks.
    - Warnings, where `update` can leave the thing as it is and still produce a working repo:
      - A file left at an old path after the moves; its folder isn't removed.
      - A row whose old and new paths both exist, which is left alone, not merged.
      - A board key not in `BOARD_DEFAULTS`. It is kept, and the checker ignores it.
      - A hook that carries no known marker. `install-hooks` will keep it running first as
        `<name>.local`.
      - A stale reference in a file that isn't Markdown. It's code or config the repo's
        checks may run.
  - Stale references are worked out against the tree after the moves, so moved handoffs
    land in `jig/handoffs/` and are skipped with the board. They are matched at a path
    boundary, so `example.com/specs/` is not one, and grouped by file.
  - `cmd_survey`: its homebrew-board check looks in every root dot-folder, not only
    `TOOL_DIRS`. On Daisy it missed `.aidev/lanes.json`, and adopt relies on the same check.
- `plugin/templates/jig/RULES.md`: `jig update` in the command list.
- `plugin/skills/update/SKILL.md` (`disable-model-invocation: true`). It runs
  `python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" update`, the plugin's copy, because
  the repo's own is older and may have no `update`. Then:
  - Clean plan: show it, ask, apply.
  - Warnings: show each one, and ask whether to proceed.
  - Blocked: say why the update would fail, and draft the change to jig that would recognize
    the pattern: which row, default or step to add, with a done-when the plugin owner can
    test. It is written the way `/jig:feedback` writes its report, to the same temporary
    path. Apply nothing, and stop.
  - After applying: fix the stale references in code with the user, in the same
    uncommitted change, until the check passes. Those are the repo's files; the skill edits
    them with the user, and `jig.py` never does. Then commit on trunk.
- `plugin/skills/hubnode/SKILL.md`, Every session: the same dry run, with one line if the
  repo is behind and one if it is blocked.
- `tests/smoke.sh`.

## Alternatives considered
- A chain of numbered migrations (1→2→3), each a function. Rejected by the owner: every old
  version keeps its own code path, which runs rarely and rots. With the table, every old
  layout takes the same single path, and a new layout is one more row. `[seen]`, stated
  Oct 28.
- No table: diff the repo against the template and move whatever differs. Rejected: a diff
  can't tell a convention change from a repo's deliberate deviation. The table moves only
  what sits at jig's own old paths, and flags the rest instead of moving it. `[seen]`
- Survey-and-map, like adopt. Rejected for `update`: adopt's judgment is for layouts jig
  didn't make. jig knows its own, including ai-dev's (see the Daisy Decision), and a coded
  table is testable in smoke and rewrites board paths exactly. `update` borrows survey's
  checks only to name what it doesn't recognize. `[seen]`
- Migrations as shell scripts shipped in the plugin. Rejected: they'd run from the plugin's
  path, not from trunk's copy, and `jig.py` is already the one portable file. `[seen]`
- Let `init` be re-runnable and do the updating. Rejected: `init` never overwrites, by
  design, and `update` must. `[seen]`, `init`'s own rule.
- Committed snapshots of each layout under `tests/fixtures/`. Rejected: git history holds
  three of them, and the ai-dev layout is a few renames away from `eaec973`. `[seen]`
- `--force` to update with open lanes. Rejected: the move takes worktrees from
  `.jig/worktrees/` to `.git/jig/worktrees/`, so a lane session would lose its folder or keep
  one the board no longer names. Close or merge every lane first. `[seen]`: `cmd_open`
  records the worktree path on the board.
- Bridging `common` over old and new paths until the update commit lands. Rejected: the
  hooks don't check that commit at all (see Decisions). `[seen]`
- `jig.py` prompts before applying a plan with warnings. Rejected: skills, hooks and scripts
  run it too, so it never prompts. The dry run is the ask, and `--apply` is the yes.
  `[seen]`: no `jig` command reads stdin today.

## Decisions
- `update` replaces the tool files (`jig.py`, `RULES.md`) wholesale and rewrites the board,
  because all three are jig's. It moves the repo's own files and reports stale references
  in them, but never edits them. The one exception is the `.gitignore` line jig itself wrote.
- A row moves a file only when its old path exists and its new one doesn't. When both
  exist, `update` leaves both and warns, so it is idempotent and never overwrites. The
  exception is the board: with two, `update` can't tell which one the lanes are on, so it
  blocks.
- Blocker or warning comes down to one question: would the repo work afterwards? Refusals
  (ahead, open lanes, extra worktrees) are separate, because each has a fix the user already
  knows.
- A blocker's fix is a change to jig, proposed in `/jig:feedback`'s form. `update` never
  teaches itself a pattern inside the repo, for the same reason a lane can't weaken its own
  rules.
- `update` runs from the plugin's copy, never the repo's. It copies itself (`__file__`) and
  the `RULES.md` beside it into the repo, so `jig.py` needs no plugin path and nothing
  Claude-specific.
- Moves are per tracked file, never a directory rename. A renamed `.jig/` would carry an
  ignored worktree folder with it and break git's record of that worktree. That is also why
  `update` refuses while any worktree besides the main checkout exists. jig never removes a
  merged lane's worktree, so there may be many; the refusal says to run
  `git worktree remove`, then `git worktree prune`.
- `docs/` is the repo's and never moves into `jig/`. That was the owner's call on Oct 28, and
  jig-folder is amended to match. The `jig/docs/` → `docs/` row only undoes `62c8d9f`'s
  layout. From `scripts/` only jig's two files move, because a repo's `scripts/` usually
  holds its own scripts too. `[assumed]`, common practice.
- A merged lane's `worktree` path and the board's `log` are history and stay as written.
  `update` refuses with open lanes, so no live path is left behind.
- The hook gap: `--apply` reinstalls hooks that read `trunk:jig/jig.py`, which doesn't exist
  until the user commits the update. The hook finds no checker and exits 0, so that one
  commit is unchecked, and the commit after it is checked by the new copy. `[seen]`: the
  hook's `git show … || exit 0`.
- Hook markers. Old jig hooks say `# jig hook` (`[seen]` at `eaec973`) and ai-dev's say
  `# aidev hook` (`[seen]` in Daisy). Both count as jig's. Without that, `install-hooks`
  would keep the old checker running first as `.local`, checking the update commit under
  the old rules.
- The check runs after `--apply` because moving jig's files can break the repo's own code
  that names them. Daisy hard-codes its board path in three files. A red check is reported
  and handed to the skill; `jig.py` still edits nothing.
- Same stamp, different tool files: `update` replaces them. There's no build number, so an
  older plugin would downgrade a newer `jig.py`. `[assumed]` acceptable at R0, with one user
  and one plugin.
- `update` commits nothing. The commit is the user's, after the skill and the user fix what
  the check and the stale references show.
- The smoke test builds the old layouts with `git archive` from this repo's history, so it
  needs a full clone.
- Daisy paper run, Oct 28. A worker stepped through this spec as it stood at `d41e165`,
  against a scratch clone of Daisy at `88560bd`, and I checked its key claims on the clone.
  - `.aidev/` is jig under its old name. After renaming aidev to jig, `.aidev/aidev.py`
    differs from `jig.py` at `eaec973` by 51 diff lines, all wording or the ledger path
    (root `WORKAROUNDS.md`). `[seen]`
  - All 12 lanes are merged, and there is one worktree, so Daisy is `update`'s, not adopt's.
  - As the spec stood, `update` blocked with no board named, because survey's check only
    looked in `TOOL_DIRS`. Six gaps came out of it:
    - the `.aidev/` and root-ledger rows
    - the `# aidev hook` marker
    - removing `.git/aidev/`
    - finding the board before the refusals
    - the dot-folder board check
    - code warnings, plus running the check after `--apply`
  - The hand-written list, with `docs/` staying:
    - `.aidev/*` (17 tracked files) → `jig/`, with `aidev.py` replaced by `jig.py`
    - `specs/` (15) → `jig/specs/`
    - root `WORKAROUNDS.md` → `jig/ledgers/`
    - `scripts/check.sh` and `scripts/format.sh` → `jig/scripts/`
    - board: `version` 1 → 3 and `payload: []` added; in `common` and `append_files`,
      `WORKAROUNDS.md`, `specs/**` and `.aidev/handoffs/**` are rewritten, and every `docs/`
      glob is unchanged
    - `.gitignore:48` removed
    - all four hooks rewritten in place
  - Expected code warnings, each a one-line constant to edit before the commit:
    - `daisy/tests/test_docs.py:66`
    - `scripts/gen_reference.py:42`
    - `scripts/reading_list.py:37`

    All three name `.aidev/lanes.json`. `.claude/claude-lane/` is another tool's archive,
    and nothing touches it.
- Order: jig-folder's docs correction lands first, because it changes the layout `update`
  targets. Then `update`, then `worktree-setup` (its first step and `STAMP` 4), then meta
  and para, which add no rows. If `worktree-setup` has landed by the real Daisy run, the
  expected list also gains a TODO `jig/scripts/setup.sh` and a fifth hook, `post-merge`.
