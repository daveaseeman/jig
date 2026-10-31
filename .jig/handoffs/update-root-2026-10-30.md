# Handoff: update-root

Commit: f90e4801aaf76e2b602c98cd5d8305aca3381682
Date: 2026-10-30
Spec: .jig/specs/update-root-specs.md

## Built
`jig update` now handles the cases the spec lists without a hand-written recovery:
- Each file in a folder row moves when its destination is free. A file at both paths stays, and a warning names it.
- A subfolder of a root `specs/` or `ledgers/` that holds Markdown moves whole, its other files included, with one warning. If any of its files collides, the whole subfolder stays, warned once.
- Worktrees: the refusal gives one command per case: `remove` for a worktree that is there, `repair` then `remove` for one that moved with a renamed repo folder, `prune` for one that is gone, and "look, then delete it" for a folder git doesn't know.
- A refusing dry run still prints the plan and exits 2. A refusing `--apply` prints the refusal only.
- Depth warning: a moved non-Markdown file whose folder depth changed, with its lines that find paths from its own location.
- The board keeps an old glob where files stayed, and rewrites a glob only when a file it matched moved.
- Stale references: a glob or `<placeholder>` reference is stale when a moved file matches it. A file or bare folder reference is stale when the path is gone.
- From another job's review: an untracked file at a move's destination refuses the dry run and `--apply`, so `git mv` never dies with renames half-staged. An untracked staged file whose `.jig/staging/` destination is taken refuses the same way.
- The update and adopt skills give the per-case worktree advice.

## Done-when evidence
All from `bash tests/smoke.sh` at f90e480: exit 0, 364 PASS, 0 FAIL.
- Tracked `.jig/specs/b.md`: "update per file: …" ×4 PASS. `a.md` moves R100, `b.md` is warned once, common holds both globs, and the `b.md` link is not stale.
- Mixed `specs/`: "update subfolders: …" PASS. The dry run exits 1 with one warning each for `specs/suite/` and `specs/deep/`, `app.spec.js` and `specs/unit/` stay with warnings, `specs/suite/t.rs` is stale, and the moves are R100.
- The same with `.jig/specs/suite/README.md` tracked: "a colliding file keeps all of specs/suite/ where it is, warned once" PASS.
- `ledgers/old/`: "ledgers/old/README.md and data.csv both move under .jig/ledgers/old/" PASS.
- `cd "$(dirname "$0")/.."` in `scripts/check.sh`: "update depth: …" ×2 PASS. The line is warned and the dry run exits 1; no fixture's scripts raise the warning.
- Worktree moved with a repo rename: "update worktrees: …" ×3 PASS. The dry run exits 2 with `git worktree repair .aidev/worktrees/l1` and `Moves`; the commands run, `--apply` runs, the commit leaves status clean, and `.aidev` is gone.
- After `remove` dropped the record: "not a checkout git knows" and "--apply exits 2 and .gitignore is unchanged" PASS.
- Untracked `.aidev/worktrees/x/f`, a folder deleted by hand (prune), and eaec973's `.jig/worktrees/y`: each PASS.
- The existing case now reads "jig/specs/ beside .jig/specs/ is judged per file: _template.md moves, new.md stays" PASS. The `--apply` case expects the same.
- Round 1 cases: "update stale: specs/*.md and specs/<task>.md are stale…", "a common glob over files that all stayed… is left as it is", "an untracked staged file whose .jig/staging/ destination is taken refuses…", and the untracked-destination pair: all PASS.
- `claude plugin validate ./plugin`: "✔ Validation passed". `grep -rniE 'prework|maige' plugin`: no output, exit 1. `.jig/scripts/check.sh`: passed.

## Review
Fresh-context review, round 1 (hubnode, Opus xhigh). Nothing was blocking. All five findings were taken in f90e480:
1. should-fix: a `.gitkeep` kept a glob reference from being stale. Now a glob or placeholder is judged against the moved files. The rejected rule is in the spec's Alternatives, and there is a smoke case.
2. should-fix: an untracked staging file whose destination was taken only warned. It now joins the untracked-destination refusal, with a smoke case.
3. optional: a glob is rewritten only when a file it matched moved. Smoke case.
4. optional: `]` and `#` end a reference. The existing "not stale" case now uses a link with an anchor.
5. optional: the depth warning also catches `__FILE__`, `__dir__` and `import.meta.url`. The spec and skill token lists are updated.

Deferred, one optional finding: a file that collides is also warned "at an old path no row names". That second warning predates this change. The hubnode ledgers it in DEFERRED.md.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because `update`'s behaviour is documented in `plugin/skills/update/SKILL.md` (updated here: refusal advice, depth warnings). `RULES.md` only lists the command, which is unchanged.

## Shared files changed
- `plugin/templates/jig/jig.py`: only inside the functions the spec names: `plan_moves`, `rewrite_board`, `stale_references` and `cmd_update`. Plus one new function, `worktree_refusals`, just above `cmd_update`. The old one-line worktree refusal in `cmd_update` was replaced, and the `old_ignores` line moved up to feed it.
- `tests/smoke.sh`: a new section at the end, before the final cleanup. Three existing update cases changed: the worktree refusal now greps for `git worktree remove`, and the "both exist" case and its `--apply` case are now per file, as the spec asks. Note for para-commands: the R6 section rebinds `R`, which breaks `old()` after it. My cases call `R="$(dirname "$(dirname "$P")")" old …`.
- `plugin/skills/update/SKILL.md`: only the refusal advice (exit 2 bullet) and one after-apply paragraph about depth warnings.
- `plugin/skills/adopt/SKILL.md` (owned): the prune step gives the per-case worktree advice.
- `.jig/specs/update-root-specs.md`: round 1's stale and glob rules, the rejected alternative, the token list, and Done-when items for the new cases.
- `marketing/FEATURES.md` (main checkout, gitignored, not in the diff): the `update` row's "what" gained a clause.

## Test by hand
In a scratch copy of an ai-dev repo:
- With a `specs/suite/` folder holding a README and a `.rs` file: run `python3 <plugin>/templates/jig/jig.py update` and read the warning that it moves whole.
- Add a worktree under `.aidev/worktrees/`, rename the repo folder, and run it again. Check that the refusal's `repair`/`remove` commands work as printed, and that the plan still shows below the refusal.

## Left
Nothing on this job. Open question 1 in the spec (keeping the stale-reference report after the update commit) stays with the skill.
