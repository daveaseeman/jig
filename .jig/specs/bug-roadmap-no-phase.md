# Bug: a roadmap has no place for work with no stage, and its view drops each phase's note

Source: jig hubnode session, staged on Dave's word ("go ahead and stage it now") / 2026-11-13 / Dave with Claude (staged as feedback-Maige-Familiar-2026-11-13-roadmap-no-stage.md): "A roadmap has no place for an item with no stage." and "The view also leaves out each phase's note, so the note saying it is not a stage never reaches a reader of ROADMAP.md."

The report's `jig_version` (a8a32d1dbb7e) is `git hash-object` of v0.12.1's
`plugin/templates/jig/jig.py`. `parse_roadmap`, `parse_up_next` and `render_roadmap` are
unchanged on main since.

## Intent
Two parts, one spec, since both change the roadmap's parser and view:
1. `.jig/roadmap.md` gets a second reserved section that isn't a phase, `## No phase`: work the
   owner has named but given no phase, in no order, each item an id and what it is, naming no
   pages. It never appears in the phase line, takes no state, and is never current.
2. `ROADMAP.md` carries each phase's note: the prose under a phase heading, before its
   `Exit when:` or `Scopes:`, printed under the phase's heading in the view.

## Why
1. Q: Why did the repo make a phase called `stage-not-set`?
   A: Its unstaged items had to go somewhere. A scope lives in a phase; the only other section,
   `## Up next`, refuses an item that names no page, and the repo has no pages for them.
2. Q: Why is a phase a dishonest home?
   A: Phases are ordered by file order and given states: the view prints `→ stage-not-set` and
   `(next)`, and once every earlier phase is done the holding phase becomes `current`.
3. Q: Why is Up next no home either, even with pages?
   A: Up next is parked mid-build work ("stops at <where>; parked <date>"), found by its pages at
   fold-in. Since project-product-boundary, the roadmap is the plan's only home, and it has no
   section for work not yet started and not yet placed. Root.

Part 2, one loop: Q: Why doesn't the note reach the view? A: `parse_roadmap` keeps no prose:
lines before a phase's first list fall through with `part == ""`, and `render_roadmap` has
nothing to print. Root.

## Givens
- `[seen]` Scratch repo `/private/tmp/claude-501/rm-nostage/repo` (template from `plugin/`,
  `jig init`, hooks on). A roadmap with `alpha` (note "The first build for the demo."), `beta`,
  and a last phase `stage-not-set` (note "No stage is set for these. … it is not a stage after
  the beta.", scopes `pay`, `pairing`) commits clean. `jig roadmap --write` prints
  `**alpha** (current) → beta → stage-not-set` and `## stage-not-set (next)`, and neither note
  appears in `ROADMAP.md`.
- `[seen]` Same repo: adding `## Up next` with `` - `pay2`: payments; not started; parked
  2026-11-13 `` is refused by the commit hook: "line 23: Up next item pay2 names no page: end it
  with (touches docs/<page>.md, …)".
- `[seen]` Same repo, `alpha` and `beta` with every box ticked and no scopes: `jig roadmap`
  prints `stage-not-set  current`. The holding phase becomes the current one.
- `[seen]` `jig init` creates no `docs/` pages, so a fresh repo has no page any Up next item could
  name.
- `[seen]` RULES.md, Roadmap: "every `## ` heading but `## Up next` is a phase"; "The first
  phase not done is *current*, the rest *next*"; Up next is "work parked mid-build, in no order",
  each item naming "the pages it will touch". The view's contents list has no note.
- `[seen]` `.jig/specs/project-product-boundary.md` and FEATURES.md row "Project / product
  boundary": priorities, queues and plans live only in `.jig/roadmap.md`; a page can't hold
  them. Up next took `## Undefined` entries, which always had a page, which is why pages are
  required there.
- `[seen]` `parse_up_next`, `parse_roadmap` (skips only `UP_NEXT`), `render_roadmap`,
  `cmd_roadmap`, `dead_touches` and `roadmap_items` in `plugin/templates/jig/jig.py`.
- `[assumed]` Maige-Familiar's roadmap and view, as the report quotes them. Not read here (out
  of bounds); the scratch repo reproduces the same shape, and nothing below depends on theirs.

## One layer up
- **Sibling: `## Up next`**, the existing unordered section. It has the right shape (reserved
  name, no order, no state, rendered after the phases) and the wrong contract (pages required,
  fold-in and merge act on it). The fix reuses its shape: `## No phase` is parsed by the same
  code with pages refused instead of required.
- **Sibling: section prose.** Up next refuses any unindented line that isn't an item, so it
  can't drop a note; it refuses one. Phases are the only place a note is silently lost. The
  prose before the first `##` (the roadmap's own intro) is dropped too; see Out of scope.
- **Sibling: `jig roadmap`'s text output** drops the note the same way; it gets the same fix.

## Generality
Any repo that keeps a roadmap has ideas with no stage yet, and from day one: "later" and
"unscheduled" lists are the common case, not Maige-Familiar's. jig's own boundary rule sends
them to the roadmap and nowhere else, so an ordinary owner does what this one did: a last phase,
which the view orders and states, and which turns `current` when the real phases finish (seen
above). That is jig misreporting the plan, not a repo wanting more than RULES.md promises.
Phase notes are general on their face: any roadmap that explains a phase loses the explanation.
Keep both.

## Workaround or correction
Correction, both parts. Part 1 adds the missing home to the rule and the parser; part 2 makes
the parser keep what it read.

## Design
- **RULES.md, Roadmap.**
  - The source: "every `## ` heading but `## Up next` and `## No phase` is a phase".
  - A new bullet after Up next: **No phase**, the other reserved section that isn't a phase:
    work the owner has named and given no phase yet, in no order. Each item reads
    `` - `<id>`: <what it is> ``, unindented. It names no pages: an item with `(touches …)` is
    parked work, which is Up next's, and the hook refuses it, a duplicate id, or a line that
    isn't an item, by line. A spec can't take one; the owner gives it a phase (moves it to a
    phase's `Scopes:`) when its work starts. It has no state and is never current.
  - A phase's note: prose under its heading, before `Exit when:` or `Scopes:`, is its note,
    shown in the view.
  - The view: "per phase its note, its exit boxes and a board …, then Up next …, then No phase,
    each item with what it is".
- **jig.py.**
  - A constant `NO_PHASE = "No phase"`, reserved like `UP_NEXT`; `parse_roadmap` skips it.
  - `parse_up_next` generalized to read either reserved section by name, with pages required
    (Up next) or refused (No phase). Only Up next feeds `dead_touches`, `roadmap_items`,
    `remove_up_next`, reading-list and fold-in, as today.
  - `parse_roadmap` keeps each phase's note: non-blank and blank lines between the heading and
    its first list, trimmed, as `p["note"]`. Lines after a list are unchanged.
  - `render_roadmap` prints the note under the phase heading, before `Exit when:`, and a
    `## No phase` section last: `_No phase set, in no order._` then `- **<id>**: <what>` per
    item. Nothing is printed for an empty or absent section, as Up next.
  - `roadmap_view` and the stale check in `cmd_roadmap` pass the No phase items through.
    `cmd_roadmap` prints each phase's note (indented, under the phase line) and a `No phase`
    block after Up next, and reports No phase problems with the others.
  - The commit hook's roadmap check reports No phase problems by line, where it reports Up
    next's today.
- **hubnode skill**, "Parked work is an item under `## Up next`" (line 146): one clause after
  it, that work with no phase yet is an item under `## No phase`, naming no pages.
- **FEATURES.md** (main checkout only): the Roadmap row's "what" gains the No phase section and
  phase notes in the view; "what it is not": not a backlog with priorities.

## Done when
- [ ] The fix fires (smoke, `sec_roadmap` or `sec_touches`): a roadmap with phases `alpha` (a
  two-line note, exit boxes, scopes) and `beta`, and `## No phase` with items `pay` and
  `pairing`, commits. `jig roadmap --write` writes a phase line exactly
  `**alpha** (current) → beta`; a `## No phase` section after the phases (and after Up next
  when present) holding `_No phase set, in no order._`, `- **pay**: …` and `- **pairing**: …`;
  and no `No phase (` heading. `jig roadmap` lists a `No phase` block apart from the phases.
- [ ] Never current: the same roadmap with every `alpha` and `beta` box ticked and no scopes
  prints `alpha ✓ → beta ✓` and no `(current)` anywhere in the view; `jig roadmap` prints no
  `current`.
- [ ] Refusals, each by line: a No phase item ending `(touches docs/a.md)` (the message names
  Up next); a duplicate No phase id; an unindented non-item line under `## No phase`; a spec with
  `Scope: No phase/pay` (unknown scope).
- [ ] Notes: the view prints alpha's two note lines between `## alpha (current)` and
  `Exit when:`, in order; `jig roadmap` prints them under `alpha  current`. A phase with no note
  renders exactly as today (the existing roadmap and up-next view assertions pass unchanged).
- [ ] The symptom is gone: the scratch repo's roadmap from Givens, rewritten with the
  `stage-not-set` scopes as `## No phase` items, gives a view with no `stage-not-set`, no third
  phase in the phase line, and alpha's note under its heading.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- The roadmap's own intro (prose between `# Roadmap` and the first `##`). The view drops it
  too, but nothing reported it and the view writes its own header there. A follow-up if asked.
- Notes under `## Up next` or `## No phase`: both refuse non-item lines today, and the view's
  fixed line says what No phase is. Loosening that is its own change.
- Moving an existing holding phase's scopes to `## No phase` in adopting repos. That is the
  owner's roadmap edit on trunk. A spec taking such a scope is named by the existing hook
  ("drops a scope a spec still takes") so it is re-pointed in the same commit.
- `jig update` regenerating `ROADMAP.md`. After the update, `jig roadmap` reports a view with
  phase notes as stale once; `jig roadmap --write` on trunk fixes it, as for any view change.
- redocument and retro: they don't propose or triage No phase items. A roadmap-like section in
  a redocumented repo stays an Up next candidate.

## Touches
- `plugin/templates/jig/RULES.md` (Roadmap)
- `plugin/templates/jig/jig.py` (`parse_up_next`, `parse_roadmap`, `render_roadmap`,
  `roadmap_view`, `cmd_roadmap`, the hook's roadmap check)
- `plugin/skills/hubnode/SKILL.md` (parked work line)
- `tests/smoke.sh` (`sec_roadmap` / `sec_touches`)
- `marketing/FEATURES.md` (Roadmap row; main checkout only)

## Alternatives considered
- Up next items may name no page while the repo has none. Rejected because "has none" is
  ill-defined (a repo with pages for other features has some), it weakens a check that keeps
  parked work visible at fold-in, and the name still reads as "next" for work with no stage.
  Reason is [seen: RULES.md's Up next contract, the scratch repo with no `docs/`].
- Widen Up next to hold both kinds, pages optional. Rejected because one section would carry
  two contracts (found by pages at fold-in, removed at merge when built vs. neither), and a
  genuinely parked item that forgets its pages would pass silently. Reason is [assumed].
- A phase marked unordered (e.g. an `Unordered: yes` line). Rejected because it keeps
  "every `## ` is a phase" true by adding a phase that isn't one: states, the phase line and
  scope ids would all need an exception. Reason is [seen: `roadmap_state`, `render_roadmap`].
- Name it `## Later`. Rejected because "Later" is a plausible existing phase name, and reserving
  it would silently turn such a phase's scopes into refused lines. "No phase" uses RULES.md's own
  term and is unlikely to be a phase. Reason is [assumed].
- Leave unstaged work off the roadmap. Rejected because the boundary rule leaves it no other
  home: a page can't hold plans. Reason is [seen: project-product-boundary].

## Decisions
- **A new reserved `## No phase` section, not a looser Up next** (Dave, 2026-11-13: "Yes, open all eight", taking the hubnode's recommendation).
- No phase items name no pages, enforced, so the two reserved sections stay distinct: pages
  make an item parked work and put it in front of fold-in; no pages means not started.
- A phase's note is the prose before its first list only. Text after a list keeps today's
  handling, so no existing roadmap changes how it parses.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
