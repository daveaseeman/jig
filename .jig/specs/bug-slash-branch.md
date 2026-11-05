# Bug: a `/` in a branch or job name breaks handoff and gate

Source: Claude Code session (walyt-type job, worktree beautiful-jemison-03e945) / 2026-11-04 / Dave Seeman + Claude (staged as feedback-Maige-Lite-2026-11-04-slash-branch-handoff.md): "`jig handoff` and `jig gate` break on a solo branch whose name has a slash". `handoff` fails with `FileNotFoundError: … .jig/handoffs/claude/beautiful-jemison-03e945-2026-11-04.md`. With that folder made by hand, `gate` still prints `claude/beautiful-jemison-03e945 has filed no handoff note on claude/beautiful-jemison-03e945: run jig handoff`.

## Intent
A name with `/` in it, whether a solo branch (`feature/x`, `claude/<name>`) or a job, hands off and gates like any other name. The note goes in flat `.jig/handoffs/` under one file-safe name that the writer and every reader share. `jig update` flattens the notes the bug already left in subfolders.

## 1. Why
- Why does handoff fail? `cmd_handoff` uses the branch as `name` and writes `handoffs/{name}-{date}.md`. It creates only `handoffs/`, so `a/b-c` needs a subfolder that isn't there. [seen]
- Why does gate miss the note made by hand? `handoff_notes` fullmatches `{name}-{date}.md` against `Path(n).name`, which is `b-c-<date>.md`. A name with `/` never matches. [seen]
- Why both? Nothing turns a name into a file name. The writer and the readers each use the raw name, and a git branch can contain `/`. Root. [seen]

## 2. Givens
- [seen] Reproduced with the current copy (`plugin/templates/jig/jig.py` at cb6af2f) in a solo repo with `jobs.json` `{}`, on branch `a/b-c`. `jig reviewed --tier 2 --effort 2` records the review (marker `.git/jig/reviewed/a%b-c`). `jig handoff --spec .jig/specs/x.md` then fails with `FileNotFoundError: … .jig/handoffs/a/b-c-2026-11-05.md` (jig.py:1167).
- [seen] After `mkdir .jig/handoffs/a`, handoff writes `.jig/handoffs/a/b-c-2026-11-05.md` and the hook accepts its commit. `jig gate` then prints `a/b-c has filed no handoff note on a/b-c: run \`jig handoff\`` and exits 1.
- [seen] A job name with `/` fails the same way. `jig open a/b` opens it in `.git/jig/worktrees/a/b`, and its `jig handoff` fails with `FileNotFoundError … .jig/handoffs/a/b-2026-11-05.md`.
- [seen] Once merged to main, the note stays at `.jig/handoffs/a/b-c-….md`. Today's `jig update` (plugin copy) says `up to date`, and `jig survey` says nothing about it.
- [seen] The gate's scratch path breaks next, but only once the note is found. A probe with `handoff_notes` patched gets past the lookup, and the gate then makes `.git/jig/worktrees/gate-a/b-c`. The printed `git worktree remove` leaves an empty `gate-a/` behind. The hubnode skill's `…/jig/gate-<name>.out` fails with `No such file or directory`.
- [seen] git allows `a-b-c` beside `a/b-c`, so `/`→`-` gives two live branches one stem.
- [seen] Every note jig writes starts `# Handoff: <name>` with the raw name. NOTE has done that since eaec973, and every fixture's note does too.
- [seen] In an update probe, the row `(.jig/handoffs/a-b-c-….md, [.jig/handoffs/a/b-c-….md])` was fed through `plan_moves`' `extra`, as `hardware_rows` is fed. The dry run lists it under Moves, and `--apply` stages an `R100` rename. The emptied `.jig/handoffs/a/` stays on disk: `git mv` keeps it, and the rmdir pass in `--apply` covers folder rows only.
- [assumed] Claude Code names worktree branches `claude/<name>`. The report saw this; it wasn't re-observed here. Nothing depends on it, since `a/b-c` reproduces the bug.

## 3. One layer up
- Every place a name becomes a path:
  - `cmd_handoff`: broken.
  - `handoff_notes`, which `cmd_gate`, `cmd_merge` and `cmd_status` all read through: broken.
  - The gate scratch `gate-{name}` and the hubnode skill's `gate-<name>.out`: hidden today because gate refuses first, and broken once it doesn't.
  - `review_marker`: works, because it already maps `/` to `%`.
  - Job worktrees `worktrees/<branch>`: work. git creates the parent folders, and `worktree_refusals` already walks nested checkouts (sec_report_fixes).
- Patterns to fit: `review_marker`'s replace and `board_slug` for names. For update, `hardware_rows` passed to `plan_moves(extra=…)`, which prints in the dry run and moves on `--apply`.

## 4. Correction
This is a correction, not a workaround. One function in jig.py (e.g. `file_safe(name)`: `/` → `-`) is used by `cmd_handoff`, by `handoff_notes`, and by the gate's scratch name. Because the stem can collide, the reader also requires the note's first line to be `# Handoff: <name>`. `handoff_rows(files)` sits beside `hardware_rows` and gives update one move per note under a subfolder of `.jig/handoffs/`.

## Done when
In a new smoke section `slash_names`, listed in `UNITS` (`bash tests/smoke.sh slash_names`):
- [ ] Solo repo on branch `a/b-c`: `jig reviewed` then `jig handoff --spec …` exits 0 and prints `wrote .jig/handoffs/a-b-c-<date>.md`, and `.jig/handoffs/a/` doesn't exist.
- [ ] With the note committed, `jig gate` exits 0 and prints `a/b-c: gate <commit> from .jig/handoffs/a-b-c-<date>.md on a/b-c`. Its output contains no `has filed no handoff note`, which is the report's symptom.
- [ ] The gate's scratch is `.git/jig/worktrees/gate-a-b-c`. After the printed `git worktree remove --force` line, `.git/jig/worktrees/` is empty.
- [ ] Collision case: commit `.jig/handoffs/a-b-c-<date>-2.md` on `a/b-c`, starting `# Handoff: a-b-c` and naming another commit. `jig gate` still gates from `a-b-c-<date>.md`.
- [ ] Job `a/b`: `jig open a/b`, then a commit, `jig reviewed` and `jig handoff` in its worktree, writes `.jig/handoffs/a-b-<date>.md`. After the commit, `jig status` on trunk shows `a/b … handoffs:1`.
- [ ] Update fixture, built in the section. A fresh `jig init` repo has these committed on main, as the hand-made folder leaves them: `.jig/handoffs/a/b-c-2026-01-01.md`, `.jig/handoffs/x/y-2026-01-01.md`, and a flat `.jig/handoffs/x-y-2026-01-01.md`. The `$UP` dry run lists `.jig/handoffs/a/b-c-2026-01-01.md → .jig/handoffs/a-b-c-2026-01-01.md` and `.jig/handoffs/x/y-2026-01-01.md → .jig/handoffs/x-y-2026-01-01-2.md` under `Moves`, and `git status --porcelain` stays empty.
- [ ] `$UP --apply` on that fixture stages both renames as `R100`. `.jig/handoffs/a/` and `.jig/handoffs/x/` are gone from disk, and a second `$UP` prints `up to date`.
- [ ] The existing guarantee holds: `board_split`'s "status: job A counts its own three notes, not job A-x's" and "gate: of three notes … takes the -3 note" pass unchanged.
- [ ] `grep -n 'gate-' plugin/skills/hubnode/SKILL.md` shows the `.out` file named after the scratch checkout `jig gate` printed.
- [ ] `bash tests/smoke.sh` passes in full, and `claude plugin validate ./plugin` passes.

## Out of scope
- Job worktrees at `.git/jig/worktrees/<branch>`. A `/` nests them, which works (see One layer up). Moving the default would move where R2 expects open jobs' worktrees.
- `review_marker` keeps `%`. Under `-`, `a/b` and `a-b` would share one marker, and a review of one would overwrite the other's.
- A nested note on an older layout (`jig/handoffs/a/…`). The first update moves it into `.jig/handoffs/a/` and the next one flattens it, so it isn't done in one pass. [assumed] No old-layout repo has one.
- An open branch that already committed a nested note. The reader never looks for nested names. The branch hands off again and gates the flat note, and update flattens the old one once it reaches trunk.
- In solo, `jig gate <branch>` still says `no job`: solo gates the current branch, as RULES.md says.

## Touches
- `plugin/templates/jig/jig.py`: the new function beside `handoff_notes`; `cmd_handoff`, `handoff_notes` (header check) and `cmd_gate`'s scratch name; `handoff_rows` beside `hardware_rows`, added to `extra` in `cmd_update`; `--apply`'s rmdir pass, extended to the emptied subfolders of `.jig/handoffs/`.
- `plugin/templates/jig/RULES.md`, Working alone: a `/` in the name becomes `-` in the note's file name.
- `plugin/skills/hubnode/SKILL.md`, Gating step 2: the `.out` file is `gate-<name>` with `/` as `-`, the scratch checkout's folder name.
- `tests/smoke.sh`: section `slash_names`.
- `marketing/FEATURES.md` (gitignored). Edit these rows first: `handoff`, `gate`, `` `update` from every generation ``.

## Alternatives considered
- `mkdir(parents=True)` and matching relative to `handoffs/`, the report's second option. Rejected: the owner keeps `handoffs/` flat, and nested names also break the gate's scratch cleanup and the `.out` path. This reason is [seen].
- An encoding that can't collide (`%2F`, or the review marker's `%`). Rejected: the owner chose `/`→`-`, and the header check makes the collision harmless. This reason is [seen]: the header has been in every note since eaec973.
- Refusing `jig open` for a name whose stem matches an open job's. Rejected: it covers neither solo branches nor merged notes on trunk. This reason is [seen]: git allows `a-b-c` beside `a/b-c`.
- Making `handoff_notes` also read nested names. Rejected: the owner wants update to clean up what the bug left, and a second name form in the reader would stay forever. This reason is [seen] (owner's decision).
- Leaving the gate's scratch nested. Rejected: the printed cleanup leaves `gate-a/` behind, and the skill's `.out` redirect fails. This reason is [seen].
- On an update clash, leaving both files and warning, as `plan_moves` does for other rows. Rejected: that leaves the nested note, which is the thing to clean up. A note's `Commit:` line, not its file name, says what was gated. This reason is [seen]: `cmd_gate` reads `Commit:`.

## Decisions
- `a/b` and `a-b` share a stem on purpose. The writer never overwrites: it takes `-2`, `-3` as today. The reader counts a note only when its first line is exactly `# Handoff: <name>`. If both branches are gated at once, the second gate refuses with "left from an earlier gate". Following that message would end the other branch's gate, but the case is rare enough to leave.
- When a moved note clashes, it takes the day's next free `-N`. The order of one day's notes matters only on a branch being gated; on trunk they are history.
- The move is keyed on what update sees in the repo, never on a version, as STEPS are. That means any tracked file in a subfolder of `.jig/handoffs/`, since jig's writer never made one. A clash on a file that isn't shaped like a note gets `plan_moves`' usual "both exist" warning.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
