---
name: update
description: Bring a repo already running jig to the current layout - move jig's files from old paths, rewrite the board, replace the tool files, reinstall the hooks, and carry out the moves the owner approved in the findings record. Shows the plan and asks before applying; never edits the repo's own files without a yes.
disable-model-invocation: true
---

Run the plugin's copy, not the repo's — the repo's is older and may have no `update`:

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" update
```

That is a dry run. It changes nothing, and its exit code says what you have:

- **0, "up to date".** Say so. If it lists Repo files to review, show each as below and ask
  about each; otherwise stop. If it lists moves approved in `findings`, `--apply` carries them
  out, layout current or not.
- **0, a plan.** Show the plan: moves, files written from jig, removals, board edits, git
  state. Say each removal out loud — an old tool's script or rendered board, a merged entry,
  a review ledger's taken rows — since the diff is the only other place it shows. Ask. On a
  yes, run it again with `--apply`.
- **1, warnings.** Show each warning and what it means for the repo, and ask whether to go
  ahead. A warning is something `update` can leave as it is and still produce a working
  repo: a file at an old path, an unknown board key, a hook jig didn't write, code that names
  a moved path.
- **2, refused or blocked.** A refusal has a fix the user knows: merge each open job
  (`jig merge`) or delete its entry from `.jig/jobs.json` on trunk, give each counter a
  `pattern` and `files`, move an untracked file out of a move's way, or update the plugin.
  Each worktree line names its own command — `git worktree remove` for one that is there,
  `repair` then `remove` for one that moved with the repo folder, `prune` for one that is gone,
  look then delete for a folder git doesn't know. Before any `remove` or delete, show what is
  uncommitted in it. Run each only on a yes; `update` runs none. A gate's scratch checkout
  (`gate-<job>`, detached) isn't a refusal: the plan lists it as gate scratch and `--apply`
  removes it, unless it holds tracked changes or a merge, which make it a refusal like the rest. A refusing dry run still prints
  the plan below the refusal: show it too, so the user sees what follows the fix. A block means the layout is one
  jig doesn't recognize. Say why the update would fail, then show the owner the drafted
  problem: the change to jig that would recognize it — which `LAYOUT` row, board default or
  `STEPS` entry to add, with a done-when the plugin owner can test. Save nothing; on the
  owner's word, the owner runs `/jig:feedback`. Apply nothing, and stop.

**Repo files to review** are the repo's own files an old convention left behind. Show each
one's proposed edit and ask about each; make it only on a yes.

**One answer per finding, recorded.** Each finding carries its id, `<kind>:<path>`, and its
recorded state. List the findings with their ids and take one answer for each: yes; defer, and
to where (`redocument`, a later job); or an exception, with the owner's reason in their words.
A recommendation is not an answer, and no question covers some findings and leaves the rest:
"apply the update?" answers the layout only. Record the answers on trunk in one commit, as
`findings` in `.jig/config.json` (`.jig/RULES.md`, Documentation: The findings record):
`"approved"`, `"deferred: <where>"`, `"exception: <reason>"`. A deep page's exception is not a
`findings` entry: it is its folder in `deep_subsystems`, with the rationale. Then run `--apply`: it carries out
each approved move itself — the `git mv`, the `docmap` key, the `boards` entry, the entry
dropped — and prints what is left to you for the same commit: the references in other files,
`contract_paths`, the `BUFFER.md` rows. In a metarepo it lists the approved moves as a job's
(M4): ask the hubnode to open one and make them there. Everything else on
the list (an edit, a fold, a nest) you make by hand on its yes; jig acts on the record, never
on an answer in chat.

Some of them are survey's home findings. A **rules** file off root: fold what still binds into
`AGENTS.md` or a page's Invariants, repoint the lines named, delete it — but a package's own rules
file in a monorepo may stay on the owner's word, so ask before proposing the delete. A **copy** of `.jig/RULES.md`:
delete it and point what names it at `.jig/RULES.md`. A page at home but **off the page contract** (no lead paragraph, an invariant with
no why or holder, the old Now / Rules / Checks shape) is fixed where it sits: show its problems and the
edit that answers each, and make it on a yes. A folder of **pages**: before the moves,
ask whether each page is a subsystem to nest under its system's folder rather than a system of
its own. Nest only system/subsystem: a page **below a subsystem** (survey's `deep`) folds into
its subsystem's page, unless the owner approves its folder for `deep_subsystems` with a rationale
as `.jig/RULES.md` (Documentation) says; that entry lands on trunk on a yes. A page in the
**wrong shape**: a folder page with nothing else in its folder goes flat beside its parent's
page, and a flat page with a folder of its own name moves into it, each with its docmap key
and `boards` entry; ask before each, and record each answer.
Then make every line the proposal names in one commit — the `git mv`s, the docmap keys,
`contract_paths`, the stale lines and, in a pararepo, a `BUFFER.md` row per cached pointer. Carry
out each finding on a yes. Never propose adding a line that restates `.jig/RULES.md`: point at it.

**The project in the product** (`.jig/RULES.md`, Documentation: Product and project) comes off
pages and out of decisions, one item at a time, each only on a yes. jig lists by words and
headings; you and the owner judge what is product.

- An **`## Undefined` entry** is listed as the Up next item it would become. Ask per entry: parked
  work goes to Up next (the default); an open product question becomes an `## Open` entry in
  `.jig/decisions.md` that the page cites; a present-tense product fact goes into the page body,
  undated. Make the second and third by hand first. Then `jig update --apply --sweep` moves the
  rest to `## Up next` in `.jig/roadmap.md`, creating it when absent, and removes the emptied
  sections; a section holding other text stays, to move by hand. The roadmap is trunk's (R5), so
  run it there; in a metarepo the pages are a job's (M4): ask the hubnode to open the job the
  run names, and run `--apply --sweep` again in its worktree, which removes the sections whose
  entries trunk's roadmap holds. A clean tree is required.
- A **page line** naming a spec, a handoff, the roadmap, a phase or scope id, or "phase 3",
  and a **`## Status`, `## Current state` or `## Roadmap`** section: propose the rewrite that
  drops the reference and keeps the product fact. A sentence that is all project leaves the
  page, and if its work is still live it becomes an Up next item.
- A **decision entry** that reads as project scope: sort it with the owner. **Strike**, the
  whole entry is project: remove it, and add under `## Unreleased` `### Removed` the line
  `- D-040: project scope, not a product decision.` in the same commit (that line is what lets
  a released entry go); if the work is still live, it becomes a roadmap item. **Split**: a new
  accepted entry superseding it keeps the product part, and the project part goes to the
  roadmap. **Keep**: it is a product decision. Before `--merge-log`, a struck register row's
  Status cell says `struck`, and the merge leaves it out; in a metarepo that edit is a job's
  and, like any register change before the log, it takes a `CHANGELOG.md` line (M3). A row that
  a struck row supersedes is struck too, or the merge refuses: it would come back accepted. A
  listed register section (a delivery queue) goes to the roadmap or is deleted before the merge.
- A **plan or register file** is listed with where its content goes: `TODO.md`, `BACKLOG.md`,
  `STATUS.md`, `PLAN.md` or a hand-written `ROADMAP.md` to `.jig/roadmap.md`; `FEATURES.md` to its
  systems' pages, each row's who and why to a decision entry; `RULES.md`, `CONVENTIONS.md`,
  `CONTRIBUTING.md` to `AGENTS.md` (40 lines at most) or a skill. Propose each conversion;
  remove the file in the same change once all of it moved. A file that holds pages goes to
  `/jig:redocument`.

A root **`CHANGELOG.md`** and a **decision register** (`DECISIONS.md`, or a metarepo's entry file
of decision rows) merge into `.jig/decisions.md`, the one log (`.jig/RULES.md`, Decision log). Run
`jig update --merge-log` and show what it prints: where each row lands, each rejected row it
leaves out, each superseded row git couldn't say who accepted or when (check its status line
before the commit), each piece with no home (it stays in its old file, to move by hand), the
`entry_files`, `append_files` and counter rewrites, the files that still name the old ones, and
the log itself. Say each removal out loud. On a yes:

- **in a metarepo**, the merge is a job, as any change to its files is: ask the hubnode to open
  one (`jig open merge-log --shares CHANGELOG.md <register>`), run `--apply --merge-log` in its
  worktree and commit there, and hand it off and merge it like any job. Then, on trunk,
  `--apply --merge-log` again rewrites the board (`append_files`, the counter): commit that;
- **elsewhere**, `--apply --merge-log` on trunk does all of it: commit it there.

Then, on a yes each, move what had no home and repoint the files it named. A refusal names rows the merged log wouldn't
pass M2 with: show them, and fix the register with the owner first.

A root **`GLOSSARY.md`**: the glossary's home is `README.md § Glossary` now. On a yes, move each
term into that section as a `### <term>` heading, its text below it, delete the file, replace it
with `README.md` in a metarepo's `entry_files`, and repoint the lines that name it. In a metarepo
this is one changelog line (`GLOSSARY: …`). After migrating, find each pararepo's citations of
`GLOSSARY.md` with `git grep GLOSSARY.md` in its checkout (`jig repos` lists them), and repoint
each to `README.md § <term>`.

The **AGENTS.md** lines are the few the template still needs there: the Rulebook line, a
Commands line for a `.jig/scripts/` file the repo has or this run adds, and a block jig retired
to replace with the Rulebook line, or delete when the line is already outside it. Show each line
with where it goes and make it only on a yes. Then read `AGENTS.md` against `.jig/RULES.md`: a
line that restates what RULES.md holds (where documents live, the docs shape, a board's page,
the job rules) is an old template line frozen in place; offer, one at a time, to replace it with
the template's line that points at RULES.md instead. Every other line is the repo's wording,
and there is no template diff to read.

**Metarepo pointers**, in a pararepo, are the cached metarepo pointers that dangle. Show each
line. One that names the commit that removed what it points to offers a `.jig/ledgers/BUFFER.md`
row: ask, and add the row as offered only on a yes (the next `jig release` proposes it). One the
repo never had is the metarepo's to fix, by `jig propose`. One that says "pending on <branch>"
was covered by a `pointers` or `proposal` answer whose branch the pin doesn't hold yet: offer
nothing, since it resolves when the pin moves. One that says "the metarepo's rewrite in <branch>
missed it" is pinned and still dangling: offer its row like any other. Never edit the metarepo
here.

**Contract removals**, beside it, are trunk commits that deleted or moved away a contract path
with nothing answering them. Each offers one `BUFFER.md` row: add it only on a yes, and change
`contract_paths` for a moved file only on the owner's word.

## After `--apply`

`update` stages its changes, commits nothing, and runs `.jig/scripts/check.sh`. Then:

1. Fix the stale references in code with the user, in the same uncommitted change, until the
   check passes. Those are the repo's files: you edit them with the user; `jig.py` never does.
   Stale references in Markdown are worth fixing too — offer the list, don't sweep it unasked.
   A warning that a moved file finds paths from its own location (`$0`, `BASH_SOURCE`,
   `__file__`, `__dirname`, `import.meta.url`, ...) is code to fix the same way: its folder depth changed, so a
   `/..` count in that line is off. Offer the edit.
2. If `update` added `.jig/scripts/setup.sh`, fill it the way `/jig:init` does. Then name
   anything in the repo that already does its job by hand — a check script that borrows the
   main checkout's environment, `ln -s` steps in a skill — and offer to remove each once
   `setup.sh` covers it.
   If it added `.jig/scripts/release.sh`, leave the TODO: `/jig:release` fills it on the first
   release. If it added `.jig/scripts/publish.sh`, leave its TODO too: `/jig:release` asks what
   a release publishes on the next release.
3. Commit on trunk. The hooks read trunk's `.jig/jig.py`. Coming from `jig/`, `.aidev/` or
   claude-lane's `.claude/claude-lane/`, it exists only once this commit lands, so this one
   commit goes unchecked. Coming from the
   first `.jig/` layout (root `specs/` and `ledgers/`), trunk's old checker judges it and
   refuses the new `jig.py` under R7, because that copy checks jig's own file: if R7 on
   `.jig/jig.py` is its only refusal, commit this one with `--no-verify` and say why. The
   next commit is checked by the new copy.
4. In a pararepo (`.jig/para.json`), then run `jig init --para` and commit only what it
   changed (`AGENTS.md`, and `.jig/para.json` if it rewrote it). Its header is generated by
   the new checker, which judges it only once step 3's commit is on trunk.
