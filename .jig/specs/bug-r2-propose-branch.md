# bug-r2-propose-branch

Source: Maige-OS hubnode session, 2026-11-18, on Dave's word ("The jig gap: file the feedback note.") (staged as r2-refuses-propose-branch.md): "R2 branch propose/Maige-OS-buffer-b5-b7 is on no job. Ask the hubnode to open one, or work on main", refused by the metarepo's `jig check` and pre-commit hook on the branch `jig propose` made, while the metarepo had a job open.

## Intent
In a metarepo, a commit on a `propose/<repo>-<slug>` branch passes R2 while jobs are open, as it
does when none are: it is the one branch RULES.md sends a pararepo to, and it is on no job by design.

## Why
- Why was the proposal's commit refused? `cmd_check` refuses any branch other than trunk that is on no job while the board has an open job (jig.py 617–621).
- Why is the proposal's branch on no job? `jig propose` makes it in the metarepo without touching the metarepo's board or checkout: RULES says "A pararepo writes the metarepo only by branch, via `jig propose`".
- Root: R2's no-job clause (from 2026-10-30) predates proposals (2026-11-02) and was never told about them. No other branch jig makes is on no job.

## Givens
- `[seen]` Report header: `kind: feedback`, but `destination:` names a spec, and `jig_version` gives release numbers (0.14.0 metarepo, 0.13.0 pararepo), not a hash. Judged on content; the clause is unchanged on trunk (`a9ce86b`).
- `[seen]` Reproduced with trunk's `plugin/templates/jig/jig.py`, in a throwaway metarepo `docs` (`init --meta`, released v0.1.0) and pararepo `pr` (`init --para docs`). `jig propose .jig/specs/x.md fmt` made `propose/pr-fmt`. In `git -C <meta> worktree add <dir> propose/pr-fmt`, with `docs/fmt.md` staged:
  - no job open: `jig check` prints `ok`;
  - after `jig open other-job --owns docs/other.md` on the metarepo's trunk: `jig check` exits 1 with `R2 branch propose/pr-fmt is on no job. Ask the hubnode to open one, or work on main`, and `git commit` is refused by the hook with the same line.
- `[seen]` The refusal's advice can't be followed from the pararepo's side: "work on main" breaks rule 1, and opening a job is the metarepo's hubnode's step.
- `[seen]` Stopgap that works today: the metarepo's hubnode adopts the branch, `jig open <job> --branch propose/pr-fmt --worktree <dir> --owns docs/fmt.md`; then `jig check` there prints `ok`. Without `--worktree` it refuses: "branch propose/pr-fmt is checked out somewhere already".
- `[seen]` Nothing else in jig.py makes a branch: `git branch` appears only in `open_proposal`, and worktree adds only in `cmd_open`.
- `[seen]` `.jig/meta.json`'s `pararepos` is `[]` after `init --meta`, and `init --para` doesn't add to it.
- `[seen]` RULES.md never states the no-job clause: R2 reads "A job is built in its own worktree", and "Working alone?" says R1–R5 go quiet with no jobs open.
- `[seen]` RULES.md, Overlapping specs: a metarepo takes proposals into a job through a consolidated spec's `## Proposals`, merged into the job's branch; the smoke's `sbland` merges one straight into trunk with no job open.
- `[assumed]` A proposal merged into a job's branch is judged there by that job's R3 (the merge's paths against trunk), so skipping R2 on the proposal branch doesn't skip ownership. Not tested; the fix doesn't depend on it, but it is why skipping R2 here is safe.

## One layer up
- Sibling: R1 also refuses with jobs open, but only for the trunk checkout itself, and `jig propose` says to use a worktree, so it doesn't fire here and stays as is.
- No other non-job branch exists to compare: `propose/` is the only one jig makes. The pattern already in use is the name form: `proposal_branches()` reads `propose/…`, and the hubnode lists `git branch --list 'propose/<pararepo>-*'`.

## Workaround or correction
Correction: R2's no-job clause learns the branch RULES already designates. A workaround (always adopting) would put a hubnode step in front of every proposal and fold proposals into jobs before the `## Proposals` merge that's meant to take them in.

## Decisions
- **A question for the owner: how does R2 recognise a proposal branch?** Recommended: in a metarepo (`.jig/meta.json` on trunk), a branch whose name starts `propose/` passes R2's no-job clause. Every other check that runs on a non-job branch still runs. R1 still refuses the trunk checkout on it. A `propose/` branch in a repo that isn't a metarepo is refused as today.

  The other ways, if the owner prefers one:
  - only `propose/<p>-*` with `<p>` in `meta.json`'s `pararepos`: tighter, but `pararepos` is empty after setup (seen), so every metarepo would first need its pararepos registered, and today nothing does that;
  - keep R2 and make adopting the route: the metarepo's hubnode opens a job per proposal (works today, seen). The pararepo still can't write until that happens, and the refusal would have to name it.

## Done when
- [ ] Smoke, symptom gone (`sec_pararepo`, after the `propose` case): with a job open in the metarepo, a worktree of `propose/pr-fmt` with a file staged passes `jig check` (`ok`) and `git commit`; the output has no `R2`.
- [ ] Smoke, fix fires only where it should: with the same job open, the hook still refuses with `R2 … is on no job`
  - on a plain branch in the metarepo (`git worktree add -b scratch`);
  - on a `propose/x` branch in a repo that isn't a metarepo.
- [ ] Smoke: the metarepo's trunk checkout switched to `propose/pr-fmt`, with a job open, is still refused with `R1`.
- [ ] RULES.md states the clause: off trunk, a branch on no job is refused while jobs are open, except a `propose/` branch in a metarepo.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.
- [ ] `grep -rnE 'Maige|maige|Daisy|daisy' plugin tests` finds nothing new.

## Out of scope
- R3/R4 for a proposal: ownership is judged where the metarepo takes the proposal in (a job's merge, or the trunk merge with no job open), not on the proposal branch.
- Registering pararepos in `meta.json`. It's only needed for the tighter alternative.
- Maige-OS's staged proposal: it commits once this lands, or on the owner's word sooner by the adopt stopgap above.

## Touches
- `plugin/templates/jig/jig.py`: `cmd_check`'s R2 no-job clause (617–621), skipping it for a `propose/` branch when the repo is a metarepo (`load_meta(trunk)` is already read above it).
- `plugin/templates/jig/RULES.md`: R2's line in The rules (the no-job clause and its `propose/` exception), and a clause in Metarepo and pararepos rule 1.
- `tests/smoke.sh`: `sec_pararepo`.
- `marketing/FEATURES.md` (main checkout only): the R2 row.

## Alternatives considered
- `jig propose` records the branch on the metarepo's board — rejected because the board changes on trunk only (R5), and propose leaves the metarepo's trunk untouched by design ("main is untouched", in code and in smoke) — this reason is [seen].
- Exempt only `propose/<p>-*` for a registered pararepo `<p>` — rejected as the default because `pararepos` is empty after `init --meta`/`--para` — this reason is [seen].
- Adopt every proposal as a metarepo job — rejected because it puts a hubnode step in front of each proposal, and RULES takes proposals into a job by `## Proposals` merge, not as jobs of their own — this reason is [seen].
- Exempt any `propose/` branch in any repo — rejected because only a metarepo receives proposals; elsewhere the name would only be a way past R2 — this reason is [seen].

## Roles
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
