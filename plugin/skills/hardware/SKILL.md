---
name: hardware
description: Spec a board from a hardware definition the user supplies, as its own page under docs/hardware/, check it against the code, and install the skills the page lists. Use when a board is ready to spec, when a handoff's fold-in asks for a board page, or when asked to install hardware skills.
---

A board page records what a board is, so the code can be checked against it. It is written
from a hardware definition the user gives you, never from the code alone: a page copied from
the code always matches it, and the check at the gate would catch nothing.

## Spec a board

1. **Get the definition.** Ask for the path to a file that describes the board — a spec
   sheet, BOM, wiring doc, vendor page — or for the text pasted in. Without one, ask and stop.
   Write nothing.
2. **Write the page.** Copy `${CLAUDE_PLUGIN_ROOT}/templates/hardware.md` to
   `docs/hardware/<board>.md`, the board's name in lowercase with dashes
   (`acme-devboard-2.md`). Never overwrite: if the page exists, you are updating it, so
   show the diff before changing it. Fill every section the definition covers and leave TODO
   where it says nothing. Board pages are only `docs/hardware/<board>.md`; the files they lean
   on go beside them:
   - **The definition**, when it is a file, is saved to `docs/hardware/<board>/` and
     `Defined from:` names that path and the first 12 hex of its sha256 (`sha256sum`, or
     `shasum -a 256`). Pasted: `pasted <date>`. A URL: the URL and a commit or hash, since the
     page behind it changes.
   - **Each datasheet** the user gives, or the checks lean on, is saved to
     `docs/hardware/components/<part>/`, the part's name in lowercase with dashes, one folder
     per part, shared by every board that uses it: never a copy per board. Its Components row's
     Datasheet cell gets a relative link to it, the source URL, the date retrieved and the
     first 12 hex of its sha256. Fetch nothing yourself: ask for the file or the URL.
   - **Committed or ignored.** Read `reference_files` in `.jig/config.json`. Unset (`""`, or
     absent), this is the repo's first board page: ask once whether reference binaries are
     committed (`commit`) or ignored (`ignore`). A public repo may not be allowed to
     redistribute vendor PDFs, so don't pick for it. On `ignore`, add
     `docs/hardware/components/**/*.pdf` to `.gitignore`; the page keeps the URL and hash, so
     the file can be fetched again. The config is the hubnode's: hand it the line
     (`"reference_files": "ignore"`) with the `docmap` line in step 6, or, working solo on
     trunk, write it.
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
6. **Tie it to the code.** Propose the `docmap` entry for the page, naming the code that
   targets this board: `"docs/hardware/<board>.md": ["main/**", "sdkconfig*"]`. Every
   handoff that changes that code then asks whether the page still matches, and the gate
   refuses until it is answered. The board is the hubnode's: hand it the line.

Report the page, the reference files saved and their hashes, each mismatch and how it was
settled, the code to change, the skills listed and installed, and the `docmap` and
`reference_files` lines.

## Install skills only

Asked to install hardware skills ("install the ESP-IDF skill"), no definition is needed.
Install the named skill from `${CLAUDE_PLUGIN_ROOT}/templates/skills/`, or, with none named,
every skill the pages under `docs/hardware/` list that `.claude/skills/` lacks. Never
overwrite. If a skill fits a board whose page doesn't list it, offer to add it to that
page's Skills.
