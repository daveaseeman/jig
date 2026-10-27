# Survey: a repo declares where it ships markdown as code

## Intent
`survey` treats every `.md` outside the taxonomy as a document looking for a home. In a
repo that ships markdown as payload — skill files, templates, fixtures, a docs site's
source — those files are code, and `adopt` would plan to move them. The repo, not the tool,
knows which directories those are. Add one board key, `payload`, so it can say so. No
directory name is special-cased in `jig.py`.

## Done when
- [ ] `tests/smoke.sh` has a case: a repo with `src/widgets/README.md` and
      `plugin/skills/x/SKILL.md`, board `payload: ["plugin/**"]` committed on trunk → survey
      lists `src/widgets/README.md` as homeless and not the skill file.
- [ ] `python3 .jig/jig.py init` writes `"payload": []` to a new board.
- [ ] `survey --json` output includes `"payload"` (the globs in effect).
- [ ] The survey's "No home" section ends with: "If a directory ships markdown as code, list
      it under `payload` on the board as a glob such as `dir/**`."
- [ ] Survey names any `payload` glob that matches no tracked file (`--json`:
      `"payload_unmatched"`); smoke covers `"plugin/"`.
- [ ] `grep -n '"plugin/' plugin/templates/jig/jig.py` returns nothing.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.

## Out of scope
- Heuristics ("a `.md` beside source files belongs to the code"). Rejected: misfires both
  ways; a stray README in `src/` is exactly what survey exists to flag — `[seen]`, the
  Daisy survey's homeless list was useful because it was literal.
- Changing `docmap`, fold-in, or `reading-list`. `payload` is read by survey only.
- The `jig/` folder move (`specs/jig-folder.md`). Order: payload → jig-folder → metarepo.

## Touches
- `plugin/templates/jig/jig.py`: `cmd_init` board skeleton; `cmd_survey` loads the board
  once (trunk's copy, as `Board.load` does) and adds `matches(f, payload)` to the at-home
  test alongside `HOMES` / `HOME_DIRS` / `TOOL_DIRS`; the `report` dict; the "No home"
  print block. Survey must still run with no board (then `payload` is empty).
- `plugin/templates/jig/RULES.md`, "The board" section: one line for `payload`.
- `plugin/skills/survey/SKILL.md`: the "No home in the taxonomy" bullet gains the sentence.
- `plugin/skills/adopt/SKILL.md` §2: before judging a homeless file, ask whether its directory
  ships markdown as code; if so, propose a `payload` entry, not a move. Survey reads trunk's
  board, so the entry takes effect after `jig init` and a commit; re-run survey then.
- `tests/smoke.sh`: the case above, board committed before survey runs.
- This repo's board, once `/jig:adopt` gives it one: `payload: ["plugin/**"]`.
- `marketing/FEATURES.md`: a row under Lanes (it is a board key).

## Alternatives considered
- Hardcode `plugin/templates/` and `plugin/skills/` in `TOOL_DIRS`. Rejected: that is this
  repo's shape leaking into the tool — `[seen]`, the same class of leak as the Daisy examples
  just removed.
- Skip any directory containing a `SKILL.md`. Rejected: covers skills only, not templates or
  fixtures; another special case next month — `[assumed]`, but the pattern is the point.
- A `.jigignore` file. Rejected: a second place to declare layout when the board already
  holds `docmap`, `common`, `append_files` — one job, one home — `[seen]`.
- Name the key `homes`. Rejected: `HOMES` in `jig.py` is where docs belong; this key says
  the opposite, that these files are not docs — `[seen]`.

## Decisions
- `payload` is globs over paths, matched with the same `matches()` the rules use.
- It does not silence `oversized`: only root `AGENTS.md`/`CLAUDE.md` are checked; unchanged.
- `payload` hides both the misfiled and the never-read signal for that directory. Skills are
  loaded by name, not linked, so that is correct.
- A glob that matches nothing is named, not silently ignored: `"plugin/"` reads like a
  directory but matches no file, and adopt would plan to move the skills again — review
  finding, `[seen]` (`glob_re` anchors `^…$`).

## Deferred (no `ledgers/` here until adopt)
- optional: a board with invalid JSON crashes survey (`JSONDecodeError` is not
  `SystemExit`). Predates this change; a hand-broken board is not a case survey owns — `[assumed]`.
- optional: adopt's first survey, on a repo without jig, still lists payload files; step 0
  has the agent judge directories first, so the plan comes out right — `[seen]`.
