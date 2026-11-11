---
name: hardware
description: Spec a board from a hardware definition the user supplies, as its own page under docs/, in a folder named for the board once it holds files, check it against the code, and install the skills the page lists. Use when a board is ready to spec, when a handoff's fold-in asks for a board page, or when asked to install hardware skills.
---

A board page records what a board is, so the code can be checked against it. It is written
from a hardware definition the user gives you, never from the code alone: a page copied from
the code always matches it, and the check at the gate would catch nothing.

## Spec a board

1. **Get the definition.** Ask for the path to a file that describes the board — a spec
   sheet, BOM, wiring doc, vendor page — or for the text pasted in. Without one, ask and stop.
   Write nothing.
2. **Write the page.** A board is a system or a subsystem like any other. Ask once whether
   it is a system of its own or a subsystem of an existing system (a board inside a larger
   product), defaulting to a system. Its folder, `<home>` below, is `docs/<board>/` for a
   system or `docs/<system>/<board>/` for a subsystem, the board's name in lowercase with
   dashes (`docs/acme-devboard-2/`). Copy `${CLAUDE_PLUGIN_ROOT}/templates/hardware.md` to
   `<home><board>.md`. Never overwrite: if the page exists, you are updating it, so show the
   diff before changing it. Fill every section the definition covers and leave TODO where it
   says nothing. The template is on the page contract (`.jig/RULES.md`, Documentation): the
   lead paragraph says what the board is and where it was defined from, and each Invariants
   entry keeps its why and gets its holder, or goes. A part not yet driven by code on this
   board is `no` in the Components table's Verified column, never an Undefined entry:
   Undefined is written only on the owner's word. The files the page leans on go in its
   folder. A page that holds none — the definition pasted or a URL, no datasheet saved — is
   flat instead, `docs/<board>.md` or `docs/<system>/<board>.md`, and wherever
   `<home><board>.md` appears below, it is that path; it moves into its folder with a
   `git mv` in the change that saves its first file. Its `boards` and `docmap` keys stay as
   they are: either form names the page:
   - **The definition.** A file the user wrote is saved to `<home>`. A vendor's (a dev
     board's spec sheet, a reference manual) is saved to `<home>datasheets/`, with its source
     URL beside the link, in either `reference_files` mode: a board is not a part of itself.
     The lead's `Defined from:` links the file and gives the first 12 hex of its sha256
     (`sha256sum`, or `shasum -a 256`). Pasted: `pasted <date>`. A URL: the URL and a commit
     or hash, since the page behind it changes.
   - **Each datasheet** the user gives, or the checks lean on, is saved to
     `<home>datasheets/`, named for the part in lowercase with dashes. One another page
     already uses moves (`git mv`) to the `datasheets/` of the nearest folder both pages sit
     under: the system's for two subsystems of one system, `docs/datasheets/` for two
     systems. Both pages link it there: never a copy per page. A part with behavior the code
     touches (a screen, a battery) is a subsystem with its own page instead, which this page
     links, and its datasheet sits in that page's `datasheets/`. Its Components row's
     Datasheet cell gets a relative link to the file, the source URL, the date retrieved and
     the first 12 hex of its sha256. Fetch nothing yourself: ask for the file or the URL.
     Given only a URL, the cell holds the URL, the date and "not saved", and no hash: there
     is no file to hash.
   - **Committed or ignored.** Read `reference_files` in `.jig/config.json`. Unset (`""`, or
     absent): ask once whether reference binaries are committed (`commit`) or ignored
     (`ignore`). Unset doesn't mean no pages yet: after `jig update` an older repo is unset
     with pages already there. A public repo may not be allowed to
     redistribute vendor PDFs, so don't pick for it. On `ignore`, `.gitignore` gains
     `docs/**/datasheets/**/*.[pP][dD][fF]`, which ignores the PDFs under every
     `datasheets/` folder (notes, and every file the repo wrote, stay committed), and any PDF
     already committed there leaves the index with `git rm --cached` (the file stays on
     disk); the page keeps the URL and hash, so the file can be fetched again. The
     `reference_files` line and the `.gitignore` edit are trunk files: in a job, hand both
     to the hubnode with the `boards` and `docmap` lines in step 6; working solo on trunk,
     make them yourself.
3. **Check it against the code.** Read what the code assumes about the board: `sdkconfig`,
   `platformio.ini`, `Kconfig`, devicetree overlays, pin and bus defines. Then show every
   difference in one list before asking about any:
   - **Mismatch** — both say something, and it differs. Show both values and the code's file
     and line, and ask which wins. Neither wins by default: it may be a wiring change the
     definition hasn't caught up with, or a bug in the code. The page takes the winner's
     value. When the definition wins, list the code to change; don't edit it — that is a task
     of its own.
   - **Only the code says it** — ask whether to add the code's value to the page.
4. **Skills.** Read the frontmatter (`platform`, `framework`, `peripheral`) and description of
   each skill in `${CLAUDE_PLUGIN_ROOT}/templates/skills/` (skip `_template`) and in
   `.claude/skills/`. Under Skills, list each one that fits this page's Components and
   Toolchain, with one line on why. List only skills that exist.
5. **Install.** Copy each listed skill that jig ships and `.claude/skills/` lacks to
   `.claude/skills/<name>/`. Never overwrite one that is there; once installed it is the
   repo's.
6. **Register it and tie it to the code.** Add the page to `boards` in `.jig/config.json`
   (`"boards": ["<home><board>.md"]`, appending to the list when there is one): that is
   what makes it a board page. Then propose the `docmap` entry for the page, naming the code
   that targets this board, its build files among it: `"<home><board>.md": ["main/**",
   "sdkconfig*"]`. Every handoff that changes that code then asks whether the page still
   matches, the gate refuses until it is answered, and "no page needed" is never an answer
   for that code. The gate also refuses a board-build file (`sdkconfig*`, `platformio.ini`,
   `idf_component.yml`, `west.yml`, `*.ino`, `*.overlay`) no registered board page's globs
   cover, and a branch that deletes or moves a page `boards` lists. The
   config is the hubnode's: in a job, hand it both lines; working solo on trunk, write them.

Report the page, the reference files saved and their hashes, each mismatch and how it was
settled, the code to change, the skills listed and installed, and the `boards`,
`docmap` and `reference_files` lines.

## Install skills only

Asked to install hardware skills ("install the ESP-IDF skill"), no definition is needed.
Install the named skill from `${CLAUDE_PLUGIN_ROOT}/templates/skills/`, or, with none named,
every skill the board pages (the pages `boards` in `.jig/config.json` lists) list that
`.claude/skills/` lacks. Never
overwrite. If a skill fits a board whose page doesn't list it, offer to add it to that
page's Skills.
