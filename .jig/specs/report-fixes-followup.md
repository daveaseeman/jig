# Follow-up to the report-born fixes: what eight `/jig:bug` evaluations found

Source: `/jig:bug` run on Nov 2 against eight shipped specs that came from other repos'
feedback reports. Each spec was checked against `main` (0.4.0+) by a fresh subagent at the spec
step's settings, using throwaway repos:
`decision-open`, `bug-hook-modes`, `bug-r6-m5-decisions-dest`, `bug-init-old-board-ledger`,
`bug-r6-take`, `hardware-reference-files`, `bug-merge-after-sync`, `update-root-specs`.

## Intent
Every one of the eight fixes still holds: its root cause was right, no later release undid it,
and its done-when passes. This spec closes what the evaluations found around them: one blocking
gap, eleven should-fix and nine optional, grouped by the code they touch.

## Findings, with their fix

### update (from update-root-specs)
1. **Blocking. A stranded worktree for a branch with `/` gets advice that strands it.** After
   the repo folder is renamed, `.aidev/worktrees/feat/x` is reported as "`.aidev/worktrees/feat`
   is not a checkout git knows: look, then delete it" plus `git worktree prune`. Following that,
   `repair` and `remove` both fail, and the checkout and its uncommitted work are stranded.
   `[seen]`. Fix: the worktree scan (`jig.py` ~3062) searches each worktrees base recursively
   for `.git` files, stopping at each checkout it finds.
2. **Should-fix. A subfolder that moves whole leaves its untracked and ignored files behind,
   with no warning.** `[seen]`: `specs/suite/notes.txt` and `specs/suite/.cache/` stayed. Fix:
   the dry run lists them, as `OLD_UNTRACKED` already does for staging.
3. **Should-fix. `.gitignore` isn't checked for stale references.** `[seen]`:
   `specs/suite/.cache/` wasn't flagged. Fix: check it, apart from the worktree lines `update`
   removes itself.
4. Optional. A reference written as `$(dirname "$0")/../specs/x.md` isn't flagged, because the
   lookbehind refuses `/`. Fix: allow `../` the way `./` is allowed.

### Merging and the gate (from bug-merge-after-sync, bug-r6-m5-decisions-dest)
5. **Should-fix. M5 skips a detached checkout sitting on trunk.** `[seen]`: `git checkout
   --detach main`, merge an unreviewed branch, `git push origin HEAD:main`, and both M5 and
   pre-push pass. M5 refused this before 0.4.0. Fix: M5 applies when HEAD is detached and is
   trunk or an ancestor of it (R6's test, ~336-344), and pre-push checks the sha pushed to
   `refs/heads/<trunk>`, not the local ref.
6. **Should-fix. `jig merge` uses plain `git merge`.** A job that wasn't synced then stops on
   trunk with an append conflict that the gate already resolved mechanically. `[seen]`. Fix: when
   every conflicted file is in `append_files`, `jig merge` aborts and says "`jig sync` the job,
   then merge". A synced job merges without a new handoff, so nothing is lost.
7. Optional. When `git merge-tree --write-tree` isn't available (git older than 2.38),
   `changed_since` refuses every synced job with the generic "changed since". Fix: say that git
   2.38 is needed, and name it in RULES.md.
8. Optional. The gate prints `./.jig/scripts/check.sh` and a plain `git worktree remove`. Fix:
   print `bash ./.jig/scripts/check.sh` and `git worktree remove --force`: `setup.sh` may leave
   untracked files.

### Hooks (from bug-hook-modes)
9. **Should-fix. The plugin's hooks always run the repo's script through `bash`.** A repo whose
   `.jig/scripts/check.sh` is Python, or any other non-bash language, exits 2 on bash's syntax
   error, so the Stop hook blocks every stop. `[seen]`. Fix:
   `plugin/scripts/check.sh` and `format.sh` exec the script when it's executable, and use
   `bash` only when it isn't, as `run_setup` and `cmd_release` already do.

### R6 (from bug-r6-take)
10. **Should-fix. `unique` never fires when no jobs are open.** In a solo repo on a feature
    branch, a second `SCHEMA_VERSION = 17` commits. `[seen]`. RULES.md says R6 applies working
    alone. Fix: run the `unique` check whenever a counter sets it, jobs or not.
11. **Should-fix (text). Rule numbers inside a section aren't reservable.** Two jobs each add
    `### 1.3` in different files, and both commits pass. `[seen]`. No counter can cover it,
    because R6 counts whole numbers. Fix: one line in RULES.md Reserved numbers saying a
    section's rule numbers are its holder's, and that within an existing section nothing stops
    two jobs adding the same one.
12. Optional. The edit and move smoke cases use only the `^## (\d+) ` counter. Fix: repeat them
    under `^### (\d+)\.\d+`, as `bug-r6-take`'s done-when describes.

### Staging (from bug-r6-m5-decisions-dest)
13. **Should-fix. `bare_path` lets prose through when it ends in `.md`.** `[seen]`:
    - `the register in docs/DECISIONS.md`, kind decisions, crashes with a traceback
    - `see docs/x.md`, kind doc, writes a file named `see docs/x.md`

    Fix: a destination is a path when it has no whitespace and no `:`, `,` or `;`.
14. **Should-fix. Decisions staged as new into a folder that doesn't exist crashes.** `[seen]`.
    Fix: create the folder, as the doc branch does.
15. Optional. A typo like `DECISION.md` silently starts a new register. Fix: in a metarepo,
    refuse a decisions destination that `entry_files` doesn't name (by `matches()`, after
    `bug-meta-entry-globs` lands).

### Advice in an old-layout repo (from bug-init-old-board-ledger)
16. Optional. `jig propose` says "`jig init --para` makes this one", which then refuses. And
    `forward` suggests `jig update` only for a `jig/lanes.json` target. Fix: both use
    `old_board()` and name `jig update` first.

### Decisions (from decision-open)
17. **Should-fix. M2's refusal names the five statuses but not the shape.** A row that used to
    pass, like `accepted, owner`, is now refused, and the message doesn't say the note goes in
    parentheses. Fix: say "a Status cell that is exactly a status, optionally `(note)` or
    `by D-…`".
18. Optional. RULES.md calls only `superseded` a reversal, and the spec also calls accepted →
    rejected one. Fix: add "or rejected".
19. Optional. `terms_changed` and `sync`'s usage grep match ids with a fixed `[A-Z]…-` and `-F`,
    so a lowercase `decision_prefix` is never reported, and `D-1` counts as a use of `D-12`.
    Fix: build the pattern from `decision_prefix`, and match on word boundaries.

### Hardware (from hardware-reference-files)
20. **Should-fix. A bare link target stops at the first `)`.** `[seen]`:
    `components/rtc/qx-20(rev1).pdf` is reported both missing and unlinked. Fix: allow one level
    of balanced parentheses in `MD_INLINE`.
21. Optional. The hardware skill says an unset `reference_files` means "the repo's first board
    page". After `update`, an old repo is unset while it already has pages. Fix: "unset: ask
    once".

## Done when
Smoke, one case per numbered finding that has a behavior, plus:
- [ ] 1: a renamed repo with a stranded `feat/x` worktree gets `repair` then `remove` advice
      that works when followed, and the checkout's uncommitted file survives.
- [ ] 5: a detached-trunk merge of an unreviewed branch is refused by M5, and `git push
      origin HEAD:main` of one is refused by pre-push.
- [ ] 9: a Python `.jig/scripts/check.sh` that exits 0 lets the plugin's Stop hook exit 0.
- [ ] 10: in a repo with no open jobs, a second `SCHEMA_VERSION = 17` on a branch is refused.
- [ ] 13: both prose destinations above are refused with the "isn't a path" message. A bare
      path resolves.
- [ ] Smoke passes, the validator passes, and nothing Claude-specific or adopting-repo-specific
      is added to `plugin/templates/jig/` or RULES.md.

## Out of scope
- Re-opening any of the eight specs. Each is shipped and closed; this spec records the change.
- `bug-meta-entry-globs` (job `entry-globs`, building now). Item 15 waits for it.

## Touches
- `plugin/templates/jig/jig.py`:
  - `cmd_update`'s worktree scan, untracked leftovers and stale references
  - M5 and the pre-push hook
  - `cmd_merge`, `changed_since`, `cmd_gate`
  - `reserved_refusals`
  - `bare_path` and decisions resolve
  - `cmd_propose`, `forward`, M2's message, `terms_changed` and the usage grep
  - `MD_INLINE`
- `plugin/scripts/check.sh`, `format.sh`.
- `plugin/templates/jig/RULES.md`: Reserved numbers, the reversal sentence, git 2.38.
- `plugin/skills/hardware/SKILL.md`, `tests/smoke.sh`.

Build after `entry-globs` merges: it also changes M3, `cmd_merge` and the metarepo paths.

## Alternatives considered
- One follow-up per original spec. Rejected: eight small jobs, all sharing `jig.py` and
  `smoke.sh`, would mostly conflict at the end of `smoke.sh`, as the last two waves did.
  `[seen]`: both waves' merges.
- `jig merge` resolves append conflicts itself, in reverse order to `resolved_appends`. Rejected
  for now: a second resolver to keep in step with sync's. Refusing and naming `jig sync` uses the
  one that exists. `[seen]`: `merge_trunk` is sync's and the gate's.
- Allow spaces in a destination (r6-merge's review choice) and refuse only `:`, `,` and `;`.
  Rejected: "see docs/x.md" passes that test. A path with a space is rare in a docs tree, and
  this refuses it loudly, not wrongly. `[seen]`: the probe.

## Decisions
- Item 13 reverses r6-merge's review call that destinations may contain spaces. The probe showed
  that call lets prose land as a file.
- Owner, Nov 2: agreed with both calls. Item 6 refuses and names `jig sync`; `jig merge` doesn't
  sync a job itself.
