# Bug: smoke runs were blamed for colliding; the real leak is into the user's own jig config

Source: owner, Nov 2, after a session's wait loop (`pgrep -f "tests/smoke.sh"`) could hang on its
own command line. Owner: "/jig:bug on this problem, then write a /jig:spec to fix broadly".

## 1. Why
- Why did sessions wait on each other's smoke runs? I told them concurrent runs collide, after
  a gate check reported 111 failures for two jobs at once.
- Why did I think they collide? I guessed the update fixtures build worktrees of this repo. They
  don't: they `git archive` old commits into the run's own temp folder. The guess was never
  tested.
- What's actually shared, then? Not the repo, and not the temp folder. The one thing a run can
  reach outside its folder is the user's jig config, and a run of part of smoke does reach it.
  Root: user-level state is isolated section by section, not once, and jig defaults to the real
  `~/.config/jig/`.

## 2. Givens
- `[seen]` Two full smoke runs at once in two clones: 444/444 each. Two at once in two worktrees
  of one repo (the gate check's setup): 444/444 each. Both pairs shared one stand-in
  `XDG_CONFIG_HOME`, and it stayed empty. (Nov 2, in scratch.)
- `[seen]` The real `~/.config/jig/repos.json` holds `plp`, `pm` and `tp`, pointing into
  `jig-smoke.OHAbT5/`: names that only smoke's para-commands section creates (lines ~1587-1697).
- `[seen]` A full run sets `JIG_CONFIG` before that section uses it (line ~1579). The first
  `export JIG_CONFIG` is at line ~832, so everything above it runs against the real config.
  Reviewers and evaluators ran pieces of smoke in throwaway repos, and nothing told them to set
  it.
- `[seen]` `repos_file()` uses `JIG_CONFIG`, else `$XDG_CONFIG_HOME/jig/`, else `~/.config/jig/`.
  The new `kind: feedback` fallback folder sits beside it, so it inherits the same exposure.
- `[seen]` The session's wait loop matched itself through `pgrep -f`. That's an agent's own shell,
  not jig code, and it existed only because of my "don't run two at once" brief.
- `[assumed]` The original 111 failures came from the subagent's environment. Its output files
  never appeared where it said it wrote them. Not reproduced: kept as a risk, with a plan below to
  catch it if it recurs.

## 3. One layer up
- Sibling: every place an agent runs jig outside the user's own repos (review, bug, verify,
  gate checks, evaluations) has the same exposure. Only smoke had any isolation, and only partly.
- Existing pattern: smoke already exports `JIG_CONFIG` per section. Doing it once, at the top,
  covers every section and every fragment copied from it.

## 4. Correction
Make every test and every agent repro hermetic, and stop the waiting:
- smoke isolates user-level state on its first lines
- it proves it touched nothing outside its temp folder
- the skills that run jig in a throwaway repo say to do the same
- "don't run two at once" is retracted, since nothing needs serializing

## 5. Spec

### Done when
- [ ] `tests/smoke.sh` exports `JIG_CONFIG="$T/repos.json"` and `XDG_CONFIG_HOME="$T/config"`
      right after `T=`, before any jig command. The per-section exports stay, as section-local
      lists.
- [ ] Smoke ends with a case that the user's real jig config folder (`$HOME/.config/jig`, as it
      was before the export) has the same listing and hashes as at the start. A run that
      touches it fails.
- [ ] Smoke's header comment says runs are independent and can run at the same time, because
      each touches only its own temp folder.
- [ ] The review, bug and verify skills say: before running jig in a throwaway repo, point
      `JIG_CONFIG` and `XDG_CONFIG_HOME` into it. The hubnode skill says the same in its gate
      check.
- [ ] If a smoke run fails in a way nobody can reproduce, the gate-check instructions say to keep
      its output file inside the repo's `.git/jig/` (not `/tmp`) and report its path, so the next
      occurrence can be read.
- [ ] Smoke passes, and the validator passes.
- [ ] Two smoke runs started together in two worktrees both pass. Run by hand once, at build;
      smoke can't run itself.

### Out of scope
- A lock around smoke. The evidence says there's nothing to serialize.
- Cleaning the leaked entries from the user's `repos.json`: that's the owner's file. Offered
  separately.

### Touches
`tests/smoke.sh`, and skills `review`, `bug`, `verify`, `hubnode`.

### Alternatives considered
- A lock so concurrent runs queue. Rejected: two pairs of concurrent runs, clones and worktrees,
  both pass. It would fix a collision that doesn't exist, and keep agents waiting. `[seen]`,
  Nov 2.
- Make `jig repos add` refuse paths under a temp folder. Rejected: it patches the one symptom
  seen, while the default-to-real-config exposure stays for every other write. `[seen]`: the
  feedback fallback folder has the same exposure.
- Point `HOME` itself at the temp folder. Rejected for now: git, Python and other tools read from
  it, and `JIG_CONFIG` and `XDG_CONFIG_HOME` already cover every path jig writes. `[seen]`:
  `repos_file()`.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
