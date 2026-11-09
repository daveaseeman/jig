---
name: redocument
description: Migrate a jig repo's docs/ from the old Now/Rules/Checks pages to the current page contract in one supervised pass - a remap the owner approves, one job per surviving page, old docs removed at the end with every reference to them. Run by the hubnode; subnodes follow its Subnode section from their kickoff.
disable-model-invocation: true
---

Read `.jig/RULES.md` (Documentation) and `.jig/docs-page.md` first: they are the contract every
page lands on. `jig` below is `python3 .jig/jig.py`.

The hubnode runs this skill; Before starting and Hubnode are the hubnode's only. A subnode
reads only Subnode, from the path its kickoff gives, and never runs the refusals. The skill
composes `update`, `survey`, `open`, `handoff`, `gate` and `merge`; it adds no command. The
owner's time goes to the remap and to flagged pages, not to diffs.

## Before starting

**A resume?** If `.jig/redocument.md` is on trunk, a run is under way. Skip the refusals
and the remap: read the file and carry on at the first step not done — a surviving row with
no job opened or merged (step 4), a merged page whose docmap entries aren't written yet
(step 5), or, with every job merged, the cleanup (step 6). In a pararepo, a remap with no
`.jig/specs/redocument-pointers.md`, or one with no `meta:` line, resumes at step 3's pararepo
half: open the pointers branch before any job. The run's own open jobs are not "other jobs".

Otherwise:

1. **Bring the layout current.** Run `/jig:update` first and land what it proposes, except
   its page moves for old-contract pages: decline those, because the remap places them (and
   in a pararepo `update` would add a BUFFER row per cached pointer, which this run's
   pointers branch replaces). Starting from a current layout means the two never propose
   different moves for the same files.
2. **Refuse unless old-format pages exist.** Run `jig survey`. Go on only if it names at
   least one page "old contract — convert" under *Pages off the page contract*, a page
   under *Pages outside the docs tree* whose file has the Now, Rules and Checks headings, or
   any file under *Board files in the old docs/hardware/ layout*. Otherwise say
   `no old-format pages: nothing to redocument` and stop.
3. **Refuse unless the board is quiet.** Run `jig status`. Go on only if it says
   `no jobs open`. Otherwise say `jobs open: <names>; redocument runs on a quiet board` and
   stop: fold-in would ask a page that is about to die about live code changes. Those jobs
   merge first.

## Hubnode: the remap

1. **Seed it from survey.** Its old-contract pages, its pages outside the docs tree (with
   where survey says each goes), and its strays under `docs/` are the first rows. Every
   tracked doc under `docs/` gets a row or an explicit `drop`, board pages included. A board
   page in an older layout, `docs/hardware/<board>.md`, gets a row to `docs/<board>/<board>.md`
   with its `boards` entry; `docs/hardware/<board>/` moves into that folder, its vendor PDFs
   into the folder's `datasheets/` (a PDF the repo wrote, a schematic, stays beside the page);
   and each file of `docs/hardware/components/<part>/` moves into the `datasheets/` of the
   page that links the part, or `docs/datasheets/` when two board pages link it. Survey's rows
   say where each file goes.

   **In a pararepo** (`.jig/para.json` on trunk), also find every cached metarepo pointer into
   this repo's docs, `<repo>/<path> § <heading>`:

   ```sh
   grep -rniE '(^|[^[:alnum:]_-])<repo>[/:]docs/' .jig/meta-cache/
   ```

   `<repo>` is each name this repo goes by, one grep per name: the board's `name`, the
   checkout's folder name, and any alias `jig repos` lists for this checkout. Names fold case. Give the table a Cited column: on
   each old page's row, every `§ <heading>` a pointer names (or the bare path). The remap is
   then the pointer crosswalk too. Migration moves pointers; it never changes a claim.
2. **Propose it as a table** and iterate with the owner until approved:

   | Old path(s) | New path | Verb | Notes | Cited |
   |---|---|---|---|---|
   | `docs/store/store.md` | `docs/store/store.md` | rewrite | path kept: rewritten in place | § Rules |
   | `docs/notes/sync.md` | `docs/store/sync/sync.md` | move | a subsystem of store | |
   | `docs/a/a.md`, `docs/b/b.md` | `docs/ab/ab.md` | merge | one system, two pages | |
   | `docs/big/big.md` | `docs/big/x/x.md`, `docs/big/y/y.md` | split | | |
   | — | `docs/gap/gap.md` | new | code with no page | |
   | `docs/old/old.md` | — | drop | describes code that is gone | |

   Cited is only for a pararepo.

   Verbs are `rewrite`, `merge`, `split`, `move`, `new`, `drop`. A new path is
   `docs/<system>/<system>.md` or `docs/<system>/<subsystem>/<subsystem>.md`, no deeper. A
   subsystem inside a subsystem is asked of the owner with its rationale, as `.jig/RULES.md`
   (Documentation) says, and lands as a `deep_subsystems` entry in `.jig/config.json` on trunk
   on a yes. Name the cleanup route in
   the pointers branch (step 6).
3. **Write the approved remap to `.jig/redocument.md`** on trunk and commit it. It is the
   hubnode's working file, frozen once approved; a change goes back through the owner. It
   opens with:

   ```markdown
   ## Sources
   The named sources valid for this redocument only, beyond the standard ones (code on
   trunk, git log, .jig/handoffs/, .jig/specs/, .jig/ledgers/). One line each: its name,
   where it lives, how a citation recovers it.
   - <name> — <where>; cite as <the query that recovers it>
   ```

   A session archive is a source only if this section names it, and it is cited as the
   query that recovers the passage (`grep -n "offline mode" <archive>`), never as a memory.
   Then the table.

   **In a pararepo,** open the metarepo pointers branch now, at approval, not at the end: an in-place
   rewrite of a contract-path page edits a contract path, and renaming a heading a cached
   pointer names fires P2 on that very commit. Write `.jig/specs/redocument-pointers.md`, the
   pointer rewrite: one line per cached citation, `<old path> § <heading> → <new path> §
   <heading>`, the new side filled in as reports land. Then:

   ```sh
   jig propose .jig/specs/redocument-pointers.md redocument-pointers --pointers
   ```

   It opens the branch on the metarepo and records `- meta: <name> pointers <branch>` in that
   spec: pointer rewrites pending on that branch, no metarepo claim changed. Commit both files
   on trunk. That line answers P2 for the whole run, and every job spec below carries it; the
   gate checks the branch is real and does not wait for its release. Never a BUFFER row per
   renamed page or heading: a rename is no claim change, and junk rows bury the real
   divergences.
4. **Open one job per surviving page** (every row but `drop`). Write each one a spec,
   `.jig/specs/redocument-<page>.md`: its remap rows, the `## Sources` section, and the
   Done-when "page lands on the contract; the conversion report is in the handoff note". In
   a pararepo it also carries, under `## Decisions`, the pointers spec's `meta:` line, and its
   rows' Cited headings.
   A page keeping its path is rewritten in place, and the job owns that path. A page that
   moves, merges or splits is written as a **new file**; the old docs stay standing until
   the end, so the whole remap is recoverable from git. Assign each old file to exactly one
   job for bookkeeping; a split sibling reads it, nobody deletes it yet.

   ```sh
   jig open <page> --spec .jig/specs/redocument-<page>.md --owns <path kept in place, if any>
   ```

   The kickoff says: "Run /jig:subnode. Follow the Subnode section of
   `<this skill's absolute path>`", the expansion of
   `${CLAUDE_PLUGIN_ROOT}/skills/redocument/SKILL.md` in the hubnode's session. The subnode
   cannot load this skill itself.
5. **As each job merges,** write that page's `docmap` entries on trunk from the Docmap list in
   its handoff note's conversion report (R5: subnodes propose them, never write them). In a
   pararepo, also fill that page's lines in `.jig/specs/redocument-pointers.md` from the
   report's Cited list, and write the same rewrite on the pointers branch in the metarepo
   checkout (`jig propose` printed where).
6. **When every job has merged,** clean up in one change: a commit on trunk, or a final job
   that owns every old path and `.jig/redocument.md`. In a metarepo (`.jig/meta.json` on
   trunk), it is the final job: M4 refuses a trunk commit outside `.jig/`. In a pararepo it is
   the final job too, its spec carrying the pointers spec's `meta:` line: deleting a page a
   cached pointer names is the contract event, and a commit on trunk is no job, so P2 finds no
   spec to answer it. Open it only once every line of `.jig/specs/redocument-pointers.md` has
   its new side and that rewrite is on the pointers branch. The change:
   - deletes every superseded old doc, the `drop` rows' files, `.jig/redocument.md`, and the
     per-job `.jig/specs/redocument-<page>.md` specs, and `.jig/specs/redocument-pointers.md`
     in a pararepo; git history keeps them, and the pointers branch is the live record until
     the pin holds it;
   - removes every old path's `docmap` key from `.jig/config.json`, `drop` rows included
     (on trunk, by the hubnode, either route);
   - repoints every tracked reference to an old path — README, `AGENTS.md`, other pages,
     comments — at its new path, or removes it for a `drop`. Find them with
     `git grep -n -F <old path>`, one old path at a time.

   Then check the end state. `jig survey` names no page off the contract and no page outside
   the docs tree; no `docmap` key names a file that doesn't exist; `git grep -n -F <old path>`
   finds nothing for any old path. Anything left is fixed before the run is called done.

## Subnode: three phases per page

Your spec carries the job's remap rows and the Sources. You write only your page.

1. **Trace.** Read the old docs your rows name, then ground every claim in a source: the
   code on trunk first (the page describes trunk), then `git log` of the affected files,
   `.jig/handoffs/`, `.jig/specs/`, the ledgers (DEFERRED, WORKAROUNDS, BUFFER), and any
   source the `## Sources` names. **Tracing migrates and verifies; it never invents.** A
   claim with no source is flagged in the report, not written on the page.
2. **Write** the page from `.jig/docs-page.md`, to the contract: a lead paragraph, sections
   named for the system's parts, optional Invariants, optional Undefined last. Every old
   Rules entry gets exactly one fate:
   - **still true of the code** → described in the body;
   - **passes the admission test** (a why it must hold, and what holds it) → `## Invariants`,
     as `- <fact> — <why>; held by <holder>.`;
   - **a parked intent** → an `## Undefined` candidate in the report, written on the page only
     once the owner confirms it;
   - **stale or unverifiable** → deleted, and listed in the report.

   **A cited heading** (a pararepo's spec names it) adds one thing: say where its claim landed.
   A cited claim is never deleted as stale. If tracing finds the code diverges from it, that is
   a divergence that was already there, now found, not a format change: flag it, and on the
   owner's word it is a row in `.jig/ledgers/BUFFER.md` in your change. Pointer moves go in the
   pointers branch; claim changes go in the buffer.

   Provenance lives in the report, not the page: the page is clean prose, with no rule
   numbers, no "formerly", no citations to the old file.
3. **Review.** Write the conversion report into your handoff note, under a heading of its own
   after the note's own headings:

   ```markdown
   ## Conversion: <new path> — clean | flagged
   ### Moved
   - <old path § old heading or rule> → <section>; source: <code path / commit / query>
   ### Deleted
   - <old rule> — <why: stale, contradicted by <code>, or unverifiable>
   ### Docmap
   - "<new path>": ["<glob>", …]
   ### Cited (a pararepo only)
   - <old path> § <heading> → <new path> § <heading>
   ### Flagged (the owner's call)
   - Undefined candidate: <entry> — <source>
   - Failed admission: <would-be invariant> — missing <why | holder>
   - Contradiction: <page claim> vs <code path> — which wins
   - Divergence (a cited claim): <claim> vs <code path> — a BUFFER row on the owner's word
   ```

   **Clean** means every claim is verified against the code and nothing is flagged; the owner
   skims it. **Flagged** means the Flagged list is not empty; the owner reviews each line.
   Refine until approved; the handoff is the normal one, `jig handoff --spec
   .jig/specs/redocument-<page>.md`.
