# Handoff: page-talks-to

Commit: d5ce40ebbb7e89d211ace651f5282237ac085b58
Date: 2026-11-10
Spec: .jig/specs/page-talks-to.md
Review: tier 2, effort 2
Ran: fresh Opus review of 42309f2: no blocking; S1 CONTRACT_HEADS doesn't count Talks to as a page marker, deferred (docmap signal in bug-redocument-any-format); O1 adopt subsystem wording fixed in d5ce40e. Hubnode checked d5ce40e by diff.

## Built
The page contract gets an optional `## Talks to` section, after the body and before Invariants, for what crosses the system's boundary, linked to its seam page or contract. RULES.md (Documentation, new item 3), `docs-page.md`, and the survey and redocument skills all say so. Redocument also says an old page's uses/serves list goes there, keeping only what crosses the boundary. A subsystem now gets a page of its own once it has something to say that its system's page doesn't; it no longer simply "moves to" one. RULES.md item 2, `docs-page.md` and adopt's docs row say so.

## Done-when evidence
- `grep -n '^## ' plugin/templates/jig/docs-page.md` printed `## <Part>`, `## Talks to`, `## Invariants`, `## Undefined` in that order. RULES.md:160 names `## Talks to` as optional.
- Scratch repo, `jig survey --json`: with Talks to before Invariants, no `page_contract` entry. With Talks to after Undefined: `sections after ## Undefined: Talks to — Undefined is last`.
- `grep -n 'Talks to'` found survey SKILL.md:33 and redocument SKILL.md:169–170 (the contract list and the Subnode line).
- `grep -n 'something to say'` found RULES.md:157 and docs-page.md:10. `grep -n 'moves to'` finds no subsystem sentence in either.
- `claude plugin validate ./plugin` passed. `bash tests/smoke.sh` exited 0 with 751 PASS and 0 FAIL, on 42309f2. d5ce40e changes only skill text and a ledger row, and the validator passed on it. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` found nothing.

## Review
- Nothing blocking.
- S1, should-fix: `CONTRACT_HEADS` in jig.py doesn't count Talks to as a page marker. Deferred, with a DEFERRED.md row: Talks to is common in house formats, and docmap becomes the page signal in bug-redocument-any-format.
- O1: adopt's docs row implied that every subsystem has a page. Fixed in d5ce40e.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] no code changed — nothing to fold in

## Shared files changed
- `plugin/templates/jig/RULES.md`: Documentation items 2–3 only. Item 3 is new, so Invariants and Undefined are now items 4 and 5.
- `plugin/skills/adopt/SKILL.md`: added to shares for O1. One table row changed.
- `.jig/ledgers/DEFERRED.md`: one row appended for S1.
- `tests/smoke.sh`: not touched.

## Test by hand
Open `plugin/templates/jig/docs-page.md` and read the Talks to block and the subsystem sentence in `<Part>`.

## Left
Nothing. The FEATURES.md Docs shape row is the hubnode's.
