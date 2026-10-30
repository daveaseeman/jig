# One name for each thing, and every old repo brought up to date

Source: cowork session 2026-10-27..29 (Dave + Claude) (staged as 2026-10-29-names-and-cleanup.md)

## Intent
Every name jig uses says what the thing is, and `/jig:update` takes a repo from any generation
it has ever been on (claude-lane, ai-dev, 0.2.x `jig/`, `.jig/` today) to the names and layout
below in one pass, removing leftovers that have no home. The renames and the migration steps
ship in the same release.

## The story's NOW column, checked against the tree (Oct 29, at 92289fa)
- Holds: every `ai-dev`/`.aidev/` row, `.git/aidev/` (update removes it), `# aidev hook`
  (`HOOK_MARKERS`), `.git/jig/reviewed/`, manager/worker → hubnode/subnode, root
  `WORKAROUNDS.md`, root `specs/`, `scripts/check.sh`/`format.sh`, `payload`, `HOMES`/`HOME_DIRS`,
  `reserve.<counter>.next` meaning "last handed out", the board `log`, `jig lane`, the record's
  `brief` field, meta/para as JSON.
- **Wrong: `docs/` (root) → `.jig/docs/`.** Docs stay the repo's, at root (`dot-jig.md`, out of
  scope; `LAYOUT` moves `jig/docs/` → `docs/`). This spec drops the row.
- **Not handled today:** claude-lane (`claude-lane.py`, `board.json`, `LANES.md`),
  `docs/REVIEW_LEDGER.md`, root `HARDWARE.md`. `docs/HARDWARE.md` is only offered as a repo
  file to review. These are new `update` rows here, not renames.
- **The ripple list is stale in two places:** worktrees live at `.git/jig/worktrees/`, not
  `.jig/worktrees/`, and `MIGRATION.md` is already folded into the adopt skill.
- "lane" count today: `jig.py` 103, smoke 54, `RULES.md` 33, adopt 18, hubnode 10,
  subnode 8, init 2, README 3, AGENTS template, feedback and update 1 each.

## Done when
Smoke, per stage:
- [ ] **Migrations.** A made-up fixture for each generation in `tests/fixtures/` (claude-lane,
      ai-dev with `docs/REVIEW_LEDGER.md` and root `WORKAROUNDS.md` and root `HARDWARE.md`, 0.2.x
      `jig/`, `.jig/` v6). `update --apply` on each ends with the same tracked jig paths and the
      same board keys; a second `update` says "up to date". The dry run lists every removal
      (`LANES.md`, `claude-lane.py`, merged board entries) before applying.
- [ ] `REVIEW_LEDGER.md` → `.jig/ledgers/DEFERRED.md` keeps its deferred and rejected rows and
      drops the taken ones; every other file moves byte-for-byte (`git mv`, `R100`).
- [ ] **Board split.** `init` writes `.jig/config.json` (trunk, common, append_files, reserve
      pattern+files, docmap, not_docs, version) and `.jig/jobs.json` (open jobs only). The hooks
      read both from trunk; a branch that edits either is refused (today's R5).
- [ ] A job record stores spec, owns, shares, after, reserved numbers and state. Branch,
      worktree and opened date come from git (see Decisions for an adopted branch).
- [ ] Merging a job removes its entry from `jobs.json` in the merge commit.
- [ ] No `next`: `jig open --reserve section` hands out max(highest on trunk, highest held by
      an open job) + 1, and the same number twice is impossible with two jobs open.
- [ ] No `log` key; `jig log` is gone or reads `git log .jig/jobs.json`.
- [ ] **Renames.** `grep -rniw 'lanes\?' plugin README.md tests` finds only `update`'s old-name
      rows and their fixtures. Same for `brief` as a record field, `payload`, `HOMES`,
      `HOME_DIRS`. `/jig:spec` exists and `/jig:brief` does not; `jig job` replaces `jig lane`;
      survey prints "Doc homes:".
- [ ] `RULES.md` defines "job" in one line, next to the standard terms it maps.
- [ ] The two dead `HOME_DIRS` entries (`.jig/`, `.claude/skills/`, already in `TOOL_DIRS`) are
      gone.
- [ ] Smoke passes, the validator passes, and `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`
      finds nothing.

## Out of scope
- `docs/` placement (stays at root).
- The `hubnode`/`subnode` names.
- Moving any repo other than this one; Daisy and the metarepo update themselves after release.

## Touches
- `marketing/FEATURES.md`: a row per NEXT, before code.
- `plugin/templates/jig/jig.py`: `LAYOUT` rows for claude-lane and `REVIEW_LEDGER.md`; the board
  split (`CONFIG`, `JOBS` in place of `BOARD`), job records, derived branch/worktree,
  delete-on-merge, no `next`, no `log`; renames throughout; `STAMP` 7.
- `plugin/templates/jig/RULES.md`, `plugin/templates/AGENTS.md`, `README.md`.
- Skills: `brief` → `spec` (folder rename), `hubnode`, `subnode`, `adopt`, `init`, `survey`,
  `update`, `feedback`.
- `tests/smoke.sh`, new `tests/fixtures/`.

## Stages
One spec, three commits, one release. Each stage leaves smoke green.
1. **Migrations into today's names**: claude-lane, `REVIEW_LEDGER.md`, root `HARDWARE.md`,
   removals listed in the dry run. Fixtures.
2. **Board split and job records**: config/jobs, derived fields, delete on merge, no `next`, no
   `log`, `STAMP` 7, and the update step that splits a v6 board.
3. **Renames**: lane → job, brief → spec, payload → not_docs, HOMES → DOC_HOMES.

## Alternatives considered
- Derive branch and worktree from `git worktree list` alone. Rejected: worktree state is
  local to one machine and the subnode's session controls it, so a session could grant itself
  files, and a job can hold reserved numbers before any worktree exists. `[seen]`: the story's
  reasoning, and `jig open --reserve` writes the reservation before the worktree.
- Rename in place and keep `lanes.json` whole. Rejected by the owner: one file does two jobs,
  settings that change rarely and open work that churns. `[seen]`, the story.
- Ship renames before the migration steps. Rejected: a release where the plugin says "job" and
  `update` still writes `lanes.json`. `[seen]`, the story.

## Decisions
- `update` already refuses while lanes are open, so splitting the board never carries open
  work: merged entries are dropped and `jobs.json` starts empty. `[seen]`: `update`'s refusal.

- Owner, Oct 29:
  - **Adopted branches.** A job's branch is its name, and its worktree is under
    `.git/jig/worktrees/`. A job adopted on an existing branch, or with its worktree elsewhere
    (`.claude/worktrees/x`), stores only the value that differs, and R2 reads that.
  - **Counters need a `pattern` and `files`,** because with no `next` the pattern is how jig
    knows what's next. `update` names any counter that lacks them and refuses until it has
    them.
  - **Staging and release are their own spec, `release.md`.** `release.md` takes staging off
    `gate` and makes drop record nothing, which removes the last board-log writes outside
    this spec.
