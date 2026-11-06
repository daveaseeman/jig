# Docs page contract: describe, don't legislate

Source: cowork session 2026-11-06, Dave with Claude (staged as docs-page-contract.md)

Source: Dave, 2026-11-06 — "the rules should tell agents how to build documentation,
they shouldn't be the documentation." The Now/Rules/Checks format turns one-off fixes
into sweeping numbered rules that accumulate forever and read as law.

## Intent
Replace the Now/Rules/Checks page contract with a descriptive one: a page states what is
true of its system on trunk today, in prose. Constraints survive only as a short
Invariants list with a stated why and holder. Parked work gets a non-binding Undefined
section. The rules about documentation live in RULES.md, never inside docs/.

## The new contract (RULES.md § Documentation)
Tree unchanged: `docs/<system>/<system>.md`, subsystems nested the same way; docmap,
fold-in, seam pages, hardware pages, pointers all stay.

Every page:
1. **Lead paragraph** — what the system is and why it exists. No heading.
2. **Body sections** — free-form description, present tense. Sections are named for the
   system's own parts (nouns the code has: Schema, Renderer, Sync), never lifecycle or
   genre headings (Overview, Notes, Misc, Changes). When a section outgrows a screen or
   acquires files of its own, it becomes a subsystem folder with its own page and the
   parent section shrinks to a paragraph plus a link.
3. **`## Invariants`** (optional) — only facts that are load-bearing. Admission test:
   each entry states *why* it must hold and *what holds it*, inline
   (`- Rows are at least 44px — touch-target minimum; held by test_touch_targets.`).
   No why + holder → it is description and goes in the body, or nowhere. No separate
   Checks section.
4. **`## Undefined`** (optional, always last) — work intentionally parked mid-build.
   Entries are written only on the owner's word: what was parked, where it stops, date.
   Nothing in it binds; nothing in it is a promise. Boundary: Undefined is parked work
   placed where the work lives; `.jig/ledgers/DEFERRED.md` is the log of review findings
   not yet implemented. Different things; file in one, not both.

Precedence inverted: trunk's code is reality. A page that disagrees with code is a stale
page; an invariant that disagrees with code is a finding the handoff surfaces for a
person to rule on — never an automatic instruction to bend the code.

Numbered rule headings and citation-by-number are gone: cite by heading
(`docs/ui/ui.md § Invariants`), which the pointer syntax already matches. R6 section
counters for docs pages are dropped from the template config examples; R6 itself stays
for genuinely scarce numbers (schema versions, migration steps).

## Mechanics
- **Fold-in question** becomes "does this page still describe the code?" — answered by
  editing the stale sentences or stating why none went stale. Deleting text is a
  first-class answer. Additionally, each Undefined entry on a covering page gets its own
  checklist line, answered **built** / **untouched** / **departed: <why>**. The gate
  refuses only blanks, exactly as today — departed and untouched are answered.
- **Built means moved, not copied.** The content enters the body and the Undefined entry
  is deleted in the same commit. Fold-in's built answer requires the deletion.
- **Spec skill**: /jig:spec reads the reading-list pages and must address any Undefined
  entry touching the task's files (adopt, depart with a why, or leave). Advisory by
  design — prompt-level, no jig.py check.
- **Survey**: flag (a) a Now/Rules/Checks-format page (invert the existing pattern
  match) as "old contract — convert"; (b) an Invariants entry missing a why or a holder;
  (c) any content after `## Undefined`; (d) a page with no lead paragraph.
- **Retro**: triage Undefined sections alongside the two ledgers; an entry that has sat
  unclaimed for months is a delete candidate, on the owner's word.
- **Template**: ship a docs page template in `plugin/templates/` so fold-in's UNOWNED →
  new-page path starts from the skeleton.

## Migration
`jig update` ships the new RULES.md; it does not rewrite pages. Survey flags old-format
pages; converting each is a normal job in that repo (reabsorb pseudo-rules as
description or delete them; keep only invariants that pass the admission test). The
conversion prompt for that first pass is a follow-up conversation, out of scope here.

## Done when
- [ ] `plugin/templates/jig/RULES.md § Documentation` states the new contract; Homes
      updated (survey looks for the new skeleton, not Now/Rules/Checks)
- [ ] docs page template exists in `plugin/templates/` and the UNOWNED path names it
- [ ] `jig handoff` writes an Undefined checklist line per entry on covering pages;
      `jig gate` refuses a blank one and passes departed/untouched (smoke covers both)
- [ ] `jig survey` flags an old-format fixture page, an invariant without why/holder,
      and content after Undefined
- [ ] spec and retro skills carry the Undefined duties above
- [ ] `bash tests/smoke.sh` passes; `claude plugin validate ./plugin` passes

## Out of scope
- Converting any adopting repo's existing pages (per-repo jobs, later)
- The first-pass rewrite prompt for those conversions
- Changes to R6 itself, docmap matching, or the metarepo pointer syntax

## Touches
- plugin/templates/jig/RULES.md (Documentation, Homes)
- plugin/templates/jig/jig.py (handoff checklist, survey checks)
- plugin/templates/ (new docs page template)
- plugin/skills/survey/SKILL.md, retro/SKILL.md, spec/SKILL.md
- tests/smoke.sh fixtures touching docs pages

## Alternatives considered
- Keep numbered rules, raise the admission bar only — rejected because the number
  economy (citable, reserved, append-only) is itself the accumulation incentive — reason
  is [seen]
- Abolish constraints entirely, pure description — rejected because a few facts per
  system genuinely must not drift (protocols, schema discipline); the fix is the
  admission test, not abolition — reason is [seen]
- Put parked work in DEFERRED.md instead of Undefined — rejected because DEFERRED is
  review-findings triage, repo-wide; parked work must sit where the work lives so
  reading-list surfaces it in context — reason is [seen]

## Decisions
- Undefined entries are written only on the owner's word
- Precedence inverted: code on trunk wins; disagreement is a finding, not a command
- Built means moved, not copied — deletion in the same commit

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
