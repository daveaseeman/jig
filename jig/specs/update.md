# `jig update`: bring a repo to the current jig convention

## Intent
When a spec changes where jig puts files or what the board holds, every repo already running
jig is left on the old convention. `jig update` closes that gap. It detects the repo's
version, runs the numbered migrations from there to the plugin's, replaces the tool files,
rewrites the board's paths, reinstalls the hooks, and reports what it would not touch.
Dry-run by default; nothing moves without `--apply`. It commits nothing. A repo already
current prints "up to date" and exits 0.

## Done when
- [ ] `tests/smoke.sh`, from a v1 snapshot (`git archive eaec973 plugin/templates`, set up as
      that commit's init skill says, with a `reserve` counter on `docs/systems/**` and a
      `docmap` page): the current template's `jig.py update --apply` leaves the current layout,
      the board at `VERSION`, and hooks that read `trunk:jig/jig.py`. After a commit, survey
      reports no homeless files.
- [ ] Every board glob that matched a tracked file before the update matches one after it:
      `common`, `append_files`, `payload`, `reserve.*.files`, `docmap` keys and values, each
      lane's `owns` and `shares`. None silently matches nothing.
- [ ] The repo's own files are renamed, not edited: each one that moved shows as `R100` in
      `git diff --cached -M --name-status`. The only other entries are the board, `jig.py`,
      `RULES.md`, and `.gitignore` losing exactly the `.jig/worktrees/` line the old init added.
- [ ] Version detection, in smoke: `eaec973` → 1, `66a044c` → 2, `62c8d9f` → 3,
      `tests/fixtures/v0/` → 0.
- [ ] From `tests/fixtures/v0/`, `update --apply` also ends at the current layout (after the v0
      layout is recorded; see Decisions).
- [ ] A second `update --apply` prints "up to date" and leaves `git status --porcelain` as it was.
- [ ] Without `--apply`, nothing changes: `git status --porcelain` and `.git/hooks/` are the
      same before and after. The plan prints version from → to, each step with the files it
      moves or edits, every stale reference as `file:line`, and the `AGENTS.md` diff against
      the template.
- [ ] A board whose version is above `VERSION` refuses: "repo is ahead; update the plugin".
- [ ] With any lane open, or any worktree besides the main checkout, `update` refuses and names
      them. There is no `--force`.
- [ ] Same version, different `jig.py` or `RULES.md`: `--apply` replaces both and reinstalls
      the hooks; no migration runs.
- [ ] `claude plugin validate ./plugin` passes.

## Out of scope
- Updating the plugin itself (that is `claude plugin update`).
- Editing the repo's own files: `AGENTS.md`, `CLAUDE.md`, docs, specs, ledgers, `check.sh`.
  `update` moves them and reports their stale references; the user edits.
- Adding template files a repo never had. A convention that needs a new file adds it in its
  own migration.
- Repos that never ran jig (`init`) or ran another tool (`adopt`). `.aidev/` is neither: it is
  jig under its old name, version 0.
- Version numbers for `meta` and `para`. Their files are opt-in, so no existing repo has to
  change.

## Touches
- `marketing/FEATURES.md`: the `update` row, before any code. Why: a convention change like
  jig-folder otherwise strands every repo already on jig, with its hooks, board globs and
  docs pointing at paths that moved. Not: a plugin updater, or a sync of the repo's own files
  to the templates.
- `plugin/templates/jig/jig.py`:
  - `VERSION = 3`. `init` writes `"version": VERSION`; today it writes 1, which nothing reads.
  - `detect_version(root)`: `.aidev/aidev.py` → 0; `.jig/lanes.json` without `payload` → 1,
    with it → 2; `jig/lanes.json` → the larger of its `version` and 3. The last rule covers
    boards written between jig-folder and this spec, which say 1.
  - `MIGRATIONS`: an ordered list of `(from_version, description, fn)`. Each `fn` is
    idempotent, moves with per-file `git mv`, and returns what it did, for the plan.
    - 0→1: `.aidev/` → the v1 layout. Written from a real `.aidev/` repo, not from this spec.
    - 1→2: the board gains `"payload": []`.
    - 2→3: `.jig/*` → `jig/`; `specs/`, `ledgers/`, `docs/` → under `jig/`;
      `scripts/check.sh` and `scripts/format.sh` → `jig/scripts/`. The board's paths are
      rewritten by the same map: `common`, `append_files`, `payload`, `reserve.*.files`,
      `docmap` keys and values, each lane's `owns`, `shares` and `handoffs`. `.gitignore`
      loses `.jig/worktrees/`. `.jig/` is removed once empty.
  - `cmd_update`: refusals (ahead, open lanes, extra worktrees) → plan → with `--apply`:
    migrations in order, copy the running `jig.py` and the `RULES.md` beside it into `jig/`,
    set the board's version, `install-hooks`. Then the report: stale references and the
    `AGENTS.md` diff, for the user to fix by hand.
  - Stale references: every tracked text file that names a moved path's old location, as
    `file:line`, matched at a path boundary so `example.com/docs/` is not one. The board and
    `jig/handoffs/` are skipped: the board is rewritten, and handoffs are history.
- `plugin/templates/jig/RULES.md`: `jig update` in the command list.
- `plugin/skills/update/SKILL.md` (`disable-model-invocation: true`). It runs
  `python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" update`, the plugin's copy, because
  the repo's own is older and has no `update`. It shows the plan, asks, applies, lists the
  stale references, and tells the user to fix them and commit on trunk.
- `plugin/skills/hubnode/SKILL.md`, Every session: the same dry run, and one line if the repo
  is behind.
- `plugin/skills/adopt/MIGRATION.md`: a repo with `.aidev/aidev.py` runs jig under its old
  name. Send it to `/jig:update`, not adopt.
- `tests/smoke.sh`; `tests/fixtures/v0/`, the only committed snapshot.

## Alternatives considered
- No versions; `update` diffs the repo against the template and moves whatever differs.
  Rejected: a diff can't tell a convention change from a repo's deliberate deviation (a repo
  that keeps `docs/` at root on purpose), and it can't order two moves. `[seen]`: the folder
  spec alone has four moves that interact.
- Migrations as shell scripts shipped in the plugin. Rejected: they'd run from the plugin's
  path, not from trunk's copy, and `jig.py` is already the one portable file. `[seen]`
- Let `init` be re-runnable and do the updating. Rejected: `init` never overwrites, by
  design, and `update` must. `[seen]`, `init`'s own rule.
- Committed snapshots of every version under `tests/fixtures/v<N>/`. Rejected: git history
  already holds each template version, so there's nothing extra to keep in step. `[seen]`:
  `eaec973`, `66a044c` and `62c8d9f` are the three layouts. Only v0 predates this repo.
- `--force` to update with open lanes. Rejected: the 2→3 move takes worktrees from
  `.jig/worktrees/` to `.git/jig/worktrees/`, so a lane session would lose its folder or keep
  one the board no longer names. Close or merge every lane first. `[seen]`: `cmd_open`
  records the worktree path on the board.
- Bridging `common` over both `.jig/**` and `jig/**` until the migration commit lands.
  Rejected: the hooks don't check that commit at all (see Decisions). `[seen]`

## Decisions
- `update` replaces the tool files (`jig.py`, `RULES.md`) wholesale and rewrites the board,
  because all three are jig's. It moves the repo's own files and reports stale references
  in them, but never edits them. The one exception is the `.gitignore` line jig itself wrote.
- A repo set up before this spec has no reliable version number. Every board says 1, and an
  `.aidev/` repo may have no board at `.jig/` at all. So the version is detected from the
  files (see Touches). From this spec on, the board's `version` is authoritative.
- Bump `VERSION` only when an existing repo must change: files move, or the board needs a key
  it can't do without. A change that only needs the new `jig.py` and its hooks needs no
  number, because every apply that replaces `jig.py` reinstalls the hooks. 1→2 stays, even
  though `.get("payload") or []` already copes with a missing key, because `payload` is what
  tells a v1 board from a v2 one.
- `update` runs from the plugin's copy, never the repo's. It copies itself (`__file__`) and
  the `RULES.md` beside it into the repo, so `jig.py` needs no plugin path and nothing
  Claude-specific.
- Moves are per tracked file, never a directory rename. A renamed `.jig/` would carry an
  ignored worktree folder with it and break git's record of that worktree. That is also why
  `update` refuses while any worktree besides the main checkout exists. jig never removes a
  merged lane's worktree, so there may be many; the refusal says to run
  `git worktree remove`, then `git worktree prune`.
- 2→3 moves `docs/` whole, because it is jig's docs shape. From `scripts/` it moves only
  jig's two files, because a repo's `scripts/` usually holds its own scripts too.
  `[assumed]`, common practice. A repo whose `docs/` also feeds another tool sees that in the
  dry run and moves by hand.
- A merged lane's `worktree` path and the board's `log` are history and stay as written. The
  migration refuses with open lanes, so no live path is left behind.
- The hook gap: `--apply` reinstalls hooks that read `trunk:jig/jig.py`, which doesn't exist
  until the user commits the update. The hook finds no checker and exits 0, so that one
  commit is unchecked, and the commit after it is checked by the new copy. `[seen]`: the
  hook's `git show … || exit 0`.
- Same version, different tool files: `update` replaces them. There's no build number, so an
  older plugin would downgrade a newer `jig.py`. `[assumed]` acceptable at R0, with one user
  and one plugin.
- `update` commits nothing. The user fixes the stale references and commits on trunk.
- The smoke test builds old snapshots with `git archive` from this repo's history, so it
  needs a full clone.
- v0 has a precondition. Before the 0→1 entry is written, read one real `.aidev/` repo
  (Daisy) and record its layout here: which files it has, where its board lives, what its
  hooks read. `tests/fixtures/v0/` is built from that, with tool files and a minimal repo
  only, nothing from Daisy's content. Until then, the only thing known is that
  `.aidev/aidev.py` exists. That comes from the draft and can't be checked in this repo,
  which has no `.aidev/` anywhere in its history. Daisy is the first real run: its pastable
  becomes "install the plugin, run `/jig:update`."
- Order: after jig-folder (`62c8d9f`), whose move is the first real migration, and before
  meta and para, which need no number.
