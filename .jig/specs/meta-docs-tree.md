# meta-docs-tree

Source: maige-ecosystem hubnode session with Dave, 2026-11-10 (Claude) (staged as feedback-maige-ecosystem-2026-11-10-redocument-metarepo.md): "`/jig:redocument` and `jig survey` have no path for a metarepo's pages"

Amended by the owner, Nov 10, overruling the drop: "in this metarepo there was no docs/ and
documentation was split up in the root and several folders within the root … the ideal jig
function would've found those and put them all into a docs/ folder." Then: "the meta repo was
the one with the genre folders because it's the source of truth for multiple other products, so
it makes sense it could categorize it's parts … there's a product ecosystem definition taking
shape in the meta repo, which is where products, features, principles, and more is coming from
… perhaps we ought to invert the requirement on a meta-repo: genre folders only."

Then: "we dont need a system-name file per system folder in meta-repos. Those terms will be well
enough defined in the readme. Jig init a meta repo should ask what your genre folders and have
templates with one being 'product ecosystem' which is this setup."

## Intent
A metarepo keeps its pages under `docs/`, each in a genre folder: `docs/<genre>/<name>.md`
(products, features, principles, concepts, as the metarepo chooses), flat until it holds more
than itself (spec `flat-pages`). Survey finds a metarepo's pages wherever they sit, and
`/jig:redocument` moves them there, tracing each claim to a decision row.

## Why
- Why did redocument refuse in maige-ecosystem? Survey named no page to convert.
- Why none? In a metarepo, every file `entry_files` names is at home, whatever its folder, so
  `products/hardware/walyt.md` is never a page out of place.
- Why is that wrong? `entry_files` says what pararepos cite, not where pages live; letting it
  make homes leaves a metarepo with no layout survey can check.

## Givens
- `[seen]` `jig.py` `doc_homes`: an entry file is a home in a metarepo (`entry`, from
  `meta.json`); page-shape checks gate on `f.startswith("docs/")`.
- `[seen]` RULES.md, Homes: "in a metarepo, what `entry_files` names". RULES.md's own
  `entry_files` example is `docs/**/*.md`.
- `[seen]` Maige-Eco (`maige-ecosystem`) `meta.json`: `entry_files` names `concepts/**/*.md`,
  `features/**/*.md`, `products/**/*.md`, `conventions/NAMING.md`, `decisions/DECISIONS.md`;
  the repo has no `docs/`.
- `[seen]` RULES.md, Documentation: a code repo's pages sit "never under a genre folder", because
  its tree names the product's parts.
- `[assumed]` Other metarepos adopted before this rule spread pages the same way.

## Design
- **Homes in a metarepo.** Pages live under `docs/`, each in a genre folder:
  `docs/<genre>/<name>.md`, or `docs/<genre>/<name>/<name>.md` with its company, its parts as
  subsystems below it. A genre is any folder directly under `docs/`, named by the metarepo; it is
  a category of the ecosystem's definition, not a page, so it has no page of its own and adds no
  depth. A page directly in `docs/` is out of place there. Registers (the decisions register,
  `CHANGELOG.md`) are not pages and stay where `meta.json` names them. RULES.md, Homes drops
  "what `entry_files` names" as a home; `entry_files` keeps saying what pararepos cite. A code
  repo keeps its rule: never a genre folder.
- **Genres are declared at init.** `meta.json` gains an optional `genres` list. `/jig:init`, for a
  metarepo, asks which genre folders it uses and offers templates. The first is **product
  ecosystem**: `products`, `features`, `principles`, `concepts`. The other is custom, where the
  owner names them. It runs `jig init --meta --genres <a,b,…>` or `--genres product-ecosystem`.
  Each genre's term is defined once, as a `### <genre>` heading in `README.md § Glossary`,
  which init seeds. A genre gets no page of its own.
  - With `genres` set, survey reports a page in an undeclared folder under `docs/`.
  - Without `genres`, any folder directly under `docs/` is a genre, so an older metarepo works
    unchanged.
  - Update proposes `genres` from the folders a metarepo already has.
- **What a page traces against there.** RULES.md, one paragraph: a claim's source is a decision
  row, or the pararepo file a pointer names; an Invariant's holder is an accepted decision id;
  Undefined holds the page's open questions. A dated state section is checked against the
  pararepo's trunk and folded into the body or dropped.
- **Survey, in a metarepo.** Every tracked Markdown file outside `docs/<genre>/` that isn't a
  register, a root doc or under `.jig/` is a `page` outside the docs tree, with `to`
  `docs/<its top folder>/<name>.md` when it sits in a folder (`products/hardware/walyt.md` →
  `docs/products/walyt.md`; a genre nested in a genre, `hardware/`, becomes part of the name or a
  page, the remap's call) and `docs/<genre>/` left for the remap when it sits at the root.
  Its footer names `/jig:redocument` (the `bug-redocument-any-format` routing).
- **Redocument, in a metarepo.** The remap gains a Cited-by column: for each moved page, the
  citations of its path or headings in each pararepo in `meta.json`'s `pararepos` (found through
  `jig repos`, `git grep` on its trunk). Cleanup rewrites `entry_files` to the new paths in the
  same final job (M4 already makes cleanup a final job). The release that carries the moves is
  a major; `bug-sync-moved-pages` names each move, and each stale citation, to the pararepos.

## Done when
- [ ] Smoke `metarepo`: a metarepo with `products/hardware/x.md` (in `entry_files`) and no
  `docs/`: `jig survey` lists it as a page outside the docs tree, `to` `docs/products/x.md`, and
  its last line names `/jig:redocument` (the reported symptom gone). The decisions register,
  `CHANGELOG.md` and `README.md` are not listed.
- [ ] Smoke: `docs/products/x.md` with a lead paragraph passes survey; `docs/x.md` in a metarepo
  is reported as needing a genre; `docs/products/products.md` is not required.
- [ ] Smoke: in a plain repo, `docs/products/x.md` is still read as system `products`, part `x`
  (the code repo's rule is unchanged).
- [ ] Smoke: `jig init --meta --genres product-ecosystem` writes `genres: [products, features,
  principles, concepts]` and a `### product` … `### concept` heading under `README.md § Glossary`.
  `--genres a,b` writes those two. With `genres` set, `docs/misc/x.md` is reported as in an
  undeclared genre.
- [ ] `plugin/skills/init/SKILL.md` asks for a metarepo's genres and offers the templates.
- [ ] RULES.md, Homes and Metarepo: the metarepo homes and the tracing paragraph;
  `grep -n "what \`entry_files\` names" plugin/templates/jig/RULES.md` no longer finds it under Homes.
- [ ] `plugin/skills/redocument/SKILL.md`: the Cited-by column and the `entry_files` rewrite at
  cleanup.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- A fixed list of genres: the metarepo names its own, or takes a template. Templates beyond
  product ecosystem wait until a metarepo needs one.
- A page per genre folder: the README's glossary defines each genre (owner, Nov 10).
- `page_roots` in `meta.json` (the report's proposal): one `docs/` tree, genres inside it, needs
  no key.
- A metarepo-specific page skeleton: the contract is the same; only what a claim traces to
  differs.
- Moving any repo's files: redocument does that, per repo, on the owner's yes.

## Touches
- `plugin/templates/jig/jig.py` (`doc_homes`, `page_home`, survey's metarepo branch,
  `cmd_meta_init` `--genres`, `META_DEFAULTS`, update's genre proposal)
- `plugin/skills/init/SKILL.md`
- `plugin/templates/jig/RULES.md` (Homes, Metarepo and pararepos)
- `plugin/skills/redocument/SKILL.md`
- `tests/smoke.sh`

## Alternatives considered
- `page_roots` in `meta.json`, each content folder a docs root (the report's approach) —
  rejected by the owner, who wants them in `docs/` — reason is [seen: owner, Nov 10]
- No genre folders in a metarepo, as in a code repo (this spec's first draft) — rejected by the
  owner: a metarepo defines an ecosystem of products, features and principles, and those
  categories are its structure — reason is [seen: owner, Nov 10]
- Leave metarepo pages where `entry_files` puts them, checked in place — rejected because a
  layout with no rule is what kept survey blind — reason is [seen]

## Decisions
- A metarepo's tree is `docs/<genre>/<name>`; a code repo's is `docs/<system>/<part>`. Genre
  folders are required in one and forbidden in the other, because a metarepo categorizes an
  ecosystem and a code repo names one product's parts.
- Interpreted: the product ecosystem template is products, features, principles and concepts.
  The owner named the first three; concepts is maige-ecosystem's fourth content folder.
- Runs after `flat-pages`, `bug-redocument-any-format`, `bug-sync-moved-pages` and
  `glossary-term-headings`, which provides the README glossary that init seeds.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
