# update-project-sweep

Source: decision-audit side session in maige-ecosystem, Dave + Claude, 2026-11-11 — findings in maige-ecosystem's .jig/specs/decision-audit.md § 6 (untracked there) (staged as feedback-maige-ecosystem-2026-11-11-scope-roadmap-out-of-product-docs.md): "Scope and roadmap
entries get into product decisions and product pages"

The owner, Nov 11: "/jig:update should take those 'undefined' sections and move them … We also need
/jig:update to scan product docs for project references to remove and decision files for project
decisions it can fully strike vs. product decisions it can leave. It should also handle RULES and
FEATURES and the like (if it doesn't already)."

## Intent
`jig update` brings an existing repo onto the project/product boundary (spec
`project-product-boundary`). It works through four kinds of content, each moved only on the
owner's yes:
- Undefined sections move to the roadmap's Up next.
- Project references come off pages.
- Project decisions are struck from the log.
- Plan and register files of the repo's own are named with where their content goes.

## Why
- Why can't the boundary alone fix existing repos? It stops new project content at the hook, and
  says nothing about what is already there: Undefined sections on every redocumented page, E-040
  and a delivery queue in released decisions, phase references in page text.
- Why `jig update`? It is the command that moves a repo onto the current rules, and it already
  lists repo files to review and asks before changing them (`--merge-log` is the model).
- Why can't jig.py do it alone? Telling a product decision from a project one, or rewriting a
  sentence to drop its phase reference, takes reading. jig.py finds the candidates and does the
  mechanical moves. The update skill and the owner judge the rest.

## Givens
- `[seen]` `cmd_update` (jig.py ~6586) prints "Repo files to review (update never applies
  these)". The update skill shows each proposed edit and makes it only on a yes.
- `[seen]` `jig update --merge-log` is a dry run that `--apply --merge-log` writes. In a metarepo
  the move runs as a job, because M4 refuses a non-merge commit on trunk.
- `[seen]` Released sections refuse removing an entry unless an accepted entry supersedes it
  (spec `decision-remove-superseded`). A project entry has no product successor.
- `[seen]` maige-ecosystem's register holds E-040 ("Demo priorities: 1) … 2) …") and a "Pending
  delivery to maige-os" section. Maige-Lite's redocument branches hold Undefined entries.
- `[seen]` Survey lists unknown Markdown files as strays. It has no list of plan or register
  file names (TODO, BACKLOG, STATUS, FEATURES, a hand-written ROADMAP).
- `[assumed]` Words such as "priorit", "phase", "milestone", "demo", "launch", "until … passes",
  "pending delivery", "sprint" and "first, then" find most project entries, with misses that the
  skill's reading catches.

## Design
- **Undefined to Up next.** `jig update` lists every `## Undefined` section on a page, each entry
  with its default destination: an Up next item naming that page, keeping its "stops at" text and
  date. The skill asks per entry:
  - **parked work** goes to Up next (the default);
  - **an open product question** goes to an `## Open` decision entry that the page cites;
  - **a present-tense product fact** goes into the page body, undated.
  
  `--apply --sweep` writes the choices. It creates `.jig/roadmap.md` with only `## Up next` when
  the repo has none, and removes the emptied sections. In a metarepo it runs as a job, as
  `--merge-log` does.
- **Project references on pages.** Under Repo files to review, update lists each page line that
  names a spec, a handoff, the roadmap, a phase or scope id, or prose like "phase 3" or "spec
  step 6". It also lists each `## Status`, `## Current state` or `## Roadmap` section. The skill
  proposes the rewrite: drop the reference and keep the product fact. A sentence that is all
  project leaves the page, and if the work is still live, it becomes an Up next item.
- **Project decisions.** Update lists each live decision entry whose text matches the scope words,
  in `.jig/decisions.md` or, before `--merge-log`, in the old register. The skill sorts each with
  the owner:
  - **strike**: the whole entry is project. It is removed, and if it's still live it becomes a
    roadmap item;
  - **split**: the product part stays, through a new accepted entry that supersedes it, and the
    project part goes to the roadmap;
  - **keep**: it's a product decision.
  
  A struck entry in a released section may be removed when the same commit adds a change line
  under `## Unreleased` `### Removed`: `- D-040: project scope, not a product decision.` This is
  the one other removal released sections allow, so a pararepo's citation of it dangles and
  `jig sync` names it. Before a migration, a struck register row is left out of the log the
  migration builds.
- **Plan and register files.** Update names each tracked file with a known plan or register name,
  with where its content belongs, under Repo files to review:
  - `TODO.md`, `BACKLOG.md`, `STATUS.md`, `PLAN.md`, a hand-written `ROADMAP.md` (project) go to
    `.jig/roadmap.md`;
  - `FEATURES.md` (product: what each feature is, and why) goes to its system's docs page, with
    each row's who and why as a decision entry;
  - `DECISIONS.md`, `ADR`s and `CHANGELOG.md` go to `--merge-log`, as today;
  - `RULES.md`, `CONVENTIONS.md`, `CONTRIBUTING.md` (rules for agents) go to `AGENTS.md` or a
    skill, with the AGENTS.md 40-line rule.
  
  Each conversion is the skill's, on the owner's yes, and a file whose content all moved is
  removed in the same change. A file that holds pages goes to `/jig:redocument`, as survey says
  today.
- RULES.md, the update section: one paragraph on the sweep.

## Done when
- [ ] Smoke: a page with `## Undefined` and two entries. The dry run lists both as Up next items
  naming the page. `--apply --sweep` writes `.jig/roadmap.md` with them under `## Up next`
  (created when absent) and removes the section. A second dry run says nothing about it.
- [ ] Smoke: a page line naming `.jig/specs/x.md`, and one saying "phase 3", are listed under
  Repo files to review. So is a `## Status` section.
- [ ] Smoke: a released `D-001 Demo priorities: A, then B` is listed as a project candidate.
  Removing it with a `### Removed` line naming D-001 under Unreleased commits. Removing it without
  that line is refused.
- [ ] Smoke: `jig update` on a clone of a metarepo register holding a priority row and a
  "Pending delivery" section lists both before `--merge-log`, and a struck row is left out of the
  log it writes. (Per the report: run by hand on a clone of maige-ecosystem at `ce61761`, which
  flags E-040 and Pending delivery. The smoke uses a generic fixture.)
- [ ] Smoke: tracked `TODO.md` and `FEATURES.md` are each listed with their destination.
- [ ] `plugin/skills/update/SKILL.md` walks the sweep: the per-entry questions, strike / split /
  keep, and the plan and register files.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Judging product versus project in jig.py. It lists candidates by words and headings, and the
  skill and the owner decide.
- This repo's own `marketing/FEATURES.md`. It is gitignored, so update doesn't see it. Moving jig
  onto its own docs pages and decision log is the owner's call, at the owner's own `/jig:update`.
- Rewriting history: a struck entry stays in git.

## Touches
- `plugin/templates/jig/jig.py` (`cmd_update` and its review list, the `--sweep` apply, the
  struck-entry removal in `frozen_problems`, the migration's skip)
- `plugin/templates/jig/RULES.md` (Decision log: struck entries; the update paragraph)
- `plugin/skills/update/SKILL.md`
- `tests/smoke.sh`
- `marketing/FEATURES.md` (main checkout only)

## Alternatives considered
- Have redocument do the sweep. Rejected: redocument converts pages that are in the wrong shape
  or place. This sweep is content on pages that are otherwise at home, plus decisions and
  registers, which is update's "Repo files to review". Reason is [seen: `bug-redocument-any-format`
  routed drifted pages at home to update].
- Strike a project entry by superseding it with a "withdrawn" entry. Rejected: that leaves a
  decision entry about project scope in the log, the thing being removed. A `### Removed` change
  line says it once, as change lines do. Reason is [seen: owner, Nov 11, "strike"].
- Let jig.py move references and strike entries by keyword. Rejected: the words have product
  meanings too, and a wrong strike removes a live decision. Reason is [assumed].

## Decisions
- Runs after `project-product-boundary`, which defines Up next and the boundary this sweep
  enforces.
- A `### Removed` change line naming an id is what lets a released project entry go.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
