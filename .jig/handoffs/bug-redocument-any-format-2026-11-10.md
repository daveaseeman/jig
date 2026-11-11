# Handoff: bug-redocument-any-format

Commit: 32e405c13845c9089f83d538597a127704b4fdcf
Date: 2026-11-10
Spec: .jig/specs/bug-redocument-any-format.md
Review: tier 2, effort 2
Ran: fresh Opus review of 4131d2e (Maige-OS clone at b57615a: 44 docmap pages listed, footer names /jig:redocument): B1 update said up to date and never listed off-contract pages, fixed in 32e405c; S1 root docmap key, S2 package READMEs fixed; O1 deep pages out of update routing, O2 clean-repo footer. Hubnode checked 32e405c by diff and smoke homes/update.

## Built
<!-- what this delivers, in a few lines -->
`doc_homes` makes a file `docmap` names a `page` wherever it sits and whatever its format,
except a README.md, which stays as its folder's own document. In a jig repo, survey's last line
never names /jig:adopt. It names /jig:redocument for pages to convert (outside the docs tree,
the old shape, old boards), /jig:update for pages at home that are off the contract (deep pages
excluded), and otherwise "On jig already: nothing to do." `jig update` lists each off-contract
page at home under Repo files to review, with its problems, even on an up-to-date repo (exit 0).
A root docmap page moves on its own. The redocument skill's refusal reads survey's last line:
`no page to convert: nothing to redocument`. Its step 1 declines all page moves, its seed
covers every page to convert, and its Subnode section has the metarepo tracing line. The
survey, update, RULES.md (Homes) and README texts match.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- Smoke `house:` cases: docs/crates/s/{store,lib}.md (Does/Gotchas, docmap keys) appear under "Pages outside the docs tree", not under "never read since"; the last line names /jig:redocument; update proposes both git mv lines with their docmap keys — PASS
- Smoke: a page at home with no lead paragraph → last line names /jig:update; update (current repo, not behind) is up to date, exits 0 and lists it with "no lead paragraph"; the same page with no board → /jig:adopt; a jig repo with only a stray → no /jig:adopt — PASS
- `bash tests/redocument-fixture.sh`: rc=0; the clean repo prints `no page to convert: nothing to redocument`; the fixture prints `start: pages to convert found, board quiet`
- Maige-OS clone at b57615a: the hubnode ran it; 44 docmap pages under "Pages outside the docs tree", last line /jig:redocument
- `grep -n 'In a metarepo' plugin/skills/redocument/SKILL.md` → the tracing line in Subnode step 1
- `bash tests/smoke.sh`: 816 PASS, 0 FAIL; `claude plugin validate ./plugin`: ✔ Validation passed; the Maige/Daisy grep on plugin/: empty

## Review
<!-- findings from the adversarial review, and what you did about each -->
- B1 (blocking) update printed only "up to date" on a current repo: fixed; Repo files to review now print there, the skill shows them, the smoke runs without behind
- S1 a root docmap key grouped under "/": fixed; it groups under its own name, and there is a case
- S2 package READMEs routed to docs/README.md: fixed; a docmap README.md stays put, and there is a case
- O1 deep pages routed to /jig:update: fixed (`in_place`)
- O2 the clean-repo footer: fixed, "On jig already: nothing to do." 

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — add to docmap (a new page starts from .jig/docs-page.md), or no page needed because jig.py is described by RULES.md and the skills, which this change updated (Homes, survey, update, redocument)

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- plugin/templates/jig/jig.py: doc_homes, the survey footer, update's up-to-date output and home_findings, as the spec's Touches lists; each change is local to those functions
- plugin/templates/jig/RULES.md: one Homes sentence (docmap-named files)
- tests/smoke.sh: new `house:` cases at the end of sec_homes; five exact "up to date" checks now read the first line, since update now lists files to review there
- plugin/skills/redocument/SKILL.md, plugin/skills/update/SKILL.md: the refusal, step 1, the seed and the tracing line; the up-to-date case and off-contract pages

## Test by hand
<!-- what a person should click or watch -->
In a jig repo with a house-format page that docmap names outside docs/, run `jig survey`: its
last line names /jig:redocument. Move the page to docs/ with no lead paragraph: survey names
/jig:update, and `jig update` lists the page under Repo files to review.

## Left
<!-- what remains on this job -->
Nothing on this job. The FEATURES.md row is the hubnode's. meta-docs-tree builds on this routing.
