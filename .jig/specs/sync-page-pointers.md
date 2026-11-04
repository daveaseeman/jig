# A metarepo pointer to a pararepo file never goes stale silently

Source: owner, 2026-11-03 ("must fix"), from the meta-rule review's DEFERRED row.

## Intent
Since *What the metarepo holds*, a metarepo page points to a claim a pararepo owns
(`<repo>/<path> § <section>`) instead of restating it. Nothing checks that pointer. The pararepo
can rename or delete the file, or the heading, and the metarepo keeps pointing at nothing. Make
that visible where it happens (the pararepo's commit) and where it's read (`jig sync`).

## Givens
- `[seen]` `uncovered_paths` (jig.py) scans only decision rows in the cache, and only to advise
  adding a cited file to `contract_paths`. A page pointer is never read.
- `[seen]` The cache (`.jig/meta-cache/`) holds the metarepo's entry files at the pin, so a page
  pararepos read is there; a page outside `entry_files` isn't read by pararepos at all.
- `[seen]` P2 already has the shape for "this change affects the metarepo": a BUFFER row, or a
  spec's `meta: buffered <id>` / `meta: <name> proposal <branch>` / `meta: none — <reason>`.
- `[seen]` A pointed-to file is the pararepo's own, not a contract path: the rule says so, so
  `uncovered_paths`' contract-path advice is wrong for it.

## Done when
- [ ] One reader finds every pointer to this repo in the cache: `<name>/<path>` or
      `<name>:<path>` (name folded as `name_in` does), optionally followed by `§ <section>`.
      Decision rows and pages both.
- [ ] `jig sync` and the pararepo's `jig release` report each stale pointer, one line each:
      `<cache file> points to <path>, which this repo doesn't have` or `… § <section>, which
      <path> has no heading for`. A pointer that resolves says nothing. Release warns, doesn't
      refuse: the fix is in the metarepo.
- [ ] P2 also covers pointers: a commit that deletes or renames a file a pointer names, or
      removes or renames the heading a `§` names, needs the same answer as a contract-path
      change (a BUFFER row or one of the spec's `meta:` lines). The refusal names the pointer.
- [ ] `uncovered_paths` no longer advises `contract_paths` for a path that only page pointers
      cite; a decision row's citation keeps today's advice.
- [ ] RULES.md: the P2 row and *What the metarepo holds* say a pointer is checked, and how.
- [ ] Repo names fold case one way only. Today `uncovered_paths` uses a regex flag, `(?i:…)`,
      while `name_in` uses `casefold()`. The new reader and `uncovered_paths` build their name
      pattern from one helper, and `name_in` uses the same fold.
- [ ] The DEFERRED rows "sync checks only decision-row citations…" and "Case folds two ways…"
      are marked taken by this job.
- [ ] Smoke, in the meta + para fixture: a page pointer to a deleted file and to a removed
      heading are each reported by sync; a commit deleting a pointed-to file is refused by P2
      and passes with `meta: buffered <id>`; a resolving pointer prints nothing.
- [ ] FEATURES.md row, edited before the change. Smoke and validator pass.

## Out of scope
- Pointers in metarepo files outside `entry_files`: pararepos don't read them.
- Pointers to another pararepo: that repo's own sync checks them.
- Rewriting the metarepo's pointer: that goes through the buffer and its proposal, as today.

## Touches
`plugin/templates/jig/jig.py` (a pointer reader beside `uncovered_paths`, `sync_meta`,
`para_problems`, P2 in the commit rules), `plugin/templates/jig/RULES.md`, `tests/smoke.sh`,
`.jig/ledgers/DEFERRED.md`, `marketing/FEATURES.md`.

## Alternatives considered
- Report at sync only. Rejected: the pararepo commit that breaks the pointer passes, and the
  writer learns later from someone else's sync. `[seen]`: P2 already judges at commit for
  contract paths.
- Make every pointed-to file a contract path. Rejected: the rule says the pararepo owns it, and
  a contract path makes every edit of it a metarepo matter, not just a move. `[seen]`: RULES
  *What the metarepo holds*.
- Refuse the pararepo's release on a stale pointer. Rejected: the pararepo can't edit the
  metarepo page; a warning plus the buffer row is its whole fix. `[seen]`: P2's buffered path.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
