---
name: survey
description: Read-only inventory of this repo against the jig shape - stray documents, oversized always-loaded files, docs that drifted from the code, missing pieces. Use to check a repo, or periodically to catch strays.
---

Run it. Nothing is written, and nothing needs to be installed first:

```sh
python3 .jig/jig.py survey            # if the repo has jig
python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" survey   # if it doesn't
```

Add `--json` to pipe it somewhere.

Report the output, then say what it means in a few lines:

- **Oversized always-loaded file.** Over 40 rule lines and the whole file starts getting
  ignored, so every rule in it is weakened by the ones around it. Highest-value fix.
- **No home in the taxonomy.** Each document gets one job and one home — AGENTS.md rules,
  `docs/` what the code is now, `.jig/specs/` a task in flight, `.jig/ledgers/WORKAROUNDS.md` patches in the code,
  `.jig/ledgers/DEFERRED.md` review findings not in it,
  `.claude/skills/` know-how, `README.md` outsiders, git for history. Zero inbound links plus
  a stale last-commit is a document written once and never read again; git keeps it either way.
  If a directory ships markdown as code, list it under `not_docs` in `.jig/config.json` as a glob
  such as `dir/**`. Survey names any `not_docs` glob that matches no file.
- **Rules files, copies, pages.** Survey checks every Markdown file against the homes
  `.jig/RULES.md` (Documentation) lists, by shape. An `AGENTS.md`, `CLAUDE.md` or `GEMINI.md` off
  root is a second rulebook; a file with three of RULES.md's sentences is a copy that froze; a
  page in the wrong folder (an Invariants section or a retired Undefined one, the old Now/Rules/Checks, or
  any file `docmap` names, whatever its format) is printed with where it goes. Each line carries its fix; `/jig:update` proposes the same ones
  with everything they touch.
- **Pages off the page contract.** A page describes what is built: a lead paragraph, sections
  named for what its code has, optional Talks to (what crosses the boundary), optional
  Invariants. Survey names an
  old Now/Rules/Checks page ("old contract — convert", a job of its own in this repo,
  `/jig:redocument`: fold what it says into description, delete what no longer holds, keep as
  Invariants only entries with a why and a holder), an invariant missing its why or holder,
  and a page with no lead paragraph.
- **Old-contract holders.** A check of the old Now / Rules / Checks headings, a `reserve`
  counter over numbered page headings, an always-loaded line that makes page rules bind or
  cites a page by number. Each converts with the pages: `/jig:redocument` makes them its first
  job, or `/jig:update` lists them once no old page is left. Never propose deleting one; such a
  file holds more than the contract.
- **Pages that own no files, and structure maps.** A page below a system that covers no file
  is a section of the page above it; one whose every file another page covers is the same
  subsystem as that page, or a seam. Each folds on the owner's yes. A JSON file that declares
  the docs structure beside the docmap must change with it: keep one, or derive one from the
  other. `--levels` prints every page's level with its evidence (own files, maps, CODEOWNERS,
  manifests, imports); the owner approves a level, survey only proposes it.
- **The project in the product.** A page or a decision entry says what the product does
  today; phases, order and parked work are `.jig/roadmap.md`'s. Survey names a `## Status`,
  `## Current state`, `## Roadmap` or `## Undefined` heading on a page or an entry file, and
  prose like "phase 3" or "spec step 6" on a page or in the log, each with where it goes. Ask
  of each: is this about the product, or about when and in what order we build it?
- **No docmap.** Handoff can't tell which page a change touches until pages are mapped to globs.
- **Missing pieces.** What `/jig:init` would add.
- **How parallel work is coordinated today.** What the repo already has, under its standard
  name (`CODEOWNERS`, PR template, husky, worktrees, unmerged branches, a homebrew board), and
  what each maps to in jig. Speak in the repo's terms when reporting this.

Offer, in one line, the command survey's last line names, or fix the one or two things that
stand out now. A repo with no board gets `/jig:adopt`; a repo on jig never does:
`/jig:redocument` when it has pages to convert (outside the docs tree, in the old shape, or
board files in the old layout), `/jig:update` when its pages are at home but off the contract. Don't start
moving files in this skill.
