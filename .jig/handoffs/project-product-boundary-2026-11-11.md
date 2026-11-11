# Handoff: project-product-boundary

Commit: 738c23ed129c520220839fb3bb8761cee0beb581
Date: 2026-11-11
Spec: .jig/specs/project-product-boundary.md
Review: tier 2, effort 2
Ran: fresh Opus reviewer (high) on fe115a4: B1 reading-list items for parents, B2 review-run evidence, S1-S8, O1-O3; fixed in 42d2ece; hubnode ran smoke boundary, page_contract and roadmap at 738c23e (91 PASS, 0 FAIL), covering the false-positive, git mv and metarepo ROADMAP.md cases

## Built
Pages and decision entries describe the product; the roadmap holds the project; specs bridge them.
- RULES.md states the boundary and one-way references (Documentation, Homes, Fold-in, Roadmap, Decision log, Metarepo); § Roadmap no longer calls a scope a decision; `## Undefined` leaves the page contract and `docs-page.md`.
- The hook refuses an added line in a docs page, the decision log or a metarepo entry file naming `.jig/specs/`, `.jig/handoffs/`, `.jig/roadmap.md` or a quoted scope id, naming the line (renames followed); and a `roadmap.md` under `docs/` or in entry files (root `ROADMAP.md` exempt only where `.jig/roadmap.md` exists).
- `## Up next` in `.jig/roadmap.md`: parked work, no phase, each item `(touches docs/…)`. `jig roadmap` and `ROADMAP.md` show it; `jig reading-list` prints items (and open/taken scopes) under each page, parents included; fold-in gets a built / untouched / departed line per Up next item or taken scope naming a covered page; `jig merge` removes an item answered built and re-points pages the job moved.
- Touched pages must exist: `jig roadmap` reports a dead one; on trunk the hook refuses a commit that strands one. Consequence (S7): when a job deletes a page an Up next item touches, the merge commit is refused, and the item is fixed on trunk before the merge goes through.
- Solo on trunk (S8): `jig gate` refuses until an item the note answers built is deleted from Up next on trunk.
- Survey lists project headings (Status, Current state, Roadmap, Undefined), plan prose ("phase 3", "spec step 6"), plan paths and scope ids on pages, entry files and the log; its verdict counts them.
- Review, spec, hubnode, redocument, retro, hardware and survey skills ask "is this about the product, or about when and in what order we build it?" and drop Undefined.

## Done-when evidence
- RULES.md boundary, § Roadmap wording, Undefined gone from contract and docs-page.md: diff of plugin/templates/jig/RULES.md and docs-page.md; `grep -n Undefined plugin/templates/jig/RULES.md` shows only the retired-section mentions.
- Hook refuses `.jig/specs/x.md` and a quoted scope id in a page and in the log, line named; the same in a spec passes: smoke `boundary` ("the hook refuses a page line naming a spec, with the line named", "…a scope id in code quotes", "…a decision-log line naming a spec or a quoted scope", "the same references in a spec pass") — PASS.
- Survey lists "phase 3", `## Status`, `## Undefined`: smoke `boundary` ("survey lists plan prose, paths and scope ids…") — PASS.
- `docs/roadmap.md` and metarepo `products/roadmap.md` refused naming `.jig/roadmap.md`: smoke `boundary` — PASS.
- Up next parses (no phase), ROADMAP.md shows it, reading-list prints it: smoke `page_contract` ("up next: a roadmap with ## Up next parses…", "ROADMAP.md shows Up next…", "jig reading-list prints…", "reading-list prints a parent page's items… in either order") — PASS.
- Fold-in line for an Up next item; built → `jig merge` removes it in the merge commit: smoke `page_contract` ("the handoff writes one fold-in line…", "jig merge removes the item answered built…") — PASS.
- Metarepo roadmap change asks no log line (M3): smoke `boundary` ("in a metarepo, changing .jig/roadmap.md on trunk asks for no log line") — PASS.
- Review run in a test repo returns the "Demo priorities: A, then B" entry. Input: a throwaway repo with the template jig, last commit adding to `.jig/decisions.md` under ## Unreleased `### D-001 Demo order` / `Touches: docs/demo.md` / "Demo priorities: A, then B. B waits until A is solid on the dev board." The hook accepted it (prose). A fresh reviewer told only to follow plugin/skills/review/SKILL.md returned: "BLOCKING — .jig/decisions.md lines 10-14 (D-001 "Demo order"): the entry is the project, not the product … a priority order and a build/delivery status … belongs in .jig/roadmap.md, never in an entry. Fix: move the sentence to the roadmap and drop D-001."
- `bash tests/smoke.sh`: rc 0, 980 PASS, 0 FAIL (42d2ece); `bash tests/redocument-fixture.sh`: rc 0; `claude plugin validate ./plugin`: ✔ Validation passed; `.jig/scripts/check.sh`: rc 0; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: nothing. Hubnode at 738c23e: boundary, page_contract, roadmap 91 PASS, 0 FAIL.

## Review
Fresh review of fe115a4 by the hubnode. All fixed in 42d2ece:
- B1 reading-list missed items for parent pages and already-shown pages: items print wherever a page first appears; smoke in three argument orders.
- B2 no evidence for the review done-when: recorded above.
- S1 false positives from phase names and bare scope ids: hook refuses only the three paths and a quoted scope id; survey lists the rest; RULES.md matches; smoke passes "Returns `1`", "the v1/api endpoint", "Values 1/screen", "See ROADMAP.md".
- S2 moving a page refused its old lines: added lines read with -M over both rename sides; smoke git mv commits.
- S3 root ROADMAP.md exemption unconditional: exempt only where trunk keeps `.jig/roadmap.md`; smoke in a metarepo.
- S4 entry files outside docs/ unchecked: `product_file` counts a metarepo's .md entry files; smoke.
- S5 survey missed plan paths and scope ids: listed now.
- S6 survey verdict ignored the project it listed: verdict counts it; smoke.
- S7 `(touches …)` never checked: `jig roadmap` reports, trunk hook refuses a stranding commit, `jig merge` re-points moved pages; a job deleting a touched page has its merge refused until the item is fixed on trunk.
- S8 solo built items never removed: `jig gate` refuses solo trunk work until the built item is deleted.
- O1 diff header parsing under diff.noprefix/mnemonicPrefix: fixed prefixes, --no-ext-diff, --no-color on both parsers.
- O2 ITEM_LINE lazy parse: anchored like PAIR_LINE.
- O3 phase message names Up next as the exception.
Deferred, rows in `.jig/ledgers/DEFERRED.md` (optional, [seen]): older logs' re-added lines refused (update-project-sweep); a phase named "Up next" stops being a phase; reading-list reads HEAD while fold-in reads trunk; `plugin/skills/update/SKILL.md:47` stale line (update-project-sweep).

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Documentation, Homes, Fold-in, Roadmap, Decision log, Metarepo).

## Shared files changed
- `.jig/ledgers/DEFERRED.md` (common): four rows for the deferred review findings.

## Test by hand
In a test repo with a roadmap holding `## Up next` and an item `(touches docs/a.md)`: `jig reading-list` on a file docmap gives to docs/a.md shows the item; add `.jig/specs/x.md` to docs/a.md and watch the commit refused; `jig survey` on a page with `## Status` and "phase 3" lists both.

## Left
Nothing on this spec. `update-project-sweep` moves existing content and fixes `plugin/skills/update/SKILL.md:47`.
