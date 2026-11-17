# Handoff: every-copy

Commit: cf8a4980a24257ca60400c9123e813c0d31e1e00
Date: 2026-11-16
Spec: .jig/specs/every-copy.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
`jig reading-list --claims <id or term>…` lists every tracked place that names a decision id or a glossary term. Each is marked `home`, `pointer` (a `§` reference or a link to the home) or `copy`.
- An id matches in any spelling (D-3 and D-003). A superseded id walks its whole chain, and only the entry holding now is home.
- An id's list adds peer entries by `Touches:`. A line with "Source" next to the id is annotated.
- A term's home is its glossary heading or table row. Its list has `§` and link pointers, entries whose `Touches:` names it, and whole-word uses outside fenced code in pages and entries.
- `/jig:spec` step 4 runs it for each id and term a spec changes. RULES.md § Every copy names it.
- `tracked()` now runs at the repo root, and `heading_lines` uses the shared `unfenced()`.

## Done-when evidence
- [x] id list (an id in a page, a table row, a status sentence, a peer entry): `bash tests/smoke.sh claims`, "claims id: the entry, a page's sentence, a table row, a source line and a peer entry are each listed" PASS. The superseded chain: "a superseded id walks its whole chain…" PASS.
- [x] term list: "claims term: the glossary heading is home…", "a § pointer, a link naming it and a link to its anchor are each a pointer", "a table row's first cell is a glossary entry" PASS.
- [x] home / pointer / copy marks: the same cases check one of each. "§ after another page names that page's heading: a copy" PASS.
- [x] `reading-list <paths>` unchanged: "claims: reading-list without --claims prints the pages to read, as before" PASS. The homes, roadmap and rules sections pass.
- [x] `/jig:spec` step: plugin/skills/spec/SKILL.md step 4.
- [x] RULES.md § Every copy names `jig reading-list --claims`.
- [x] `.jig/scripts/check.sh` rc=0. `claude plugin validate ./plugin` → ✔ Validation passed. The grep for names from other repos (`Maige|maige|Daisy|daisy|"E-`) finds nothing. `bash tests/smoke.sh claims homes roadmap rules` → 211 PASS, 0 FAIL, after the sync. `bash tests/smoke.sh headings pointers glossary` → 70 PASS. The full smoke is the check role's.

## Review
Review-work of 2f03161: blocking 0. Should-fix 1–4 and optionals (1), (3), (4) were taken in 3cd2b9c:
- `--claims` run from a subfolder now finds the same lines (`tracked()` at the root).
- `heading_lines` reuses `unfenced()`.
- A `§` after another page's path is a copy.
- A superseded id walks its whole chain.
- The smoke message about code is reworded.
- Only the entry holding now is home.
- The pointer forms are on separate lines, plus an id link.
Optional (2), "per D-3?" not matched, is deferred (DEFERRED.md).

Review-change of 2f03161..3cd2b9c, recorded at 9b84007: blocking 0. The should-fix round was used, so the rest is deferred, each with a row in DEFERRED.md:
- should-fix: `claim_mark`'s `§` pattern is quadratic on a long line (a 400 KB one-line file takes 77 s). Fix: test ``§[ \t`]*$`` first, then take the last word as the page.
- optional: the chain is walked twice.
- optional: a link before `§` counts as a pointer home.
- optional: the link check matches `old-decisions.md` as `decisions.md`.
- optional, no change: a supersedes cycle.
- optional: correct the "per D-3?" row's reason in place. Not done: an in-place edit to DEFERRED.md counts as a change since the review, and `jig handoff` refused it for a new review-change. The row's real reason is "the same boundary as `decision_citers`"; the `D-?slug` clause in it is off.
- optional: the spec's accepted reading 4 says "lines naming its successor". The code lists lines naming every id in the chain (D-004 → D-005 → D-006 lists all three), as the review-change confirmed.

Readings the hubnode accepted (the spec's Decisions, `Interpreted:` lines):
1. Under .jig/, only the log, specs/ and ledgers/ are scanned.
2. A line with any `§` or link to the home is a pointer.
3. Touches peers and entries whose Touches names the term are copies, with a reason.
4. A superseded id lists the old id's lines and its chain's; the holding entry is home; D-4 resolves to D-004.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each roadmap item naming one of those
     pages (an Up next item, or a taken scope) has its own line: keep one answer, built,
     untouched or departed: <why>. An Up next item answered built leaves the roadmap when
     the job merges. The gate refuses an unanswered line. An UNOWNED file has no page
     covering it: add it to docmap in the board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (§ Every copy, updated here) and the spec skill (step 4, updated here).

## Shared files changed
- plugin/templates/jig/jig.py: the command itself (`print_claims`, `claims_of_id`, `claims_of_term`, `claim_mark`, `claim_texts`, `unfenced`, `hold_chain`, the parser flag); `tracked()` runs at the root; `heading_lines` uses `unfenced()`.
- plugin/templates/jig/RULES.md: § Every copy names the command.
- plugin/skills/spec/SKILL.md: step 4 runs it.
- tests/smoke.sh: a new `claims` section, added to UNITS.
- .jig/ledgers/DEFERRED.md: appended rows for the untaken findings.

## Test by hand
In a repo with a decision log and docs/glossary.md, run `python3 .jig/jig.py reading-list --claims D-<n> <term>`. Check that the home comes first, then pointers, then copies, each as `file:line`. Run it again from a subfolder and check you get the same list.

## Left
Nothing in the spec. The deferred quadratic `§` pattern is the one to pick up first: `--claims` on a repo with a minified bundle seems to hang.
