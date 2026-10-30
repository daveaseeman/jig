# `jig update`: root `specs/` collisions, mixed subfolders, scripts moved down, stranded worktrees

Source: an adopting repo's report on running `jig update` from an ai-dev layout; it recovered by
hand and put jig out of scope. This is the jig side.

## Intent
A repo that reaches `update` with a pre-written `.jig/specs/` file, a root `specs/` subfolder of
mixed files, a script that finds the repo root from its own folder, or lane worktrees left behind by
a folder rename gets a working update, or a refusal that names the exact fix. Nothing needs a
hand-written recovery.

## The report's candidates, checked against `plugin/templates/jig/jig.py` at `bb1eb98`
Each checked in a scratch ai-dev repo with today's template `update`.

| Candidate | Checked | Whose | What changes |
|---|---|---|---|
| A tracked `.jig/specs/` file stops the whole root `specs/` move | [seen] "both left, not merged" | jig's: update.md's own rule is per file ("old path exists and new one doesn't"); the folder-level check is coarser than that | Per file: a file moves when its destination is free. A file at both paths stays, and the warning names it |
| Markdown-only splits `specs/prework/` from its other files | [seen] README moves, `t.rs` stays | jig's: jig's move does the splitting | A subfolder of root `specs/` or `ledgers/` holding any non-Markdown file, at any depth, stays whole, Markdown included. One warning names it and gives the `git mv` that moves it whole. Non-Markdown still never moves |
| `cd "$(dirname "$0")/.."` is wrong after `scripts/` → `.jig/scripts/` | [seen] no template generation (`eaec973`, `66a044c`, `62c8d9f`, `5d955a2`, now) wrote that line | The line is the repo's. jig's part: its move breaks the line, and the dry run says nothing | Warning: a moved file whose folder depth changed and that has a line building a path from its own location (`$0`, `BASH_SOURCE`, `__file__`, `__dirname`) with `..`. The warning shows the line. The skill offers the edit; `jig.py` never makes it |
| Worktrees stranded by a repo folder rename | [seen] the refusal's own advice, `git worktree remove <old path>`, exits 0, drops git's record, and leaves the checkout on disk | jig's: the advice is wrong for this case | A registered worktree whose path is gone (`prunable`), with a folder in the repo whose `.git` file names that record: the refusal says `git worktree repair <folder>`, then `git worktree remove <folder>`. Prunable with no such folder: `git worktree prune` |
| The old `worktrees/` ignore line goes while folders remain | [seen] `ignore_lines` never looks at the disk | jig's | Any folder inside an old worktrees folder (`.aidev/worktrees/`, or `.jig/worktrees/` beside an older board) is a refusal. A folder with a `.git` file gets the advice above. Any other folder gets "not a checkout git knows: look, then delete it". jig deletes nothing |
| The stale-reference report prints only on `--apply`; nothing rewrites | [seen] false: the dry run prints it. But a refusal returns before the plan, so a repo with worktrees never sees a plan at all | Rewriting is the repo's: update.md puts editing the repo's files out of scope, and the skill already offers it. Hiding the plan is jig's | A dry run that refuses prints the refusal, then the plan and the report, and still exits 2. `--apply` that refuses prints the refusal only |

## Done when
`bash tests/smoke.sh` gains these cases, each on the ai-dev fixture, and passes:
- [ ] Root `specs/a.md`, `specs/b.md`, and a tracked `.jig/specs/b.md`. `update --apply` moves `a.md` (`R100`) and leaves `specs/b.md`. One warning names `specs/b.md`, and `.jig/specs/b.md` is unchanged.
- [ ] `specs/top.md`, `specs/app.spec.js`, `specs/prework/README.md` and `specs/prework/t.rs`. `top.md` moves and the other three stay. One warning names `specs/prework/` with `git mv specs/prework .jig/specs/prework`. A moved spec that names `specs/prework/t.rs` is not listed under stale references.
- [ ] A tracked `scripts/check.sh` with `cd "$(dirname "$0")/.."`. The dry run exits 1, and a warning names `.jig/scripts/check.sh` and shows that line. The existing fixtures' scripts raise no such warning.
- [ ] A worktree at `.aidev/worktrees/l1`, then the repo folder renamed. The dry run exits 2 and its refusal contains `git worktree repair .aidev/worktrees/l1`. Run the printed commands, then `update --apply`, then commit: `git status --porcelain --untracked-files=all` is empty, and `.aidev` is gone.
- [ ] An untracked, unregistered `.aidev/worktrees/x/f`. The dry run and `--apply` both exit 2 and name `.aidev/worktrees/x`, and `.gitignore` is unchanged.
- [ ] With an extra worktree, the dry run prints the refusal and then `Moves`, and exits 2. `--apply` prints no `Moves`.
- [ ] `claude plugin validate ./plugin` passes. `grep -rniE 'prework|maige' plugin` finds nothing: smoke fixtures use generic names.

## Out of scope
- `jig.py` editing the repo's files: stale references, script `cd` lines (update.md, Out of scope).
- `update` running `git worktree repair`, `remove` or `prune` itself.
- Moving any non-Markdown file out of a root `specs/` or `ledgers/`.
- P2 and the para rules. The report's P2 concern goes away once the move is per file.

## Touches
- `plugin/templates/jig/jig.py`:
  - `plan_moves`: per-file collision check for folder rows; a mixed subfolder stays whole.
  - `stale_references`: skip references into a subfolder that stayed.
  - `cmd_update`: the worktree refusal reads `prunable` and old worktrees folders on disk; the depth warning; the plan printed under a dry-run refusal.
  - No `LAYOUT` row, board default or `STEPS` entry, so no `STAMP` bump.
- `plugin/skills/update/SKILL.md`: the refusal's repair advice. After `--apply`, a depth warning is code to fix, like a stale reference.
- `tests/smoke.sh`.
- `marketing/FEATURES.md` (main checkout, ignored): a clause in the `update` row's "what". No new row; no new feature.

**Collision with lane `names`.** It edits the same functions: `LAYOUT` gets claude-lane, `REVIEW_LEDGER.md` and root `HARDWARE.md` rows; `BOARD` becomes `CONFIG`/`JOBS`; lane→job and `/jig:brief`→`/jig:spec` everywhere; new refusals for counters without a pattern. It also edits `smoke.sh` and the update skill. Its new rows are file rows, and the per-file rule here changes folder rows only, so the logic doesn't conflict, but the text does. Build this after `names` merges and use its words: "job", `/jig:spec`. This spec is the smaller one to rebase.

## Alternatives considered
- Move all of a root `specs/` under an old board, non-Markdown included. Rejected: the filter protects a repo's own test files (`specs/app.spec.js`). [seen] The comment at the filter, and update.md's Oct 29 review.
- Move a mixed subfolder whole, the Markdown and the rest. Rejected: a test folder with a README is still the repo's test folder, and its runner names those paths. [assumed] See open question 1.
- `update` rewrites `/..` to `/../..` in moved scripts. Rejected: update renames and never edits, and smoke asserts `R100`. The line was never jig's. [seen] update.md Decisions; the five template generations.
- `update` runs `git worktree repair` and `remove` itself. Rejected: a dry run changes nothing, removal needs someone to look at uncommitted work first, and jig never removes a worktree. [seen] update.md Decisions.
- Keep the old ignore line while folders remain. Rejected: it hides checkouts that git no longer tracks (the report's were tens of GB) behind a line jig no longer owns, and the refusal's fix is one the user knows. [assumed]
- Keep the folder-level collision rule, and have the skills write specs to root `specs/` while the repo is behind. Rejected: every skill that writes into `.jig/` would need the branch (brief, bug, stage), and per file is already update.md's rule. [assumed]

## Decisions
- Non-Markdown under a root `specs/` or `ledgers/` still never moves. A mixed subfolder now stays with it, rather than being split.
- Each refusal names the exact command for the case it sees. `update` itself still runs none of them.

## Open questions
1. Should a mixed subfolder stay whole at the root (this spec) or move whole into `.jig/specs/`, as the reporting repo did by hand?
2. Should the stale-reference report be retrievable after the update commit? Once the board is current, a re-run says "up to date". This spec leaves it to the skill, before the commit.
3. Should the depth warning cover only shell scripts, or any moved file (this spec)? Today `scripts/check.sh` and `format.sh` are the only file rows that change depth.
