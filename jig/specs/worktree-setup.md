# Every checkout jig hands out is runnable

## Intent
jig makes a worktree for every lane and every gate. Git never brings ignored folders along,
so a new worktree has no `.venv`, no `node_modules`, no submodules and no local config. Any
repo whose checks need those breaks at its first lane, and its gate fails or borrows another
checkout's environment. Each repo gets one script, `jig/scripts/setup.sh`, that makes the
checkout it runs in runnable. jig's git hooks run it whenever git brings another commit's
files into a checkout: a new worktree, or a merge. jig decides when it runs, and the repo
decides what it does. That is the same split as `check.sh` and `format.sh`.

## Done when
- [ ] `tests/smoke.sh`, in a repo whose `setup.sh` appends `$PWD` to a log outside the repo:
      - `jig open` and a plain `git worktree add --detach` each log the new worktree once.
      - `git switch` in an existing checkout logs nothing.
      - A merge that changes files logs the checkout that merged, once, for both a
        fast-forward and a true merge. "Already up to date" logs nothing.
      - `jig sync` that resolves an append conflict itself logs the lane's worktree once.
      - `jig open`'s stderr shows what `setup.sh` printed.
- [ ] A `setup.sh` that exits 1 fails nothing. `jig open` exits 0, the lane is on the board
      and the worktree exists. A plain `git worktree add` exits 0. Stderr names
      `jig/scripts/setup.sh`, its exit code and the checkout. (smoke)
- [ ] A checkout with no `jig/scripts/setup.sh`, such as a branch from before this change,
      runs nothing and prints nothing extra. (smoke)
- [ ] After init, `jig/scripts/setup.sh` is executable and exits 0. Its body is TODOs, like
      `check.sh`'s. (smoke)
- [ ] The template's link example, uncommented, can be run twice in a worktree and once in
      the main checkout. Each run leaves the same state, and the worktree's
      `git status --porcelain` stays empty. Checked by hand in a scratch repo.
- [ ] With this and `update` both landed, `update --apply` on a repo without `setup.sh` copies
      the template's and installs the `post-merge` hook. A repo that has one keeps it
      byte-identical. (smoke, in update's cases)
- [ ] A Claude Code worktree session in a jig repo starts with `setup.sh` already run.
      Checked once by hand. `[assumed]` until then: that Claude Code makes its worktrees with
      `git worktree add`.
- [ ] `claude plugin validate ./plugin` passes.

## Out of scope
- A board list of paths to link from the main checkout (see Alternatives).
- Branch switches inside an existing checkout. R1 keeps the trunk checkout on trunk and R2
  gives each lane its own worktree, so a switch is the exception. `post-checkout` still only
  warns there.
- A merge finished by hand after a conflict. Git runs no `post-merge` for it, so whoever
  resolves it runs `setup.sh`. `jig sync` finishes its own merges and runs it itself.
- Making installs fast, sharing caches, timeouts. That's the package manager's job.
- Windows. jig's hooks and scripts are POSIX already.
- Daisy's own files: what its `setup.sh` says, and removing its hand-made equivalents. That
  happens in Daisy, through `update` (see Decisions).

## Touches
- `marketing/FEATURES.md`: the `jig/scripts/setup.sh` row (added with this spec).
- `plugin/templates/jig/scripts/setup.sh`, new. Header comment: makes this checkout
  runnable; runs in every new worktree and after every merge; safe to run twice, and cheap
  when already current. Commented examples:
  - Install, the default: `uv sync`, `npm install --prefix ui`,
    `git submodule update --init --recursive`.
  - Copy local config: `[ -e .env ] || cp "$main/.env" .env`.
  - Link instead of install, with its trade-off spelled out: lanes then share one
    environment, and the gate can't catch a package that is installed but not declared.
    `[ -e .venv ] || ln -s "$main/.venv" .venv`. Ignore the path as `.venv`, not `.venv/`,
    because git doesn't treat a link as a folder.
  - `main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")` for the
    two examples that need the main checkout.
- `plugin/templates/jig/jig.py`:
  - `cmd_install_hooks`: `post-merge` joins the list. A predecessor's `post-merge` is kept
    as `.local`, like the others.
  - `run_setup(root)`: if this checkout has `jig/scripts/setup.sh`, print one line naming
    the checkout, then run the script from the checkout's root, with its stdout sent to
    stderr. If it fails, print the script, the exit code and "fix it, then run it again
    in <checkout>". It returns nothing, so no caller fails because setup failed.
  - `cmd_hook`:
    - `post-checkout` whose previous ref is all zeros (a new checkout) calls `run_setup`.
    - `post-merge` calls `run_setup`.
    - Both return 0 whatever setup did. Neither needs the board.
  - `cmd_open`: runs `git worktree add` with stderr passed through, so setup's output and
    failures show.
  - `cmd_sync`: the merge also passes stderr through. After it commits a merge it resolved
    itself, it calls `run_setup`, because git ran no `post-merge` for that merge. The
    "resolve by hand" message adds `./jig/scripts/setup.sh` after `git commit`.
  - Survey's present list: `jig/scripts/setup.sh`.
  - `cmd_gate`'s printed commands don't change (see Decisions).
  - `update`'s first `STEPS` entry: when `jig/scripts/setup.sh` is missing, copy the
    template's from beside the running `jig.py`, never overwriting. `STAMP` goes to 4.
- `plugin/templates/AGENTS.md`, Commands: `setup: jig/scripts/setup.sh (runs itself in new
  worktrees and after merges; run it after changing dependencies)`.
- `plugin/templates/jig/RULES.md`: one sentence where the gate's scratch checkout is
  described. The hooks set it up with `setup.sh`, at add and again at the merge.
- `plugin/skills/init/SKILL.md`, "Fill what the code tells you": fill `setup.sh` from what is
  there, and leave a TODO for anything else.
  - `uv.lock` → `uv sync`
  - `poetry.lock` → `poetry install`
  - `requirements*.txt` → a venv and `pip install -r`
  - each `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` → that tool's install in its
    directory
  - `.gitmodules` → `git submodule update --init --recursive`
  - a gitignored `.env` in the main checkout → the copy line
- `plugin/skills/update/SKILL.md` (from `update.md`): when `update` added `setup.sh`, fill it
  the way init's skill does. Then name anything in the repo that already does the job by
  hand, like a check script that borrows the main checkout's environment, or `ln -s` steps in
  a skill, and offer to remove each once `setup.sh` covers it.
- `plugin/skills/adopt/MIGRATION.md`:
  - A mapping row: "a step that links or installs into each new worktree" → `setup.sh`.
  - Stage 1's copy list gains `jig/scripts/setup.sh`.
- `jig/specs/update.md`: once update is built, its done-when list of changed entries gains
  `jig/scripts/setup.sh` when the repo lacked it. Its expected Daisy run gains the TODO
  `setup.sh` and a fifth hook.
- `tests/smoke.sh`.

## Alternatives considered
- A board `links` list, symlinked from the main checkout into each new worktree. This was
  Daisy's predecessor's `LINKS` (`76a2dba^:scripts/lane.py`, lines 50 and 819–829) and my
  first proposal. Rejected:
  - It is one strategy for one kind of repo.
  - It shares one environment between trunk and every lane, so the gate can pass a commit
    whose dependency is installed but never declared. `[seen]`: Daisy's documents lane
    installed pypdf and openpyxl into the main checkout's `.venv` (its Oct 14 handoff).
  - A repo can still link inside `setup.sh`, as its own recorded choice.
- `jig open` runs setup itself. Rejected: that misses gate's scratch checkout, Claude Code's
  worktrees and hand-made ones. `[seen]`, tested Oct 28: git runs `post-checkout` for every
  `git worktree add`, with `-b` or `--detach`, inside the new worktree, and the previous ref
  is all zeros. Ordinary checkouts pass a real ref.
- Print a setup line in gate's commands instead of hooking `post-merge`. Rejected: it covers
  only the gate. `post-merge` also covers `jig sync`, the hubnode's merges into trunk and
  pulls, with no jig command special-cased. `[seen]`, same test: `post-merge` fires on
  fast-forward and true merges, and not on "Already up to date" or a conflicted merge.
- Run trunk's copy of `setup.sh`, the way the hooks run trunk's `jig.py`. I proposed this on
  Oct 28; reversed here.
  - The hooks run trunk's checker so a branch can't weaken the rules that judge it.
    `setup.sh` judges nothing.
  - It must match the files checked out: a lane that adds a package updates `setup.sh` in
    the same branch.
  - `check.sh` and `format.sh` already run the checkout's own copy. `[seen]`
- Let a failing setup fail the checkout. Rejected: the worktree exists either way.
  `[seen]`: a `post-checkout` that exits 3 makes `git worktree add` exit 3 with the worktree
  created. `jig open`, and any tool that makes worktrees, would then report failure for a
  worktree that is there.
- Copy the main checkout's environment. Rejected: a venv's scripts carry the absolute path
  they were made at. `[seen]`: a fresh venv's `bin/pip` shebang and `activate`'s
  `VIRTUAL_ENV`.
- A Claude Code hook instead of a git hook. Rejected:
  - Enforcement and its plumbing live in `jig.py` and git hooks, with nothing AI-tool-specific
    (`AGENTS.md`).
  - A git hook covers worktrees made by any tool.

## Decisions
- `setup.sh`'s contract:
  - It makes the checkout it runs in runnable.
  - It is safe to run twice, and cheap when already current.
  - It takes no arguments and nothing from jig's environment, so the same script runs from
    a hook, from `jig sync` or by hand after a dependency change.
- Install is the template's default, and linking is opt-in. The gate can only catch an
  undeclared dependency when its checkout installs from the repo's own manifests.
- Gate's printed commands stay as they are:
  - `git worktree add --detach` sets the scratch checkout up for the lane's commit.
  - `git merge trunk` sets it up again for the merged tree, or does nothing when the lane
    already has trunk, in which case the first setup was for that same tree.
- The main checkout runs setup after the hubnode merges a lane. That keeps trunk's own
  environment current with what lanes added. A repo that links makes this a no-op with the
  `[ -e … ] ||` guard.
- The hooks go from four to five. Each costs one `git show` and a Python start
  (`[seen]`, the hook template). `post-merge` runs only on merges, not on every commit.
- Order: `update` lands first, since it is already specced and next. This then adds
  `update`'s first step and bumps `STAMP` to 4. Daisy gets both with one `jig update`:
  - The step adds a TODO `setup.sh`.
  - The update skill fills it from Daisy's `uv`/npm files and names the hand-made
    equivalents. `[seen]` on the scratch clone at `88560bd`: the borrow-the-venv fallback in
    `scripts/check.sh` and `scripts/format.sh`, and the two `ln -s` lines with absolute paths
    in `.claude/skills/daisy-lanes/SKILL.md:70-71`.
  - Removing those is Daisy's change, made with the user before the update commit.
- Daisy's predecessor also added each link to `.git/info/exclude`. A script that links
  needs the same care. `[seen]`: a linked `.venv` shows as untracked under a `.venv/`
  ignore pattern, and a linked `node_modules` is ignored under `node_modules`. The template
  says so beside the link example, instead of jig editing `info/exclude`.
