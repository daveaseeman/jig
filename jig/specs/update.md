# `jig update`: bring a repo to the current jig convention

## Intent
When a spec changes where jig puts files or what the board holds, every repo already running
jig is left on the old convention. `jig update` brings it to the current one in one step,
from wherever it is. It holds one table of jig's own files, giving where each lives now and
where it used to, and it moves whatever it finds at an old path. Missing board keys get
init's defaults. It also replaces the tool files, rewrites the board's paths, and reinstalls
the hooks.

When `update` finds something in jig's territory it doesn't recognize, it flags it. A
blocker says why the update would fail, and the skill drafts the change to jig that would
recognize the pattern. A warning is shown, and the user decides whether to go ahead.

Dry-run by default; nothing moves without `--apply`. It commits nothing. A repo already
current prints "up to date" and exits 0.

## Done when
- [ ] `tests/smoke.sh`: each of the three layouts in this repo's history (`eaec973`,
      `66a044c`, `62c8d9f`) is set up as that commit's init skill says, with a `reserve`
      counter on its docs and a `docmap` page. The current template's
      `jig.py update --apply` takes all three to the same tracked paths, the same board keys,
      and hooks that read `trunk:jig/jig.py`. After a commit, survey reports no homeless
      files.
- [ ] Every board glob that matched a tracked file before the update matches one after it:
      `common`, `append_files`, `payload`, `reserve.*.files`, `docmap` keys and values, each
      lane's `owns` and `shares`. None silently matches nothing.
- [ ] The repo's own files are renamed, not edited: each one that moved shows as `R100` in
      `git diff --cached -M --name-status`. The only other entries are the board, `jig.py`,
      `RULES.md`, and `.gitignore` losing exactly the `.jig/worktrees/` line the old init added.
- [ ] A second `update --apply` prints "up to date" and leaves `git status --porcelain` as it was.
- [ ] Without `--apply`, nothing changes: `git status --porcelain` and `.git/hooks/` are the
      same before and after. The plan prints:
      - each move and each board edit
      - each warning and blocker
      - every stale reference as `file:line`
      - the `AGENTS.md` diff against the template
- [ ] Unrecognized patterns, one smoke case each:
      - Blocked: two boards, at `jig/lanes.json` and `.jig/lanes.json`. `update` names both,
        and `--apply` changes nothing.
      - Blocked: no board at any path in the table. `update` names the homebrew boards and
        foreign hooks that survey's checks find.
      - Warning: an extra file in `.jig/`. `--apply` proceeds, and the file and `.jig/` stay.
      - Warning: a board key jig doesn't know. It is kept and named.
- [ ] Exit codes: 0 when up to date, applied, or the plan is clean; 1 when the plan has
      warnings; 2 when it is blocked or refused.
- [ ] A board stamped above the plugin's `STAMP` refuses: "repo is ahead; update the plugin".
- [ ] With any lane open, or any worktree besides the main checkout, `update` refuses and names
      them. There is no `--force`.
- [ ] Same stamp, different `jig.py` or `RULES.md`: `--apply` replaces both and reinstalls
      the hooks, and nothing moves.
- [ ] Daisy evaluation. A worker runs the dry run on a scratch copy of Daisy (the owner gives
      the path) and compares it with a hand-written move list for its `.aidev/` folder. Each
      gap is recorded under Decisions as a row, a step, or adopt's job. The real repo is not
      touched.
- [ ] `claude plugin validate ./plugin` passes.

## Out of scope
- Updating the plugin itself (that is `claude plugin update`).
- Editing the repo's own files: `AGENTS.md`, `CLAUDE.md`, docs, specs, ledgers, `check.sh`.
  `update` moves them and reports their stale references; the user edits them.
- Adding template files a repo never had. A change that needs one adds a step.
- Fixing an unrecognized pattern from inside `update`. The fix is a change to jig, proposed
  to the plugin and made there.
- Repos with open lanes: adopt carries lanes over, and `update` refuses.
- Repos that never ran jig (`init`) or ran another tool (`adopt`). Whether `.aidev/` is jig
  under an old name (rows) or another tool (adopt) is for the Daisy evaluation to decide.

## Touches
- `marketing/FEATURES.md`: the `update` row, before any code. Why: a convention change like
  jig-folder otherwise strands every repo already on jig, with its hooks, board globs and
  docs pointing at paths that moved. Not: a plugin updater, or a sync of the repo's own files
  to the templates.
- `plugin/templates/jig/jig.py`:
  - `LAYOUT`: ordered rows of `(current path, [old paths])`.

    | now | used to be |
    |---|---|
    | `jig/lanes.json` | `.jig/lanes.json` |
    | `jig/jig.py`, `jig/RULES.md` | `.jig/…` |
    | `jig/handoffs/` | `.jig/handoffs/` |
    | `jig/specs/`, `jig/ledgers/`, `jig/docs/` | `specs/`, `ledgers/`, `docs/` |
    | `jig/scripts/check.sh`, `jig/scripts/format.sh` | `scripts/…` |

  - Lines jig used to write to `.gitignore` and now removes: `.jig/worktrees/`.
  - `BOARD_DEFAULTS`: init's board, factored out so `init` and `update` share it. A key
    missing from the board gets its default, which covers `payload` and every key added
    later.
  - `STAMP = 3`, written to the board's `version` by `init` and `update`. Any spec that adds
    a row, a default or a step bumps it. Nothing branches on it except the "ahead" refusal.
  - `STEPS`: coded changes that aren't a move or a missing key. Each is keyed on a condition
    it can see in the repo, not on a version. Empty today.
  - `cmd_update` runs in order:
    1. Refusals: the repo is ahead, a lane is open, or a worktree besides the main checkout
       exists.
    2. The plan: moves, board edits, steps, warnings, blockers.
    3. With `--apply` and no blockers: the moves, the steps, a copy of the running `jig.py`
       and the `RULES.md` beside it into `jig/`, the stamp, and `install-hooks`.
    4. The report: stale references, the `AGENTS.md` diff, and the warnings again.
  - What it flags, beyond the rows:
    - Blockers, where the repo wouldn't work afterwards: no board at any path in the table;
      a board that isn't valid JSON; two boards. A missing board also names the homebrew
      boards and foreign hooks found by survey's own checks, reused rather than copied.
    - Warnings, where `update` can leave the thing as it is and still produce a working repo:
      - A file left at an old path after the moves; its folder isn't removed.
      - A row whose old and new paths both exist, which is left alone, not merged.
      - A board key not in `BOARD_DEFAULTS`. It is kept, and the checker ignores it, so
        whatever an older tool enforced with it stops.
      - A hook at a `.git/hooks/` name that isn't jig's. `install-hooks` will keep it
        running first as `<name>.local`.
  - Stale references: every tracked text file that names a moved path's old location, as
    `file:line`, matched at a path boundary so `example.com/docs/` is not one. The board and
    `jig/handoffs/` are skipped: the board is rewritten, and handoffs are history.
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
  - After applying: list the stale references, and tell the user to fix them and commit on
    trunk.
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
  didn't make. jig knows its own, and a coded table is testable in smoke and rewrites board
  paths exactly. `update` borrows survey's checks only to name what it doesn't recognize.
  `[seen]`
- Migrations as shell scripts shipped in the plugin. Rejected: they'd run from the plugin's
  path, not from trunk's copy, and `jig.py` is already the one portable file. `[seen]`
- Let `init` be re-runnable and do the updating. Rejected: `init` never overwrites, by
  design, and `update` must. `[seen]`, `init`'s own rule.
- Committed snapshots of each layout under `tests/fixtures/`. Rejected: git history already
  holds all three. `[seen]`: `eaec973`, `66a044c`, `62c8d9f`.
- `--force` to update with open lanes. Rejected: the move takes worktrees from
  `.jig/worktrees/` to `.git/jig/worktrees/`, so a lane session would lose its folder or keep
  one the board no longer names. Close or merge every lane first. `[seen]`: `cmd_open`
  records the worktree path on the board.
- Bridging `common` over both `.jig/**` and `jig/**` until the update commit lands.
  Rejected: the hooks don't check that commit at all (see Decisions). `[seen]`
- `jig.py` prompts before applying a plan with warnings. Rejected: skills, hooks and scripts
  run it too, so it never prompts. The dry run is the ask, and `--apply` is the yes.
  `[seen]`: no `jig` command reads stdin today.

## Decisions
- `update` replaces the tool files (`jig.py`, `RULES.md`) wholesale and rewrites the board,
  because all three are jig's. It moves the repo's own files and reports stale references
  in them, but never edits them. The one exception is the `.gitignore` line jig itself wrote.
- A row moves only when its old path exists and its new one doesn't. When both exist,
  `update` leaves both and warns, so it is idempotent and a repo's own root `docs/` is safe
  once `jig/docs/` exists. The exception is the board: with two, `update` can't tell which
  one the lanes are on, so it blocks.
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
- `docs/` moves whole, because it is jig's docs shape. From `scripts/` only jig's two files
  move, because a repo's `scripts/` usually holds its own scripts too. `[assumed]`, common
  practice.
- A merged lane's `worktree` path and the board's `log` are history and stay as written.
  `update` refuses with open lanes, so no live path is left behind.
- The hook gap: `--apply` reinstalls hooks that read `trunk:jig/jig.py`, which doesn't exist
  until the user commits the update. The hook finds no checker and exits 0, so that one
  commit is unchecked, and the commit after it is checked by the new copy. `[seen]`: the
  hook's `git show … || exit 0`.
- Old hooks carry the `# jig hook` marker, so `install-hooks` rewrites them in place rather
  than keeping them as `.local`. `[seen]` at `eaec973`.
- Same stamp, different tool files: `update` replaces them. There's no build number, so an
  older plugin would downgrade a newer `jig.py`. `[assumed]` acceptable at R0, with one user
  and one plugin.
- `update` commits nothing. The user fixes the stale references and commits on trunk.
- The smoke test builds the old layouts with `git archive` from this repo's history, so it
  needs a full clone.
- Daisy is the first real test of the unrecognized path. Expect `.aidev/` to block (no board
  at a path in the table), with its board named as a homebrew candidate. The evaluation then
  decides between rows (jig under an old name) and adopt (another tool). If Daisy has open
  lanes, adopt handles it either way.
- Order: after jig-folder (`62c8d9f`), whose move is the first set of rows, and before meta
  and para, which add no rows.
