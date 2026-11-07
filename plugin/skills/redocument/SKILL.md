---
name: redocument
description: Migrate a jig repo's docs/ from the old Now/Rules/Checks pages to the current page contract in one supervised pass - a remap the owner approves, one job per surviving page, old docs deleted at the end. Run by the hubnode; subnodes follow its Subnode section from their kickoff.
disable-model-invocation: true
---

Read `.jig/RULES.md` (Documentation) and `.jig/docs-page.md` first: they are the contract every
page lands on. `jig` below is `python3 .jig/jig.py`.

The hubnode runs this skill. It composes `survey`, `open`, `handoff`, `gate` and `merge`;
it adds no command. The owner's time goes to the remap and to flagged pages, not to diffs.

## Before starting: refuse unless both hold

1. **Old-format pages exist.** Run `jig survey`. Go on only if it names at least one page
   "old contract — convert" under *Pages off the page contract*, or a page under *Pages
   outside the docs tree* whose file has the Now, Rules and Checks headings. Otherwise
   say "no old-format pages: nothing to redocument" and stop.
2. **The board is quiet.** Run `jig status`. Go on only if it says `no jobs open`. Otherwise
   name the open jobs and stop: fold-in would ask a page that is about to die about live
   code changes. Their merges come first.

## Hubnode: the remap

1. **Seed it from survey.** Its old-contract pages, its pages outside the docs tree (with
   where survey says each goes), and its strays under `docs/` are the first rows. Every
   tracked doc under `docs/` gets a row or an explicit `drop`; board pages
   (`docs/hardware/`) are left out unless the owner adds them.
2. **Propose it as a table** and iterate with the owner until approved:

   | Old path(s) | New path | Verb | Notes |
   |---|---|---|---|
   | `docs/store/store.md` | `docs/store/store.md` | rewrite | path kept: rewritten in place |
   | `docs/notes/sync.md` | `docs/store/sync/sync.md` | move | a subsystem of store |
   | `docs/a/a.md`, `docs/b/b.md` | `docs/ab/ab.md` | merge | one system, two pages |
   | `docs/big/big.md` | `docs/big/x/x.md`, `docs/big/y/y.md` | split | |
   | — | `docs/gap/gap.md` | new | code with no page |
   | `docs/old/old.md` | — | drop | describes code that is gone |

   Verbs are `rewrite`, `merge`, `split`, `move`, `new`, `drop`. A new path is
   `docs/<system>/<system>.md`, nesting subsystems the same way.
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
4. **Open one job per surviving page** (every row but `drop`). A page keeping its path is
   rewritten in place, and the job owns that path. A page that moves, merges or splits is
   written as a **new file**; the old docs stay standing until the end, so the whole remap
   is recoverable from git. Assign each old file to exactly one job for bookkeeping; a split
   sibling reads it, nobody deletes it yet.

   ```sh
   jig open <page> --spec "redocument: <new path>, rows in .jig/redocument.md" --owns <path kept in place, if any>
   ```

   The kickoff carries the job's rows, the `## Sources` section, and: "Run /jig:subnode.
   Follow the Subnode section of the redocument skill (`skills/redocument/SKILL.md` in the
   jig plugin)."
5. **As each job merges,** rewrite that page's `docmap` entries on trunk from the entries its
   report proposes (R5: subnodes propose them, never write them).
6. **When every job has merged,** one cleanup commit on trunk deletes every superseded old
   doc and `.jig/redocument.md`, with every `drop` row. Run `jig survey`: it must name no
   page off the contract and no page outside the docs tree. Anything it names is fixed
   before the run is called done.

## Subnode: three phases per page

Your kickoff carries the job's remap rows and the Sources. You write only your page.

1. **Trace.** Read the old docs your rows name, then ground every claim in a source: the
   code on trunk first (the page describes trunk), then `git log` of the affected files,
   `.jig/handoffs/`, `.jig/specs/`, the ledgers (DEFERRED, WORKAROUNDS, BUFFER), and any
   source the remap's `## Sources` names. **Tracing migrates and verifies; it never
   invents.** A claim with no source is flagged in the report, not written on the page.
2. **Write** the page from `.jig/docs-page.md`, to the contract: a lead paragraph, sections
   named for the system's parts, optional Invariants, optional Undefined last. Every old
   Rules entry gets exactly one fate:
   - **still true of the code** → described in the body;
   - **passes the admission test** (a why it must hold, and what holds it) → `## Invariants`,
     as `- <fact> — <why>; held by <holder>.`;
   - **a parked intent** → an `## Undefined` candidate in the report, written on the page only
     once the owner confirms it;
   - **stale or unverifiable** → deleted, and listed in the report.

   Provenance lives in the report, not the page: the page is clean prose, with no rule
   numbers, no "formerly", no citations to the old file.
3. **Review.** Deliver the page with a conversion report:

   ```markdown
   # Conversion: <new path>   [clean | flagged]
   ## Moved
   - <old path § old heading or rule> → <section>; source: <code path / commit / query>
   ## Deleted
   - <old rule> — <why: stale, contradicted by <code>, or unverifiable>
   ## Docmap
   - "<new path>": ["<glob>", …]
   ## Flagged (the owner's call)
   - Undefined candidate: <entry> — <source>
   - Failed admission: <would-be invariant> — missing <why | holder>
   - Contradiction: <page claim> vs <code path> — which wins
   ```

   **Clean** means every claim is verified against the code and nothing is flagged; the owner
   skims it. **Flagged** means the Flagged list is not empty; the owner reviews each line.
   Refine until approved, then hand off as `/jig:subnode` says.
