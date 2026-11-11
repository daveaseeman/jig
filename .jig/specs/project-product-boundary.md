# project-product-boundary

Source: decision-audit side session in maige-ecosystem, Dave + Claude, 2026-11-11 — findings in maige-ecosystem's .jig/specs/decision-audit.md § 6 (untracked there) (staged as feedback-maige-ecosystem-2026-11-11-scope-roadmap-out-of-product-docs.md): "Scope and roadmap
entries get into product decisions and product pages"

The owner's framing, Nov 11, in his words: "What we need to keep separate are these basic concepts:
project vs. product. The docs and decisions are about products. The project is about scopes and
phases. The roadmap is a project artifact. Where they change hands is in specs." Then "undefined
should get moved out of docs and into .roadmap, perhaps in an 'up next' section … It should
reference the doc it'll touch rather than be at the end of it", and "agreed on reference
directions (one-way)".

## Intent
Docs pages and decision entries describe the product, and the roadmap holds the project. A spec
is where the two meet. References go one way only: a project artifact may point at a page or a
decision, and a page or a decision never points at a spec, a handoff, a phase or a scope, built
or not. Parked work leaves the page and becomes a roadmap item under `## Up next`, naming the
pages it will touch.

## Why
- Why did scope reach the product decisions and pages? Nothing says what a page or an entry may
  be about. RULES.md § Roadmap even calls a phase or a scope "a decision, not work".
- Why does jig itself add scope to pages? The page contract's `## Undefined` section holds "work
  parked mid-build … where it stops, and the date", and fold-in tracks it. That is project status,
  written on a product page by rule.
- Why does it matter? Scope changes often and without record, by the owner's design. On a page
  or in a log it goes stale, gets released to pararepos as a contract, and reads as a
  contradiction in an audit.

## Givens
- `[seen]` The report's five cases on maige-ecosystem's and Maige-OS's trunks: E-040's priority
  order, a "Pending delivery" queue in the register, `products/roadmap.md` as an entry file,
  `## Status` sections, and `Maige-OS/docs/ROADMAP.md` cited as specification.
- `[seen]` Maige-Lite trunk pages cite the project: `docs/identity/identity.md` names
  `.jig/specs/walyt-alpha-demo.md` "phases 2 and 3", "spec phase 4" and "spec phase 5";
  `docs/gesture/gesture.md` says "phase 3 confirms it".
- `[seen]` Maige-Lite's redocument branches write `## Undefined` entries that are project status
  ("checked on the Walyt — stops at … parked 2026-10-30").
- `[seen]` RULES.md, Documentation item 5, defines Undefined as parked work. Fold-in gives each
  entry a built / untouched / departed line. RULES.md, Metarepo, says "Undefined holds the page's
  open questions", so one heading has two meanings.
- `[seen]` RULES.md § Roadmap: "A phase or a scope is a decision, not work". It explains why
  roadmap files change on trunk only (R5).
- `[seen]` `parse_roadmap` (jig.py ~5514) reads every `## ` heading as a phase.

## Design
- **The boundary, in RULES.md** (Documentation, Decision log, Roadmap, and Homes):
  - A docs page and a decision entry are about the product: what it is and how it behaves today.
  - Priorities, phases, ordering, delivery queues, build status and "not built yet, phase n" are
    project, and live in `.jig/roadmap.md` only.
  - A spec takes project items and turns them into product: code, pages and decisions.
  - A page may say what the product does not do today ("Changing the PIN isn't supported"). It
    never says when or in what order that will change.
- **References go one way.**
  - A page or a decision entry never names `.jig/specs/`, `.jig/handoffs/`, `.jig/roadmap.md`,
    `ROADMAP.md`, or a phase or scope id.
  - The hook refuses an added line in a docs page or in `.jig/decisions.md` that names one of those
    paths or ids, naming the line.
  - `jig survey` also lists text like "phase 3" or "spec step 6" on pages and in entries. A hook
    can't judge prose, so survey reports it and nothing refuses.
  - Specs, handoffs and the roadmap may cite pages and decisions freely.
  - Amended after review (Nov 11): the hook refuses only what can't be product text: the
    `.jig/specs/`, `.jig/handoffs/` and `.jig/roadmap.md` paths anywhere, and a full scope id inside
    backticks. Bare phase names and scope ids (`1`, `alpha`, `v1/api`) are ordinary words often
    enough that survey lists them instead. A moved page's old lines aren't new, and a metarepo's
    entry files count as pages.
- **Retire `## Undefined`.** It leaves the page contract, `docs-page.md` and the page checks. Its
  two meanings each get a home:
  - **Parked work** becomes an item under a new reserved `## Up next` section in
    `.jig/roadmap.md`. That section is not a phase, and its items are in no order. An item reads
    `` - `<id>`: <what is parked>; stops at <where>; parked <date> (touches docs/<page>.md, …) ``.
    Scopes inside phases may also name pages with `(touches …)`.
  - **An open product question** becomes an `## Open` entry in `.jig/decisions.md`, which the
    page may cite.
- **Fold-in asks about the roadmap, not the page.** A handoff whose change touches a page that an
  Up next item or a taken scope names gets a line for that item: **built**, **untouched** or
  **departed: <why>**. The roadmap changes on trunk only, so `jig merge` removes a built Up next
  item in the merge commit and rewrites `ROADMAP.md`.
- **`jig reading-list`** prints, after each page, the Up next items and open scopes that name
  that page. The context Undefined gave stays, now as project items.
- **The roadmap view.** `ROADMAP.md` shows Up next after the phases, each item with its pages.
- **Roadmap paths.** The hook refuses a `roadmap.md` or `ROADMAP.md` under `docs/` or matching a
  metarepo `entry_files` glob, naming `.jig/roadmap.md`. The generated root `ROADMAP.md` is
  exempt.
- **Survey** lists `## Status`, `## Current state`, `## Roadmap` and `## Undefined` headings on
  pages and entry files, each with where its content goes.
- **The skills ask the question.** Review, spec and the hubnode's gate ask of each new decision
  entry and page change: "is this about the product, or about when and in what order we build
  it?" An entry that is project is sent back to the roadmap. Redocument's "parked intent" becomes
  an Up next item. Retro triages Up next in place of Undefined. Hardware's "never an Undefined
  entry" line goes.
- RULES.md § Roadmap: "A phase or a scope is a decision, not work" becomes "Phases and scopes are
  the owner's plan, not work, so they change on trunk only". No log entry and no changelog line
  are ever asked for a roadmap change.

## Done when
- [ ] RULES.md states the boundary and one-way references (Documentation, Decision log, Roadmap,
  Homes). § Roadmap no longer calls a scope a decision, and Undefined is gone from the page
  contract and `docs-page.md`.
- [ ] Smoke: adding `.jig/specs/x.md` or `` `phase-1/screen` `` (a scope id the roadmap has) to a docs
  page, or to a decision entry, is refused by the hook with the line named. The same reference in
  a spec passes.
- [ ] Smoke: `jig survey` lists "phase 3" in a page's text, and a `## Status` or `## Undefined`
  heading.
- [ ] Smoke: committing `docs/roadmap.md`, or `products/roadmap.md` in a metarepo whose
  `entry_files` match it, is refused with a message naming `.jig/roadmap.md`.
- [ ] Smoke: a roadmap with `## Up next` and an item `(touches docs/a.md)` parses (Up next isn't a
  phase), `ROADMAP.md` shows it, and `jig reading-list` on a file docmap gives to `docs/a.md`
  prints the item.
- [ ] Smoke: a job changing a file `docs/a.md` covers gets a fold-in line for that Up next item.
  Answered **built**, `jig merge` removes the item from `.jig/roadmap.md` in the merge commit.
- [ ] Smoke: changing `.jig/roadmap.md` on trunk in a metarepo asks for no log line (M3).
- [ ] The review, spec, hubnode, redocument, retro, hardware and survey skills say it. A review
  run in a test repo returns an entry reading "Demo priorities: A, then B".
- [ ] `bash tests/smoke.sh`, `bash tests/redocument-fixture.sh` and `claude plugin validate
  ./plugin` pass, and `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Moving any repo's existing content. `jig update` does that, in spec `update-project-sweep`.
- A log for roadmap changes. The owner doesn't want one, and git keeps the history.
- Dates or estimates on roadmap items beyond the parked date.

## Touches
- `plugin/templates/jig/jig.py` (page checks, the hook's reference and roadmap-path refusals,
  `parse_roadmap`, `render_roadmap`, `foldin_lines`, `cmd_merge`, `cmd_reading_list`, survey)
- `plugin/templates/jig/RULES.md`, `plugin/templates/jig/docs-page.md`
- `plugin/skills/{review,spec,hubnode,redocument,retro,hardware,survey}/SKILL.md`
- `tests/smoke.sh`, `tests/redocument-fixture.sh`
- `marketing/FEATURES.md` (main checkout only: retire the Undefined row, add Up next and the
  boundary)

## Alternatives considered
- Allow pages to cite finished specs and phases, and refuse only unbuilt ones. Rejected by the
  owner in favour of none: a finished spec is a task artifact, and its phase names stop meaning
  anything once the roadmap moves on. Git keeps the history. Reason is [seen: owner, Nov 11].
- Keep `## Undefined` and only forbid dates and phase numbers in it. Rejected: parked work is
  project status whatever its wording, and the owner wants it in the roadmap, naming its page.
  Reason is [seen: owner, Nov 11].
- A separate log for roadmap changes. Rejected by the owner ("I dont think we need it"). Reason
  is [seen: the report].
- Refuse "phase N" prose in the hook. Rejected: the words have product meanings too ("the
  charge phase"), so only paths and the roadmap's own ids are refused. Reason is [assumed].

## Decisions
- Up next is the one roadmap section that isn't a phase. It is reserved by name.
- A built Up next item leaves the roadmap at merge, since R5 keeps the roadmap trunk-only.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
