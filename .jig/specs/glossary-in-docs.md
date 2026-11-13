# glossary-in-docs

Source: Maige hubnode work, Dave, 2026-11-12: "I dont want README's being pointed to in docs, docs
should only point to other docs. That means at least that glossary has to go into docs, maybe
more."

## Intent
Docs point only at docs. A repo's glossary is a docs file, `docs/glossary.md`, one `## <term>`
heading per term. Pages and decision entries never name a root document (`README.md`,
`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CHANGELOG.md`). The README is for outsiders and may
point into `docs/`, never the reverse.

## Why
- Why move the glossary? It is product vocabulary, and pages cite its terms. While it lives in
  the README, every term citation is a page pointing at a root document. The README's job is
  outsiders, so the arrow points the wrong way.
- Why a rule and not just the move? The project/product boundary made references one-way between
  project and product. This is the same for product and outsiders' material: the README may
  summarise docs, and docs never lean on the README.

## Givens
- `[seen]` RULES.md ~311: the glossary home is `README.md § Glossary`, `### <term>` each, and a
  root `GLOSSARY.md` is listed with that section as where it goes.
- `[seen]` jig.py: `GLOSSARY_HOME`, `glossary_section`, `glossary_terms`, `glossary_text`,
  `glossary_unheaded` (~2324–2370) read the README. `jig init --meta` seeds the section and genre
  headings (~3130). The release term report reads the README's Glossary headings (~4808). M3
  counts a README change only inside its Glossary (~3002). Update's fold-in names README as the
  home for `GLOSSARY.md` (~7186).
- `[seen]` RULES.md ~768, ~782: a metarepo's genre terms are `### <genre>` headings in
  `README.md § Glossary`, and `entry_files` names `README.md` for that section.
- `[seen]` The init, update and retro skills, `tests/smoke.sh` (69 matches) and jig's own
  README name the README glossary.
- `[seen]` In the four Maige repos on 2026-11-12, only maige-ecosystem has a README glossary (its
  redocument moved `GLOSSARY.md` there). Maige-OS's `docs/registry/registry.md` and kept
  `docs/ARCHITECTURE.md` each have one line naming a README.

## Design
- **The glossary file.** `docs/glossary.md`: a `# Glossary` title, an optional lead line, then
  one `## <term>` heading per term, saying what it means and what it is not.
  `docs/glossary.md § <term>` names one.
  - It is not a system page: it is not in `docmap`, covers no files, and is exempt from the
    page-contract checks (part sections, Invariants, a lead paragraph).
  - In a metarepo it sits directly in `docs/`, the one file the genre-folder rule allows there.
    Each genre's term is a `## <genre>` heading in it.
  - Survey names a term written as a bold word opening a paragraph, as today, now in this file.
- **Docs point only at docs.** A page or a decision entry never names a root document. The hook
  refuses an added line in a page or in `.jig/decisions.md` that names `README.md`, `AGENTS.md`,
  `CLAUDE.md`, `GEMINI.md` or `CHANGELOG.md` as a path, with or without `§`, naming the line, as
  it refuses a spec path. `jig survey` lists softer mentions ("listed in the root README") on
  pages and entries, since a hook can't judge prose. Code paths, other pages, decision ids and
  pointers into other repos' docs stay as they are.
- **Moving an existing glossary.** `jig update` lists a README `## Glossary` section, or a root
  `GLOSSARY.md`, under Repo files to review, with `docs/glossary.md` as where it goes.
  `--apply --glossary` moves it on a yes:
  - each term, its text unchanged, from `### <term>` to `## <term>` (a bold-paragraph term
    becomes a heading, as the existing fold-in does);
  - the section, or the file, is removed. The README may keep a one-line link to
    `docs/glossary.md`;
  - every tracked `README.md § <term>` and `GLOSSARY.md` reference is listed to repoint.
    Pages and entries must be repointed before the hook allows their next change.
  
  In a metarepo the move runs on a job branch, as `--sweep` does (M4).
- **A metarepo.**
  - `jig init --meta` seeds `docs/glossary.md`, not a README section.
  - `entry_files` drops `README.md` once the move lands. `docs/**/*.md` already covers the
    glossary.
  - M3's README carve-out goes: the README is no longer an entry file, so its prose needs no log
    line. `docs/glossary.md` changes need one, like any page.
  - The release term report reads `docs/glossary.md`'s `##` headings. For a release whose older
    side has the README glossary, it reads that side's README, so the first release after the
    move reports moved terms, not removed ones.
  - Pararepo pointers `<meta>/README.md § <term>` dangle after the release that moves them.
    `jig sync`'s pin-bump report names each with its new home, `<meta>/docs/glossary.md §
    <term>`.
- **Words.** RULES.md (Documentation, the metarepo's docs tree, entry_files, M3), the init,
  update and retro skills, and jig's README say `docs/glossary.md`.

## Done when
- [ ] Smoke: a repo with a README glossary gets it listed by `jig update`. `--apply --glossary`
      writes `docs/glossary.md` with every term as a `##` heading, text byte-for-byte the same,
      and removes the README section.
- [ ] Smoke: a root `GLOSSARY.md` folds into `docs/glossary.md` the same way.
- [ ] Smoke: the hook refuses an added page line naming `README.md § x`, and one naming
      `AGENTS.md`, and passes a line naming `docs/glossary.md § x`.
- [ ] Smoke: survey doesn't hold `docs/glossary.md` to the page contract, doesn't list it as a
      stray in a metarepo's `docs/`, and names a bold-paragraph term in it.
- [ ] Smoke: `jig init --meta` seeds `docs/glossary.md` with genre headings, and `entry_files`
      has no `README.md`.
- [ ] Smoke: in a metarepo, a README prose change needs no log line, and a glossary term change
      does.
- [ ] Smoke: a release across the move reports each term as moved. A pararepo's
      `<meta>/README.md § term` citation is named at its pin bump with the new path.
- [ ] `grep -rn "README.md § Glossary" plugin README.md` finds nothing.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Moving any repo's glossary. Each repo moves its own through `/jig:update`.
- What the README says to outsiders, beyond losing its Glossary section.
- Specs, handoffs and the roadmap: project artifacts may cite any file.

## Touches
- `plugin/templates/jig/jig.py` (glossary readers, init --meta, survey, update, the hook's page
  line check, release term report, M3, sync's pin-bump report)
- `plugin/templates/jig/RULES.md`, `plugin/templates/jig/docs-page.md` (the glossary's
  exemption)
- `plugin/skills/init/SKILL.md`, `plugin/skills/update/SKILL.md`, `plugin/skills/retro/SKILL.md`
- `tests/smoke.sh`, `tests/redocument-fixture.sh` if its metarepo has a README glossary
- `README.md` (jig's own, the glossary line)
- `marketing/FEATURES.md` (main checkout only)

## Alternatives considered
- Keep the README glossary and exempt it from the rule. Rejected by the owner: "docs should only
  point to other docs". Reason is [seen: owner, Nov 12].
- `.jig/glossary.md`. Rejected: `.jig/` is jig's and the project's, and the glossary is product
  vocabulary that pages cite. Reason is [assumed].
- `docs/glossary/glossary.md`, the folder form. Rejected: the folder form is for a page that
  holds other files, and a glossary holds none. Reason is [seen: RULES.md, Documentation].
- Keep `###` term headings. Rejected: in a file of its own the terms are the top level under its
  title, so `##`. Pointers name the heading text, not its level, so nothing that cites a term
  breaks. Reason is [assumed].

## Decisions
- Interpreted: "docs" covers decision entries as well as pages, since the boundary rule already
  treats both as the product side. The owner may narrow it to pages.
- Interpreted: the root documents named are `README.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`
  and `CHANGELOG.md` (`ROOT_DOCS` plus the rules files).
- Runs after the Maige run's releases, so no repo's glossary moves mid-redocument. Shares
  jig.py, RULES.md and smoke.sh with bug-r3-log-merge and the renames; order it with them at
  open.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
