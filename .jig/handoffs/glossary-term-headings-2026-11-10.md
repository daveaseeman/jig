# Handoff: glossary-term-headings

Commit: fef4dfce41db95325e3b724c4579b174012717c1
Date: 2026-11-10
Spec: .jig/specs/glossary-term-headings.md
Review: tier 2, effort 2
Ran: fresh Opus review of 60fd1da: B1 every README heading reported as a term (reproduced), fixed in fef4dfc (only ### under ## Glossary); S1 M3 on any README edit, scoped to the Glossary section; S2 update skill promised an unbuilt check, now git grep; O1 hand-made meta.json without entry_files deferred. Hubnode checked fef4dfc by diff and smoke metarepo/report_fixes.

## Built
A repo's terms are a `## Glossary` section of root `README.md`, one `### term` heading each; no `GLOSSARY.md`.
- RULES.md, Documentation: the rule. Metarepo: `entry_files` default, and of README only the Glossary counts (term report, M3).
- `jig survey`: `glossary_unheaded` names bold-paragraph terms in that section, any repo; a root `GLOSSARY.md` is a stray with `to` `README.md § Glossary`.
- `jig init --meta`: seeds README's `## Glossary`; `META_DEFAULTS["entry_files"]` is `DECISIONS.md`, `README.md`.
- `terms_changed` reads README's Glossary `###` headings only; M3 counts README only when its Glossary changes.
- `jig update`: lists `GLOSSARY.md` under Repo files to review; the update skill says what a yes does.

## Done-when evidence
- `grep -n "## Glossary" plugin/templates/jig/RULES.md` → the Documentation paragraph and the Metarepo line.
- smoke `homes`: PASS "survey names mote and seam, bold terms in README.md § Glossary, and nothing outside it"; PASS "with ### headings instead, survey names no term".
- smoke `homes`: PASS "a root GLOSSARY.md is listed with to README.md § Glossary, in --json and in print".
- smoke `metarepo`: PASS "init --meta writes no GLOSSARY.md, a ## Glossary in README.md, and names README.md in entry_files"; `report_fixes`: PASS "a ### term in README.md § Glossary is in the term report" (vault).
- smoke `homes`: PASS "update lists GLOSSARY.md under Repo files to review, and --apply leaves it alone".
- `bash tests/smoke.sh` → rc=0, 761 PASS, no FAIL; `claude plugin validate ./plugin` → Validation passed; the Maige/Daisy/"E-" grep of plugin/ is empty.

## Review
- B1 (blocking): every README heading was reported as a term once README became an entry file. Fixed: `terms_changed` reads only `###` under `## Glossary`; smoke case: a README `## Install` is no term.
- S1: M3 asked a changelog line for any README edit. Fixed: only a Glossary change counts; smoke cases both ways; RULES.md M3 row says so.
- S2: the update skill promised an unbuilt citation check. Fixed: it says `git grep GLOSSARY.md` in each pararepo checkout.
- O1 (optional): a hand-written meta.json with no entry_files switches silently. Deferred, row in DEFERRED.md.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's docs are .jig/RULES.md (plugin/templates/jig/RULES.md), updated here: Documentation § Homes and Metarepo and pararepos (entry_files, M3)

## Shared files changed
- `plugin/templates/jig/jig.py`: survey, init --meta, META_DEFAULTS, terms_changed, M3, update's files to review.
- `plugin/templates/jig/RULES.md`: the rule, and M3's README scope.
- `tests/smoke.sh`: about 20 metarepo lines wrote `GLOSSARY.md`, no longer an entry file; they write `### X` to `README.md` now. New cases in homes, metarepo, report_fixes. Expect merge contact with other jobs' metarepo lines.
- `.jig/ledgers/DEFERRED.md`: O1's row, as the hubnode asked.

## Test by hand
In a throwaway repo, put `**term** — x` under a README `## Glossary` and run `jig survey`: it names the term. `jig init --meta` in a fresh repo writes README.md with `## Glossary` and no GLOSSARY.md.

## Left
Nothing in this spec. The owner's open question stays open: whether a commit gate refuses an added bold term.
