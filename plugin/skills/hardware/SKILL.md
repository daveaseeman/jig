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
   (`esp32-s3-devkitc-1.md`). Never overwrite: if the page exists, you are updating it, so
   show the diff before changing it. Fill every section the definition covers and leave TODO
   where it says nothing. Set `Defined from:` to the file's path, or `pasted <date>`.
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

Report the page, each mismatch and how it was settled, the code to change, the skills listed
and installed, and the `docmap` line.

## Install skills only

Asked to install hardware skills ("install the ESP-IDF skill"), no definition is needed.
Install the named skill from `${CLAUDE_PLUGIN_ROOT}/templates/skills/`, or, with none named,
every skill the pages under `docs/hardware/` list that `.claude/skills/` lacks. Never
overwrite. If a skill fits a board whose page doesn't list it, offer to add it to that
page's Skills.
