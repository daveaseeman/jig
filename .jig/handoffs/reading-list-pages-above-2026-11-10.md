# Handoff: reading-list-pages-above

Commit: c0f256be0f5d464eff23e9ac26d22cc24494b02c
Date: 2026-11-10
Spec: .jig/specs/reading-list-pages-above.md
Review: tier 2, effort 2
Ran: fresh Opus review of 599373b: no blocking; S1 seam-style page climbed to its folder's page, fixed in c0f256b (climb only from folder pages) with a smoke case; O1 board-under-system parent and O2 tracked parents deferred. Hubnode checked c0f256b by diff and smoke homes.

## Built
<!-- what this delivers, in a few lines -->
`jig reading-list <files>` prints, after each covering page named for its folder, the pages
above it in the docs tree (`pages_above`, walking `owner_page`, `deep_subsystems` honoured),
each as `<page>   (parent of <page below>)` and printed once. A page that covers a named file
prints plain, at the first place it is reached. A seam-style page (not named for its folder)
lists no parent. Fold-in is unchanged. RULES.md's reading-list sentence and Commands line say so.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- reading-list for `src/a/b.rs`: smoke homes "prints its page, then its system's page marked as the parent" PASS.
- approved `docs/a/b/c`: smoke homes "prints c, then b and a, each once and marked" PASS.
- `src/a/lib.rs src/a/b.rs`: smoke homes "a page that covers a named file prints once, without the parent mark" PASS.
- handoff changing only `src/a/b.rs`: smoke homes "asks only its page" PASS (one fold-in line, `docs/a/b/b.md`).
- seam page: smoke homes "a seam-style page not named for its folder prints no parent" PASS.
- `bash tests/smoke.sh` exit 0, 774 PASS, 0 FAIL; `claude plugin validate ./plugin` ✔ Validation passed; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` empty; `.jig/scripts/check.sh` exit 0.

## Review
<!-- findings from the adversarial review, and what you did about each -->
Hubnode's fresh review of 599373b: nothing blocking.
- S1 (should-fix): a seam-style covering page climbed to its folder's page, the other side of the seam. Fixed in c0f256b: only a folder page climbs; smoke case added.
- O1 (optional): a board page under a system whose globs reach another system prints its own system as parent. Deferred, DEFERRED.md row.
- O2 (optional): parents come from `tracked()`, so an uncommitted parent is left out. Deferred, DEFERRED.md row.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because this repo's docmap is empty and has no docs/ tree; RULES.md's reading-list sentence and Commands line (updated) describe the change.

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- `plugin/templates/jig/jig.py`: `pages_above` beside `owner_page`, and `cmd_reading_list`.
- `plugin/templates/jig/RULES.md`: the seam paragraph's reading-list sentence, and the Commands line.
- `tests/smoke.sh`: a new `homes-reading` repo appended at the end of `sec_homes`.
- `.jig/ledgers/DEFERRED.md` (common): two appended rows, O1 and O2.
- `.jig/specs/reading-list-pages-above.md` (common): marker wording, grep line, design line for S1.

## Test by hand
<!-- what a person should click or watch -->
In a repo with `docs/a/a.md` and `docs/a/b/b.md` mapping `src/a/b.rs`, run
`python3 .jig/jig.py reading-list src/a/b.rs`: `docs/a/b/b.md`, then `docs/a/a.md   (parent of docs/a/b/b.md)`.

## Left
<!-- what remains on this job -->
Nothing. Flat part pages climb in the `flat-pages` job.
