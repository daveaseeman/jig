# Staging picks a target, kind and status by jig's own homes rules

Source: Maige-Lite hubnode session 25f7e824 / 2026-11-13 / Dave Seeman (staged as feedback-maige-lite-2026-11-13-staging-preliminary-research.md): "I wouldn't log those as decisions because they're so preliminary"

## Intent
A session staging a file chooses its target as the repo that owns the subject, its kind by what
the content is, and a decision's status by what the owner said, as RULES.md already places
claims; the resolving session asks the same before landing; and `jig staging check` warns on
every decision entry that says Accepted, since `resolve` logs it as decided.

## Why
1. Why did preliminary hardware research land in a pararepo as two specs and Accepted
   decisions? The chat chose target and kinds; the stage skill asks only "a repo name, or this",
   with no rule for choosing either. [seen]
2. Why no rule? RULES.md's rule for where a claim lives (What the metarepo holds; Homes) is
   applied by the spec role, never by staging, so staging takes the nearest repo and kind. [seen]
3. Why did an entry claim the owner's acceptance unchecked? Nothing says who may write
   Accepted; `check` reads headers only, and `resolve` files Accepted under `## Unreleased`. [seen]

Root: staging chooses target, kind and status without the homes rules jig already has, and
checks only the header.

## Givens
- [seen] `plugin/skills/stage/SKILL.md`: the header's target is "repo name from `jig repos`, or
  this"; "Staging a file" says where to write, never how to choose the target or the kind.
- [seen] `cmd_staging_check` (jig.py): "Headers only"; kind, keys, destination, target listed,
  `after`, cycles; one warning, a near-duplicate target, which doesn't fail the check.
- [seen] Repro in a throwaway repo, current plugin: the reported shape (a `spec` for planned
  hardware and a `decisions` file with `Accepted (Dave, 2026-11-13).`, `target: this`) passes
  `staging check` with no note; `resolve` puts the entry under `## Unreleased` and the spec in
  `.jig/specs/`, both without a question.
- [seen] The same repro: a `Proposed (…)` entry resolves under `## Open`. jig's home for an
  unsettled decision exists (RULES.md: Decision log; Documentation, "An open product question is
  an `## Open` entry").
- [seen] RULES.md, What the metarepo holds: a claim lives where others must agree with it, else
  with its one owner. The spec role's step 4 applies it; staging doesn't mention it.
- [seen] maige-ecosystem is the metarepo of Maige-Lite (`para.json` `meta`); it has a page per
  Walyt mod under `docs/products/walyt/`, and research pages (`towyr/module-research.md`, "Everything
  here is Proposed"; `features/identity/walyt-identity-research.md`).
- [seen] maige-ecosystem's README § Status markers defines Proposed and Open for page text, and
  routes a single-product Open question to the product page. RULES.md defines neither: its
  statuses are the decision log's.
- [seen] The forwarded batch in maige-ecosystem's staging uses existing kinds (`doc new` for
  `docs/products/walyt/battery-research.md`, `doc update` for `recorder.md` and `walyt.md`) and
  passes `staging check` (copies checked from the scratchpad). Its source names "Cowork session
  (Dave + Claude, 2026-11-13)": the owner was in the staging session.
- [seen] Maige-Lite's own staging holds two stories and a request for its firmware: most of a
  pararepo's staged files are its own.
- [seen] The report's `jig_version` (`c2af1224b3cc`, jig.py's blob) predates `roles-and-flows`;
  the staging check and the stage skill's target and kind text are unchanged since.
- [assumed] The original decisions file's entries said "Accepted (Dave, 2026-11-13)": the files
  were forwarded and combined, and no copy is left to read. The fix doesn't rest on it: the
  repro shows the route.
- [assumed] maige-ecosystem's `maige-lite.md` ("hardware spec") pulled the target (the reporter's
  own tag).

## One layer up
- Sibling: the spec role places a claim by What the metarepo holds (its step 4), and `jig survey`
  names a stray's home. Staging is the other door content comes through, and applies neither.
- Pattern: `staging check`'s near-duplicate warning, confirmed with the owner and never failing,
  is the shape for the Accepted warning. `log_prefix_of` reads an id prefix from text where no
  config is, which `check`, run outside any repo, needs.

## General?
Picture any set of registered repos, regular or meta and para: a chat in one repo stages
material about another's subject as `this`, takes the nearest kind, and writes a discussion as
Accepted. Those are ordinary mistakes, and jig already has the rules that place the material.
General: choosing the target by ownership, the kind by content, the status by the owner's word,
and a check-time warning on Accepted.
Too specific: a `research` kind, Proposed markers on pages, routing a one-product Open question
to its page, and a check keyed to a metarepo's `docs/products/`. Those are maige-ecosystem's own
conventions (README § Status markers); RULES.md promises that an unsettled decision is an
`Open`/`Proposed` entry under `## Open`, and that a metarepo page under a genre folder is staged
as `kind: doc`, which the forwarded batch shows works today. maige-ecosystem can state its
research-page and Open-list convention in its own `AGENTS.md`, so a session resolving there
routes to it.

## Design
- **Stage skill, Staging a file.** The target is the repo that owns the subject: the one that
  builds it, or in a set, the metarepo for a product, definition or contract the set shares
  (`.jig/RULES.md`, What the metarepo holds). Never the repo just because the chat runs there:
  when it isn't that one, ask the owner one question naming the candidate. Pick the kind by
  what the content is, not by what's nearest: a spec is a task the target will build; a doc is a
  page in the target's shape; a decision entry says `Accepted (who, date).` only for what that
  person accepted in the chat, else `Proposed` or `Open`. Material that is none of these is no
  file for the nearest kind: ask the owner where it lives.
- **Stage skill, A batch.** The check's Accepted warning is confirmed with the owner, like the
  near-duplicate one: an entry they didn't accept becomes Proposed.
- **Stage skill, Resolving.** Before a file's route, read it: does this repo own the subject,
  and is it as settled as it says? Not this repo's: change `target` with the owner, and
  `resolve` forwards it. Not settled: back to Proposed or Open, with the owner, before resolve.
- **`staging check`.** For a `decisions` file, one warning per entry whose status line parses as
  Accepted: `<id> says Accepted (<who>, <date>): resolve logs it as decided; confirm <who>
  accepted it, else write Proposed`. The prefix is read from the entries' own headings. It never
  fails the check.
- **RULES.md § Staging.** One sentence for the target rule, one for the warning.

## Done when
- [ ] Smoke (staging_batches): `staging check` on a `decisions` file with one
      `Accepted (Dave, 2026-11-13).` entry and one `Proposed (2026-11-13).` entry exits 0 and
      prints one warning, naming the accepted entry's id and Dave; none for the proposed one.
- [ ] Smoke: entries with another prefix (`### X-?a …`, as a metarepo's) are warned alike, run
      outside any repo; a file of another kind gets no such warning, and every existing
      `staging check` case still passes.
- [ ] Smoke, the replay (pararepo section, generic names): the pararepo stages, `target: this`,
      two `spec` files about a product its metarepo has a page for, and a `decisions` file with
      four Accepted entries. `staging check` prints four warnings, one per entry, and passes. The
      corrected batch, targeting the metarepo by name, `doc new
      docs/<genre>/<product>/<product>-research.md` (its claims marked Proposed) and `doc update`
      to the product's page `after:` it, passes with no warning. `staging resolve` in the
      pararepo forwards both into the metarepo's `.jig/staging/`; there, the research page
      resolves to its path carrying its `Source:` line, and the update waits until the product
      page carries its mark. No new kind is used.
- [ ] Smoke greps `plugin/skills/stage/SKILL.md` for the target rule (naming What the metarepo
      holds), the status rule (`Accepted` only for what was accepted), and the Resolving
      question; and RULES.md § Staging for the target sentence and the warning.
- [ ] `marketing/FEATURES.md`'s staging-batches row names the warning and its why.
- [ ] `.jig/scripts/check.sh` passes, the `staging`, `staging_batches` and `pararepo` sections
      pass, `claude plugin validate ./plugin` passes, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` is empty.

## Out of scope
- A `research` kind, page-level status markers, and per-product Open lists: maige-ecosystem's
  conventions, which it can state in its own `AGENTS.md` (General?, above).
- A home for unsettled research in a code repo: RULES.md's homes are a closed list, and adding
  one is a change to jig's documents, for the owner as a feature request, not this fix.
- A warning keyed to a metarepo page named in a pararepo file, or to every pararepo target
  (Alternatives considered).
- maige-ecosystem's `maige-lite.md` wording ("hardware spec"): that repo's page.
- A register's rows, in a repo not yet on the log: not read by the warning.
- The original symptom's long exchange is closed by the skill's target and kind rules and the
  Resolving question; no code can prove a session asks, so the replay proves only the check.

## Touches
- `plugin/templates/jig/jig.py` (`cmd_staging_check`)
- `plugin/skills/stage/SKILL.md` (Staging a file, A batch, Resolving)
- `plugin/templates/jig/RULES.md` (§ Staging)
- `tests/smoke.sh` (`staging_batches`, `pararepo`)
- `marketing/FEATURES.md` (the staging-batches row)

## Alternatives considered
- A `research` kind (the report's) — rejected because `kind: doc` already lands a metarepo
  research page, and the forwarded batch passes `staging check` today; Proposed on a page is
  maige-ecosystem's README convention, not RULES.md's — this reason is [seen].
- A `staging check` warning when a pararepo-targeted doc or spec names a page under the
  metarepo's `docs/products/` (the report's) — rejected because a pararepo is meant to cite its
  metarepo's pages (RULES.md, Citing the metarepo), `products` is one metarepo's genre, and the
  report's target was `this`, which `check` doesn't resolve to a repo — this reason is [seen].
- A warning on every file that targets a pararepo — rejected because most of a pararepo's staged
  files are its own (Maige-Lite's: two stories and a request) [seen], so it would fire on nearly
  all and be ignored — this reason is [assumed].
- Warn only when `source:` is a working session with no quoted acceptance (the report's) —
  rejected because `source:` is free text (`<session / date / author>`), so jig can't tell a
  quote from a description; one line per Accepted entry covers the route that commits — this
  reason is [seen].
- `resolve` refusing an Accepted entry without an `--accepted` flag — rejected because the owner
  sat in the staging session here, where the check's warning reaches, and resolve already runs
  with the user — this reason is [assumed].
- Resolve rerouting "preliminary" files to a research path (the report's) — kept only as the
  Resolving question, without the research path: jig can't judge fit, and the path is the
  metarepo's convention — this reason is [seen].

## Decisions
- The Accepted warning never fails `check`, like the near-duplicate one: an entry the owner did
  accept in the chat is right as written.
- Interpreted: "Not settled" in Resolving means the owner says so; the session asks, it doesn't
  judge alone.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
