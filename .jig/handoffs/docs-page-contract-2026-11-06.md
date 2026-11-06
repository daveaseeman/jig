# Handoff: docs-page-contract

Commit: 13d82627295e920e8ff2bcf24fc1fcb0c26e821d
Date: 2026-11-06
Spec: .jig/specs/docs-page-contract.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown, fresh context (subagent; effort set to high, not readable by the subagent); should-fix A–D fixed by 13d8262, optionals taken but one deferred

## Built
<!-- what this delivers, in a few lines -->
Docs pages describe what is built rather than legislate. RULES.md § Documentation states the new
contract: a lead paragraph, sections named for the system's parts, optional Invariants (why +
holder), optional Undefined last; code on trunk wins; pages are cited by heading. The skeleton
ships as `.jig/docs-page.md`, and update installs it. Fold-in writes one line per Undefined entry
on a covering page (built / untouched / departed: why). The gate refuses blank, ambiguous or
why-less answers, and a built entry still on the page word for word or reworded (matched on the
entry's name). Survey flags old-contract pages, invariants missing a why or holder, sections
after Undefined, and pages with no lead. The spec, retro and survey skills carry the Undefined
duties.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- RULES.md § Documentation + Homes: new contract and survey's page checks — reviewed by the hubnode at 13d8262
- docs page template: `plugin/templates/jig/docs-page.md`; RULES.md Fold-in and the UNOWNED line name `.jig/docs-page.md`; smoke "update installs .jig/docs-page.md in a repo that lacks it, and a rerun is up to date" PASS
- handoff Undefined lines + gate: smoke `page_contract` PASS: one line per entry; refuses blank; passes untouched/departed with trailing text; refuses built still there, built reworded; passes built beside an unrelated new entry; refuses two answers and bare departed; solo trunk commit gets its line
- survey: smoke `page_contract` PASS: old contract — convert; invariant without why/holder; section after Undefined; no lead paragraph; board and contract pages not flagged
- spec and retro skills: plugin/skills/spec/SKILL.md step 4, plugin/skills/retro/SKILL.md Undefined triage
- `bash tests/smoke.sh`: 612 PASS, 0 FAIL, exit 0 at 13d8262 (side-session notes, docs-page-contract-smoke-4.out); `claude plugin validate ./plugin`: ✔ Validation passed; `.jig/scripts/check.sh`: exit 0; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: no matches

## Review
<!-- findings from the adversarial review, and what you did about each -->
Hubnode review of b47bd64 (tier 2, effort 2), recorded at 13d8262. No blocking findings.
- Should-fix A, built passing when the entry was edited rather than deleted: fixed. The gate matches on the entry's name (exact text, or a new entry whose name contains it or has difflib ratio >= 0.6); an unrelated new entry passes. Count rule tried in 9c3e60e and replaced in 13d8262.
- Should-fix B, template unreachable from adopting repos: fixed. Moved to templates/jig/docs-page.md → `.jig/docs-page.md`, added to update's tool files.
- Should-fix C, answers with an explanation refused: fixed. Any case, trailing text allowed; refusals say why.
- Should-fix D, update skill said "a page's Rules": fixed ("a page's Invariants").
- Optionals taken: adopt skill's `section=<held>` dropped; R6 docstring generic; one RULES.md sentence on dotted numbers; solo fold-in reads `HEAD~1:page`; UNDEF_LINE non-greedy.
- Optional deferred: a misplaced lead-and-body page is a `stray`, not a `page`. Row in `.jig/ledgers/DEFERRED.md`.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's repo has no docs/ pages; RULES.md is its rulebook and was updated in this change

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- plugin/templates/jig/RULES.md: the Documentation contract itself, Homes, Fold-in, Reserved numbers example, pointer prose.
- plugin/templates/jig/jig.py: fold-in Undefined lines, gate checks, survey page checks, update installs docs-page.md, R6 docstring.
- tests/smoke.sh: new `page_contract` section; four existing cases now list `.jig/docs-page.md`.
- plugin/templates/AGENTS.md: the "rules in a page bind" line contradicted the contract.
- plugin/templates/jig/docs-page.md: new (shares widened at c53d2ef).
- plugin/skills/update/SKILL.md, plugin/skills/adopt/SKILL.md: fix D and an optional (shares widened at c53d2ef).
- .jig/ledgers/DEFERRED.md (common): one deferred row.

## Test by hand
<!-- what a person should click or watch -->
In a throwaway repo: add a docs page with an `## Undefined` entry, docmap it, open a job, change covered code and run `jig handoff`. The note has a line for the entry. Answer it `built — …` without deleting the entry: `jig gate` refuses and names it. Delete it: the gate passes. Then run `jig survey` on a Now/Rules/Checks page and look for "old contract — convert".

## Left
<!-- what remains on this job -->
Nothing on this job. Follow-ups outside its scope: converting adopting repos' pages, and the first-pass conversion prompt (per the spec). The init skill's copy list (`templates/jig/ → .jig/`) doesn't mention docs-page.md; it's copied anyway.
