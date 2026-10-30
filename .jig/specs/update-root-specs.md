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
| Markdown-only splits a subfolder from its other files | [seen] README moves, `t.rs` stays | jig's: the split is jig's doing | A mixed subfolder is never split. It stays whole unless the run names it with `--move`, decided with the user. See below |
| `cd "$(dirname "$0")/.."` is wrong after `scripts/` → `.jig/scripts/` | [seen] no template generation (`eaec973`, `66a044c`, `62c8d9f`, `5d955a2`, now) wrote that line | The line is the repo's. jig's part: its move breaks the line, and the dry run is silent | Warning: a moved non-Markdown file whose folder depth changed, with its lines that use its own location (`$0`, `BASH_SOURCE`, `__file__`, `__dirname`). The skill offers the edit; `jig.py` never makes it |
| Worktrees stranded by a repo folder rename | [seen] the refusal's own advice, `git worktree remove <old path>`, exits 0, drops git's record, and leaves the checkout on disk. Once the record is gone, `repair` and `remove` both fail on it | jig's: the advice is wrong for this case | Advice per case, below |
| The old `worktrees/` ignore line goes while folders remain | [seen] `ignore_lines` reads only `.gitignore` | jig's | Folders left in an old worktrees folder refuse, below |
| The stale-reference report prints only on `--apply`; nothing rewrites | [seen] false: the dry run prints it. But a refusal returns before the plan is printed, so a repo with worktrees never sees one | Rewriting is the repo's: update.md puts editing the repo's files out of scope, and the skill already offers it. Hiding the plan is jig's | A refusing dry run prints the refusal, then the plan and report (Subfolders to decide included), and still exits 2. A refusing `--apply` prints the refusal only |

**Mixed subfolders: `jig.py` gathers, the skill judges, `--move` moves.**

`jig.py` (applies only under an old board, `root_is_jigs`):
- A mixed subfolder is an immediate subfolder `<sub>` of root `specs/` or `ledgers/` that holds both Markdown and non-Markdown files, at any depth.
- It stays whole by default; nothing in it moves, Markdown included.
- Today's behaviour stays for the rest:
  - a subfolder with no Markdown stays, each file warned "isn't Markdown";
  - a Markdown-only subfolder moves per file, like top-level Markdown.
- The dry run and `--apply` both list each mixed subfolder under **Subfolders to decide**, one line each, and each line is a warning. The line looks like:

  `specs/<sub>/: named by N specs, N lane briefs, N handoff notes; files .md N, .rs N; named by code: <file>:<line>, … (or none); --move specs/<sub>`

  - "Specs" are top-level Markdown files in the same root folder that carry the template's `## Intent` and `## Done when`; every generation's template has both.
  - "Code" is any tracked non-Markdown file outside the subfolder and outside jig's old folder, comment lines included. It is the same scan as `stale_references`.
- "Names" means `specs/<sub>` (or `ledgers/<sub>`) at the stale-reference boundary, followed by `/` or end of token. So `specs/suite2/` never names `specs/suite`, and `specs/**` names no subfolder.
- A held subfolder counts as files left behind for the board rule below. A glob under it (`specs/<sub>/**`) is left as written.

`--move <root>/<sub>`, repeatable (`action="append"`); a trailing `/` and a leading `./` are dropped:
- It moves that subfolder whole into the plan, file by file, `R100`, Markdown or not.
- Board globs, collisions and stale references are worked out with it, as for any other move.
- It is checked before anything else runs, including the up-to-date path. These exit 2 with `refused: --move …` on stderr and change nothing:
  - a path that is not a mixed subfolder of the plan;
  - a subfolder with a file already at its destination (the message names that file);
  - a repo already current. The message says: "update has run; move it with `git mv` in the update commit, and fix what names it".

The update skill orders the steps so the user sees every plan before it is applied:
1. Dry run.
2. For each subfolder to decide, read its README, its files and the evidence line. Say in one line whether it is jig's task material or the repo's own (tests, fixtures, a runner's input). Ask. When unsure, say so and recommend leaving it.
3. Dry run again with the chosen `--move` flags. This run shows the new moves and the stale references they make.
4. The usual ask.
5. `--apply` with the same `--move` flags.

A `refused: --move` exit 2 goes back to step 2 for that subfolder. It is not a block, so no `/jig:feedback` draft.

Checked against the reporting repo's last ai-dev commit [seen]:
- `specs/prework/` is named by 18 top-level specs (all carry both headings), 9 lane briefs and 21 handoff notes.
- Its READMEs say what it is, e.g. "the lane copies … verbatim".
- Code naming it: only the board, which isn't counted.

The skill has what it needs to recommend `--move specs/prework`.

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
- Where files stayed behind, the board keeps the old glob beside the new one. Files left behind means colliding files and held subfolders only. A top-level non-Markdown file filtered out today (`specs/app.spec.js`) doesn't count, so `common`'s `specs/**` is rewritten as today.
- A reference is stale only when the path it names no longer exists after the moves. For a glob or a folder, the path is its prefix up to the first wildcard.
- Board briefs that name moved paths stay as written: like the board's `log`, they are history.

## Done when
`bash tests/smoke.sh` passes with these new cases. Each runs on the ai-dev fixture unless a case says otherwise:
- [ ] Root `specs/a.md` and `specs/b.md`, plus a tracked `.jig/specs/b.md`.
  - `update --apply` moves `a.md` (`R100`) and leaves `specs/b.md`.
  - One warning names `specs/b.md`, and `.jig/specs/b.md` is unchanged.
  - The board's `common` holds both `specs/**` and `.jig/specs/**`.
  - A file naming `specs/b.md` is not listed as stale.
- [ ] The fixture: root `specs/top.md` (with both headings), `specs/app.spec.js`, `specs/suite/README.md` and `specs/suite/t.rs`.
  - `top.md` names `specs/suite/t.rs` and `specs/suite2/x`.
  - A merged lane's brief names `specs/suite/`, and its `owns` holds `specs/suite/**`.
  - `Makefile` has `cat specs/suite/t.rs`.
  - `specs/notes/n.md` is the only file in `specs/notes/`.
  - The dry run prints exactly: `specs/suite/: named by 1 specs, 1 lane briefs, 0 handoff notes; files .md 1, .rs 1; named by code: Makefile:1; --move specs/suite`. `specs/notes/` is not listed.
  - `--apply` prints the same line. `top.md` and `specs/notes/n.md` move; `specs/suite/` and `app.spec.js` stay untouched.
  - The board's `common` holds both `specs/**` and `.jig/specs/**`, and the lane's `owns` still says `specs/suite/**`.
  - `top.md` is not listed as stale for `specs/suite/t.rs`.
  - After the commit, `--move specs/suite` exits 2 with "update has run".
- [ ] The same fixture with `--move specs/suite/`:
  - The dry run lists both `specs/suite/` files under Moves, and lists `.jig/specs/top.md` and `Makefile` as stale for `specs/suite/t.rs`.
  - `--apply --move specs/suite` moves both, `R100`.
- [ ] `--move specs/nope` exits 2 and names it. So does `--move specs/suite` with a tracked `.jig/specs/suite/README.md`: it names that file, `--apply` changes nothing, and `git status --porcelain` is the same before and after.
- [ ] Root `ledgers/old/README.md` and `ledgers/old/data.csv`, and nothing else to warn about. The dry run exits 1 and lists `ledgers/old/`. `--move ledgers/old --apply` moves both under `.jig/ledgers/old/`.
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
- [ ] `grep -n 'Subfolders to decide' plugin/skills/update/SKILL.md` finds the skill's step.
- [ ] `claude plugin validate ./plugin` passes, and `grep -rniE 'prework|maige' plugin` finds nothing. Smoke's fixtures use generic names (`specs/suite/`).

## Out of scope
- `jig.py` editing the repo's files: stale references, script lines (update.md, Out of scope).
- `jig.py` deciding whether a mixed subfolder is jig's.
- `update` running `git worktree repair`, `remove` or `prune` itself.
- Moving a non-Markdown file from the top level of a root `specs/` or `ledgers/`.
- P2 and the para rules. The report's P2 concern goes away once the move is per file.

## Touches
- `plugin/templates/jig/jig.py`:
  - `plan_moves`:
    - the per-file check for every folder row;
    - mixed subfolders held whole, with their evidence;
    - `--move` subfolders moved whole.

    The comment at the filter says why a subfolder differs from the top level.
  - `rewrite_board`: keeps the old glob when files stay.
  - `stale_references`: a reference to a path that still exists is not stale.
  - `cmd_update`:
    - `--move`;
    - the "Subfolders to decide" section;
    - the worktree refusal, per case;
    - the depth warning;
    - the plan printed under a refusing dry run;
    - an untracked staging or cache file whose destination is taken is now warned, not skipped silently.
  - No `LAYOUT` row, board default or `STEPS` entry, so no `STAMP` bump.
- `main`: `--move` on the `update` subparser.
- `plugin/skills/update/SKILL.md`:
  - the "Subfolders to decide" steps, in order;
  - `refused: --move` in the exit-code list;
  - the refusal advice;
  - after `--apply`, a depth warning is code to fix, like a stale reference.
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
- Leave a mixed subfolder for a hand `git mv`. Rejected by the owner, Oct 30: "update should move it". [seen]
- Move any subfolder that holds Markdown. Rejected by the owner, Oct 30: "not any specs folder, just one that's clearly a jig spec folder". [seen]
- Let `jig.py` decide by heuristics: jig records claim a folder, and test-named files or code references veto the claim. Rejected after three review rounds. Each round found a repo whose test folder still moves:
  - fixtures read from a sibling test file;
  - `.rspec` lines that start with `--` and read as comments;
  - `*_spec.rb`, `__tests__/`, mocha's default `./test`.

  Whether the repo's tooling reads a folder is open-ended. Telling a lane's material from a test folder takes reading it, which the skill does with the user. [seen] Reviews of `cec238f` and `16178af`.
- Judge the top level of `specs/` as a whole, the way a subfolder is judged. Rejected: specs were always written flat (`specs/<task>.md`), so at the top level each file is judged alone. [seen] Every generation's brief skill.
- Per file only for the root `specs/` and `ledgers/` rows. Rejected: `jig/specs/` would keep the folder-level rule, an asymmetry with no reason behind it. update.md's Decision is per file for every row. [seen]
- `update` rewrites `/..` to `/../..` in moved scripts. Rejected:
  - `update` renames and never edits, and smoke asserts `R100`;
  - the line was never jig's.

  [seen] update.md Decisions; the five template generations.
- `update` runs `git worktree repair` and `remove` itself. Rejected:
  - a dry run changes nothing;
  - removal needs someone to look at uncommitted work first;
  - jig never removes a worktree.

  [seen] update.md Decisions.
- Leftover worktree folders as a warning, with the ignore line kept. Rejected: they are checkouts, possibly with uncommitted work, and update already refuses on extra worktrees for this reason, with a fix the user knows. [seen] update.md Decisions, "Refusals".

## Decisions
- Owner, Oct 30:
  - `update` moves a mixed subfolder of root `specs/` or `ledgers/` whole, but only one that is clearly jig's, judged from its contents and context.
  - `jig.py` stays deterministic: it gathers the evidence and moves on `--move`. The skill reads the folder and decides with the user. It is like update.md's repo files to review, except that `jig.py` carries out the move, so the plan, the board and the stale references stay one computation.
  - When in doubt, a subfolder stays. Decided before `--apply`, that costs a rerun. After it, it costs a `git mv` in the update commit, which the refusal names. A test folder that moves would simply stop running.
  - This supersedes the Oct 29 review decision in `update.md` that a root `specs/` or `ledgers/` moves only its Markdown, for mixed subfolders. Top-level files and Markdown-only subfolders keep that rule.
- Each refusal names the exact command for the case it sees. `update` runs none of them.
- The depth warning covers any moved non-Markdown file, not only shell scripts. A false positive costs one warning line.

## Open questions
1. Should the stale-reference report be retrievable after the update commit? Once the board is current, a re-run says "up to date". This spec leaves it to the skill, before the commit.
