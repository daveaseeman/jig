# glossary-term-headings

Source: maige-ecosystem hubnode session with Dave, 2026-11-10 (Claude) (staged as feedback-maige-ecosystem-2026-11-10-redocument-metarepo.md): "A glossary term is a heading: make it the checked standard." Its terms are bold words in paragraphs, so no anchor exists for any term; "the seed says 'One term per heading' only as a comment in a new file; nothing checks an existing glossary."

Amended by the owner, Nov 10: "glossary should be an acceptable item for any repo. i use a lot
of my own terminology." Then: "can we just adopt Glossary as another part of the readme?? Give
it a section in there and we dont need the file. So many documents begin with a 'definitions'
section, that's what this is."

## Intent
Any repo keeps its terms in a `## Glossary` section of its root `README.md`, one heading per
term, so `README.md § <term>` resolves. There is no `GLOSSARY.md`, and `jig survey` names a
term that isn't a heading.

## Why
- Why does it matter? A `§` pointer names a heading, and `jig sync`'s term report reads only
  heading lines: a bold-paragraph term can't be pointed at, and adding or dropping one goes unreported.
- Why did maige-ecosystem's glossary pass? "One term per heading" is only a comment in the
  `GLOSSARY.md` that `init --meta` seeds; RULES.md says nothing and no check reads a glossary.
- Why the README? It is already every repo's home for what outsiders need, and a glossary is the
  definitions section a document opens with; a second root file adds a home for one section.

## Givens
- `[seen]` `cmd_meta_init` seeds `GLOSSARY.md` with `<!-- One term per heading: what it means,
  and what it is not. -->`; `META_DEFAULTS["entry_files"]` is `["DECISIONS.md", "GLOSSARY.md"]`.
  RULES.md mentions a glossary only in M6's `GLOSSARY: …`.
- `[seen]` RULES.md: a pointer's `§` names a heading; Documentation's homes: "what outsiders need
  in `README.md`".
- `[seen]` `terms_changed` (behind "Changed, in this repo's terms") reads only `^[+-]#{2,3} ` lines
  of entry files. Reproduced at 5e58ca0: a release adding `## vault` and `**chain** — …` and
  removing `**seam** — …` reports `['vault']`.
- `[seen]` In a plain repo, a root `GLOSSARY.md` has no home (`ROOT_DOCS`).
- `[seen]` maige-ecosystem `GLOSSARY.md` (read only): category headings and 45 paragraphs opening
  `**term** —` or `**term** (alias) —`.

## Design
- **The home.** RULES.md, Documentation: a repo's terms are a `## Glossary` section of root
  `README.md`, each term a `### <term>` heading of its own, what it means and what it is not, so
  `README.md § <term>` names it. No other glossary file is a home.
- **Metarepo.** `init --meta` seeds `README.md`'s `## Glossary` section instead of
  `GLOSSARY.md`, and `META_DEFAULTS["entry_files"]` names `README.md` in its place, so `jig sync`'s
  term report reads the terms. M6's example prefix stays `GLOSSARY: …`.
- **The check.** `jig survey`, in any repo, reads `README.md`'s `## Glossary` section and names
  each paragraph there that opens with a bold term followed on its line by a dash or colon
  (`**mote** — …`, `**operation** (registry op) — …`): the count and the first few terms. JSON key
  `glossary_unheaded`. A root `GLOSSARY.md` is a stray whose `to` is "README.md § Glossary".
- **Migration.** `jig update` lists a root `GLOSSARY.md` under Repo files to review and, on a yes,
  moves its terms into `README.md § Glossary` as headings, removes the file, and rewrites
  `entry_files` in a metarepo. Pararepo citations of `GLOSSARY.md` are named by
  `bug-sync-moved-pages`' citation check at the next pin bump.
- Whether a commit gate also refuses an added bold term is the owner's open question (Nov 10).

## Done when
- [ ] `grep -n "## Glossary" plugin/templates/jig/RULES.md` shows the rule.
- [ ] Smoke `homes`: in a plain repo with `**mote** — x` under `README.md`'s `## Glossary`, survey
  names `mote`; with `### mote` instead, survey names nothing.
- [ ] Smoke `homes`: a root `GLOSSARY.md` is listed with `to` `README.md § Glossary`.
- [ ] Smoke `metarepo`: `jig init --meta` writes no `GLOSSARY.md` and a `## Glossary` section in
  `README.md`; a release adding `### vault` there reports `vault` in the pararepo's term report.
- [ ] Smoke: `jig update` lists `GLOSSARY.md` under Repo files to review and changes nothing
  without a yes.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.

## Out of scope
- Checking `GLOSSARY.md#<term>` anchors: that form is the repo's own; jig's is `§`.
- Converting any repo's glossary unasked: update proposes, the repo's owner says yes.
- `terms_changed` missing a changed definition under an unchanged heading (seen: an edit under
  `## grain` reported nothing). A sibling bug, its own spec.

## Touches
- `plugin/templates/jig/jig.py` (`cmd_survey`, `cmd_meta_init`, `META_DEFAULTS`, update's repo
  files to review)
- `plugin/templates/jig/RULES.md` (Documentation's homes, Metarepo and pararepos)
- `plugin/skills/update/SKILL.md`
- `tests/smoke.sh`

## Alternatives considered
- A root `GLOSSARY.md` in every repo (this spec's second draft) — rejected by the owner: a
  glossary is the definitions section a document opens with, so it belongs in the README —
  reason is [seen: owner, Nov 10]
- A commit gate refusing an added `**term** —` line — left to the owner; it would refuse only the
  touched term, converting the glossary as it is edited — reason is [seen: how added-line checks
  like M2 read the diff]
- A `glossary` key in `meta.json` — rejected because the section has one fixed home — reason is [seen]

## Decisions
- The glossary is `README.md § Glossary`, in every kind of repo.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
