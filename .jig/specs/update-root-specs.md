# `jig update`: folder collisions, mixed subfolders, files moved deeper, stranded worktrees

Source: an adopting repo's report on running `jig update` from an ai-dev layout; it recovered by
hand and put jig out of scope. This is the jig side.

## Intent
A repo that reaches `update` with any of these gets a working update, or a refusal that names the
exact fix:
- a pre-written `.jig/specs/` file,
- a root `specs/` subfolder of mixed files,
- a moved script that finds paths from its own folder,
- lane checkouts left behind by a repo folder rename.

Nothing needs a hand-written recovery.

## The report's candidates, checked against `plugin/templates/jig/jig.py` at `bb1eb98`
Each checked in a scratch ai-dev repo with today's template `update`.

| Candidate | Checked | Whose | What changes |
|---|---|---|---|
| A tracked `.jig/specs/` file stops the whole root `specs/` move | [seen] "both left, not merged". The check is folder-level (`free`, in `plan_moves`) | jig's: update.md's Decision is per file ("old path exists and new one doesn't") | Per file, for every folder row. A file moves when its destination is free. A file at both paths stays, and is warned by name |
| Markdown-only splits a subfolder from its other files | [seen] README moves, `t.rs` stays | jig's: the split is jig's doing | An immediate subfolder of root `specs/` or `ledgers/` that holds any Markdown, at any depth, moves whole, its other files included. A warning names it, so the dry run exits 1. If any file in it collides, the whole subfolder stays, warned once: it is never split. A subfolder with no Markdown, and non-Markdown files at the top level, stay as today |
| `cd "$(dirname "$0")/.."` is wrong after `scripts/` → `.jig/scripts/` | [seen] no template generation (`eaec973`, `66a044c`, `62c8d9f`, `5d955a2`, now) wrote that line | The line is the repo's. jig's part: its move breaks the line, and the dry run is silent | Warning: a moved non-Markdown file whose folder depth changed, with its lines that use its own location (`$0`, `BASH_SOURCE`, `__file__`, `__dirname`). The skill offers the edit; `jig.py` never makes it |
| Worktrees stranded by a repo folder rename | [seen] the refusal's own advice, `git worktree remove <old path>`, exits 0, drops git's record, and leaves the checkout on disk. Once the record is gone, `repair` and `remove` both fail on it | jig's: the advice is wrong for this case | Advice per case, below |
| The old `worktrees/` ignore line goes while folders remain | [seen] `ignore_lines` reads only `.gitignore` | jig's | Folders left in an old worktrees folder refuse, below |
| The stale-reference report prints only on `--apply`; nothing rewrites | [seen] false: the dry run prints it. But a refusal returns before the plan is printed, so a repo with worktrees never sees one | Rewriting is the repo's: update.md puts editing the repo's files out of scope, and the skill already offers it. Hiding the plan is jig's | A refusing dry run prints the refusal, then the plan and report, and still exits 2. A refusing `--apply` prints the refusal only |

**Worktree refusal, per case.**
- It reads git's records (`.git/worktrees/<id>/gitdir`) and the folders in the old worktrees folder (`.aidev/worktrees/`, or `.jig/worktrees/` beside an older board) and in `.git/jig/worktrees/`.
- Like the other refusals, it fires only when there is something to apply.
- Each case gets its own line:
  - A record whose path exists: `git worktree remove <path>`. This is today's advice.
  - A record whose path is gone, with a folder whose `.git` file names that record's id: it moved with the repo. `git worktree repair <folder>`, then `git worktree remove <folder>`.
  - A record whose path is gone, with no such folder: `git worktree prune`.
  - A folder in an old worktrees folder whose record is gone, or that has no `.git` file: "not a checkout git knows: look, then delete it". jig deletes nothing.

**A partly moved folder row.**
- A row counts as applied when at least one file moved.
- Where files stayed behind, the board keeps the old glob beside the new one.
- A reference is stale only when the path it names no longer exists after the moves. For a glob or a folder, the path is its prefix up to the first wildcard. So a runner's `specs/**/*.spec.js` stays quiet while `specs/` remains, and the moved-subfolder warning is what catches it.

## Done when
`bash tests/smoke.sh` passes with these new cases. Each runs on the ai-dev fixture unless a case says otherwise:
- [ ] Root `specs/a.md` and `specs/b.md`, plus a tracked `.jig/specs/b.md`.
  - `update --apply` moves `a.md` (`R100`) and leaves `specs/b.md`.
  - One warning names `specs/b.md`, and `.jig/specs/b.md` is unchanged.
  - The board's `common` holds both `specs/**` and `.jig/specs/**`.
  - A file naming `specs/b.md` is not listed as stale.
- [ ] Root `specs/top.md`, `specs/app.spec.js`, `specs/suite/README.md`, `specs/suite/t.rs`, `specs/unit/x.spec.js`, `specs/deep/t.rs` and `specs/deep/a/n.md`.
  - `top.md`, all of `specs/suite/` and all of `specs/deep/` move, each `R100`.
  - The dry run exits 1, with one warning each for `specs/suite/` and `specs/deep/`.
  - `app.spec.js` and `specs/unit/` stay, each with today's warning.
  - A file naming `specs/suite/t.rs` is listed as stale.
- [ ] The same with a tracked `.jig/specs/suite/README.md`: all of `specs/suite/` stays, with one warning naming it.
- [ ] Root `ledgers/old/README.md` and `ledgers/old/data.csv` both move under `.jig/ledgers/old/`.
- [ ] A tracked `scripts/check.sh` with `cd "$(dirname "$0")/.."`.
  - The dry run exits 1, and a warning names `.jig/scripts/check.sh` with that line.
  - The existing fixtures' scripts raise no such warning.
- [ ] A worktree at `.aidev/worktrees/l1`, then the repo folder renamed.
  - The dry run exits 2, and its output contains both `git worktree repair .aidev/worktrees/l1` and `Moves`.
  - Run the printed commands, then `update --apply`, then commit. `git status --porcelain --untracked-files=all` is empty, and `.aidev` is gone.
- [ ] The same, after `git worktree remove <old path>` has dropped the record.
  - The refusal names `.aidev/worktrees/l1` as not a checkout git knows.
  - `--apply` exits 2, and `.gitignore` is unchanged.
- [ ] An untracked `.aidev/worktrees/x/f` with no `.git` file: the dry run and `--apply` exit 2 and name it.
- [ ] A worktree whose folder was deleted by hand: the refusal says `git worktree prune`.
- [ ] On the eaec973 `dot` fixture, a folder in `.jig/worktrees/` refuses the same way.
- [ ] The existing case "jig/specs/ and .jig/specs/ both exist, so neither moves" now expects `jig/specs/_template.md` to move and `.jig/specs/new.md` to stay.
- [ ] `claude plugin validate ./plugin` passes, and `grep -rniE 'prework|maige' plugin` finds nothing. Smoke's fixtures use generic names (`specs/suite/`).

## Out of scope
- `jig.py` editing the repo's files: stale references, script lines (update.md, Out of scope).
- `update` running `git worktree repair`, `remove` or `prune` itself.
- Moving non-Markdown out of a root `specs/` or `ledgers/`, except inside a subfolder that holds Markdown.
- P2 and the para rules. The report's P2 concern goes away once the move is per file.

## Touches
- `plugin/templates/jig/jig.py`:
  - `plan_moves`: the per-file check for every folder row; a subfolder with Markdown moves whole. The comment at the filter says why a subfolder differs from the top level.
  - `rewrite_board`: keeps the old glob when files stay.
  - `stale_references`: a reference to a path that still exists is not stale.
  - `cmd_update`:
    - the worktree refusal, per case;
    - the depth warning;
    - the plan printed under a refusing dry run;
    - an untracked staging or cache file whose destination is taken is now warned, not skipped silently.
  - No `LAYOUT` row, board default or `STEPS` entry, so no `STAMP` bump.
- `plugin/skills/update/SKILL.md`:
  - The refusal advice.
  - After `--apply`, a depth warning is code to fix, like a stale reference.
- `plugin/skills/adopt/SKILL.md`: the same worktree advice, per case. It gives today's `git worktree remove <path>` too.
- `tests/smoke.sh`.
- `marketing/FEATURES.md` (main checkout, ignored): a clause in the `update` row's "what". No new feature.

**Collision with lane `names`.** It edits the same places:
- functions: `LAYOUT` (claude-lane, `REVIEW_LEDGER.md` and root `HARDWARE.md` rows), `plan_moves`, `cmd_update`'s refusals (new ones for counters without a pattern);
- names used everywhere: `BOARD` → `CONFIG`/`JOBS`, lane → job, `/jig:brief` → `/jig:spec`;
- files: `smoke.sh` and the update and adopt skills.

Its new rows are file rows, and the per-file rule here changes how folder rows decide. The logic doesn't conflict, but the text does. Build this after `names` merges, in its words. This spec is the smaller one to rebase.

## Alternatives considered
- Move all of a root `specs/` under an old board, non-Markdown included. Rejected: the filter exists so a repo's own top-level test files (`specs/app.spec.js`) never move. [seen] The comment at the filter in `plan_moves`, and update.md's Oct 29 review.
- Leave a mixed subfolder whole at the root, and let the repo `git mv` it by hand. Rejected by the owner, Oct 30: "update should move it". [seen]
- Judge the top level of `specs/` whole too, the way a subfolder is judged. Rejected: specs were always written flat (`specs/<task>.md`), so at the top level each file is judged alone. A subfolder is one unit. [seen] Every generation's brief skill. That Markdown in a subfolder marks it as task material is the owner's call, below, not an observation.
- Per file only for the root `specs/` and `ledgers/` rows. Rejected: `jig/specs/` would keep the folder-level rule, an asymmetry with no reason behind it. update.md's Decision is per file for every row. [seen]
- `update` rewrites `/..` to `/../..` in moved scripts. Rejected:
  - `update` renames files and never edits them, and smoke asserts `R100`;
  - the line was never jig's.

  [seen] update.md Decisions; the five template generations.
- `update` runs `git worktree repair` and `remove` itself. Rejected:
  - a dry run changes nothing;
  - removal needs someone to look at uncommitted work first;
  - jig never removes a worktree.

  [seen] update.md Decisions.
- Leftover worktree folders as a warning, with the ignore line kept. Rejected: they are checkouts, possibly with uncommitted work, and update already refuses on extra worktrees for this reason, with a fix the user knows. [seen] update.md Decisions, "Refusals".

## Decisions
- Owner, Oct 30: a subfolder of root `specs/` or `ledgers/` that holds Markdown moves whole under `.jig/`, its other files included. A subfolder with no Markdown is the repo's own, and stays. This supersedes the Oct 29 review decision in `update.md` that a root `specs/` or `ledgers/` moves only its Markdown; that still holds at the top level. The risk is a repo's own test subfolder that carries a README. It moves, so each moved subfolder is warned by name and the skill puts it to the user before `--apply`.
- Each refusal names the exact command for the case it sees. `update` runs none of them.
- The depth warning covers any moved non-Markdown file, not only shell scripts. A false positive costs one warning line.

## Open questions
1. Should the stale-reference report be retrievable after the update commit? Once the board is current, a re-run says "up to date". This spec leaves it to the skill, before the commit.
