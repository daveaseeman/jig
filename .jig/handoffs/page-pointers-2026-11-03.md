# Handoff: page-pointers

Commit: d5dd8181d4b6e358cf74f9dd3bc9b63cc2aba93c
Date: 2026-11-03
Spec: .jig/specs/sync-page-pointers.md
Review: tier 2, effort 1
Ran: claude-opus-5-5 at unknown, fresh context (subagent; effort set to xhigh, not readable by the subagent)

## Built
A metarepo's pointer to a pararepo file (`<repo>/<path> § <section>` or `<repo>:<path>`) can no longer go stale silently.
- One reader, `pointers()`, finds them in the cache, in decision rows and pages alike. It skips `CHANGELOG.md`, superseded and rejected rows, and `this/…`.
- `jig sync` and the pararepo's `jig release` report each stale pointer on one line. They warn and refuse nothing.
- P2 refuses a commit that leaves a pointer dangling (a deleted or renamed file or folder, or a removed or renamed heading) unless it has a BUFFER row or a spec `meta:` line. The refusal names the pointer.
- Repo names fold case only in `name_in`. The reader and `uncovered_paths` share `named_path()`.

## Done-when evidence
Each line below is a case in `bash tests/smoke.sh` (rc=0, 515 PASS, 0 FAIL, run on d5dd818's tree), unless it says otherwise.
- One reader, pages and rows, name folded by `name_in`: `pointers()`. The case "a decision may name this repo in any case" passes, as do the pointer cases below, which read pointers from GLOSSARY.md (a page) and skip a superseded DECISIONS row.
- sync and release report stale pointers, one line each; a resolving pointer is silent:
  - PASS `pointers: sync reports a page pointer to a file this repo doesn't have, and to a heading a file lacks` (exact lines grepped with `-x`).
  - PASS `pointers: pointers that resolve print nothing: in prose, a code span with (, a heading with code, a folder`.
  - PASS `pointers: the pararepo's release warns of a stale pointer and still tags`.
- P2 covers pointers and the refusal names them:
  - PASS `pointers P2: a commit deleting a file a page pointer names is refused, and the refusal names the pointer`.
  - PASS `… renaming the heading a § names is refused, naming it`.
  - PASS `… removing a heading a code-span pointer names, ( and all, is refused`.
  - PASS `… removing a pointed-to folder is refused`.
  - PASS `… the delete passes with meta: buffered <id>`.
- `uncovered_paths` gives no contract_paths advice for a page pointer: PASS `pointers: this/that is not a pointer, a superseded row's pointer isn't checked, and a page pointer gets no contract_paths advice`. The decision-row cases (`buffer: jig sync reports a pararepo path a metarepo decision cites…`) still pass.
- RULES.md: *What the metarepo holds*, the P2 row and the pararepo release paragraph say what is checked and how (`git diff 18dd014 -- plugin/templates/jig/RULES.md`).
- One case fold: `grep -n "casefold\|(?i" plugin/templates/jig/jig.py` prints only `name_in`'s line.
- DEFERRED: both rows are marked `taken by page-pointers (sync-page-pointers)`.
- FEATURES.md row: edited by the hubnode before this job. Smoke rc=0. `claude plugin validate ./plugin` printed `✔ Validation passed`.

Smoke tail:
```
PASS  feedback: jig repos prints where tool reports wait
PASS  isolation: the user's real jig config folder is unchanged by the run
rc=0
```
Validator:
```
✔ Validation passed
```

## Review
Round 1 was a fresh claude-opus-5-5 subagent. Its effort was set to xhigh, but the subagent reported it as unknown, and it's recorded that way. It found one blocking issue, three should-fix and four optional; all of the taken ones were fixed in d5dd818.
- B1 (blocking), the section parse misread `§` sections (prose, `(`, `,`, inline code), which blinded P2. Taken. A code-span section runs to its closing backtick and is matched whole. In prose, any heading the text after `§` begins with resolves it. Headings are compared with code and emphasis marks removed. RULES now recommends backticks and names `<repo>:<path>`. Smoke cases added.
- S1, `this/that` was read as a pointer. Taken: `pointers()` drops "this" from the names. Smoke case added.
- S2, P2 never checked a folder pointer. Taken: a changed path under the folder counts, and existence is checked with `ls-tree`/`ls-files`. Smoke case added.
- S3, superseded and rejected rows were checked. Taken: those rows are skipped. Smoke case added.
- O1, which cache to read. Taken: sync and release read `root / CACHE`; P2 reads the primary checkout's, since a worktree has none.
- O2, the diff missed non-ASCII names. Taken: `-c core.quotePath=false`.
- O3, the heading-rename case didn't check why it was refused. Taken: it greps the pointer line.
- O4, pointers go unreported when the metarepo can't be reached. Deferred, with a DEFERRED row.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because the checker's documentation is `plugin/templates/jig/RULES.md`, which this job updated (What the metarepo holds, the P2 row, the pararepo release paragraph). Adding jig.py to docmap is the hubnode's call.

## Shared files changed
- `plugin/templates/jig/jig.py`: the spec's Touches. New functions `named_path`, `pointers`, `plain`, `body_at`, `body_now`, `pointer_gap`, `stale_pointers`. Small edits in `para_rules` (P2), `sync_meta`, `para_problems` and `uncovered_paths`.
- `plugin/templates/jig/RULES.md`: *What the metarepo holds*, the P2 row, the pararepo release paragraph.
- `tests/smoke.sh`: the pointer cases, added at the end of the sync buffer section; no existing case was moved or changed.
- `.jig/ledgers/DEFERRED.md` (common): two rows marked taken, and the O4 row appended.

## Test by hand
In a pararepo whose metarepo page has `` `<repo>/docs/x.md § Some heading` ``, run `jig sync`. It is silent. Rename that heading and commit: P2 refuses and names the pointer.

## Left
Nothing. O4 is in DEFERRED.
