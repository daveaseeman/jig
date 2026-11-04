# Bug: `jig sync` on a pararepo misses a cited file, reports .jig/ headings, and names the wrong release

Source: maige-ecosystem hubnode session, 2026-11-03 (sync-buffer replay) (staged as feedback-maige-ecosystem-2026-11-03.md)
Items 1, 7 and 8 of that report. Three roots, not one: each is a separate function in
`sync_meta`'s path. Two of them depart from a sibling that already reads the metarepo correctly.

## 1. Why
1. **Cited file not named (item 1).** Why? `uncovered_paths` builds `(?:{names})[/:]` from
   `this_repo_names()` and matches case-exactly. A decision citing `app-lite/docs/ui.md` misses a
   repo named `App-Lite`. Root: names are compared exactly, and a citation is text a human typed.
2. **`.jig/` headings in the report (item 7).** Why? `terms_changed` diffs `-- . :!CHANGELOG.md`
   and keeps every `##`/`###` heading. Root: it reads the whole tree, not the entry set that
   release and the cache use.
3. **"released by" names the latest (item 8).** Why? `sync_meta` checks `proposal_in(..., latest)`
   and prints `latest`. Root: it asks "is it in the newest release?", not "which release first held it?".

## 2. Givens
Reproduced in scratch (`fix-bug-sync-report/repro.sh`, `repro2.sh`): a metarepo `hub`, a pararepo
whose config name is `App-Lite`, jig from `plugin/templates/jig/`.
- `[seen]` Item 1: D-001 at the pin cites `app-lite/docs/ui.md`, and the file is tracked and outside
  `contract_paths`. `jig sync` prints no `cited by` line. With a `app-lite` alias in repos.json it
  prints `docs/ui.md is cited by D-001 and is not a contract path`.
- `[seen]` Item 7: v0.2.0 → v0.4.0 added `.jig/handoffs/h.md` (`## Built`, `## Left`) in the
  metarepo. The report lists `Built: not used here` and `Left: used in docs/dir.md`.
  v0.1.0 → v0.2.0 picks up a `.jig/specs/` file's `Done when` and `Touches` the same way.
- `[seen]` Item 8: the proposal merged in v0.3.0, then v0.4.0 was released. Sync prints
  `released by v0.4.0`. `git tag --contains` on its merge gives v0.3.0 first.
- `[seen]` `fill_cache` copies only `entry_paths(pin)` and CHANGELOG. A pararepo never sees a
  metarepo heading outside the entry set, and `is_entry` already drops `.jig/`.
- `[seen]` `unreleased_proposals` (the gate) already names the first later tag holding a
  proposal (`later[0]`). The settle step in `sync_meta` scans tags in order the same way.
- `[seen]` `this_repo_names()` also feeds `release_waits_for` and `staging resolve`'s target
  check. Both compare exactly too.
- `[assumed]` Citations spelled with `_` or a space where the name has `-`. None seen: every
  case in the report is a case difference only.

## 3. One layer up
- Item 7: release (`is_entry` on the diff) and the cache (`entry_paths`) both read the entry set.
  `terms_changed` is the one reader that doesn't.
- Item 8: the gate and the settle step both scan `released_tags` in order for the first hit. The
  status line is the one that checks only `latest`.
- Item 1: no sibling matches names loosely. The staging target checks compare exactly too, but
  they compare a `target:` field, not prose. A miss in `resolve` fails loudly
  (`forward` says the target isn't in repos.json). A miss in `uncovered_paths` is silent.

## 4. Correction
All three change what produced the output. The repos.json alias is the reporter's workaround for
item 1. It's per machine and needs you to know the miss happened.

## 5. Spec

### Done when
- [ ] **1.** `uncovered_paths` matches this repo's names case-insensitively and the path
      case-exactly (`(?i:{names})`). A smoke case: a pararepo named `sb-para`, a decision at the
      pin citing `SB-Para/docs/z.md` → `docs/z.md is cited by …`. `other-para/docs/x.md` is still
      not reported.
- [ ] **7.** `terms_changed` diffs only the entry files at either release (`entry_paths(old)` ∪
      `entry_paths(new)`, CHANGELOG left out), passed as paths, not globs. If there are none, it returns
      nothing. A smoke case: a metarepo release that adds a `.jig/specs/` file and a
      `.jig/handoffs/` note with headings, plus one decision, reports the decision and none of
      those headings.
- [ ] **8.** The sync status line names the first release in `released_tags` that holds the
      proposal: `released by <first>`, else `not released`. A smoke case: in the `pm` section,
      after v0.3.0 is released, the spec citing `propose/pa-g` still reads `released by v0.2.0`.
- [ ] RULES.md's sync-buffer paragraph says a decision may cite this repo by name in any case.
- [ ] Smoke passes, and the validator passes.

### Out of scope
- `repo_path` and the `meta:` proposal line's metarepo name. jig writes both from `para.json`
  itself, so they don't drift in case.
- Saying in the status line whether the first release is past the pin. The gate already says it.

### Touches
`plugin/templates/jig/jig.py` (`uncovered_paths`, `terms_changed`, `sync_meta`),
`plugin/templates/jig/RULES.md`, `tests/smoke.sh`.

### Alternatives considered
- Item 1: rely on a repos.json alias. Rejected: per machine, and the miss is silent until you
  look for it. `[seen]`: no output without the alias.
- Item 1: `re.IGNORECASE` on the whole pattern. Rejected: paths would fold too, so `docs/UI.md`
  would match a cite of `docs/ui.md`. `[assumed]`: no such pair tested.
- Item 1: a citation name per pararepo in meta.json `pararepos`. Rejected: one more name to keep
  in step, and `forward` already reads that list exactly. `[seen]`.
- Item 7: exclude only `.jig/`. Rejected: headings in non-entry pages (a README) would still be
  reported, though the cache never gives them to the pararepo. `[seen]`: `fill_cache`.
- Item 7: pass `entry_files` globs to git as pathspecs. Rejected: git's `**` misses a file
  directly under the folder. `[seen]`: `is_entry` docstring.
- Item 8: `git tag --contains` on the merge. Rejected: a proposal still on its branch, or landed
  by `jig merge` with the branch deleted, is found only by `proposal_in`. `[seen]`: its two branches.

## Decided
Owner, 2026-11-03: each recommendation below is taken. Build to it.

1. **Fold `-`, `_` and spaces too, as the report proposes?** Recommendation: not now. Nothing seen
   needs it `[assumed]`. Buildable either way: the name pattern comes from one place, and folding
   is a single `re.sub` over each escaped name.
2. **Fold case in `release_waits_for` and `staging resolve`'s target check as well?**
   Recommendation: yes, through the same comparison. Today, a fallback report whose `target`
   differs only in case doesn't hold the release, and nothing says why (read in the code, not
   run). Buildable either way: two `in names` tests.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
