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

In a pararepo the pass is a format migration, never a claim change, and jig's P2 learned what
that needs: an answer read from the job's spec on trunk, and a `pointers` answer for metarepo
pointer rewrites worked ahead of (Decisions).

## Process

### Hubnode: the remap
1. Run `/jig:update` first (declining its moves of old-contract pages), then `jig survey`; its
   old-format flags, strays and homeless files seed the remap. Every tracked doc gets a row or
   an explicit drop. In a pararepo the remap also marks every page and heading a cached
   metarepo pointer cites.
2. Propose the remap to the owner as a table: `old path(s) → new path, verb
   (rewrite / merge / split / move / new / drop), notes`. Iterate until approved.
3. Write the approved remap to `.jig/redocument.md` on trunk — the hubnode's working
   file, frozen once approved; changes go back through the owner. It opens with a
   `## Sources` section defining the named sources valid for this process only
   (see Tracing). The file is deleted in the final cleanup commit; git history keeps it. In a
   pararepo, approval also opens the metarepo pointers branch (`jig propose --pointers`).
4. Open one job per surviving page, each with a spec of its own from its remap rows. A page
   keeping its path is rewritten in place (the
   job owns that path). A page that moves, merges or splits is written as a **new file**;
   the old docs stay standing until the end, so the whole remap is recoverable from git
   history. Each old file is assigned to exactly one job for derivation bookkeeping;
   split-siblings read it, nobody deletes it yet.
5. As each job merges, the hubnode rewrites that page's `docmap` entries on trunk (R5 —
   subnodes propose entries in their report, never write them).
6. When all jobs have merged: one cleanup commit on trunk (or a final job owning all old
   paths; always a job in a metarepo or a pararepo) deletes every superseded old doc,
   `.jig/redocument.md` and the run's specs, drops the old paths' docmap keys and repoints
   every reference to them. Run `jig survey`; it must come back clean, with no docmap key
   naming a missing file and no old path left in `git grep`.

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
3. **Review.** Deliver the page plus a conversion report, in the handoff note: what moved where, what was
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
      jobs are open, and resumes a run whose remap is on trunk
- [ ] survey's footer points a repo with old-format pages, at home or outside the docs tree,
      at /jig:redocument
- [ ] P2 accepts a job's answer from its spec on trunk: on its branch, at the gate's scratch
      merge and at `jig merge`, for one job only (never a stacked job's or an octopus)
- [ ] P2 accepts `meta: <name> pointers <branch>`; the gate refuses it for another metarepo,
      a branch the metarepo neither has nor merged, or a metarepo it can't reach, and doesn't
      wait for a release; update's Contract removals and Metarepo pointers blocks read the
      same answers

## Out of scope
- Running it on any real repo (owner's call, after docs-page-contract ships)
- New jig.py commands — the skill composes update, survey, open, propose, handoff, gate,
  merge (a `--pointers` flag on `jig propose` is the one addition)
- Changing the page contract itself

## Touches
- plugin/skills/redocument/SKILL.md (new)
- plugin/templates/ only if the remap file wants a template (it didn't: the format is in the skill)
- README.md: the skill in the list, a usage block, and the user-only list
- tests/smoke.sh: redocument in the pinned user-only set; survey's footer pointing at it
- tests/redocument-fixture.sh (new): the fixture, the remap seed, both refusals, the resume,
  and a pararepo whose remap marks a cited page and whose job answers P2 from the proposal
- plugin/templates/jig/jig.py, plugin/skills/survey/SKILL.md: survey points a repo with
  old-contract pages at /jig:redocument instead of /jig:adopt
- plugin/templates/jig/jig.py, plugin/templates/jig/RULES.md: P2 reads the job's own spec
  from trunk; the `pointers` answer, `jig propose --pointers`, and the gate's branch check;
  update's Contract removals and Metarepo pointers read the same answers; `jig sync` lists
  pointers branches
- plugin/skills/review/SKILL.md, plugin/skills/spec/SKILL.md: the `pointers` answer, and
  review's check that a `pointers` spec changes no claim
- .jig/ledgers/DEFERRED.md: a pointers branch only on a remote-tracking ref

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
- For a pararepo's pointer rewrites, B: each job spec answers P2 with `meta: none — format
  migration; no claim changes; pointer rewrites in proposal <branch>`, no rule change, the
  proposal linked only in prose — rejected: prose routing around a gap in the tool; a `none`
  that means "one is pending, trust the reason text" makes the form a lie and the link
  unchecked — reason is [seen] (owner, 2026-11-06)
- For a pararepo's pointer rewrites, C: jobs keep `meta: <name> proposal <branch>` and nothing
  gates until every report is in, the metarepo releases the proposal and the pin moves; then
  every job gates and merges, cleanup last — rejected: it doesn't just stall, it inverts the
  dangling window (cache ahead of trunk instead of behind), which is more confusing than the
  normal work-ahead state, and it leaves finished jobs drifting against trunk while a metarepo
  release blocks mid-run — reason is [seen] (owner, 2026-11-06)
- In a pararepo, skip contract-path pages — rejected: it leaves the most-cited pages in the
  old format, which defeats the migration — reason is [seen] (owner, Nov 6)
- In a pararepo, a BUFFER row per renamed page or heading — rejected: buffer rows are
  claim-level (the claim at the pin, what this repo does now); a heading rename is no claim
  change, and dozens of junk rows bury the real divergences — reason is [seen] (owner, Nov 6)
- For P2, answer only at merge from MERGE_HEAD, or have the hubnode commit the `meta:` line onto
  each job's branch — rejected: the first leaves every commit on the branch refused until the
  merge; the second is the hubnode writing on a subnode's branch, and still a ritual. Reading
  the job's spec from trunk answers on the branch, at the gate's scratch merge and at
  `jig merge` alike, resolving the job from the side of the merge trunk lacks — reason is
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
- In a pararepo, redocument is a format migration, not a claim change (owner, Nov 6). The remap
  marks every page and heading a cached metarepo pointer cites (grep of `.jig/meta-cache/`), so
  it is the pointer crosswalk too. At approval the hubnode writes
  `.jig/specs/redocument-pointers.md` and opens the metarepo pointers branch from it with
  `jig propose --pointers`; every job spec, the cleanup job's included, carries its
  `meta: <name> pointers <branch>` line as the P2 answer, and the branch fills in as reports
  land. A subnode reports where each cited claim landed and never deletes one as stale; a real
  divergence is a BUFFER row on the owner's word. Pointer moves go on the pointers branch;
  claim changes go in the buffer. Cleanup is the contract event: a final job, opened once every
  crosswalk line has its new side and is on the branch; the gate checks the branch and doesn't
  wait for the metarepo's release
- P2 also reads the job's own spec: the board's `spec`, from trunk's board and trunk's copy (a
  one-line spec is its own text), beside the specs the change touches (owner, 2026-11-06:
  strictly stronger — the answer comes from trunk). So a job spec's `meta:` line answers P2 for
  every commit of the job, with nothing staged, and at its gate and `jig merge`, where the job
  is found from the merge's side that trunk lacks: the branch tip itself, else the one job whose
  first-parent line holds it. Anything ambiguous, a job stacked on another, or an octopus merge
  belongs to no job and gets only the change's own answers. A plain commit on trunk is no job,
  so a pararepo's cleanup stays a final job. Update's Contract removals and Metarepo pointers
  blocks read the answers the same way (the job a merge deleted from the board): Contract
  removals lists no removal any answer covered, and Metarepo pointers shows a dangling pointer
  whose removal a `pointers` or `proposal` answer covered as pending on that branch, with no
  BUFFER row offered (a `none` or `buffered` answer still gets the offer: nothing will fix the
  pointer)
- P2's fifth answer, `meta: <name> pointers <branch>` (`jig propose --pointers`), with the
  gate checking the branch is on this repo's metarepo (or merged into its trunk, released or
  not) and not waiting for its release (owner, 2026-11-06, Option A). It means pointer rewrites pending on
  that branch and no metarepo claim change; review, not P2, holds a spec to that. The vocabulary
  then matches: claim changes → a BUFFER row; pointer moves → `pointers <branch>`; a real
  dependency on a metarepo change → `proposal <branch>`, which waits. Every redocument job spec,
  the cleanup job's included, carries the `pointers` line. Chosen over B (a `none` whose prose
  names the proposal) and C (every job waits for the release) — see Alternatives considered

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
