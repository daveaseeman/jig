# bug-touches-abstract

Source: maige-ecosystem hubnode session / 2026-11-13 / Dave (staged as feedback-maige-ecosystem-2026-11-13-touches-abstract-entries.md): "`Touches:` has no value for
an entry about something more abstract than a page … Some decisions rule on no page." Dave:
"/jig:feedback needs an option for when it applies to something more abstract, cite three
examples (a whole repo, how we name products, etc)".

## Intent
An entry that rules on a term, such as how products are named or the brand name, can say so
with `docs/glossary.md § <term>`. An entry that rules on no page or term, such as a rule for
the whole repo, can say so with `Touches: none — <reason>`. Either passes M2, `jig update` stops
listing it, and `--peers` says what peers each one can have.

## Why
- Q: Why can't E-001 or E-021 be written? A: `touches_problems` takes a pointer only if it is
  `docs/….md` and exists. No other value passes, and an empty line counts as no line.
- Q: Why only pages? A: peers are found by shared pages (`keys_meet`), so M2 accepts only what
  can be paired. RULES.md: "Pages are the shared vocabulary".
- Q: Why does that fail? A: the vocabulary's own home, the glossary, can't be named one term at
  a time, and nothing allows "no page". The author has to name a false page, list every page,
  or leave the entry unfixable. Root: Touches has only one form, a whole page.

## Givens
- `[seen]` v0.12.1's jig.py is the report's `jig_version` (blob a8a32d1). Main (de3cc14) behaves
  the same way: `touches_problems` is now at `plugin/templates/jig/jig.py:4899`.
- `[seen]` Throwaway metarepo (`/private/tmp/claude-501/touches-abstract/m`, `init --meta`,
  pages `docs/products/{alpha,beta}.md`, `docs/features/{pay,pass}.md`). Every candidate value,
  checked with `jig check --staged` on an added entry:
  - no line, or an empty `Touches:`: M2 "names no page it touches";
  - `Touches: repo`, `docs/features/`, `docs/features` and `none — the whole repo`: M2 "is no
    docs page";
  - `Touches: README.md § Naming` and `README.md`: M2, plus the root-document check: "the
    decision log points only at docs … a term is docs/glossary.md § <term>";
  - `Touches: docs/glossary.md § products`: M2 "is no docs page". **The check above tells the
    author to use this form, and M2 refuses it.**
  - `Touches: docs/glossary.md` passes, and has no peers with an entry on `docs/features/pay.md`.
  - The four-page list passes, and pairs D-001 (naming) with D-002 (pay rounding) on
    `docs/features/pay.md`. That pair is the false peer the report describes.
- `[seen]` `untouched_entries` lists only entries with no line at all (`entry_touches` returns
  None). An empty line isn't listed, but M2 refuses the entry once it changes.
- `[seen]` RULES.md: a metarepo genre "has no page of its own … its term is a `## <genre>`
  heading in `docs/glossary.md`". A `docs/features/` folder pointer would name something RULES
  says isn't a page. The genre's own term already exists.
- `[seen]` RULES.md (Documentation): `docs/glossary.md § <term>` names a term. `glossary_terms`
  and `glossary_term_in` (jig.py:3211) already resolve that form. Since glossary-in-docs, the
  log may not point at a root document, so the report's `README.md § Naming` is ruled out.
- `[seen]` Precedent for "no target, with a reason": P2's `meta: none — <reason>`.
- `[assumed]` E-021's and E-024's terms (the product and feature genres, the family name) are,
  or can be, glossary headings in maige-ecosystem. The fix doesn't depend on it, since any repo
  can add the term.

## One layer up
- Sibling: the handoff's fold-in `(touches …)` on scopes and roadmap items takes page pointers
  too, but no hook demands it. Only the decision log has this wall.
- Generality (fix step 3): a regular repo's log has the same kind of entry. "All errors are
  typed" or "names are kebab-case" rules on no docmap page, so it hits M2 the same way. Nobody
  has to work against jig to trigger it: honest entries do. Keep it.
- Pattern that already solves the shape: a glossary term is the shared vocabulary that RULES.md
  says pages stand for. Naming a term is the same idea at a finer grain.

## Correction
1. **Glossary terms.** A pointer to the glossary may carry `§ <term>`
   (`docs/glossary.md § products`, or `<meta>/docs/glossary.md § products` from a pararepo, read
   from the cache at the pin). M2 checks that the term is in that glossary (`glossary_term_in`),
   or checks only its shape when there is no cache. That is the same leniency pages get. `§`
   is refused on any other page, so a pointer can't break when an ordinary heading is renamed.
   Peer key: the term under the glossary page (`docs/glossary/<term>`), so `keys_meet` pairs
   two entries on one term, and a bare `docs/glossary.md` pointer meets every term (the page
   above).
2. **None, with a reason.** `Touches: none — <reason>` is the whole line: the reason has a
   word, and it doesn't mix with pointers. It passes M2, `jig update` doesn't list it, and it
   peers with nothing. `jig decision <id> --peers` prints "<id> touches no page (<reason>), so
   it has no peers", and the fold-in gives it no pair lines. Parse it before the comma split,
   so a reason can contain commas.
3. RULES.md: the Touches paragraph gives both forms, says when to use each, and says what each
   does to peers. The Peers paragraph adds "or name one glossary term". M2's row adds both.
4. `marketing/FEATURES.md`: extend the Decision log row's Touches clause (what, why, what it is
   not).

How the report's examples come out:
- E-001 (whole repo): `none — the metarepo points and never copies`;
- E-021 (naming): `docs/glossary.md § products, docs/glossary.md § features`;
- E-024 / E-056 (brand): `docs/glossary.md § <family name>`;
- E-032 (vocabulary in other repos): `docs/glossary.md`, which already passes today.

## Done when
- [ ] Smoke, the reported symptom: in a metarepo, an entry with
      `Touches: docs/glossary.md § products` (the term is a heading) and an entry with
      `Touches: none — repo-wide rule` both pass `check --staged`, and `jig update` lists neither.
- [ ] Smoke, the fix fires: `--peers` on two entries naming `§ products` lists each as the
      other's peer. An entry naming `docs/glossary.md` peers with both. An entry on
      `docs/features/pay.md` peers with none of them. `--peers` on the `none` entry prints
      "touches no page" and its reason.
- [ ] Smoke, still refused: `§ nosuchterm`, `docs/products/alpha.md § Intro` (a `§` off the
      glossary), `Touches: none` with no reason, `none — x, docs/a.md`, and a missing page.
- [ ] Smoke, pararepo: `<meta>/docs/glossary.md § products` with the cache at the pin passes,
      and with a term the cache lacks it is refused.
- [ ] Fold-in: a branch adding a `§ products` entry next to a trunk entry on `§ products` gets
      one pair line. A `none` entry gets none.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- `§` on pages other than the glossary. It can be added when an entry needs it.
- A folder or genre pointer that stands for every page under it (see Open).

## Alternatives considered
- `Touches: repo` keyword — rejected because it means the same as `none` but reads like a
  pointer. If it peers with every entry, every handoff gets a line for it; if it peers with
  nothing, that's `none` under another name. It also has no meaning across repos
  (`mm:repo`?) — this reason is [assumed].
- A folder pointer (`docs/features/`) — rejected because RULES.md says a genre has no page and
  its term lives in the glossary. Its peers are the same as listing every page, which is the
  noise the report complains about (D-001 paired with D-002 on pay.md) — this reason is [seen].
- `README.md § <heading>` — rejected because glossary-in-docs forbids the log from pointing at
  a root document, and the hook already refuses it — this reason is [seen].
- A bare empty `Touches:` line meaning "none" — rejected because it carries no reason, and a
  forgotten line would look the same — this reason is [assumed].

## Decisions
- **A genre term does not peer with the pages in its genre** (Dave, 2026-11-13: "Yes, open all eight", taking the hubnode's recommendation). `§ features` peers only with entries naming `§ features` or the whole glossary.

## Open (answered above)
- **The owner's call: does a genre term peer with the pages in its genre?** Recommended: no.
  `§ features` peers only with entries naming `§ features` or the whole glossary. That keeps
  E-021 from pairing with every feature decision. The cost: a page entry that renames one
  feature ("pay is called Payy") isn't put beside the naming rule unless it also names the
  term. The report's own Done when asks for yes ("prints the entries touching a page under
  that folder"), which brings back peers with everything.

## Touches
- `plugin/templates/jig/jig.py`: `entry_touches`, `touch_key`/`page_key`,
  `touches_problems`, `untouched_entries`, `cmd_peers`
- `plugin/templates/jig/RULES.md`: Decision log (Touches, Peers), the M2 row
- `tests/smoke.sh`: the metarepo and para decision sections
- `marketing/FEATURES.md`: the Decision log row

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
