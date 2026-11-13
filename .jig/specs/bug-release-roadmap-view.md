# bug-release-roadmap-view

Source: Maige-Eco hubnode session, 2026-11-13, for the owner: its `jig release --major` was
refused, naming ten trunk commits "without a reviewed merge". Each changed only `.jig/` files
and `ROADMAP.md`, and each was accepted by the commit hook when it was made.

## Intent
A metarepo trunk commit that the commit hook accepts as bookkeeping is also accepted by the
release check and pre-push. Today `ROADMAP.md`, the roadmap's generated view, passes the hook
and fails the release.

## Why
- Q: Why was the release refused? A: `meta_problems` lets a first-parent trunk commit through
  only when every file it changes is under `.jig/` and isn't the log. `ROADMAP.md` isn't.
- Q: Why did the hook accept those commits? A: M4 (`meta_branch_problems`) adds `ROADMAP_VIEW`
  to what trunk may take whenever the repo keeps `.jig/roadmap.md`, since the hubnode is told
  to `jig roadmap --write` and commit the view on trunk.
- Q: Why do they differ? A: the roadmap commit (224e010) widened M4 and missed its twin in
  `meta_problems`. Root: two copies of one rule, one updated.

## Givens
- `[seen]` jig.py: M4's `keeps = (ROADMAP_VIEW,) if in_index(ROADMAP, staged) or
  at_rev(trunk, ROADMAP) else ()`; `meta_problems`'s check is
  `all(f.startswith(f"{DIR}/") and f != LOG for f in files)`, with no `keeps`.
- `[seen]` `meta_problems` serves both `jig release` and the pre-push hook (its docstring).
- `[seen]` Maige-Eco: the original reports 10 problems, a copy with the fix below reports 0.
- `[seen]` Smoke's `rm-meta` repo already commits `ROADMAP.md` on a metarepo trunk (M4 passes)
  and never releases after it, which is why smoke missed this.

## One layer up
- The sibling is M4 itself, which is right. No other check judges trunk's first-parent files.
- The pattern: judge each commit as M4 judged it then, so the roadmap is read at that commit,
  not at today's trunk.

## Fix (a correction)
In `meta_problems`, a commit's files may also include `ROADMAP_VIEW` when `.jig/roadmap.md`
exists at that commit:
`keeps = (ROADMAP_VIEW,) if git("show", f"{commit}:{ROADMAP}") else ()`, then
`all((f.startswith(f"{DIR}/") and f != LOG) or f in keeps for f in files)`.
The comment ties it to M4, so the next change finds both.

## Done when
- [ ] Smoke: in a metarepo with `.jig/roadmap.md`, a trunk commit of `ROADMAP.md` (the M4 case)
      no longer stops `jig release`, which tags, and pre-push passes. (The reported symptom.)
- [ ] Smoke: a `ROADMAP.md` commit on a metarepo trunk with no `.jig/roadmap.md`, made with the
      hooks off, is still refused by release, naming the commit. (The fix fires only where M4's does.)
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Merging M4 and `meta_problems` into one function: they judge different things (a staged
  index vs a commit's diff), so the shared part is one line.

## Alternatives considered
- Patch the adopting repo's `.jig/jig.py` — rejected because that copy changes only by
  `/jig:update`, and every metarepo with a roadmap has the same refusal — this reason is [seen].
- Read the roadmap at trunk, as M4's `at_rev(trunk, …)` does — rejected because a release
  judges history, and a later removal of `.jig/roadmap.md` would turn old commits into
  problems — this reason is [assumed].

## Touches
- `plugin/templates/jig/jig.py` (`meta_problems`)
- `tests/smoke.sh` (the `roadmap` section's `rm-meta` repo)

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
