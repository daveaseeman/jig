# Hardware: a page per board, skills matched to it

## Intent
A repo that builds for boards documents each one in its own page, `docs/hardware/<board>.md`.
The page is made from a template in the plugin once the board is ready to spec, not before
any code is written. It is filled from a hardware definition the user supplies, as a file or
pasted text, and then checked against the code. Each mismatch goes to the user, who decides
which source wins. Before code for that board passes the gate, its page must match the
code. Each page lists the skills to use when writing code for that board. A hardware skill
gets into a repo only when a board page names it, or when the user asks for it. init copies
nothing hardware-related, and no blank skill template. Skills are matched to the whole
hardware definition, never to a chip name.

## Done when
- [x] `tests/smoke.sh` passes, and init leaves nothing in `docs/` or `.claude/`.
- [x] `plugin/templates/hardware.md` exists, and init never copies it. Its headings, in
      order:
      1. Pre-flight (the checklist)
      2. Components (a table of parts and their roles, with no single "chip" field)
      3. Board
      4. Toolchain
      5. Flash / rollback
      6. Wiring
      7. Emulation
      8. Known failure modes
      9. Skills
- [x] `plugin/templates/skills/` holds `esp-idf/` (`name: esp-idf`, with a description not
      tied to one chip) and `_template/`. `plugin/skills/` has no ESP skill.
- [ ] In a session with the plugin reloaded, `jig:esp-idf-esp32s3` is gone from the skill
      list.
- [x] Outside the update review list, `grep -rnE 'HARDWARE\.md|skill-template|esp32s3' plugin tests`
      returns nothing.
- [x] Smoke: docmap ties a board page to code. A lane changes a file that page covers, and
      its handoff has a fold-in line for the page. `jig gate` refuses until that line is
      answered.
- [x] Smoke: survey names a page under `docs/hardware/` that no `docmap` entry covers.
- [x] Smoke: a file covered by both a system page and a board page gets a fold-in line for
      each, and `reading-list` names both. The system page is listed first in `docmap`.
- [x] Smoke: a lane that changes only `sdkconfig` gets a fold-in line for the board page
      whose `docmap` entry names it.
- [x] Walked through by hand, following the skill's steps as written, in a scratch ESP-IDF repo (an `sdkconfig`, and a `main/` that defines the LED
      on GPIO 48), `/jig:hardware devkit`:
      - With no definition, it asks for a file or pasted text, and writes nothing.
      - Given a definition file that puts the LED on GPIO 2, it writes
        `docs/hardware/devkit.md` from the template, filled from the definition, with the
        source named at the top.
      - It shows the LED mismatch with both values and the code's file and line, and asks
        which wins. The page takes the winner's value. When the definition wins, the skill
        lists the code to change and doesn't edit it.
      - Where the definition is silent and the code isn't, such as the flash size in
        `sdkconfig`, it asks whether to add the code's value.
      - It lists `esp-idf` under Skills, installs `.claude/skills/esp-idf/`, and proposes the
        `docmap` entry.
      - Run a second time, it overwrites nothing.
- [ ] The same, run as `/jig:hardware devkit` in a session with the plugin reloaded:
      `${CLAUDE_PLUGIN_ROOT}` resolves, and the argument reaches the skill.
- [ ] By hand: a board page names `esp-idf` under Skills, and `.claude/skills/esp-idf/` is
      missing. `/jig:retro` installs it.
- [ ] By hand: asked to "install the ESP-IDF skill", `/jig:hardware` installs it without
      writing a page.
- [ ] With `update` built: its dry run lists `docs/HARDWARE.md` and
      `.claude/skills/_skill-template/` under "repo files to review", each with a proposed
      edit. `--apply` touches neither. The update skill asks about each one. (smoke, in
      update's cases)
- [x] `claude plugin validate ./plugin` passes.

## Out of scope
- Checking the match mechanically, pin by pin, at the gate. `/jig:hardware` compares the
  definition with the code when it writes the page. After that, the lane answers the
  fold-in line, and the gate and review read it.
- Editing code to match the definition. The skill lists what to change, and changing it is
  a task of its own.
- Choosing skills by a fixed field. The hardware skill reads each skill's frontmatter and
  description against the page.
- More hardware skills.
- Splitting a `docs/HARDWARE.md` that describes several boards. The update skill proposes
  one rename, and the user does the split.

## Touches
- `marketing/FEATURES.md`: these rows, already added:
  - `docs/hardware/<board>.md` (replacing `docs/HARDWARE.md`)
  - `hardware` (new)
  - `esp-idf`, as a template skill
  - `retro`
- `plugin/templates/hardware.md`: from `templates/docs/HARDWARE.md`.
  - Its Board section's "MCU / board" line becomes the Components table.
  - Its pre-flight checklist moves to the top, under one line naming the definition the
    page came from: a file path, or "pasted" and the date.
  - Skills is a new last section: the skills to load when writing code for this board,
    each with one line on why. Only skills that exist go in it.
  - `templates/docs/` is removed.
- `plugin/templates/skills/esp-idf/SKILL.md`: from `plugin/skills/esp-idf-esp32s3/`.
  - Its frontmatter becomes `name: esp-idf`, and `platform` becomes ESP32-family boards
    built with ESP-IDF.
  - The ESP32-S3 specifics stay, marked as such, and so does `verified: false`.
  - "Check `docs/HARDWARE.md` pre-flight" becomes "the board page's Pre-flight".
- `plugin/templates/skills/_template/SKILL.md`: from `templates/skill-template/`.
- `plugin/skills/hardware/SKILL.md`, new:
  - Spec a board:
    1. Get the hardware definition from the user, as the path to a file (a spec sheet, BOM,
       wiring doc or vendor page) or as pasted text. Without one, ask and stop. A page is
       never written from the code alone.
    2. Copy `${CLAUDE_PLUGIN_ROOT}/templates/hardware.md` to `docs/hardware/<board>.md`,
       never overwriting. Fill it from the definition, and name the definition at the top.
    3. Check it against the code: `sdkconfig`, `platformio.ini`, `Kconfig`, devicetree and
       pin defines.
       - Each mismatch is shown with both values and the code's file and line, and the user
         says which wins. The page takes the winner's value.
       - When the definition wins, list the code to change. The skill doesn't edit it.
       - Where the definition is silent and the code isn't, ask whether to add the code's
         value.
    4. Under Skills, list the skills that fit, from `${CLAUDE_PLUGIN_ROOT}/templates/skills/`
       (except `_template`) and from the repo's `.claude/skills/`. A skill fits when its
       frontmatter (`platform`, `framework`, `peripheral`) and description match the page's
       components and toolchain.
    5. Install each listed skill that jig ships and the repo lacks: copy it to
       `.claude/skills/<name>/`, never overwriting.
    6. Propose the `docmap` entry tying the page to the code that targets the board. The
       hubnode edits the board.
  - On "install skills" alone, it does steps 4 and 5 against the existing pages, or installs
    the named skill. No definition is needed for that.
- `plugin/skills/init/SKILL.md`:
  - The firmware step keeps the AGENTS.md Firmware section, copies nothing, and names
    `/jig:hardware` for when a board is ready.
  - The description drops HARDWARE.md.
- `plugin/skills/retro/SKILL.md`:
  - A hardware quirk becomes one line in that board's page, under Known failure modes.
  - A new skill comes from the plugin's `templates/skills/_template/`, and goes into the
    Skills section of each board it applies to.
  - Fallback: a skill a board page names that jig ships and `.claude/skills/` lacks is
    installed.
- `plugin/skills/verify/SKILL.md`: emulation counts only if the board's page says that
  peripheral is modeled.
- `plugin/skills/adopt/SKILL.md`, homes table: `docs/hardware/<board>.md`, one per board.
- `plugin/templates/AGENTS.md`, Firmware section:
  - Each board this repo builds for gets a page in `docs/hardware/<board>.md`
    (`/jig:hardware`) before code for it passes the gate.
  - Read the page, where one exists, before touching a pin, bus or peripheral, and load the
    skills it names.
- `plugin/templates/jig/RULES.md` § Documentation, one paragraph:
  - Board pages are made from jig's board template (`/jig:hardware`).
  - A `docmap` entry ties each page to the code that targets its board.
  - Code that runs on a board doesn't pass the gate without a page that matches it, so for
    that code "no page needed" is not an answer.
- `plugin/templates/jig/jig.py`:
  - `doc_owner` becomes `doc_owners`, which returns every page that covers a file, not
    the first. `foldin_lines` and `reading-list` use every page.
  - `foldin_lines` asks about every changed file that `docmap` names, whatever its type,
    and still flags only source files as UNOWNED.
  - `.ino` joins `SRC_EXT`.
  - `HOME_DIRS`: the `docs/` text names `docs/hardware/<board>.md`.
  - Survey names each `docs/hardware/*.md` that no `docmap` entry covers: no handoff will
    ask whether it still matches.
- `README.md` and `plugin/.claude-plugin/plugin.json`: `hardware` in the skill list.
- `plugin/templates/jig/RULES.md` § Fold-in: a file can have several pages, and `docmap`
  can name any file.
- `plugin/skills/hubnode/SKILL.md`, gating step 3: no fold-in line for board code says
  "no page needed".
- `tests/smoke.sh`.
- `jig/specs/jig-folder.md`: its `HARDWARE.md` and `skill-template` lines point here.
- `jig/specs/update.md`: the review list (see Decisions).

## Alternatives considered
- A board page before any code targets the board. That was my proposal, and the owner
  rejected it: a prototype's board settles while it's being built. The page has to match
  by the time the code passes the gate. `[seen]`, stated Oct 28.
- Filling the page from the code alone. That was my draft, and the owner rejected it. The
  code says what the firmware assumes, not what the board is. A page copied from the code
  always matches it, so the gate's check would catch nothing. Two independent sources, the
  definition and the code, are what give the check meaning. `[seen]`, stated Oct 28.
- The board page's shape written in `RULES.md`, like the docs shape. Rejected by the owner:
  the rules point to how a board page is made, and the template carries the shape. A board
  page is a form to fill in (tables, TODOs, a checklist), and the docs shape is a
  convention for writing prose. `[seen]`, stated.
- Matching skills to a `Chip:` line through the skill folder's name. That was my proposal,
  and the owner rejected it:
  - A board may have no single chip, or call it a processor or a module.
  - A skill like `esp-idf` covers a framework across chips.

  So skills match the whole hardware definition. `[seen]`, stated.
- Keeping the ESP skill a plugin skill. Rejected: a plugin skill shows up in every repo that
  has the plugin, firmware or not. `[seen]`: `jig:esp-idf-esp32s3` is in the skill list of
  a session in this repo, which has no firmware.
- init copying a blank skill template into firmware repos. Rejected by the owner: it has no
  hardware knowledge in it. retro reads the plugin's template when it writes a skill.
  `[seen]`, stated.
- `update` rewriting `docs/HARDWARE.md` itself. Rejected by the owner: `update` shows the
  edits it would make to a repo's own files, and asks. `[seen]`, stated.

## Decisions
- "Released" means passing the gate onto trunk, since jig has no later release step.
  `[assumed]` reading of the owner's word. If it means a tagged release, the check moves
  there.
- The match is checked with the machinery docs already use. A board page is a documentation
  page, and docmap ties it to the code for its board. A handoff then asks whether the page
  still matches, and the gate refuses until that's answered. `jig.py` can't tell which
  files run on a board. So refusing "no page needed" for board code is up to the hubnode,
  which reads the note against the diff at the gate. Survey's unmapped-page line catches a page that nothing would ask about.
- Neither source wins by default. A mismatch might be a wiring change the definition hasn't
  caught up with, or a bug in the code. Only the user knows which, so the skill asks each
  time.
- A board page's Skills section is the record of which skills go with which hardware.
  Installs and retro's fallback read it, so a skill is never installed from a guess. Whoever
  writes the page makes the judgment, from each skill's frontmatter and description, once.
- A skill jig ships becomes the repo's once installed: retro edits it, and flips `verified`.
  It sits in `.claude/skills/<name>/`, the home it already has.
- `_template/` sits beside the shipped skills, so retro reads one place. It is never listed
  under Skills, so it is never installed.
- The update review list. For a repo's own files, `update` shows proposed edits and the
  skill asks about each one. `--apply` never touches them. This spec adds two entries:
  - `docs/HARDWARE.md`:
    - It still holds only the template's TODOs → remove it.
    - It holds a real board → rename it to `docs/hardware/<board>.md`, with the board name
      taken from its "MCU / board" line.
  - `.claude/skills/_skill-template/`:
    - It matches the old template → remove it.
    - It differs → leave it and name it.
- Build, Oct 28: smoke 26/26 and the validator pass. The two new survey and gate cases fail
  against a copy with the check removed. The by-hand item was walked through by following
  `/jig:hardware`'s steps as written, in a scratch ESP-IDF repo with a definition file. It
  was not run as an invoked skill.
  - Found: two mismatches (LED pin, flash size from the N8R8 module) and one fact only the
    code had (USB-Serial-JTAG console).
  - Installed: `esp-idf`.
  - A second run changed nothing.
  - Not yet run: retro's fallback, install-only, and the reloaded skill list.
- Review, Oct 28: a fresh-context subagent, given only the diff, this spec and `AGENTS.md`.
  It reproduced both blocking findings in scratch repos, and both are fixed:
  - Blocking: `doc_owner` returned the first page that matched. A board page's code is the
    same code a system page covers, so the board page was never asked about, and the gate
    passed with it stale. It is now `doc_owners`, every page. This also makes seam pages
    work as `RULES.md` describes them.
  - Blocking: `foldin_lines` kept only source files, so a change to `sdkconfig` alone was
    "nothing to fold in", even with a `docmap` entry naming it. Mapped files of any type now
    count.
  - Should-fix: nothing enforced "no page needed" being refused for board code. `/jig:review`
    runs before the note exists. Now the hubnode's gating step 3 checks it.
  - Should-fix: the by-hand box was checked on a walkthrough. Its wording now says so, and
    the invoked run has its own open box.
  - Optional: `plugin.json`'s description lacked `hardware`. Added.
  - Smoke 28/28. The four new cases fail against a copy with the two fixes undone.
- Open, from the walkthrough: `Defined from:` records a path outside the repo when the
  definition lives elsewhere, and nobody else can open it.
- Order: this lands before `update`, because the owner asked for it first. `update`'s
  review list is written into its spec now and built with it.
