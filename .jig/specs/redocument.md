# /jig:redocument — migrate a repo's docs to the current page contract

Source: cowork session 2026-11-06, Dave with Claude (staged as redocument.md)

Source: Dave, 2026-11-06. Blocked behind `docs-page-contract`: needs the new RULES.md
text, the page template, and survey's old-format flag. Not integrated or run until that
lands.

## Intent
One skill that takes a jig-managed repo's `docs/` to the current docs system in a single
supervised pass: propose a remap of systems and subsystems, get it approved, land every
surviving page through subnodes, and leave git history as the record of the move —
while keeping the owner's review time on the judgment calls, not the diffs.

## Process

### Hubnode: the remap
1. Run `jig survey`; its old-format flags, strays and homeless files seed the remap.
   Every tracked doc gets a row or an explicit drop.
2. Propose the remap to the owner as a table: `old path(s) → new path, verb
   (rewrite / merge / split / move / new / drop), notes`. Iterate until approved.
3. Write the approved remap to `.jig/redocument.md` on trunk — the hubnode's working
   file, frozen once approved; changes go back through the owner. It opens with a
   `## Sources` section defining the named sources valid for this process only
   (see Tracing). The file is deleted in the final cleanup commit; git history keeps it.
4. Open one job per surviving page. A page keeping its path is rewritten in place (the
   job owns that path). A page that moves, merges or splits is written as a **new file**;
   the old docs stay standing until the end, so the whole remap is recoverable from git
   history. Each old file is assigned to exactly one job for derivation bookkeeping;
   split-siblings read it, nobody deletes it yet.
5. As each job merges, the hubnode rewrites that page's `docmap` entries on trunk (R5 —
   subnodes propose entries in their report, never write them).
6. When all jobs have merged: one cleanup commit on trunk (or a final job owning all old
   paths) deletes every superseded old doc and `.jig/redocument.md`. Run `jig survey`;
   it must come back clean.

Run with a quiet board: no other jobs open, so fold-in never asks a dying page about
live code changes.

### Subnode: three phases per page
Kickoff carries the job's remap rows and the Sources definitions.

1. **Trace.** Read the affected old docs, then ground every claim in the named sources:
   the code itself (primary — the page describes trunk), `git log` of the affected
   files, `.jig/handoffs/`, `.jig/specs/`, the ledgers (DEFERRED, WORKAROUNDS, BUFFER),
   plus any repo-specific sources the remap's `## Sources` section defines. A grepped
   session archive is cited as the query that recovers it. **Tracing migrates and
   verifies; it never invents.** A claim with no source is flagged, not written.
2. **Write.** Produce the page from the template, to the contract. Every old Rules
   entry gets exactly one fate:
   - still true of the code → body description
   - passes the admission test (why + holder) → `## Invariants`
   - a parked intent → `## Undefined` candidate, written only once the owner confirms
   - stale or unverifiable → deleted, listed in the report
   Provenance lives in the report, not the page: pages stay clean prose.
3. **Review.** Deliver the page plus a conversion report: what moved where, what was
   deleted and why, proposed docmap entries, and a flagged list needing the owner's call
   (Undefined candidates, failed-admission invariants, doc-vs-code contradictions). Mark
   the page **clean** (every claim verified against code, nothing flagged) or
   **flagged**. The owner skims clean pages and reviews flagged ones; refine until
   approved, then the normal handoff.

## Done when
- [ ] `plugin/skills/redocument/SKILL.md` exists, carrying the remap table format, the
      Sources section, the four-fate rubric, the never-invent rule, and the
      clean/flagged report; `claude plugin validate ./plugin` passes
- [ ] a dry run on a test fixture repo produces a remap proposal from survey output
- [ ] the skill refuses to start when survey shows no old-format pages, or when other
      jobs are open

## Out of scope
- Running it on any real repo (owner's call, after docs-page-contract ships)
- New jig.py commands — the skill composes survey, open, handoff, gate, merge
- Changing the page contract itself

## Touches
- plugin/skills/redocument/SKILL.md (new)
- plugin/templates/ only if the remap file wants a template (it didn't: the format is in the skill)
- README.md: the skill in the list, a usage block, and the user-only list
- tests/smoke.sh: redocument in the pinned user-only set; survey's footer pointing at it
- tests/redocument-fixture.sh (new): the fixture, the remap seed, both refusals, the resume
- plugin/templates/jig/jig.py, plugin/skills/survey/SKILL.md: survey points a repo with
  old-contract pages at /jig:redocument instead of /jig:adopt

## Alternatives considered
- Batch subnodes by system instead of per page — rejected because per-surviving-page
  keeps the invariant "all jobs settled = all docs landed" and ownership stays trivial —
  reason is [seen]
- Rewrite old files in place everywhere — rejected because new-file-beside-old keeps the
  remap recoverable from git history and removes delete-ownership collisions; in-place
  is kept only for pages whose path doesn't change, where a second file would collide —
  reason is [seen]
- Keep the remap file after the work — rejected: it's a working artifact; history keeps it —
  reason is [seen]
- Reimplement page moves in the cleanup — rejected: `jig update` already makes a page-outside-
  the-tree move with every docmap key, contract path and stale reference it touches, so the
  skill runs /jig:update first and its cleanup does the same set for the old paths it retires;
  two tools proposing different moves for the same files is the failure avoided — reason is
  [seen] (review, Nov 6)

## Decisions
- The remap is the hubnode's file, frozen on approval; owner changes only
- Old docs are deleted only at the end, in one commit, after survey comes back clean
- Sessions are defined as sources only inside the remap's `## Sources` section; a
  session citation is the query that recovers it
- Unchanged-path pages are the one in-place exception to every-doc-is-a-new-doc
- `disable-model-invocation: true`: only the owner starts it, like adopt and update, because
  it opens jobs and deletes docs. Subnodes therefore read its Subnode section by the absolute
  path the hubnode's kickoff gives, not by loading the skill
- Each job gets a real spec, `.jig/specs/redocument-<page>.md`, from its remap rows, so
  `jig handoff --spec` works and the job's record has a file home
- The conversion report lives in the subnode's handoff note under its own heading; the hubnode
  reads the docmap proposals from there
- Cleanup removes old docmap keys and repoints every reference, not only deletes files; in a
  metarepo it is a final job, since M4 refuses a trunk commit outside `.jig/`
- `.jig/redocument.md` on trunk means a run is under way: a restart resumes at the first
  unfinished step and skips the refusals

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
