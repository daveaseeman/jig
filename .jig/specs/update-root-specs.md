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
| Markdown-only splits a subfolder from its other files | [seen] README moves, `t.rs` stays | jig's: the split is jig's doing | A subfolder is never split. It moves whole when it is clearly jig's, and otherwise stays whole. See below. Files at the top level are judged as today |
| `cd "$(dirname "$0")/.."` is wrong after `scripts/` → `.jig/scripts/` | [seen] no template generation (`eaec973`, `66a044c`, `62c8d9f`, `5d955a2`, now) wrote that line | The line is the repo's. jig's part: its move breaks the line, and the dry run is silent | Warning: a moved non-Markdown file whose folder depth changed, with its lines that use its own location (`$0`, `BASH_SOURCE`, `__file__`, `__dirname`). The skill offers the edit; `jig.py` never makes it |
| Worktrees stranded by a repo folder rename | [seen] the refusal's own advice, `git worktree remove <old path>`, exits 0, drops git's record, and leaves the checkout on disk. Once the record is gone, `repair` and `remove` both fail on it | jig's: the advice is wrong for this case | Advice per case, below |
| The old `worktrees/` ignore line goes while folders remain | [seen] `ignore_lines` reads only `.gitignore` | jig's | Folders left in an old worktrees folder refuse, below |
| The stale-reference report prints only on `--apply`; nothing rewrites | [seen] false: the dry run prints it. But a refusal returns before the plan is printed, so a repo with worktrees never sees one | Rewriting is the repo's: update.md puts editing the repo's files out of scope, and the skill already offers it. Hiding the plan is jig's | A refusing dry run prints the refusal, then the plan and report, and still exits 2. A refusing `--apply` prints the refusal only |

**Is a subfolder jig's?** This applies to each immediate subfolder `<sub>` of root `specs/` or `ledgers/`, only under an old board (`root_is_jigs`), whatever its files are.
- **Claimed**, any one of:
  - A jig record names a path inside it: a lane's `brief` on the board, or a handoff note under the handoffs row's old paths (`.aidev/handoffs/`, `jig/handoffs/`, `.jig/handoffs/`).
  - A jig spec names a path inside it. A jig spec is a top-level Markdown file in the same root folder that carries the template's `## Intent` and `## Done when` headings; every generation's template has both. It counts whether the spec moves or collides and stays.
  - A Markdown file in the subfolder, at any depth, carries those headings.
  - Not counted: lane `owns`/`shares`, `common`, `docmap`. Those name the repo's code.
- **Used by the repo**, any one of:
  - A file in it is named like a test a runner finds by default: `*.spec.*`, `*.test.*`, `test_*`, `*_test.*`.
  - A non-comment line (the `COMMENT` prefixes) in a tracked file names the root folder or the subfolder. The file counts if it is not Markdown, decodes as text, is outside the root folder, and is not jig's: not the old jig folder, the board, `.gitignore` or `.gitattributes`.
- **Names** means `specs` (or `ledgers`):
  - not preceded by a word character, `.` or `-` (a leading `/` is allowed, so `<rootDir>/specs/unit` counts);
  - then either the root folder, followed by end of token or a wildcard: `specs`, `specs/`, `specs/**`;
  - or `/<sub>`, followed by `/` or end of token, so `specs/suite2/` never names `specs/suite`.

  End of token is a quote, whitespace, `,`, `)`, `]` or end of line.
- A subfolder that is claimed and not used moves whole. A warning names it and its claim, so the dry run exits 1. It is `R100`, file by file, Markdown or not.
- Otherwise it stays whole, warned once with the reason: "not claimed", or "used: `<file>:<line>`". A user who knows better moves it with `git mv`. Every "used" mistake fails safe this way, another tool's JSON among them.
- A collision anywhere in the subfolder keeps it whole at the root, warned once.
- Board briefs that name moved paths stay as written. Like the board's `log`, they are history.

Checked against the reporting repo's last ai-dev commit [seen]:
- **Claimed:**
  - all 21 top-level specs carry both headings, and 18 of them name paths inside `specs/prework/`;
  - so do 9 lane briefs and 21 handoff notes.
- **Not used:**
  - no file in it is test-named;
  - outside the board, no non-Markdown file names it or root `specs`, except in comments.
- So it moves.

A JS repo's `specs/unit/` holding `login.spec.js` is the opposite case. Its files are test-named, so the folder stays even when a jig spec touched one of them.

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
- A reference is stale only when the path it names no longer exists after the moves. For a glob or a folder, the path is its prefix up to the first wildcard. So a runner's `specs/**/*.spec.js` stays quiet while `specs/` remains. A runner that names a subfolder keeps that subfolder at the root ("used by the repo").

## Done when
`bash tests/smoke.sh` passes with these new cases. Each runs on the ai-dev fixture unless a case says otherwise:
- [ ] Root `specs/a.md` and `specs/b.md`, plus a tracked `.jig/specs/b.md`.
  - `update --apply` moves `a.md` (`R100`) and leaves `specs/b.md`.
  - One warning names `specs/b.md`, and `.jig/specs/b.md` is unchanged.
  - The board's `common` holds both `specs/**` and `.jig/specs/**`.
  - A file naming `specs/b.md` is not listed as stale.
- [ ] One ai-dev fixture with root `specs/top.md`, `specs/app.spec.js`, and subfolders, each holding a `README.md` and one `.rs` file unless the item says otherwise. `top.md` carries `## Intent` and `## Done when`, and names `specs/suite/t.rs`, `specs/suite2/u.rs` and `specs/unit/login.spec.js`.
  - `specs/suite/` is named by `top.md`.
  - `specs/suite2/` is named by `top.md` and by a non-comment `Makefile` line, `cat specs/suite2/u.rs`.
  - `specs/deep/` is named by a lane's `brief`, with its Markdown one level down (`specs/deep/a/n.md`).
  - `specs/tpl/` is named by nothing; `specs/tpl/a/plan.md` has both headings.
  - `specs/unit/` holds `login.spec.js` instead of the `.rs` file, and is named by `top.md`.
  - `specs/misc/` is named by nothing.
  - `specs/notes/` is Markdown only and named by nothing.
  - `specs/cmt/` is named by `top.md` and by a `.py` file, only in a `#` comment.

  Expected:
  - `top.md` moves, and so do `specs/suite/`, `specs/deep/`, `specs/tpl/` and `specs/cmt/`, each file `R100`.
  - The dry run exits 1, with one warning per moved subfolder naming its claim.
  - These stay whole, each warned once:
    - `specs/suite2/`: used, `Makefile:<n>`;
    - `specs/unit/`: used, `login.spec.js`;
    - `specs/misc/` and `specs/notes/`: not claimed.
  - `app.spec.js` stays, with today's warning.
  - A file naming `specs/suite/t.rs` is listed as stale.
- [ ] The same with a tracked `.jig/specs/suite/README.md`: all of `specs/suite/` stays, with one warning naming it.
- [ ] The same with a `package.json` holding `"test": "mocha --recursive specs"`. It names the root folder, so every subfolder stays, each with a warning: used, `package.json:<n>`.
- [ ] Root `ledgers/old/README.md` and `ledgers/old/data.csv`, named by a note in `.aidev/handoffs/`, both move under `.jig/ledgers/old/`.
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
- Moving a non-Markdown file from the top level of a root `specs/` or `ledgers/`. Only a subfolder that is clearly jig's moves non-Markdown.
- P2 and the para rules. The report's P2 concern goes away once the move is per file.

## Touches
- `plugin/templates/jig/jig.py`:
  - `plan_moves`: the per-file check for every folder row; whole-subfolder judgment by claim and use. It takes the board and reads the tracked files to find them. The comment at the filter says why a subfolder differs from the top level.
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
- Move any subfolder that holds Markdown. Rejected by the owner, Oct 30: "not any specs folder, just one that's clearly a jig spec folder". A README in a test folder doesn't make the folder jig's. [seen]
- Judge the top level of `specs/` whole too, the way a subfolder is judged. Rejected: specs were always written flat (`specs/<task>.md`), so at the top level each file is judged alone. A subfolder is one unit. [seen] Every generation's brief skill.
- Claim by jig's references alone, with no "used by the repo" veto. Rejected: a jig spec routinely names the test files a lane touched, so a test folder would move away from its runner. The veto costs one warning and a hand `git mv` in the rare case of a jig folder that the repo's code also reads. [seen] The reporting repo's specs name test paths, and a jig spec's Touches section exists to name files. See open question 2.
- Count lane `owns`/`shares` as a claim. Rejected: they name the repo's own code, which is exactly what a lane changes. [seen] update.md's board, `owns`.
- Recognize a test folder only by a runner config naming it. Rejected: default discovery (jest, mocha, pytest) finds tests by file name and names no folder. [seen] Hence the test-name signal.
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
- Owner, Oct 30:
  - `update` moves a subfolder of root `specs/` or `ledgers/` whole, its other files included, but only when it is clearly jig's. That is judged from its contents and from what names it, as above. When in doubt it stays: a jig folder left at the root costs one `git mv`, while a test folder that moves stops running.
  - Every other subfolder stays whole. This includes a Markdown-only subfolder nothing claims, which `update` moves today.
  - This supersedes the Oct 29 review decision in `update.md` that a root `specs/` or `ledgers/` moves only its Markdown. That still holds at the top level.
- Each refusal names the exact command for the case it sees. `update` runs none of them.
- The depth warning covers any moved non-Markdown file, not only shell scripts. A false positive costs one warning line.

## Open questions
1. Should the stale-reference report be retrievable after the update commit? Once the board is current, a re-run says "up to date". This spec leaves it to the skill, before the commit.
2. A subfolder jig claims that the repo's own code also names: stay (this spec, warned), or move, with the code's reference reported as stale?
