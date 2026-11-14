# Every copy of a claim, listed at the spec

Source: maige-ecosystem hubnode session / 2026-11-13 / Dave (staged as feedback-maige-ecosystem-2026-11-13-job-flow-speed.md): "why are these taking so long?"

## Intent
A spec that changes a claim starts from a list of every tracked place that states it, so the
review stops being where a second copy is found. `jig reading-list --claims <id or term>…`
prints that list, and `/jig:spec` runs it for each claim the spec changes.

## Done when
- [ ] `jig reading-list --claims <id>` lists, by file and line, every tracked line that names
      the decision id (in any form the log accepts, a superseded id hopping to its successor as
      `jig decision` does), the entries that peer with it by `Touches:`, and each page citing it
      as a source. Smoke: a fixture with an id in a page, a table row, a status sentence and a
      peer entry lists all four.
- [ ] `jig reading-list --claims <term>` lists the term's glossary entry (`docs/glossary.md §
      <term>`, in either form), each `§ <term>` pointer, each entry whose `Touches:` names it,
      and each line of a page or entry that uses the term as a whole word. Smoke.
- [ ] Each hit is marked `home`, `pointer` or `copy`: the home is the decision or the glossary
      entry; a pointer is a `§` reference or a link to the home; anything else is a copy. Smoke
      checks one of each.
- [ ] `jig reading-list <paths>` without `--claims` prints what it prints today. Smoke.
- [ ] `/jig:spec` says: in a repo with a decision log or a glossary, run `--claims` for each id
      and term the spec changes, list each copy in Touches, and give each a done-when item.
      Matching by meaning stays the spec writer's: the command finds names only.
- [ ] RULES.md § Every copy names `jig reading-list --claims` as where the list starts.
- [ ] `bash tests/smoke.sh`, `claude plugin validate ./plugin`, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Finding a claim stated in other words: no grep finds a paraphrase, and the rule already asks
  for meaning.
- Searching registered pararepos' checkouts: a claim a pararepo owns is stated there and pointed
  at here; `jig decision --peers` already crosses repos for ids.
- Refusing a spec that skipped the list: a skill step, as the owner chose for this one.

## Touches
- `plugin/templates/jig/jig.py` (`cmd_reading_list`, its parser; reusing the decision-log,
  glossary and peers readers)
- `plugin/templates/jig/RULES.md` § Every copy
- `plugin/skills/spec/SKILL.md`
- `tests/smoke.sh` (a new `claims` section)

## Alternatives considered
- A new `jig claims` command — rejected because `reading-list` already answers "what to read
  before touching this", and a flag keeps one entry point — [assumed].
- Running it inside `jig open` — rejected because the spec is written, and its Touches fixed,
  before the job opens; the list belongs at writing time — [seen] in the report: the misses
  were in specs, found at review.

## Decisions
- Calls the owner made on 2026-11-13: its own spec, separate from the job-flow fixes.
- Interpreted: whole-word matching on the term as the glossary spells it, case-insensitive,
  outside code blocks.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
