#!/usr/bin/env python3
"""jig - parallel jobs on one repository.

Git hooks execute TRUNK's copy of this file, so a branch cannot weaken the
rules it is judged by. Stdlib only.
"""
from __future__ import annotations

import argparse
import difflib
import fnmatch
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import urllib.parse
from datetime import date
from pathlib import Path

DIR = ".jig"
# The board is two files: what rarely changes, and the open jobs, which churn. Both are read
# from trunk and written only there.
CONFIG = f"{DIR}/config.json"
JOBS = f"{DIR}/jobs.json"
LEGACY_BOARD = f"{DIR}/lanes.json"   # the one-file board, before version 8
WORKAROUNDS = f"{DIR}/ledgers/WORKAROUNDS.md"
DEFERRED = f"{DIR}/ledgers/DEFERRED.md"
# A merged job has no state: its entry is gone, deleted in its merge commit.
STATES = ["claimed", "building", "ready", "gated", "parked"]
# The layout this copy of jig writes into the config's "version". Any change that adds a
# LAYOUT row, a config default or an update STEP bumps it. Nothing branches on it except
# update's refusal to take a newer repo back to an older jig.
STAMP = 10
BOARD_DEFAULTS = {
    "version": STAMP,
    "name": "",            # init and update fill it with the folder name; staging's targets match it
    "trunk": "main",
    "common": ["AGENTS.md", "docs/**", f"{DIR}/**"],
    "append_files": ["AGENTS.md", f"{DIR}/ledgers/**", f"{DIR}/decisions.md"],
    "reserve": {},         # counter: {"pattern": regex with one group, "files": [globs], "unique": bool}
    "docmap": {},
    "not_docs": [],        # globs whose markdown ships as code; survey finds no home for it
    "release": {"artifacts": []},   # globs release.sh must produce; see `jig release`
    # Whether a board's datasheets are committed ("commit") or gitignored ("ignore"). Left
    # unset, the hardware skill asks once, the next time it writes a page: a public repo may
    # not be allowed to redistribute vendor PDFs, so it's the repo's call.
    "reference_files": "",
}
# Board keys jig reads but never writes: absent means jig's defaults, so update adds none of
# them. Each new optional key goes here, or update calls it unknown.
BOARD_OPTIONAL = (
    "workflow",            # overrides WORKFLOW_DEFAULTS
    "deep_subsystems",     # {"docs/<system>/<subsystem>/<folder>": rationale}: owner-approved deeper pages
    "boards",              # ["docs/<board>/<board>.md", "docs/<system>/<board>/<board>.md"]: the pages that are boards, never inferred from a path
    "findings",            # {"<kind>:<path>": "approved" | "deferred: <where>" | "exception: <reason>"}: the owner's answer to each finding
)
# Who runs each step, as numbers the tool maps to its own models and efforts. Tier 1 is the
# tool's best model, a higher number a lesser one; effort 0 is its highest, each number up one
# level lower. Effort 0 is left unused so a repo can raise any step. Overridden per repo by
# config.json's "workflow", never per task: a model would be choosing its own budget.
WORKFLOW_DEFAULTS = {
    "spec":    {"tier": 2, "effort": 2},   # and decide, retro, a hardware page: the hubnode's
    "bug":     {"tier": 2, "effort": 1},   # a /jig:bug investigation, before any diff exists
    "execute": {"tier": 2, "effort": 3},   # and fix, in the session that executed
    "review":  {"tier": 2, "effort": 1},   # always in a fresh context
    "check":   {"tier": 3, "effort": 4},   # gate check, release run, survey: fixed commands
}


# ---------------------------------------------------------------- git helpers

def git(*args: str, check: bool = False, cwd: str | None = None) -> str:
    p = subprocess.run(["git", *args], capture_output=True, text=True, cwd=cwd)
    if check and p.returncode:
        die(f"git {' '.join(args)}: {p.stderr.strip()}", 2)
    return p.stdout.strip()


def die(msg: str, code: int = 1) -> None:
    print(f"jig: {msg}", file=sys.stderr)
    sys.exit(code)


def repo_root() -> Path:
    top = git("rev-parse", "--show-toplevel")
    if not top:
        die("not a git repository", 2)
    return Path(top)


def main_root() -> Path:
    """The primary checkout's root, even when called from a linked worktree."""
    common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
    return common.parent


def worktrees_dir() -> str:
    """Where jobs are checked out, relative to the primary checkout. Inside .git/ because
    a worktree is git state, and tools that walk the repo (test runners, globbers) never
    look there — a visible folder would hand them every job's full copy of the repo."""
    common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
    return Path(os.path.relpath(common / "jig" / "worktrees", main_root())).as_posix()


def is_main_worktree(root: Path) -> bool:
    """True in the primary checkout, false in a linked worktree."""
    return main_root().resolve() == root.resolve()


def glob_re(pattern: str) -> re.Pattern[str]:
    out, i = "", 0
    while i < len(pattern):
        c = pattern[i]
        if pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif c == "*":
            out, i = out + "[^/]*", i + 1
        elif c == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(c), i + 1
    return re.compile(f"^{out}$")


def matches(path: str, patterns: list[str]) -> bool:
    return any(glob_re(p).match(path) for p in patterns)


# ---------------------------------------------------------------------- board

class Board:
    """The config and the open jobs, read together: every rule needs both."""
    def __init__(self, root: Path, data: dict, jobs: dict):
        self.root, self.data, self.jobs = root, data, jobs

    @classmethod
    def load(cls, root: Path, *, working_tree: bool = False) -> "Board":
        """Read the board from TRUNK by default, so a branch cannot edit the rules
        it is judged by. working_tree=True is for the hubnode, who writes it."""
        base = main_root()
        if not working_tree:
            trunk = cls.trunk_name(base)
            raw = git("show", f"{trunk}:{CONFIG}")
            if raw:
                return cls(base, json.loads(raw), json.loads(git("show", f"{trunk}:{JOBS}") or "{}"))
        if not (base / CONFIG).exists():
            old = old_board(base)
            die(f"an older jig's board is at {old}: run /jig:update first" if old
                else f"no board at {CONFIG}. Run: jig init", 2)
        jobs = base / JOBS
        return cls(base, json.loads((base / CONFIG).read_text()),
                   json.loads(jobs.read_text()) if jobs.exists() else {})

    @staticmethod
    def trunk_name(root: Path) -> str:
        p = root / CONFIG
        if p.exists():
            try:
                return json.loads(p.read_text()).get("trunk", "main")
            except Exception:
                pass
        return "main"

    def save(self) -> None:
        """Only the jobs: nothing the hubnode does day to day changes the config."""
        (self.root / JOBS).write_text(json.dumps(self.jobs, indent=2) + "\n")

    @property
    def trunk(self) -> str:
        return self.data.get("trunk", "main")

    def open_jobs(self) -> dict:
        return self.jobs        # a merge deletes the entry, so every one is open

    # A job's branch is its name and its worktree is under .git/jig/worktrees/. Only a job
    # adopted on another branch, or checked out elsewhere, stores the value that differs.
    def branch(self, name: str) -> str:
        return (self.jobs.get(name) or {}).get("branch") or name

    def worktree(self, name: str) -> str:
        return (self.jobs.get(name) or {}).get("worktree") or f"{worktrees_dir()}/{self.branch(name)}"

    def job_for_branch(self, branch: str) -> tuple[str, dict] | tuple[None, None]:
        for name, job in self.jobs.items():
            if self.branch(name) == branch:
                return name, job
        return None, None


# ------------------------------------------------------------------- workflow

def workflow_steps(config: dict) -> tuple[dict, list[str]]:
    """The steps in effect, and every way the override breaks the rules. Execute is judged
    against the spec it builds from; review needs a model at least as good as the one whose
    work it judges (its effort is the owner's call); a bug investigation writes a spec, so it
    gets at least the spec's budget."""
    steps = {k: dict(v) for k, v in WORKFLOW_DEFAULTS.items()}
    over = config.get("workflow") or {}
    if not isinstance(over, dict):
        return steps, ["workflow: must map step names to {\"tier\": N, \"effort\": N}"]
    bad = []
    for step, vals in over.items():
        if step not in steps:
            bad.append(f"workflow.{step}: no such step; the steps are {', '.join(steps)}")
            continue
        if not isinstance(vals, dict):
            bad.append(f"workflow.{step}: must be {{\"tier\": N, \"effort\": N}}")
            continue
        for k, v in vals.items():
            least = {"tier": 1, "effort": 0}.get(k)
            if least is None:
                bad.append(f"workflow.{step}.{k}: only tier and effort are set")
            elif type(v) is not int or v < least:
                bad.append(f"workflow.{step}.{k}: {v!r} is not a whole number from {least} up")
            else:
                steps[step][k] = v
    # A raised spec raises bug with it: an investigation that writes a spec never gets less.
    for k in ("tier", "effort"):
        if k not in (over.get("bug") or {}):
            steps["bug"][k] = min(steps["bug"][k], steps["spec"][k])
    sp, bg, ex, rv = steps["spec"], steps["bug"], steps["execute"], steps["review"]
    lower = " (a higher number is a lower effort)"
    if bg["tier"] > sp["tier"]:
        bad.append(f"workflow.bug: tier {bg['tier']} is below the spec's tier {sp['tier']}")
    if bg["effort"] > sp["effort"]:
        bad.append(f"workflow.bug: effort {bg['effort']} is lower than the spec's "
                   f"effort {sp['effort']}{lower}")
    if ex["tier"] < sp["tier"]:
        bad.append(f"workflow.execute: tier {ex['tier']} is above the spec's tier {sp['tier']}")
    if ex["effort"] <= sp["effort"]:
        bad.append(f"workflow.execute: effort {ex['effort']} is not below the spec's "
                   f"effort {sp['effort']}{lower}")
    if rv["tier"] > ex["tier"]:
        bad.append(f"workflow.review: tier {rv['tier']} is below execute's tier {ex['tier']}")
    return steps, bad


def cmd_workflow(root: Path, args) -> int:
    """Print the steps in effect; refuse an override that breaks a rule."""
    # The working tree's config, so the hubnode sees a refusal before committing the edit.
    steps, bad = workflow_steps(Board.load(root, working_tree=True).data)
    # Refused, nothing goes to stdout: a skill copying the steps into a spec must get none.
    for b in bad:
        print(b, file=sys.stderr)
    if bad:
        return 1
    for step, v in steps.items():
        print(f"{step}: tier {v['tier']}, effort {v['effort']}")
    return 0


# ---------------------------------------------------------------------- rules

AUTO_MERGE = False   # set by the pre-merge-commit hook: git has not written MERGE_HEAD yet


def base(trunk: str) -> str:
    """What a change is compared against: HEAD, or trunk while a merge of trunk is
    being finished — otherwise everything trunk brought in looks like ours."""
    if AUTO_MERGE:
        return trunk
    merge_head = git("rev-parse", "-q", "--verify", "MERGE_HEAD")
    if merge_head and subprocess.run(["git", "merge-base", "--is-ancestor", merge_head, trunk],
                                     capture_output=True).returncode == 0:
        return merge_head
    return "HEAD"


def since_trunk(trunk: str) -> str:
    """Where a branch's log and numbers are judged from: where it left trunk, so a branch is judged
    as its squash would be and a later commit may correct an earlier one. On trunk, on a detached
    HEAD (the gate's scratch merge), or finishing a merge of trunk, it is base()."""
    b = base(trunk)
    if b != "HEAD" or git("branch", "--show-current") in (trunk, ""):
        return b
    return git("merge-base", trunk, "HEAD") or b


def changed_paths(trunk: str, staged: bool, removed: bool = False) -> list[str]:
    """What the change writes: a rename shows under its new path only, and a delete not at all,
    which is what a rule on content judges. With REMOVED, every path it adds, edits or removes,
    both sides of a rename included: a rule guarding a path counts taking it away as changing it."""
    args = (["-c", "core.quotePath=false", "diff", "--name-only", "--no-renames"] if removed
            else ["diff", "--name-only", "--diff-filter=ACMRT"])
    args += [base(trunk), *(["--cached"] if staged else [])]
    return [p for p in git(*args).splitlines() if p]


def at_rev(rev: str, path: str) -> str:
    return git("show", f"{rev}:{path}")


def in_index(path: str, staged: bool) -> str:
    if not staged:
        return (Path(path).read_text(errors="replace") if Path(path).exists() else "")
    return git("show", f":{path}")


def has_log(trunk: str) -> bool:
    """Whether trunk keeps the decision log. A repo `jig update` hasn't moved to it yet keeps
    the rules it had: a metarepo's CHANGELOG.md and its register of rows."""
    return bool(git("ls-tree", "--name-only", trunk, "--", LOG))


def holds_old_log(text: str, path: str, prefix: str | None) -> bool:
    """Whether a file still is a log from before .jig/decisions.md: a CHANGELOG.md with its
    sections, or a register with rows. What the merge leaves behind (a preamble, a note) isn't."""
    if path == CHANGELOG:
        return bool(re.search(r"^## ", text, re.M))
    return bool(rows_in(text, prefix))


def migrated_here(trunk: str, staged: bool, meta: dict | None) -> bool:
    """This change is the merge into the log: it adds the log and no longer holds CHANGELOG.md's
    sections or a register's rows. A change that adds a log beside the old files is no merge,
    and the old rules still judge it."""
    if not in_index(LOG, staged):
        return False
    entry = (meta or {}).get("entry_files", [])
    prefix = (meta or {}).get("decision_prefix")
    olds = [f for f in git("ls-tree", "-r", "--name-only", trunk).splitlines()
            if f == CHANGELOG or (f.endswith(".md") and not f.startswith(f"{DIR}/")
                                  and (f in entry or Path(f).name.lower() == "decisions.md"))]
    return not any(holds_old_log(in_index(f, staged), f, prefix) for f in olds)


def changelog_only_grows(trunk: str, staged: bool) -> bool:
    """CHANGELOG.md is still there and this change deletes none of its lines."""
    if not in_index(CHANGELOG, staged):
        return False
    stat = git("diff", "--numstat", base(trunk), *(["--cached"] if staged else []), "--", CHANGELOG)
    return all(line.split("\t")[1] == "0" for line in stat.splitlines() if line)


def existed_on_trunk(trunk: str, path: str) -> bool:
    return bool(git("ls-tree", "-r", "--name-only", trunk, "--", path))


def check_rules(root: Path, board: Board, *, staged: bool) -> list[str]:
    """Return a list of refusals. Empty means pass."""
    out: list[str] = []
    branch = git("branch", "--show-current")
    trunk = board.trunk
    name, job = board.job_for_branch(branch)
    paths = changed_paths(trunk, staged)
    guarded = changed_paths(trunk, staged, removed=True)
    meta = load_meta(trunk)
    if meta is not None:
        out += meta_rules(root, board, meta, staged)
    para = load_para(trunk)
    if para is not None:
        out += para_rules(root, board, para, staged)
    if LOG in guarded:
        out += log_rules(trunk, staged, on_trunk(trunk, branch))

    # R1 the trunk checkout stays on trunk (only when jobs are open: solo, one checkout
    # with a feature branch is normal and nobody else's tree is being moved)
    if board.open_jobs() and is_main_worktree(root) and branch and branch != trunk:
        out.append(
            f"R1 the {trunk} checkout stays on {trunk}; it is on {branch}. "
            f"Work in a worktree: {worktrees_dir()}/{branch}"
        )

    # R5 the board is the hubnode's
    for f in (CONFIG, JOBS):
        if f in guarded and branch != trunk:
            out.append(f"R5 the board is the hubnode's: {f} is edited on {trunk} only")
    # A phase or a scope is the owner's decision, and a branch regenerating the view would
    # only make merge conflicts: both roadmap files change on trunk alone.
    # ROADMAP.md is jig's only where trunk keeps a roadmap: elsewhere it is the repo's own page.
    for f in (ROADMAP, *([ROADMAP_VIEW] if at_rev(trunk, ROADMAP) else [])):
        if f in guarded and branch != trunk:
            out.append(f"R5 the roadmap is the owner's: {f} is edited on {trunk} only")
    out += roadmap_rules(board, branch, staged, paths, guarded)
    out += boundary_rules(trunk, branch, staged, paths, meta)
    if CONFIG in paths and (raw := in_index(CONFIG, staged)):
        try:
            out += workflow_steps(json.loads(raw))[1]
        except ValueError as e:
            out.append(f"{CONFIG} is not JSON: {e}")
    # A remap that keeps a page where survey moves it overrides jig's rule: the owner's
    # exception must be on record first, or one line of prose approves it unseen.
    if REMAP in paths and (raw := in_index(REMAP, staged)):
        cfg = board.data
        if CONFIG in paths and branch == trunk:
            try:
                cfg = json.loads(in_index(CONFIG, staged))
            except ValueError:
                pass
        out += [f"the remap contradicts survey: {contradiction_fix(c, trunk)}"
                for c in remap_contradictions(root, tracked(root), cfg, raw)]

    # R7 a workaround needs its ledger row — job or not; code only, prose may quote it. Only
    # the marker right after a comment opener is the comment the rule names: a string or regex
    # that mentions it isn't. jig's own checker is skipped too, since the previous checker,
    # which may match the marker anywhere, judges every update of it.
    code = [p for p in paths if (p.endswith(CODE_EXT) or Path(p).name == "Kconfig")
            and p != f"{DIR}/jig.py"]
    diff = git("diff", "-U0", base(trunk), *(["--cached"] if staged else []), "--", *code) if code else ""
    if re.search(r"^\+(?:.*(?:#|//|/\*)|\s*\*)\s*WORKAROUND:", diff, re.M) and WORKAROUNDS not in paths:
        # The ledger is made by its first row, so the refusal says where that row goes.
        out.append(f"R7 the diff adds a WORKAROUND: comment but {WORKAROUNDS} is not staged: "
                   f"add its row there in this commit (the first row creates the file from "
                   f"jig's ledger template)")

    # R6 on a job branch always; on trunk only while jobs are open, since solo
    # there is nobody to collide with and the numbers are yours
    held: dict[str, set[int]] = {}
    who = f"job {name}"
    for k, v in held_numbers(job or {}).items():
        held.setdefault(k, set()).update(v)
    if job is None and branch == trunk:
        # Merging a job brings in the numbers it holds: trunk takes them by merging it.
        tips = set(merging_commits())
        for n, l in board.jobs.items():
            if tips and git("rev-parse", "-q", "--verify", f"refs/heads/{board.branch(n)}") in tips:
                for k, v in held_numbers(l).items():
                    held.setdefault(k, set()).update(v)
                who = "the job being merged"
        # The numbers the merge itself gave the job's new entries are the job's too.
        given = numbers_given(trunk) if tips else set()
        for k, v in (board.data.get("reserve") or {}).items():
            if given and isinstance(v, dict) and matches(LOG, v.get("files") or []):
                held.setdefault(k, set()).update(given)
    head = git("rev-parse", "HEAD") if job is None and not branch else ""
    if head and subprocess.run(["git", "merge-base", "--is-ancestor", head, trunk],
                               capture_output=True).returncode:
        # A detached HEAD off trunk is the gate's scratch checkout of a job's commit: it holds
        # what the job holds, or its merge of trunk would take every number the job built. A
        # detached trunk holds nothing, or a fast-forward could carry a held number onto it.
        for n, l in board.jobs.items():
            if subprocess.run(["git", "merge-base", "--is-ancestor", head,
                               f"refs/heads/{board.branch(n)}"], capture_output=True).returncode == 0:
                for k, v in held_numbers(l).items():
                    held.setdefault(k, set()).update(v)
                who = f"job {n}"
    # Working alone the numbers are yours, but a second migration 17 still breaks a database:
    # "unique" applies with no jobs open too.
    out += reserved_refusals(root, board, held, who, staged,
                             takes=job is not None or bool(board.open_jobs()))

    if job is None:
        if branch and branch != trunk and board.open_jobs():
            out.append(
                f"R2 branch {branch} is on no job. Ask the hubnode to open one, "
                f"or work on {trunk}"
            )
        return out

    # R2 a job is built in its worktree
    wt = board.worktree(name)
    expect = (main_root() / wt).resolve()
    here = Path(git("rev-parse", "--show-toplevel")).resolve()
    if expect.exists() and here != expect:
        out.append(f"R2 job {name} is built in {wt}, not here")

    common = board.data.get("common", [])
    owns, shares = job.get("owns", []), job.get("shares", [])
    others = {n: l for n, l in board.open_jobs().items() if n != name}

    for p in guarded:
        if p.startswith(f"{DIR}/handoffs/"):
            continue
        # R4 another open job's owns wins, even over this job's lists
        for on, ol in others.items():
            if matches(p, ol.get("owns", [])):
                out.append(f"R4 {p} is owned by job {on}: ask the hubnode before touching it")
                break
        else:
            # Any job may record a decision or a change, whatever its lists say, since M3 asks
            # a metarepo job for its line. It only adds, outside ## Open where an open entry's
            # status changes in place: a rewrite would take what others recorded with it.
            if p == LOG:
                since = git("merge-base", trunk, "HEAD") or base(trunk)
                now = in_index(LOG, staged)
                if now and not outside_open_deleted(at_rev(since, LOG), now):
                    continue
                # A log the branch added and then removed was never trunk's.
                if not now and not at_rev(since, LOG):
                    continue
                out.append(f"R3 {LOG}: a job adds to the log, and changes lines in place only "
                           f"under ## Open")
                continue
            # R3 only this job's files, or a file new to the repository. Removing a file is
            # changing it: one trunk has must be declared; one only this job added never was trunk's.
            if matches(p, owns) or matches(p, shares) or matches(p, common):
                continue
            # Before the log, M3 asks every metarepo job for a CHANGELOG.md line, so every one may
            # add lines to it. Only add: a rewrite would take the released history with it.
            if meta is not None and p == CHANGELOG and not has_log(trunk) and changelog_only_grows(trunk, staged):
                continue
            if not existed_on_trunk(trunk, p):
                continue
            out.append(f"R3 {p} is not job {name}'s: ask the hubnode to add it to shares")

    return out


# ------------------------------------------------------------------- commands

def doc_owners(board: "Board", path: str) -> list[str]:
    """Every docmap page that covers this file. A file can have several — its system page,
    a seam page, the page of the board it runs on — and each must be asked about."""
    return [page for page, globs in (board.data.get("docmap") or {}).items()
            if matches(path, globs)]


def highest_on_trunk(board: "Board", counter: str, spec: dict) -> int:
    """The highest value of a counter actually present on trunk, so a number taken
    outside the board is never handed out again."""
    if not isinstance(spec, dict) or not spec.get("pattern"):
        return 0
    pat = re.compile(spec["pattern"], re.M)
    top = 0
    for f in git("ls-tree", "-r", "--name-only", board.trunk).splitlines():
        if f and matches(f, spec.get("files") or ["**"]):
            for m in pat.finditer(git("show", f"{board.trunk}:{f}")):
                try:
                    top = max(top, int(m.group(1)))
                except ValueError:
                    pass
    return top


def held_numbers(job: dict) -> dict[str, set[int]]:
    """What a job holds, per counter. `jig reserve` turns one value into a list."""
    out: dict[str, set[int]] = {}
    for k, v in (job.get("reserved") or {}).items():
        out.setdefault(k, set()).update(int(x) for x in (v if isinstance(v, list) else [v])
                                        if str(x).isdigit())
    return out


def next_number(board: "Board", counter: str, spec: dict) -> int:
    """The next free number: above everything trunk has and everything an open job holds,
    so two jobs open at once never get the same one."""
    held = [n for l in board.jobs.values() for n in held_numbers(l).get(counter, ())]
    return max([highest_on_trunk(board, counter, spec), *held]) + 1


def reserved_refusals(root: Path, board: "Board", holds: dict[str, set[int]],
                      who: str, staged: bool, takes: bool = True) -> list[str]:
    """R6. A scarce number (migration step, schema version) belongs to one job.
    A number is taken when the base has no match for it in the counter's files and the
    index adds one. A dotted number under a whole number the base already has takes nothing,
    and editing or moving a match nets to zero. A counter with "unique" also refuses a number
    whose count rises past one: a second migration 17 is a collision of its own. Numbers
    compare as ints, so D-002 is the 2 a job holds; a refusal shows the text it matched.
    With TAKES false (no job open, so nobody to collide with) only "unique" is checked."""
    out: list[str] = []
    # A counter without a pattern matches nothing; update refuses one.
    counters = {k: v for k, v in (board.data.get("reserve") or {}).items()
                if isinstance(v, dict) and v.get("pattern") and (takes or v.get("unique"))}
    if not counters:
        return out
    at = since_trunk(board.trunk)
    touched = git("diff", "--name-only", "--no-renames", at,
                  *(["--cached"] if staged else [])).splitlines()
    tree = git("ls-tree", "-r", "--name-only", at).splitlines()
    for counter, spec in counters.items():
        pat = re.compile(spec["pattern"], re.M)
        globs = spec.get("files") or ["**"]
        held = holds.get(counter)
        files = {p for p in touched if p and matches(p, globs)}
        # Counted over every file the counter covers at the base, so a number defined in a
        # file this change doesn't touch is still one the base has.
        before: dict[int, int] = {}
        after: dict[int, int] = {}
        shown: dict[int, str] = {}

        def count(text: str, *into: dict[int, int]) -> None:
            for m in pat.finditer(text):
                try:
                    n = int(m.group(1))
                except ValueError:
                    continue
                shown.setdefault(n, m.group(1))
                for d in into:
                    d[n] = d.get(n, 0) + 1

        for p in tree:
            if p and matches(p, globs):
                count(at_rev(at, p), before, *([] if p in files else [after]))
        for p in files:
            count(in_index(p, staged), after)
        for n in sorted(after):
            got = shown[n]
            if spec.get("unique") and after[n] > max(1, before.get(n, 0)):
                out.append(f"R6 {counter} {got} already exists: a {counter} is unique, and this "
                           f"change adds another" if n in before else
                           f"R6 {counter} {got} appears twice in this change: a {counter} is unique")
            if n in before or not takes:
                continue
            if not held:
                out.append(f"R6 this change takes {counter} {got}, but this branch holds no "
                           f"{counter}: ask the hubnode to reserve one")
            elif n not in held:
                out.append(f"R6 this change takes {counter} {got}, but {who} holds "
                           f"{counter} {', '.join(str(h) for h in sorted(held))}")
    return out


def old_board(root: Path) -> str | None:
    """An older jig's board, at any path update knows how to move."""
    return next((p for p in LAYOUT[0][1] if (root / p).exists()), None)


def cmd_init(root: Path, args) -> int:
    # A second board beside an old one is what update refuses as "two boards", and the hooks
    # would run a trunk .jig/jig.py that doesn't exist yet: so nothing is written at all.
    old = old_board(root)
    if old:
        die(f"refused: {old} is an older jig's board, and init would write a second one beside "
            f"it. Run `jig update` (then --apply), commit, then run this same `jig init` again", 2)
    (root / DIR).mkdir(exist_ok=True)
    ensure_staging(root)
    path = root / CONFIG
    if path.exists():
        print(f"{CONFIG} already exists")
    else:
        data = json.loads(json.dumps(BOARD_DEFAULTS))
        data["trunk"] = args.trunk
        data["name"] = main_root().name
        path.write_text(json.dumps(data, indent=2) + "\n")
        print(f"wrote {CONFIG}")
    if not (root / JOBS).exists():
        (root / JOBS).write_text("{}\n")
        print(f"wrote {JOBS}")
    if not (root / LOG).exists() and old_log_files(root):
        # A seed here would leave nothing for the merge to fill: the old files go in first.
        print(f"{LOG} not written: {', '.join(f for f, _ in old_log_files(root))} merge into it "
              "with `jig update --merge-log`, on the owner's yes")
    elif not (root / LOG).exists():
        (root / LOG).write_text(LOG_SEED)
        print(f"wrote {LOG}")
    rc = 0
    if getattr(args, "no_hooks", False):
        print("hooks not installed (--no-hooks). Run `jig install-hooks` to cut over.")
    else:
        rc = cmd_install_hooks(root, args)
    # A metarepo or pararepo is a repo with one more file, so it is made by the same init.
    if getattr(args, "meta", False):
        return cmd_meta_init(root, args)
    if getattr(args, "para", None) is not None:
        args.meta = args.para
        return cmd_para_init(root, args)
    return rc


HOOK = """#!/bin/sh
# jig hook ({dir}/jig.py). Delete to disable; `jig install-hooks` rewrites it.
# Runs TRUNK's copy of the checker, so a branch cannot weaken its own rules.
# git hands pre-push the pushed refs on stdin, once: read here, a chained .local hook
# (git-lfs) and jig each get them, where the first reader would otherwise take them all.
if [ {name} = pre-push ]; then refs=$(cat); fi
feed() {{ if [ {name} = pre-push ]; then printf '%s\n' "$refs" | "$@"; else "$@"; fi; }}
[ -x "$0.local" ] && {{ feed "$0.local" "$@" || exit $?; }}
copy=$(mktemp "${{TMPDIR:-/tmp}}/jig.XXXXXX") || exit 0
git show {trunk}:{dir}/jig.py > "$copy" 2>/dev/null || {{ rm -f "$copy"; exit 0; }}
feed python3 "$copy" hook {name} "$@"
status=$?
rm -f "$copy"
exit $status
"""


HOOKS = ("pre-commit", "pre-merge-commit", "pre-push", "post-checkout", "post-merge",
         "commit-msg")
# ai-dev was jig under its old name, and claude-lane the tool jig grew from: their hooks are
# ours to rewrite, not a predecessor's to keep.
HOOK_MARKERS = ("# jig hook", "# aidev hook", "claude-lane.py")


def git_common() -> Path:
    return Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))


def foreign_hooks() -> list[str]:
    """Hooks in this clone that jig didn't write."""
    hooks = git_common() / "hooks"
    if not hooks.exists():
        return []
    return sorted(h.name for h in hooks.iterdir()
                  if h.is_file() and not h.name.endswith(".sample")
                  and not any(m in h.read_text(errors="replace") for m in HOOK_MARKERS))


def cmd_install_hooks(root: Path, args) -> int:
    # The old board's hooks still work; these would run a trunk .jig/jig.py that isn't there.
    # Update installs them itself, once the board has moved.
    old = old_board(root)
    if old:
        die(f"refused: {old} is an older jig's board, and these hooks would replace its own with "
            f"ones that check nothing. Run `jig update` (then --apply) instead: it installs them", 2)
    trunk = Board.trunk_name(root)
    common = git_common()
    hooks = common / "hooks"
    hooks.mkdir(parents=True, exist_ok=True)
    for name in HOOKS:
        t = hooks / name
        if t.exists() and not any(m in t.read_text(errors="replace") for m in HOOK_MARKERS):
            if getattr(args, "replace", False):
                t.unlink()
                print(f"removed predecessor hook {name}")
            else:
                t.rename(hooks / f"{name}.local")
                print(f"kept existing {name} as {name}.local; it runs first")
        if getattr(args, "replace", False) and (hooks / f"{name}.local").exists():
            (hooks / f"{name}.local").unlink()
            print(f"removed {name}.local")
        t.write_text(HOOK.format(dir=DIR, trunk=trunk, name=name))
        t.chmod(0o755)
    # Opt-in marker for the Claude Code plugin's own hooks. It lives in .git/, which is
    # never cloned or committed, so a repo you fetched cannot enable them for itself.
    (common / "jig").mkdir(exist_ok=True)
    (common / "jig" / "enabled").write_text("jig hooks enabled for this checkout\n")
    print(f"hooks installed in {hooks}")
    return 0


def run_setup(root: Path) -> None:
    """Make this checkout runnable with its own .jig/scripts/setup.sh — the checkout's copy, not
    trunk's: it judges nothing, and must match the files checked out. Its output goes to
    stderr so whoever made the checkout sees it. A failure is reported and fails nothing,
    because the checkout exists either way."""
    # A pararepo's cache of the pinned metarepo docs is gitignored, so a new worktree has none,
    # and a merge of trunk's pin bump leaves it at the old pin. The main checkout's is refilled
    # before that bump is committed, so copying it needs no metarepo.
    cache, main_cache = root / CACHE, main_root() / CACHE
    if (root / PARA).exists() and main_cache.exists() and cache != main_cache:
        try:
            pin = json.loads((root / PARA).read_text()).get("pin")
        except ValueError:
            pin = None
        def at(c: Path) -> str | None:
            return (c / "PIN").read_text().split("\n")[0] if (c / "PIN").exists() else None
        # Copying a cache at some other pin would only trade one stale cache for another.
        if (not cache.exists() or at(cache) != pin) and at(main_cache) == pin:
            shutil.rmtree(cache, ignore_errors=True)
            shutil.copytree(main_cache, cache)
    script = root / DIR / "scripts" / "setup.sh"
    if not script.exists():
        return
    print(f"jig: setting up {root} with {DIR}/scripts/setup.sh", file=sys.stderr)
    # The same script runs from a hook, from sync, or by hand: none of git's hook variables.
    env = {k: v for k, v in os.environ.items()
           if k not in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_PREFIX")}
    cmd = [str(script)] if os.access(script, os.X_OK) else ["bash", str(script)]
    rc = subprocess.run(cmd, cwd=root, env=env, stdout=sys.stderr).returncode
    if rc:
        print(f"jig: {DIR}/scripts/setup.sh exited {rc} in {root}. Fix it, then run it again "
              f"in {root}.", file=sys.stderr)


def cmd_hook(root: Path, args) -> int:
    name = args.name
    # git just brought another commit's files into this checkout: a new worktree (its
    # previous ref is all zeros) or a merge. Neither needs the board.
    if name == "post-merge":
        run_setup(root)
        return 0
    if name == "post-checkout" and args.rest and set(args.rest[0]) == {"0"}:
        run_setup(root)
    try:
        board = Board.load(root)
    except SystemExit:
        return 0
    if name == "post-checkout":
        if board.open_jobs() and is_main_worktree(root):
            b = git("branch", "--show-current")
            if b and b != board.trunk:
                print(f"jig: the {board.trunk} checkout is on {b}. "
                      f"Work in {worktrees_dir()}/{b}.", file=sys.stderr)
        return 0
    meta = load_meta(board.trunk)
    if name == "commit-msg":
        refusals = check_subject(args.rest[0], meta) if meta and args.rest else []
        for r in refusals:
            print(f"jig: {r}", file=sys.stderr)
        return 1 if refusals else 0
    if name == "pre-push":
        # git names what is pushed on stdin: `<local ref> <sha> <remote ref> <sha>`. What goes
        # to the remote's trunk is judged, not the local trunk: `git push origin HEAD:main`
        # from a detached checkout sends a commit the local ref never had.
        pushed = [l.split()[1] for l in (sys.stdin.read().splitlines() if meta else [])
                  if len(l.split()) == 4 and l.split()[2] == f"refs/heads/{board.trunk}"
                  and set(l.split()[1]) != {"0"}]
        problems = []
        for rev in pushed or ([""] if meta else []):
            problems += [p for p in meta_problems(root, meta, board.trunk, rev) if p not in problems]
        for p in problems:
            print(f"jig: refused: {p}", file=sys.stderr)
        return 1 if problems else 0
    if name == "pre-merge-commit":
        global AUTO_MERGE
        AUTO_MERGE = True
    refusals = check_rules(root, board, staged=True)
    for r in refusals:
        print(f"jig: {r}", file=sys.stderr)
    return 1 if refusals else 0


def cmd_status(root: Path, args) -> int:
    board = Board.load(root)
    trunk = board.trunk
    if not board.jobs:
        print("no jobs open")
    else:
        print(f"trunk: {trunk}")
    for name, l in board.jobs.items():
        br = board.branch(name)
        behind = git("rev-list", "--count", f"{br}..{trunk}") or "?"
        wt = main_root() / board.worktree(name)
        dirty = ""
        if wt.exists():
            dirty = " dirty" if git("status", "--porcelain", cwd=str(wt)) else " clean"
        notes = handoff_notes(br, name)
        print(f"  {name:<20} {l.get('state',''):<9} behind:{behind}{dirty}"
              f"  handoffs:{len(notes)}  after:{','.join(l.get('after',[])) or '-'}")
    for k, v in (board.data.get("reserve") or {}).items():
        if isinstance(v, dict) and v.get("pattern"):
            print(f"reserve {k}: next free {next_number(board, k, v)}")
    return 0


def file_safe(name: str) -> str:
    """A job or branch name as one file or folder name. git allows `/` in a branch; the notes
    and the gate's scratch stay flat, so `a/b` and `a-b` share a stem, and a note's header,
    not its file name, says whose it is."""
    return name.replace("/", "-")


def handoff_notes(branch: str, name: str) -> list[str]:
    """The notes a job has filed, read from its branch, oldest first: the record of a handoff
    is the note."""
    # The names `jig handoff` writes: <job>-<date>.md, then -2, -3 the same day. By name alone
    # "-" sorts before ".", putting the day's first note last; and job X-y's notes start "X-".
    note = re.compile(rf"{re.escape(file_safe(name))}-(\d{{4}}-\d{{2}}-\d{{2}})(?:-(\d+))?\.md")
    listing = git("ls-tree", "--name-only", branch, "--", f"{DIR}/handoffs/")
    found = [(m.group(1), int(m.group(2) or 1), n) for n in listing.splitlines()
             if (m := note.fullmatch(Path(n).name))
             and git("show", f"{branch}:{n}").split("\n", 1)[0] == f"# Handoff: {name}"]
    return [n for *_, n in sorted(found)]


def opened(board: "Board", name: str) -> str:
    """The day the job's entry reached trunk. git keeps that, so the record doesn't."""
    # Newest first: a name opened again after a merge has its latest entry.
    days = git("log", "--format=%as", "-S", f'"{name}": {{', board.trunk, "--", JOBS)
    return days.splitlines()[0] if days else ""


def cmd_open(root: Path, args) -> int:
    board = Board.load(root, working_tree=True)
    if git("branch", "--show-current") != board.trunk:
        die(f"open a job from {board.trunk} (the hubnode's checkout)")
    if args.name in board.jobs:
        die(f"job {args.name} already exists")
    if file_safe(args.name).startswith("gate-"):
        die(f"a job name can't start with gate-: worktrees/{file_safe(args.name)} is where "
            f"`jig gate {args.name[5:]}` checks out, and removes when that job is gated")
    # Notes and gate scratch are named file_safe(job): two open jobs sharing that stem would
    # each commit the same note path the same day, an add/add conflict at the second merge.
    twin = [n for n in board.jobs if file_safe(n) == file_safe(args.name)]
    if twin:
        die(f"job {args.name} and open job {twin[0]} share the file name {file_safe(args.name)} "
            "for their handoff notes and gate checkout: pick another name")
    branch = args.branch or args.name
    owns = args.owns or []
    # R4 pre-check: a file another open job already changed is shared, never owned
    conflicts = []
    for p in owns:
        for on in board.open_jobs():
            # A file the job moved away is as much its change as one it edited.
            changed = git("-c", "core.quotePath=false", "diff", "--name-only", "--no-renames",
                          f"{board.trunk}...{board.branch(on)}").splitlines()
            if any(matches(c, [p]) for c in changed):
                conflicts.append(f"{p} (changed by open job {on})")
    if conflicts:
        die("these cannot be owns; put them in shares:\n  " + "\n  ".join(conflicts))

    existing = bool(git("rev-parse", "--verify", "-q", f"refs/heads/{branch}"))
    reserve = {}
    for kv in args.reserve or []:
        k, _, explicit = kv.partition("=")
        spec = (board.data.get("reserve") or {}).get(k)
        if not (isinstance(spec, dict) and spec.get("pattern") and spec.get("files")):
            die(f"counter '{k}' needs a \"pattern\" and \"files\" in reserve.{k} of {CONFIG}: "
                "the pattern is how jig knows which numbers are taken")
        # An adopted branch may already hold a number: it is recorded as held, and held
        # numbers are never handed out again while its job is open.
        reserve[k] = int(explicit) if explicit else next_number(board, k, spec)
        holder = [n for n, l in board.jobs.items() if reserve[k] in held_numbers(l).get(k, ())]
        if holder:
            die(f"{k} {reserve[k]} is held by open job {holder[0]}: one number, one job")
    # A merged job's entry is gone, so a name that isn't open reads as merged to R8: a typo
    # here would never gate anything.
    unknown = [a for a in args.after or [] if a not in board.jobs]
    if unknown:
        die(f"--after names no open job: {', '.join(unknown)}")

    default = f"{worktrees_dir()}/{branch}"
    worktree = args.worktree or default
    state = args.state or ("building" if existing else "claimed")
    record = {"spec": args.spec or "", "state": state, "after": args.after or [],
              "owns": owns, "shares": args.shares or [], "reserved": reserve}
    if branch != args.name:
        record["branch"] = branch
    if worktree != default:
        record["worktree"] = worktree
    board.jobs[args.name] = record
    board.save()

    if not (root / worktree).exists():
        if existing:
            if git("worktree", "list", "--porcelain").find(f"refs/heads/{branch}") >= 0:
                die(f"branch {branch} is checked out somewhere already: pass --worktree <path>")
            add = ["worktree", "add", worktree, branch]
        else:
            add = ["worktree", "add", "-b", branch, worktree, board.trunk]
        # stderr passes through: the post-checkout hook sets the worktree up, and what
        # setup.sh printed, or why it failed, belongs in front of whoever opened the job.
        subprocess.run(["git", *add], stdout=subprocess.DEVNULL)
    verb = "adopted" if existing else "opened"
    print(f"job {args.name} {verb}. worktree: {worktree}  state: {state}")
    if reserve:
        print("reserved: " + ", ".join(f"{k}={v}" for k, v in reserve.items()))
    print(f"\n--- kickoff ---\nJob: {args.name}\nBranch: {branch}\nWorktree: {worktree}\n"
          f"Spec: {args.spec or '(see board)'}\n"
          f"Owns: {', '.join(owns) or '-'}\nShares: {', '.join(args.shares or []) or '-'}\n"
          f"Read {DIR}/RULES.md, then `python3 {DIR}/jig.py check`.")
    return 0


def cmd_reserve(root: Path, args) -> int:
    """Another number for an open job, by the rule `open --reserve` uses: a hand edit of the
    board is checked by nothing, so a number taken that way can collide."""
    board = Board.load(root, working_tree=True)
    if git("branch", "--show-current") != board.trunk:
        die(f"reserve from {board.trunk} (the hubnode's checkout)")
    job = board.jobs.get(args.name)
    if job is None:
        die(f"no open job {args.name}")
    spec = (board.data.get("reserve") or {}).get(args.counter)
    if not (isinstance(spec, dict) and spec.get("pattern") and spec.get("files")):
        die(f"counter '{args.counter}' needs a \"pattern\" and \"files\" in reserve.{args.counter} "
            f"of {CONFIG}: the pattern is how jig knows which numbers are taken")
    n = next_number(board, args.counter, spec)
    reserved = job.setdefault("reserved", {})
    had = reserved.get(args.counter)
    reserved[args.counter] = n if had is None else [*(had if isinstance(had, list) else [had]), n]
    board.save()
    print(f"job {args.name}: {args.counter} {n} reserved. Commit {JOBS} on {board.trunk}.")
    return 0


def gate_scratch(name: str) -> str:
    """Where `jig gate` checks a job out, relative to the primary checkout."""
    return f"{worktrees_dir()}/gate-{file_safe(name)}"


def gate_scratch_problem(where: Path, shown: str) -> str | None:
    """Why the checkout at WHERE can't be removed as gate scratch, or None when it can. The
    gate's checkout is detached; anything on a branch at that path is someone's work. Untracked
    files are setup's (a venv, a build) and go with it."""
    top = git("rev-parse", "--show-toplevel", cwd=str(where))
    if not top or Path(top).resolve() != where.resolve():
        return f"{shown} is not a checkout jig's gate made: look at it, then delete it"
    branch = git("symbolic-ref", "-q", "--short", "HEAD", cwd=str(where))
    if branch:
        return (f"{shown} has branch {branch} checked out, so it isn't a gate's scratch: "
                "jig leaves it alone")
    remove = f"`git worktree remove --force {shown}`"
    if git("rev-parse", "-q", "--verify", "MERGE_HEAD", cwd=str(where)):
        return f"{shown} has a merge in progress: look at it, then {remove}"
    edited = git("diff", "--name-only", "HEAD", cwd=str(where)).splitlines()
    if edited:
        # An install in setup.sh can rewrite a tracked lockfile after a passing check.
        return (f"{shown} has tracked changes ({', '.join(edited[:5])}), from setup.sh or a hand "
                f"edit: copy any edit to the job's branch, then {remove}")
    return None


def remove_checkout(where: Path) -> bool:
    ok = subprocess.run(["git", "worktree", "remove", "--force", str(where)],
                        capture_output=True).returncode == 0
    # A folder deleted by hand leaves git's record; prune it so the next gate and update agree.
    git("worktree", "prune")
    return ok and not where.exists()


def remove_gate_scratch(name: str, why: str) -> None:
    """Remove the job's gate checkout once it is spent. jig made it, so jig removes it: a
    printed remove command was run by nobody."""
    scratch = gate_scratch(name)
    where = main_root() / scratch
    git("worktree", "prune")
    if not where.exists():
        return
    problem = gate_scratch_problem(where, scratch)
    if problem:
        die(f"{problem}, and {why} again")
    if not remove_checkout(where):
        die(f"git couldn't remove {scratch}: `git worktree remove --force {scratch}`, and {why} again")
    print(f"removed the gate's scratch checkout {scratch}")


def cmd_mark(root: Path, args) -> int:
    board = Board.load(root, working_tree=True)
    if args.name not in board.jobs:
        die(f"no job {args.name}")
    if args.state == "merged":
        die(f"a job is merged by `jig merge {args.name}`, which deletes its entry in the merge commit")
    if args.state not in STATES:
        die(f"state must be one of {', '.join(STATES)}")
    if args.state == "gated":
        # Gated means the checks ran: the checkout they ran in is spent.
        remove_gate_scratch(args.name, f"`jig mark {args.name} gated`")
    board.jobs[args.name]["state"] = args.state
    board.save()
    print(f"{args.name}: {args.state}")
    return 0


def cmd_merge(root: Path, args) -> int:
    """Merge a job into trunk and delete its entry in the same commit: trunk never holds a
    merged job, and the merge commit is the record of it."""
    board = Board.load(root, working_tree=True)
    trunk, name = board.trunk, args.name
    if args.number:
        # The conflicted merge's last step before its commit: the ids it brings in get numbers.
        if not git("rev-parse", "-q", "--verify", "MERGE_HEAD"):
            die("no merge in progress: `jig merge <job>` numbers its ids itself")
        if git("diff", "--name-only", "--diff-filter=U"):
            die("resolve and `git add` the conflicted files first")
        for line in number_placeholders(root, trunk) or ["nothing to number"]:
            print(f"numbered {line}" if "→" in line else line)
        return 0
    if not name:
        die("usage: jig merge <job> [-m msg] [--subject ids], or jig merge --number", 2)
    if git("branch", "--show-current") != trunk:
        die(f"merge from {trunk} (the hubnode's checkout)")
    if name not in board.jobs:
        die(f"no job {name}")
    if git("status", "--porcelain", "--untracked-files=no"):
        die("commit or stash first: the merge commit carries the job and its entry, nothing else")
    waiting = [d for d in board.jobs[name].get("after", []) if d in board.jobs]
    if waiting:
        die(f"R8 job {name} builds after {', '.join(waiting)}, which has not merged")
    branch = board.branch(name)
    # The gate checked the commit the latest note names; anything built since is unchecked.
    notes = handoff_notes(branch, name)
    if not notes:
        die(f"{name} has filed no handoff note on {branch}: hand off and gate it first")
    m = re.search(r"^Commit: (\w+)", git("show", f"{branch}:{notes[-1]}"), re.M)
    since = changed_since(m.group(1) if m else branch, branch, board)
    if since:
        die(f"{branch} has changed since the commit {notes[-1]} names ({', '.join(since[:5])}): "
            "hand off again and gate that, or merge the gated commit by hand")
    # A job merged without being marked gated still leaves nothing of its gate behind.
    remove_gate_scratch(name, f"`jig merge {name}`")
    # The subject ends in `merge <job>` either way: the gate's deleted-branch fallback finds
    # the job by it. A caller who already wrote it out isn't given it twice.
    subject = args.subject or ""
    if not re.search(rf"(?:^|: )merge {re.escape(name)}$", subject):
        subject = (f"{subject}: " if subject else "") + f"merge {name}"
    msg = subject + (f"\n\n{args.message}" if args.message else "")
    p = subprocess.run(["git", "merge", "--no-ff", "--no-commit", "-m", msg, branch],
                       capture_output=True, text=True)
    merging = bool(git("rev-parse", "-q", "--verify", "MERGE_HEAD"))
    if p.returncode and not merging:
        die(f"git merge {branch}: {(p.stderr or p.stdout).strip()}")
    conflicted = git("diff", "--name-only", "--diff-filter=U").splitlines()
    appends = [f for f in conflicted if matches(f, append_globs(board))]
    if p.returncode and appends:
        # The gate resolved these the way sync does; by hand on trunk they could come out
        # differently. Sync resolves them in the job and stops on the rest; a job whose only
        # conflicts were appends merges after it with no new handoff.
        git("merge", "--abort")
        die(f"merging {branch} conflicts in append files ({', '.join(appends)}): "
            f"`jig sync` the job, then merge again")
    del board.jobs[name]
    board.save()
    git("add", "--", JOBS, check=True)
    # A branch writes D-?<slug>, so no job waits on the hubnode for a number: they are given
    # here, in the merge commit, where no two branches can take the same one.
    numbered = [] if p.returncode else number_placeholders(root, trunk)
    # R5 keeps the roadmap on trunk, so the Up next items the job built leave it here, in the
    # merge commit, rather than on the branch that built them.
    # A page the job moved is re-pointed in every (touches …) naming it, for the same reason.
    built = built_up_next(git("show", f"{branch}:{notes[-1]}"))
    roadmap = main_root() / ROADMAP
    if roadmap.is_file():
        text = roadmap.read_text()
        kept = retarget_touches(remove_up_next(text, built), page_moves("HEAD"))
        if kept != text:
            roadmap.write_text(kept)
            git("add", "--", ROADMAP, check=True)
            if built & {i["id"] for i in parse_up_next(text)}:
                print(f"removed from {ROADMAP}, built: {', '.join(sorted(built))}")
    # States change when work lands, so the view is rewritten in the merge commit itself.
    snap = Snapshot(where="index")
    phases = None if p.returncode else roadmap_state(snap)
    if phases is not None:
        (main_root() / ROADMAP_VIEW).write_text(roadmap_view(snap, phases))
        git("add", "--", ROADMAP_VIEW, check=True)
    if p.returncode:
        then = f", `jig roadmap --write` and `git add {ROADMAP_VIEW}`" if git("show", f":{ROADMAP}") else ""
        print(f"conflicts merging {branch}; {name}'s entry is already deleted in the index. "
              f"Resolve these, `git add` each{then}, `jig merge --number` (it numbers the job's "
              f"D-?<slug> ids), `git commit`, then run {DIR}/scripts/setup.sh:",
              file=sys.stderr)
        for f in conflicted:
            print(f"  {f}", file=sys.stderr)
        return 1
    commit = ["git", "commit", "-q", "--no-edit"] if merging else \
        ["git", "commit", "-q", "-m", f"{msg}: already in {trunk}, entry deleted"]
    if subprocess.run(commit).returncode:
        print(f"the merge isn't committed. Fix what the hook refused, then `git commit`; or "
              f"`git merge --abort`, which puts {name}'s entry back", file=sys.stderr)
        return 1
    for line in numbered:
        print(f"numbered {line}")
    # git runs post-merge only for a merge it commits itself, not this one.
    run_setup(root)
    print(f"merged {name}; its entry is gone from {JOBS} in the same commit. Sync the clean jobs.")
    return 0


def append_globs(board: "Board") -> list[str]:
    """The board's append files, and the decision log in every repo: any job may add to it,
    so two jobs' entries at one spot are the conflict sync resolves by itself."""
    return [*board.data.get("append_files", []), LOG]


def cmd_check(root: Path, args) -> int:
    board = Board.load(root)
    refusals = check_rules(root, board, staged=args.staged)
    for r in refusals:
        print(r)
    if not refusals:
        print("ok")
    return 1 if refusals else 0


def cmd_job(root: Path, args) -> int:
    board = Board.load(root)
    name, job = board.job_for_branch(git("branch", "--show-current"))
    if not name:
        print("no job for this branch")
        return 1
    print(json.dumps({name: {**job, "branch": board.branch(name), "worktree": board.worktree(name),
                             "opened": opened(board, name)}}, indent=2))
    return 0


# --------------------------------------------------------------- sync + merge

CONFLICT = re.compile(
    r"^<<<<<<< .*?\n(?P<ours>.*?)^\|\|\|\|\|\|\| .*?\n(?P<base>.*?)^=======\n"
    r"(?P<theirs>.*?)^>>>>>>> .*?\n",
    re.S | re.M,
)


def resolve_appends(path: Path) -> bool:
    """Resolve conflicts where both sides only added at the same spot. True if clean."""
    text, ok = resolved_appends(path.read_text())
    path.write_text(text)
    return ok


def resolved_appends(text: str) -> tuple[str, bool]:
    out, pos, ok = [], 0, True
    for m in CONFLICT.finditer(text):
        out.append(text[pos:m.start()])
        if m.group("base").strip() == "":
            out.append(m.group("theirs") + m.group("ours"))  # trunk's lines, then ours
        else:
            ok = False
            out.append(m.group(0))
        pos = m.end()
    out.append(text[pos:])
    return "".join(out), ok


def cmd_sync(root: Path, args) -> int:
    board = Board.load(root)
    trunk = board.trunk
    branch = git("branch", "--show-current")
    name, job = board.job_for_branch(branch)
    # Sync brings in this checkout's upstream: trunk for a job, the metarepo for a pararepo's
    # trunk. A plain repo's or a metarepo's trunk has nothing upstream.
    if not name and branch == trunk and (root / PARA).exists():
        return sync_meta(root)
    if not name:
        die("not on a job branch")
    # Only the merge needs a clean tree; the metarepo step writes only the untracked cache.
    if git("status", "--porcelain"):
        die("commit or stash first: the tree is dirty")
    stuck = merge_trunk(board, root)
    if stuck is None:
        print(f"merged {trunk}; nothing to resolve")
        return 0
    if stuck:
        print(f"resolve by hand, then `git commit` and `./{DIR}/scripts/setup.sh`:", file=sys.stderr)
        for f in stuck:
            print(f"  {f}", file=sys.stderr)
        return 1
    print(f"merged {trunk}; append conflicts resolved automatically")
    return 0


def merge_trunk(board: "Board", here: Path) -> list[str] | None:
    """Merge trunk into the checkout at HERE, resolving append-only conflicts in append_files.
    None: git merged it cleanly. []: resolved and committed. Otherwise the files left for a
    hand, with the merge still in progress."""
    p = subprocess.run(["git", "-c", "merge.conflictStyle=diff3", "merge", "--no-edit", board.trunk],
                       stdout=subprocess.PIPE, text=True, cwd=here)
    if p.returncode == 0:
        return None
    append_files = append_globs(board)
    stuck = []
    for f in git("diff", "--name-only", "--diff-filter=U", cwd=str(here)).splitlines():
        if matches(f, append_files) and resolve_appends(here / f):
            git("add", "--", f, cwd=str(here))
        else:
            stuck.append(f)
    if stuck:
        return stuck
    git("commit", "--no-edit", check=True, cwd=str(here))
    # git runs post-merge only for a merge it finished itself, not this one.
    run_setup(here)
    return []


def git_version() -> tuple[int, ...]:
    m = re.search(r"(\d+)\.(\d+)", git("version"))
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)


def blob(rev: str, path: str) -> str:
    return subprocess.run(["git", "show", f"{rev}:{path}"], capture_output=True, text=True).stdout


def changed_since(commit: str, branch: str, board: "Board") -> list[str]:
    """What a job did after the commit that was checked: the files its own commits changed,
    and what a merge of trunk carries beyond what `jig sync` makes of that merge. Trunk's
    changes aren't the job's, a hand edit hidden in a resolution is, and handoff notes are
    bookkeeping made after the check by design."""
    trunk, appends = board.trunk, append_globs(board)
    out: list[str] = []
    for line in git("rev-list", "--first-parent", "--parents", f"{commit}..{branch}").splitlines():
        c, *parents = line.split()
        if len(parents) > 1 and subprocess.run(["git", "merge-base", "--is-ancestor", parents[1], trunk],
                                               capture_output=True).returncode == 0:
            # Replay the sync: git's merge, then the append rule, compared with what was committed.
            p = subprocess.run(["git", "-c", "merge.conflictStyle=diff3", "merge-tree", "--write-tree",
                                "--name-only", "--no-messages", parents[0], parents[1]],
                               capture_output=True, text=True)
            tree, *conflicted = p.stdout.splitlines() or [""]
            if p.returncode not in (0, 1) or not tree:
                if git_version() < (2, 38):
                    die(f"comparing a synced job needs git 2.38 or later (`git merge-tree "
                        f"--write-tree`); this is git {'.'.join(map(str, git_version()))}")
                # No replay to compare with: everything the merge changed counts as the job's.
                tree, conflicted = parents[0], []
            files = []
            for f in git("-c", "core.quotePath=false", "diff", "--name-only", "--no-renames", tree, c).splitlines():
                if f in conflicted and matches(f, appends):
                    text, ok = resolved_appends(blob(tree, f))
                    if ok and text == blob(c, f):
                        continue
                files.append(f)
        else:
            files = git("-c", "core.quotePath=false", "diff", "--name-only", "--no-renames",
                        parents[0], c).splitlines()
        out += [f for f in files if f and not f.startswith(f"{DIR}/handoffs/") and f not in out]
    return out


# ---------------------------------------------------------- review + handoff

def review_marker(root: Path) -> Path:
    common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
    d = common / "jig" / "reviewed"
    d.mkdir(parents=True, exist_ok=True)
    return d / (git("branch", "--show-current") or "detached").replace("/", "%")


def cmd_reviewed(root: Path, args) -> int:
    """Record that HEAD has had its adversarial review, and what it ran at. Called by the
    review skill."""
    if (args.tier is None) != (args.effort is None):
        die("give --tier and --effort together")
    if args.tier is not None and (args.tier < 1 or args.effort < 0):
        die("tier counts from 1, effort from 0")
    head = git("rev-parse", "HEAD")
    ran = {k: v for k, v in (("tier", args.tier), ("effort", args.effort), ("ran", args.ran))
           if v is not None}
    review_marker(root).write_text(head + "\n" + (json.dumps(ran) + "\n" if ran else ""))
    # Every review ever, for a metarepo's gate: a merge's second parent must be one of them.
    with open(git_common() / "jig" / "reviewed.log", "a") as log:
        log.write(head + "\n")
    print(f"recorded review of {head[:12]}")
    return 0


NOTE = """# Handoff: {job}

Commit: {head}
Date: {today}
Spec: {spec}
{partial}{ran}
## Built
<!-- what this delivers, in a few lines -->

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->

## Review
<!-- findings from the adversarial review, and what you did about each -->

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each roadmap item naming one of those
     pages (an Up next item, or a taken scope) has its own line: keep one answer, built,
     untouched or departed: <why>. An Up next item answered built leaves the roadmap when
     the job merges. The gate refuses an unanswered line. An UNOWNED file has no page
     covering it: add it to docmap in the board, or say why it needs none. -->
{foldin}

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->

## Test by hand
<!-- what a person should click or watch -->

## Left
<!-- what remains on this job -->
"""


def page_sections(text: str) -> list[tuple[str, list[str]]]:
    """A page's `## ` sections in order, each with its lines; what precedes the first is ''.
    Fenced code is skipped, so a page quoting a heading inside ``` doesn't gain a section."""
    out, fence = [("", [])], False
    for line in text.splitlines():
        if line.lstrip().startswith(("```", "~~~")):
            fence = not fence
        m = None if fence else re.match(r"^ {0,3}##[ \t]+(.*?)[ \t#]*$", line)
        if m:
            out.append((m.group(1).strip(), []))
        else:
            out[-1][1].append(line)
    return out


def section_items(lines: list[str]) -> list[str]:
    """The top-level list items of a section, each as its first line without the marker."""
    return [re.sub(r"^[-*+][ \t]+", "", l).strip() for l in lines if re.match(r"^[-*+][ \t]+\S", l)]


# The fold-in line for one roadmap item a change reached. The gate and merge parse it back,
# so a change here changes ITEM_LINE too.
CLIP = 60
ITEM_LINE = re.compile(r'^- \[[ xX]\] (Up next|Scope) `([^`]+)` \(([^()]*)\): "(.*)" — '
                       r'((?:(?!" — ).)*?)\s*$')


def item_answer(answer: str) -> str:
    """Why an item line's answer doesn't count yet, or "" when it does: built, untouched or
    departed (with its why), in any case, and anything after it."""
    a = answer.strip()
    if not a or "___" in a:
        return "blank: keep one of built, untouched, departed: <why>"
    if re.match(r"\w+\s*/", a):
        return "more than one answer kept: keep one"
    word = re.match(r"[A-Za-z]+", a)
    kind = word.group(0).lower() if word else ""
    if kind not in ("built", "untouched", "departed"):
        return "not built, untouched or departed"
    if kind == "departed" and not re.search(r"\w", a[len(kind):]):
        return "departed needs its why"
    return ""


def clip(text: str) -> str:
    return text if len(text) <= CLIP else text[:CLIP].rstrip() + "…"


def roadmap_items(rev: str, states: tuple[str, ...] = ("taken",)) -> list[tuple[str, str, str, list[str]]]:
    """(kind, id, what, pages) for every Up next item, and every scope in STATES, in REV's
    roadmap: the project work that names a page with `(touches …)`."""
    snap = Snapshot(rev)
    text = snap.show(ROADMAP)
    if not text:
        return []
    out = [("Up next", i["id"], i["what"], i["touches"]) for i in parse_up_next(text)]
    for p in roadmap_state(snap) or []:
        for sc in p["scopes"]:
            if sc["state"] in states:
                what, pages = split_touches(sc["what"])
                out.append(("Scope", sc["id"], what, pages))
    return out


def built_up_next(note: str) -> set[str]:
    """The Up next items a handoff note's fold-in answers built."""
    sec = re.search(r"^## Fold-in\n(.*?)(?=^## |\Z)", note, re.S | re.M)
    out = set()
    for l in (sec.group(1).splitlines() if sec else []):
        m = ITEM_LINE.match(l.strip())
        if m and m.group(1) == "Up next" and not item_answer(m.group(5)) \
                and m.group(5).strip().lower().startswith("built"):
            out.add(m.group(2))
    return out


def foldin_lines(root: Path, board: Board, branch: str) -> str:
    """One line per documentation page covering the code this branch changed."""
    trunk = board.trunk
    base = trunk if branch and branch != trunk else "HEAD~1"
    rng = f"{trunk}...HEAD" if base == trunk else "HEAD~1..HEAD"
    # Both sides of a rename: the page that covered the old path describes it there.
    changed = [f for f in git("-c", "core.quotePath=false", "diff", "--name-only", "--no-renames",
                              rng).splitlines()
               if f and not f.startswith((".", f"{DIR}/"))]
    at_head = set(git("-c", "core.quotePath=false", "ls-tree", "-r", "--name-only", "HEAD").splitlines())
    # A file docmap names is asked about whatever its type (sdkconfig, a devicetree
    # overlay); only source files are flagged when no page covers them.
    pages, unowned = {}, []
    for f in changed:
        owners = [page_in(p, at_head) for p in doc_owners(board, f)]
        for page in owners:
            pages.setdefault(page, []).append(f)
        if not owners and f.endswith(SRC_EXT) and f in at_head:
            unowned.append(f)
    cited = decision_citers(root, trunk, rng)
    pairs = pair_lines(root, trunk, rng)
    if not pages and not unowned and not cited and not pairs:
        return "- [ ] no code changed — nothing to fold in"
    out = []
    for page in sorted(set(pages) | set(cited)):
        fs, ids = pages.get(page, []), cited.get(page, [])
        why = ([f"{len(fs)} file{'s' if len(fs) > 1 else ''}"] if fs else []) + ids
        out.append(f"- [ ] {page} — updated / no change because ___   ({', '.join(why)})")
    # Project work that names a page this change reached asks whether the change built it.
    # A page asked only for a decision it cites changed no code, so built nothing.
    asked: dict[tuple[str, str, str], list[str]] = {}
    for kind, iid, what, touches in roadmap_items(trunk):
        hit = [page for page in sorted(pages) if any(same_page(t, page) for t in touches)]
        if hit:
            asked[(kind, iid, what)] = hit
    out += [f'- [ ] {kind} `{iid}` ({", ".join(hit)}): "{clip(what)}" — built / untouched / departed: ___'
            for (kind, iid, what), hit in asked.items()]
    out += [f"- [ ] UNOWNED {f} — add to docmap (a new page starts from {DIR}/docs-page.md), "
            "or no page needed because ___"
            for f in sorted(unowned)]
    return "\n".join(out + pairs)


def cmd_handoff(root: Path, args) -> int:
    board = Board.load(root)
    branch = git("branch", "--show-current")
    name, job = board.job_for_branch(branch)
    if not name:
        name = branch or "work"          # solo: no job, the branch is the unit
    if git("status", "--porcelain"):
        die("commit everything first: a handoff names one commit")
    head = git("rev-parse", "HEAD")
    marker = review_marker(root)
    lines = marker.read_text().splitlines() if marker.exists() else []
    if not lines or lines[0].strip() != head:
        die("no adversarial review on record for this commit.\n"
            f"  Review {head[:12]}, then: python3 {DIR}/jig.py reviewed")
    (root / DIR / "handoffs").mkdir(parents=True, exist_ok=True)
    # handoff_notes reads these names back in order; a change here changes its pattern.
    path = root / DIR / "handoffs" / f"{file_safe(name)}-{date.today().isoformat()}.md"
    i = 2
    while path.exists():
        path = root / DIR / "handoffs" / f"{file_safe(name)}-{date.today().isoformat()}-{i}.md"
        i += 1
    ran = json.loads(lines[1]) if len(lines) > 1 and lines[1].strip() else {}
    # The roadmap matches a note to its spec by path from the repo root, so that is what is
    # written; a job's spec on the board stands in for a bare `jig handoff`.
    spec = args.spec or (job or {}).get("spec") or ""
    if spec:
        at = (Path.cwd() / spec).resolve()
        if not at.is_relative_to(root.resolve()):
            die(f"--spec {spec} is outside this repo: give the spec's path in it")
        spec = at.relative_to(root.resolve()).as_posix()
    # jig gate reads the Review line back against the spec's Workflow section.
    ran_lines = (f"Review: tier {ran['tier']}, effort {ran['effort']}\n" if "tier" in ran
                 else "Review: tier and effort not recorded\n")
    if ran.get("ran"):
        ran_lines += f"Ran: {ran['ran']}\n"
    path.write_text(NOTE.format(job=name, head=head, today=date.today().isoformat(),
                                spec=spec or "(none)", ran=ran_lines,
                                partial="Partial: yes\n" if args.partial else "",
                                foldin=foldin_lines(root, board, branch)))
    print(f"wrote {path.relative_to(root)}")
    if job is not None:
        print("Fill every heading, commit it, then tell the hubnode the job and the commit.")
    else:
        print(f"Fill every heading, commit it, then: python3 {DIR}/jig.py gate")
    return 0


def cmd_reading_list(root: Path, args) -> int:
    """Given the files a task will touch, print the docmap pages to read first."""
    board = Board.load(root)
    want, unowned = [], []
    for pattern in args.paths:
        hits = [f for f in tracked(root) if matches(f, [pattern])] or [pattern]
        for f in hits:
            # A docmap key names the page in either form; list the one on disk.
            owners = [q for p in doc_owners(board, f)
                      if (q := next((g for g in page_forms(p) if (root / g).exists()), ""))]
            want += [p for p in owners if p not in want]
            if not owners and f.endswith(SRC_EXT):
                unowned.append(f)
    print("Read first:")
    for core in ("AGENTS.md", f"{DIR}/RULES.md"):
        if (root / core).exists():
            print(f"  {core}")
    # A subsystem's page names only its own files in docmap, so its system page, where the
    # shared facts live, is reached by the docs tree, not the globs.
    have = set(tracked(root))
    deep = board.data.get("deep_subsystems")
    deep = deep if isinstance(deep, dict) else {}
    shown: set[str] = set()
    # A flat page in a system's folder is that system's, so it climbs like any part. A seam's
    # page lives in the nearest folder both its systems share, docs/ for two, with none above.
    named = named_pages(board.data)
    flat = frozenset(p for p in want if flat_page(
        p, have, named, lambda f: (root / f).read_text(errors="replace")))
    # The project work naming a page is the context a page itself never carries.
    items = roadmap_items("HEAD", ("open", "taken"))

    def show(page: str, line: str) -> None:
        """Print PAGE once, wherever it first appears, with the items that name it."""
        if page in shown:
            return
        print(line)
        shown.add(page)
        for kind, iid, what, touches in items:
            if any(same_page(t, page) for t in touches):
                print(f"      {kind.lower()} `{iid}`: {what}   ({ROADMAP})")
    for page in want:
        show(page, f"  {page}")
        for up, below in pages_above(page, have, deep, flat):
            # a page that covers a named file needs no reason to be listed
            show(up, f"  {up}" if up in want else f"  {up}   (parent of {below})")
    if not want:
        print("  (no documentation page covers these files)")
    if unowned:
        print("\nNot covered by any page — the work may be undocumented:")
        for f in sorted(set(unowned)):
            print(f"  {f}")
    return 0


def review_shortfall(root: Path, branch: str, name: str, note: str) -> str:
    """What the note's review fell short of in the spec's Workflow section, or "". A warning
    for now: it becomes a refusal only if weak reviews keep reaching the gate."""
    # The board's spec before the note's, and trunk's copy before the branch's, so a branch
    # can't edit what it is judged by. Only a spec trunk lacks (solo work) is read from the
    # branch.
    trunk_board = Board.load(root)
    m = re.search(r"^Spec: (\S+)", note, re.M)
    paths = [(trunk_board.jobs.get(name) or {}).get("spec") or "", m.group(1) if m else ""]
    text = ""
    for path in filter(None, paths):
        text = git("show", f"{trunk_board.trunk}:{path}") or git("show", f"{branch}:{path}")
        if text:
            break
    sec = re.search(r"^## Workflow\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    asked = re.search(r"\breview: tier (\d+), effort (\d+)", sec.group(1)) if sec else None
    if not asked:
        return ""
    want = f"the spec asks for tier {asked.group(1)}, effort {asked.group(2)}"
    got = re.search(r"^Review: tier (\d+), effort (\d+)", note, re.M)
    if not got:
        return f"the review's tier and effort are not recorded; {want}"
    if int(got.group(1)) > int(asked.group(1)) or int(got.group(2)) > int(asked.group(2)):
        return f"review ran at tier {got.group(1)}, effort {got.group(2)}; {want}"
    return ""


def cmd_gate(root: Path, args) -> int:
    """Hubnode-side verification. Prints what to run; refuses what it can decide."""
    board = Board.load(root, working_tree=True)
    trunk = board.trunk
    name = args.name or git("branch", "--show-current") or trunk
    job = board.jobs.get(name)
    if args.name and job is None:
        die(f"no job {args.name}")
    bad = []
    for dep in (job or {}).get("after", []):
        if dep in board.jobs:
            bad.append(f"R8 job {name} builds after {dep}, which has not merged")
    branch = board.branch(name) if job is not None else name
    notes = handoff_notes(branch, name)
    if not notes:
        bad.append(f"{name} has filed no handoff note on {branch}: run `jig handoff`")
    for b in bad:
        print(b, file=sys.stderr)
    if bad:
        return 1
    note = notes[-1]
    body = git("show", f"{branch}:{note}")
    sec = re.search(r"^## Fold-in\n(.*?)(?=^## )", body, re.S | re.M)
    if sec:
        # checklist items only — the instructions above them contain ___ by design
        open_lines = [l for l in sec.group(1).splitlines()
                      if l.strip().startswith("- [")
                      and (l.strip().startswith("- [ ]") or "___" in l)]
        # Each item line needs one answer; anything after it is the answerer's to say.
        for l in sec.group(1).splitlines():
            u = ITEM_LINE.match(l.strip())
            if u and l not in open_lines and (why := item_answer(u.group(5))):
                open_lines.append(f"{l.strip()}   <- {why}")
        for l in sec.group(1).splitlines():
            if l not in open_lines and (why := pair_problem(l)):
                open_lines.append(f"{l.strip()}   <- {why}")
        # Code a registered board page covers runs on that board: "no page needed" is not an
        # answer for it. The note's UNOWNED line predates the board's docmap entry (trunk's,
        # read here), or was written by hand. An unregistered page has no such teeth.
        docmap = board.data.get("docmap") or {}
        for l in sec.group(1).splitlines():
            u = re.search(r"UNOWNED (.+?) — .*no page needed", l, re.I)
            if not u or l in open_lines:
                continue
            for page in board_pages(board.data):
                if matches(u.group(1), page_globs(docmap, page)):
                    open_lines.append(f"{l.strip()}   <- {page} is a board page covering it: "
                                      "code that runs on a board needs its page")
        if open_lines:
            print(f"the fold-in in {note} is unanswered:", file=sys.stderr)
            for l in open_lines[:10]:
                print(f"  {l.strip()}", file=sys.stderr)
            return 1
        # A job's built items leave the roadmap in its merge commit; solo work on trunk has no
        # merge, so they leave in a commit of their own before the gate passes.
        if job is None and branch == trunk:
            left = built_up_next(body) & {i["id"] for i in parse_up_next(at_rev(trunk, ROADMAP))}
            if left:
                print(f"{note} answers built for {', '.join(sorted(left))}, still under "
                      f"## {UP_NEXT} in {ROADMAP}: delete each item on {trunk} and commit, then "
                      "gate again", file=sys.stderr)
                return 1
    m = re.search(r"^Commit: (\w+)", body, re.M)
    commit = m.group(1) if m else branch
    unpaged = board_refusals(board.data, trunk, commit)
    if unpaged:
        for u in unpaged:
            print(u, file=sys.stderr)
        return 1
    para = load_para(trunk)
    if para is not None:
        spec = re.search(r"^Spec: (\S+)", body, re.M)
        unready = unreleased_proposals(root, para, trunk, commit,
                                       [(job or {}).get("spec") or "", spec.group(1) if spec else ""])
        if unready:
            for u in unready:
                print(u, file=sys.stderr)
            return 1
    label = f"job {name}" if job is not None else name
    print(f"{label}: gate {commit[:12]} from {note} on {branch}")
    weak = review_shortfall(root, branch, name, body)
    if weak:
        print(f"warning: {weak}", file=sys.stderr)
    # The commit the note names, never the job's live worktree, which may have moved on; and
    # trunk merged in the way `jig sync` merges it, so the gate checks the merge a sync makes.
    scratch = gate_scratch(name)
    where = main_root() / scratch
    # A gate whose checks failed is gated again after a new handoff, with no mark between.
    remove_gate_scratch(name, f"`jig gate {name}`")
    subprocess.run(["git", "worktree", "add", "--detach", str(where), commit], stdout=subprocess.DEVNULL)
    if not where.exists():
        die(f"git worktree add {scratch} {commit[:12]} failed")
    try:
        stuck = merge_trunk(board, where)
    except SystemExit:
        # The merge failed without conflicts; the checkout holds nothing of anyone's.
        if not remove_checkout(where):
            print(f"jig: remove the checkout: git worktree remove --force {scratch}", file=sys.stderr)
        raise
    if stuck:
        # Nothing in it is anyone's: the half-done merge is jig's own.
        gone = remove_checkout(where)
        print(f"merging {trunk} into {scratch} needs a hand in {', '.join(stuck)}: the job resolves "
              f"that by `jig sync` and hands off again. "
              + ("The checkout is removed." if gone else
                 f"Remove the checkout: git worktree remove --force {scratch}"), file=sys.stderr)
        return 1
    # Pairs are found at handoff against the trunk of then; a job merged since may rule on the
    # same page, and the merge here is where the two first meet.
    unmet = gate_pairs(where, trunk, sec.group(1) if sec else "")
    if unmet:
        gone = remove_checkout(where)
        print(f"{trunk} moved since the handoff, and the note doesn't answer these pairs: "
              f"`jig sync`, then hand off again" + ("." if gone else
              f". Remove the checkout: git worktree remove --force {scratch}"), file=sys.stderr)
        for l in unmet:
            print(f"  {l}", file=sys.stderr)
        return 1
    print(f"{scratch} holds {commit[:12]} with {trunk} merged in. Run the project checks there; "
          "jig never runs them:\n")
    # As the hooks run it: itself when executable (any language), through bash when not.
    check = f"./{DIR}/scripts/check.sh"
    # A subshell: a shell left inside the checkout would sit in a deleted folder once it's removed.
    print(f"  (cd {scratch} && {'' if os.access(where / check, os.X_OK) else 'bash '}{check})")
    print()
    if job is not None:
        print(f"Then: jig mark {name} gated, which removes {scratch}, and on the owner's word: "
              f"jig merge {name}")
    else:
        # No job, no state change to hang the removal on.
        print("Then merge it, and remove the checkout (no job: solo work, so there is no board "
              f"state to mark):\n  git worktree remove --force {scratch}")
    return 0



# --------------------------------------------------------------------- survey

# The vendor documents a page leans on (datasheets, a dev board's spec sheet, app notes) sit in
# a folder of this name inside the page's folder; one two pages use sits in the datasheets/ of
# the nearest folder both share, docs/datasheets/ at the top: a per-page copy would drift.
# Reserved at any depth: never a subsystem, never a page's home.
DATASHEETS = "datasheets"
# The layout before boards were systems: pages at docs/hardware/<board>.md, a board's files in
# docs/hardware/<board>/, parts in docs/hardware/components/<part>/. Read only to say where each
# file goes now; nothing writes there.
OLD_BOARDS = "docs/hardware/"
OLD_PARTS = f"{OLD_BOARDS}components/"
# Board-build files, by name. A branch adding or changing one builds for a board, and a board
# has a page: the gate refuses one no registered board page's docmap covers. /jig:init also
# reads a main/ with C as firmware, which no file name can say, so this list is the gate's own.
BOARD_BUILD = ("sdkconfig*", "platformio.ini", "idf_component.yml", "west.yml", "*.ino", "*.overlay")
# Where each kind of document lives: a file by name, a folder by its trailing "/".
DOC_HOMES = {
    "AGENTS.md": "rules, always loaded",
    "CLAUDE.md": "pointer to AGENTS.md",
    "README.md": "for people outside",
    "ROADMAP.md": f"with a {DIR}/roadmap.md, its view, generated by `jig roadmap --write`",
    "docs/": f"what the code is now: docs/<system>.md each system, a board as much as any, docs/<system>/<subsystem>.md its subsystems one level down (deeper only where {CONFIG} deep_subsystems approves it); a page holding other files moves into a folder named for it, docs/<system>/<system>.md, beside the files it links; any other file there has no home",
    f"docs/…/{DATASHEETS}/": "the vendor documents a page leans on, in that page's folder; one two pages use, in the nearest folder both share",
    f"docs/{DATASHEETS}/": "a vendor document two systems use: reference files only, never a page",
    f"{DIR}/specs/": "a task in flight",
    f"{DIR}/ledgers/": "WORKAROUNDS.md patches that are in the code; DEFERRED.md review findings that are not",
    f"{DIR}/staging/": "chat-born files waiting to be resolved (untracked)",
}
# Tooling directories, jig's own among them. Their contents are a tool's own records, not
# documents looking for a home, so the stray check skips them entirely.
TOOL_DIRS = (f"{DIR}/", ".claude/", ".github/", ".gitlab/", ".vscode/", ".devcontainer/")
SRC_EXT = (".c", ".h", ".cpp", ".ino", ".rs", ".ts", ".tsx", ".js", ".jsx", ".py", ".go", ".swift")
CODE_EXT = SRC_EXT + (".sh", ".cmake", ".kconfig")


def tracked(root: Path) -> list[str]:
    return [p for p in git("ls-files").splitlines() if p]


def naming(root: Path, path: str, files: list[str]) -> dict[str, list[int]]:
    """The tracked files that name PATH, each with its line numbers: by path, or by bare name
    when no other tracked file has that name, since a bare `AGENTS.md` could mean any of them.
    A match needs a path boundary on both sides, so `ui.md` is not `touch_ui.md` and
    `docs/ui.md` is not `app/docs/ui.md`; a leading `./` or `../` still counts.
    A handoff records what was true then, and jig's own files define the names, so neither cites."""
    base = Path(path).name
    pats = [path] + ([base] if base != path and [Path(f).name for f in files].count(base) == 1 else [])
    bound = re.compile(r"(?:(?<![\w./-])|(?<=\./))(?:" + "|".join(map(re.escape, pats)) + r")(?![\w/-])")
    # -I: a datasheet or firmware image that happens to hold the bytes is no citation. Any
    # tracked text may be in any encoding, so the lines are decoded leniently.
    hits = subprocess.run(["git", "grep", "-I", "-n", "-F", "--null",
                           *[a for p in pats for a in ("-e", p)], "--", "."],
                          capture_output=True, cwd=root).stdout.decode(errors="replace")
    out: dict[str, list[int]] = {}
    for hit in hits.splitlines():
        f, line, text = (hit.split("\0", 2) + ["", ""])[:3]
        if (not line.isdigit() or f == path or "/handoffs/" in f"/{f}"
                or f in (*TOOL_FILES, CONFIG, JOBS) or not bound.search(text)):
            continue
        out.setdefault(f, []).append(int(line))
    return out


def inbound(root: Path, path: str, files: list[str]) -> int:
    return len(naming(root, path, files))


# A root CHANGELOG.md is a home until `jig update` merges it into .jig/decisions.md.
ROOT_DOCS = ("AGENTS.md", "CLAUDE.md", "GEMINI.md", "README.md", "CHANGELOG.md")
# Agent instruction files under their standard names. Off root, each is a second rulebook
# that an agent opening that folder may load in place of the real one.
RULES_NAMES = ("AGENTS.md", "CLAUDE.md", "GEMINI.md")
# The page shape jig used before the descriptive contract: a page with all three is in it.
PAGE_HEADS = re.compile(r"^ {0,3}#{1,6}[ \t]+(Now|Rules|Checks)\b", re.M)
# Sections only the page contract has, so a file carrying one is a page wherever it sits.
CONTRACT_HEADS = re.compile(r"^ {0,3}##[ \t]+(Invariants|Undefined)[ \t#]*$", re.M)


def old_contract(text: str) -> bool:
    return set(PAGE_HEADS.findall(text)) == {"Now", "Rules", "Checks"}


def page_problems(text: str) -> list[str]:
    """What a page at home does against the page contract (RULES.md, Documentation)."""
    if old_contract(text):
        return ["old contract — convert: Now / Rules / Checks; fold what it says into "
                "description, delete what no longer holds, keep as Invariants only what has a "
                "why and a holder"]
    out, secs = [], page_sections(text)
    lead = [l.strip() for l in secs[0][1] if l.strip() and not l.lstrip().startswith("<!--")]
    # The title is the page's one `# ` line; whatever follows it first is the lead, or isn't.
    if lead and lead[0].startswith("# "):
        lead = lead[1:]
    if not lead or lead[0].startswith("#"):
        out.append("no lead paragraph: open with what the system is and why it exists")
    for name, lines in secs:
        if name == "Invariants":
            for item in section_items(lines):
                if " — " not in item or "held by" not in item.lower():
                    out.append(f'invariant without a why (" — ") or a holder ("held by"): {clip(item)}')
    return out


# Headings that hold the project on a product page, and where what is under each goes.
def project_heads() -> dict[str, str]:
    built = f"what is built → the body, in the present tense; what isn't → {ROADMAP}"
    return {"undefined": f"parked work → an item under ## {UP_NEXT} in {ROADMAP} naming this page; "
                         f"an open question → an ## Open entry in {LOG}",
            "status": built, "current state": built, "roadmap": ROADMAP}


# Prose naming the project's plan: a hook can't judge it, since "phase" has product meanings
# too, so survey lists it for a person.
PROJECT_PROSE = re.compile(r"(?i)\b(?:spec\s+(?:phase|step)\s+\d+|phases?\s+\d+(?:\s*(?:and|,|-|–)\s*\d+)*)\b")


def project_sections(text: str) -> list[str]:
    heads = project_heads()
    return [f"## {name} is the project's: {heads[name.lower()]}"
            for name, _ in page_sections(text)[1:] if name.lower() in heads]


def project_prose(text: str, sids: list[str] = ()) -> list[str]:
    """Lines naming the plan, outside fenced code: a phase or a spec's step in prose, a spec,
    handoff or roadmap path, or a scope id SIDS holds, quoted or not."""
    out, fence = [], False
    finds = [PROJECT_PROSE, PLAN_PATHS, *scope_bare(list(sids))]
    for n, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith(("```", "~~~")):
            fence = not fence
        elif not fence:
            out += [f'line {n}: "{m.group(0)}" names the plan: say what the product does today, '
                    f"and leave when to {ROADMAP}" for r in finds for m in r.finditer(line)]
    return out


def sentences(text: str) -> set[str]:
    """Prose sentences long enough that a match is a copy, not a common phrase."""
    flat = re.sub(r"\s+", " ", text)
    return {s.strip() for s in re.split(r"(?<=[.!?])\s+(?=[A-Z`*-])", flat) if len(s.strip()) > 25}


def reference_file(path: str, have: set[str] | None = None) -> bool:
    """Under a datasheets/ folder: a vendor's document, never a page. Given HAVE, only where
    RULES.md homes one, in a page's folder or at docs/datasheets/: an orphan datasheets/ folder
    is reported, not invisible. Without HAVE, any datasheets/ folder under docs/, which is
    enough to say a file is no page."""
    parts = path.split("/")
    if parts[0] != "docs" or DATASHEETS not in parts[1:-1]:
        return False
    if have is None:
        return True
    i = parts.index(DATASHEETS, 1)
    return i == 1 or bool(folder_owner("/".join(parts[:i]), have))


def reserved_page(path: str) -> bool:
    """A page named for a folder called datasheets: a system or subsystem under the reserved
    name, which would be read as reference files."""
    parts = path.split("/")
    return parts[0] == "docs" and len(parts) >= 3 and parts[-2] == DATASHEETS == Path(path).stem


def old_board_rows(files: list[str], read) -> list[dict]:
    """Every file in the old docs/hardware/ layout, as {path, to, board, why}: a page to
    docs/<board>.md, or docs/<board>/<board>.md when files go with it (BOARD: its boards entry); a board's files into that folder, its
    vendor PDFs into the folder's datasheets/; a part's files into the datasheets/ of the one
    board page that links the part, or docs/datasheets/ when two do, or none. A part's folder
    goes: a datasheet is a file in a page's datasheets/. Two files bound for one place, or one
    bound for a file already there, are named for where they came from (the part, the board).
    TO is None, and WHY says so, for a file with no one place to go: the owner places it."""
    pages = [f for f in files if f.startswith(OLD_BOARDS) and f.endswith(".md")
             and "/" not in f[len(OLD_BOARDS):]]
    users = {}
    for page in pages:
        for t in link_targets(page, read(page)):
            if t.startswith(OLD_PARTS) and "/" in t[len(OLD_PARTS):]:
                users.setdefault(t[len(OLD_PARTS):].split("/")[0], set()).add(Path(page).stem)
    rows = []
    for f in (f for f in files if f.startswith(OLD_BOARDS)):
        rest, to, board, why, origin = f[len(OLD_BOARDS):], None, False, "", ""
        if f in pages:
            to, board = f"docs/{Path(f).stem}/{Path(f).stem}.md", True
            if to == f:
                to, board, why = None, False, "the old layout's own index, not a board: fold it in or drop it"
        elif f.startswith(OLD_PARTS):
            origin = f[len(OLD_PARTS):].split("/")[0]
            who = sorted(users.get(origin, ()))
            to = (f"docs/{who[0]}/{DATASHEETS}/" if len(who) == 1 else f"docs/{DATASHEETS}/") + Path(f).name
        elif "/" in rest:
            origin = rest.split("/", 1)[0]
            if f"{OLD_BOARDS}{origin}.md" not in pages:
                why = f"{OLD_BOARDS}{origin}/ has no board page beside it: place it by hand"
            elif f.lower().endswith(".pdf"):
                to = f"docs/{origin}/{DATASHEETS}/{Path(f).name}"
            else:
                to = f"docs/{rest}"
        else:
            why = "names no board: place it by hand"
        rows.append({"path": f, "to": to, "board": board, "fold": False, "why": why, "origin": origin})
    # A page is flat until it holds another file (RULES.md, Documentation).
    for r in (r for r in rows if r["board"]):
        d = os.path.dirname(r["to"])
        if not any(o["to"] and o["to"].startswith(f"{d}/") for o in rows if o is not r):
            r["to"] = f"{d}.md"
    there = {f for f in files if not f.startswith(OLD_BOARDS)}
    for r in (r for r in rows if r["board"] and set(page_forms(r["to"])) & there):
        r["to"], r["board"], r["why"] = None, False, f"{page_in(r['to'], there)} is there already: fold the two by hand"
    for _ in range(2):
        bound = {}
        for r in rows:
            if r["to"]:
                bound.setdefault(r["to"], []).append(r)
        for to, rs in bound.items():
            if len(rs) < 2 and to not in there:
                continue
            for r in (r for r in rs if not r["board"]):
                if r["origin"] and not Path(to).name.startswith(f"{r['origin']}-"):
                    r["to"] = f"{os.path.dirname(to)}/{r['origin']}-{Path(to).name}"
                else:
                    r["to"], r["why"] = None, f"would land on {to}, which another file takes: place it by hand"
    for r in rows:
        del r["origin"]
    return rows


# A metarepo's docs tree has one level more than a code repo's: docs/<genre>/<page>, where a
# genre categorizes the ecosystem it defines (RULES.md, Metarepo and pararepos). None in a code
# repo; in a metarepo, the genres meta.json declares, or () when any folder under docs/ is one.
# Set from the repo once, by doc_homes, so the tree helpers below read one layout throughout.
GENRES: tuple[str, ...] | None = None
# `jig init --meta --genres product-ecosystem`: the categories an ecosystem's definition takes.
GENRE_TEMPLATES = {"product-ecosystem": ("products", "features", "principles", "concepts")}


def load_genres(root: Path) -> None:
    global GENRES
    GENRES = None
    if (root / META).exists():
        try:
            g = json.loads((root / META).read_text() or "{}").get("genres")
        except (ValueError, AttributeError):
            g = None
        GENRES = tuple(x for x in g if isinstance(x, str)) if isinstance(g, list) else ()


def genre_level(d: str) -> bool:
    """docs/<x> in a metarepo: a genre's place, which holds pages but is no page's folder."""
    return GENRES is not None and d.startswith("docs/") and d.count("/") == 1


def genre_dir(d: str) -> bool:
    """A metarepo's genre folder, declared, or any when meta.json declares none."""
    return genre_level(d) and (not GENRES or d[len("docs/"):] in GENRES)


def page_root(d: str) -> bool:
    """Where a top-level page sits flat: docs/ in a code repo, a genre folder in a metarepo."""
    return genre_dir(d) if GENRES is not None else d == "docs"


def old_layout(path: str) -> bool:
    """Under docs/hardware/, the layout before boards were systems. In a metarepo that folder
    is a genre like any other."""
    return GENRES is None and path.startswith(OLD_BOARDS)


def folder_page(path: str) -> bool:
    """docs/<...>/<name>/<name>.md: a page named for its folder, the shape of a page that holds
    other files. A page with nothing else to hold is flat (flat_page)."""
    parts = path.split("/")
    return (parts[0] == "docs" and len(parts) >= 3 and parts[-2] == Path(path).stem
            and not reference_file(path))


def page_shaped(text: str) -> bool:
    """Sections only a page has, in the contract's shape or the old one."""
    return old_contract(text) or bool(CONTRACT_HEADS.search(text))


def flat_spot(path: str, have: set[str]) -> bool:
    """Where a flat page can sit: directly in docs/, or beside the page of the folder it is in.
    Nothing in the path tells such a page from a note beside it; flat_page says which."""
    parent, name = os.path.dirname(path), os.path.basename(path)
    return (path.startswith("docs/") and path.endswith(".md") and not folder_page(path)
            and not reference_file(path) and not old_layout(path)
            and name not in RULES_NAMES and Path(path).stem != DATASHEETS
            and (page_root(parent) or bool(folder_owner(parent, have))))


def flat_page(path: str, have: set[str], docmap, read) -> bool:
    """docs/<name>.md or docs/<...>/<name>.md: a page with no folder of its own, which the
    board names (DOCMAP: named_pages) or its own sections make a page. Any other file there is
    one of its folder page's. A genre has no page, so a file directly in it is a page."""
    return flat_spot(path, have) and (path in docmap or genre_dir(os.path.dirname(path))
                                      or page_shaped(read(path)))


def page_folder(path: str) -> str:
    """The folder a page stands for, which the depth rule counts: docs/a/b for docs/a/b/b.md
    and for a flat docs/a/b.md alike."""
    return os.path.dirname(path) if folder_page(path) else path[:-len(".md")]


def folder_owner(d: str, have: set[str]) -> str:
    """The page that folder D stands for, in either form: d/<name>.md, or d.md still flat
    beside the folder it has started to fill (survey says to move it in). Empty for none."""
    name = os.path.basename(d)
    if name == DATASHEETS or "/" not in d or genre_level(d):
        return ""
    return next((p for p in (f"{d}/{name}.md", f"{d}.md") if p in have), "")


def page_forms(path: str) -> tuple[str, ...]:
    """A docs page's two forms, flat and in its folder: one page, whichever the tree holds.
    docmap keys and boards entries name it in either, so a branch can grow the folder with a
    git mv alone, since config.json is trunk's (R5)."""
    if not (path.startswith("docs/") and path.endswith(".md")) or reference_file(path):
        return (path,)
    d = page_folder(path)
    return (f"{d}.md", f"{d}/{os.path.basename(d)}.md")


def same_page(a: str, b: str) -> bool:
    return a in page_forms(b)


def page_in(path: str, have) -> str:
    """The form of page PATH that HAVE holds, PATH itself when it holds neither."""
    return next((f for f in page_forms(path) if f in have), path)


def page_globs(docmap: dict, page: str) -> list[str]:
    """Every glob docmap gives PAGE, under a key in either of its forms."""
    return [g for k, gs in docmap.items() if same_page(k, page) and isinstance(gs, list) for g in gs]


def owner_page(path: str, have: set[str], deep: dict) -> str:
    """The page whose folder PATH sits in, nearest first: its own folder's page holds the
    files it links. Empty when no folder above PATH has a page."""
    parts = path.split("/")
    for i in range(len(parts) - 1, 1, -1):
        d = "/".join(parts[:i])
        if (page := folder_owner(d, have)) and depth_ok(d, deep):
            return page
    return ""


def pages_above(page: str, have: set[str], deep: dict,
                flat: frozenset[str] = frozenset()) -> list[tuple[str, str]]:
    """Each page above PAGE in the docs tree, nearest first, as (page above, page below it).
    A page named for its folder climbs, and a flat page in FLAT; any other docmap key, a file
    outside the docs tree, has no page above it. A seam's page sits in the folder its two
    systems share, so what is above it is above both."""
    out, below = [], page
    while ((folder_page(below) or below in flat)
           and (up := owner_page(page_folder(below), have, deep))):
        out.append((up, below))
        below = up
    return out


def depth_ok(folder: str, deep: dict) -> bool:
    """A docs folder may hold a page: docs/<system> and docs/<system>/<subsystem> always, each
    level below that only with the owner's rationale in config.json's deep_subsystems. The key
    is trunk-only (R5), so the agent proposing a level can't approve it. Every level needs its
    own entry: approving docs/a/b/c says nothing about docs/a/b/c/d."""
    return not unapproved(folder, deep)


def unapproved(folder: str, deep: dict) -> list[str]:
    """Each level of FOLDER below a subsystem that deep_subsystems doesn't approve."""
    parts = folder.split("/")
    if parts[0] != "docs":
        return []
    # A genre adds no depth: its pages are systems, as docs/<system> is in a code repo.
    first = 4 if GENRES is None else 5
    return [d for i in range(first, len(parts) + 1) if not (
        isinstance(r := deep.get(d := "/".join(parts[:i])), str) and r.strip())]


def deep_fix(h: dict, deep: dict) -> str:
    """A deep page's two choices, shared by survey and update."""
    ask = " and ".join(unapproved(page_folder(h["path"]), deep))
    return (f"{'fold it into' if h['fold'] else 'move it to'} {h['to']}, or ask the owner to "
            f"approve {ask} in {CONFIG} deep_subsystems, with its rationale")


def at_home(path: str, registers: list[str], deep: dict, have: set[str] = frozenset()) -> bool:
    """RULES.md (Documentation) lists these homes; a change there changes this. A file in a
    page's folder that isn't a page is one of that page's files, wherever it sits below it."""
    # ROADMAP.md is a home only as the view of a roadmap; a hand-written one is a stray.
    return (path in ROOT_DOCS or (path == ROADMAP_VIEW and ROADMAP in have) or reference_file(path, have) or path in registers
            or (folder_page(path) and depth_ok(os.path.dirname(path), deep) and system_above(path, have, deep))
            or (not folder_page(path) and bool(owner_page(path, have, deep))))


def system_above(page: str, have: set[str], deep: dict) -> bool:
    """A folder page sits where a page may: its folder is a system's, flat in the page root,
    or inside a folder a page owns. A folder no page owns is no system, so a page below it is
    misplaced, the test a flat page passes through owner_page."""
    up = os.path.dirname(os.path.dirname(page))
    return page_root(up) or bool(owner_page(os.path.dirname(page), have, deep))


def page_home(path: str, have: set[str], deep: dict) -> str:
    """Flat beside the nearest page that has a folder, as a subsystem's page sits in its
    system's folder; else a system of its own, flat in docs/. A page of that name already
    there, flat or in its folder, is where it folds. Where the page would be deeper than the
    docs tree allows, the nearest page itself: fold it in. In a metarepo, the system of its own
    is flat in its genre folder. A page in its own folder moves with that folder, so it climbs
    from the folder above and lands in its folder unless the flat form is there to fold into."""
    stem, folders = Path(path).stem, path.split("/")[:-1]
    own = folder_page(path)
    if own:
        folders = folders[:-1]

    def there(d: str) -> str:
        flat, inner = f"{d}/{stem}.md", f"{d}/{stem}/{stem}.md"
        return flat if (own and flat in have) or (not own and inner not in have) else inner
    for i in range(len(folders), 1, -1):
        d = "/".join(folders[:i])
        if (page := folder_owner(d, have)) and depth_ok(d, deep):
            return there(d) if depth_ok(f"{d}/{stem}", deep) else page
    return there("/".join(folders[:2]) if GENRES is not None and len(folders) >= 2 else "docs")


def deep_home(path: str, deep: dict, have: set[str] = frozenset()) -> str:
    """The page of the nearest folder above PATH's own that the docs tree allows: in that
    folder, or flat beside it when only that one is there."""
    d = os.path.dirname(page_folder(path))
    while not depth_ok(d, deep):
        d = os.path.dirname(d)
    page = f"{d}/{os.path.basename(d)}.md"
    return f"{d}.md" if page not in have and f"{d}.md" in have else page


def meta_registers(root: Path, files: list[str], read) -> list[str]:
    """A metarepo's decision registers. entry_files says what pararepos cite, not where pages
    live; a register is no page, and stays wherever it is."""
    return [f for f in files if GENRES is not None and f.endswith(".md")
            and (Path(f).name == "DECISIONS.md" or bool(decision_rows(read(f), root)))]


def meta_hidden(root: Path, files: list[str], not_docs: list[str], read) -> list[dict]:
    """Each not_docs glob that hides a metarepo's pages from survey, as {glob, pages}: Markdown
    outside docs/ that is no root document and no register is a page to convert, and a glob
    left over from a code repo's reading of the tree keeps it out of sight."""
    if GENRES is None:
        return []
    regs = set(meta_registers(root, files, read))
    md = [f for f in files if f.endswith(".md") and not f.startswith(("docs/", *TOOL_DIRS))
          and f not in ROOT_DOCS and f not in regs]
    return [{"glob": g, "pages": hit} for g in not_docs if (hit := [f for f in md if matches(f, [g])])]


def doc_homes(root: Path, files: list[str], not_docs: list[str],
              read=None, deep: dict | None = None, docmap=None) -> list[dict]:
    """Every tracked Markdown file with no home, as {path, kind, to, fold, naming, named_at}.
    Kinds: `rules` an agent instruction file off root, `genre` a metarepo page under docs/ but
    in no genre folder, `board` a file in the old docs/hardware/
    layout (TO is where it goes), `reserved` a page named datasheets, `deep` a page named for its folder below
    a subsystem that deep_subsystems doesn't approve, flat or not, `page` a page, old shape or
    new, in the wrong place (in a folder with no page of its own), `copy` three or more
    sentences of RULES.md word for word, `stray` anything else.
    DEEP is the board's deep_subsystems, DOCMAP the pages it names (named_pages): a flat
    file there is a page.
    READ maps a path to its text, for update, which judges the files where they will be."""
    read = read or (lambda f: (root / f).read_text(errors="replace") if (root / f).is_file() else "")
    rules_md = Path(__file__).resolve().parent / "RULES.md"
    rules = re.sub(r"\s+", " ", rules_md.read_text()) if rules_md.exists() else ""
    load_genres(root)
    registers = meta_registers(root, files, read)
    deep = deep if isinstance(deep, dict) else {}
    docmap = docmap or set()
    have = set(files)
    old = {} if GENRES is not None else {r["path"]: r["to"] for r in old_board_rows(files, read)}
    out = []
    for f in files:
        if not f.endswith(".md") or f.startswith(TOOL_DIRS) or matches(f, not_docs):
            continue
        if f == "GLOSSARY.md":
            named = naming(root, f, files)
            out.append({"path": f, "kind": "stray", "to": f"README.md § {GLOSSARY_HOME[3:]}",
                        "fold": False, "naming": sorted(named),
                        "named_at": [f"{n}:{i}" for n in sorted(named) for i in named[n]]})
            continue
        # A metarepo's pages are all under docs/<genre>/, wherever entry_files finds them,
        # and in whatever shape: outside docs/, only a root document or a register is at home.
        if GENRES is not None and (
                (f.startswith("docs/") and not at_home(f, registers, deep, have)
                 and (f.count("/") == 1 or not genre_dir("/".join(f.split("/")[:2]))))
                or (not f.startswith("docs/") and f not in registers
                    and ("/" in f or not at_home(f, registers, deep, have)))):
            named = naming(root, f, files)
            top = f.split("/")[0] if "/" in f and not f.startswith("docs/") else ""
            to = page_in(f"docs/{top}/{Path(f).stem}.md", have) if top else None
            out.append({"path": f, "kind": "genre" if f.startswith("docs/") else "page", "to": to,
                        "fold": bool(to and (to in have or (root / to).exists())),
                        "naming": sorted(named),
                        "named_at": [f"{n}:{i}" for n in sorted(named) for i in named[n]]})
            continue
        if f in old or reserved_page(f):
            named = naming(root, f, files)
            out.append({"path": f, "kind": "board" if f in old else "reserved", "to": old.get(f),
                        "fold": False, "naming": sorted(named),
                        "named_at": [f"{n}:{i}" for n in sorted(named) for i in named[n]]})
            continue
        # A README is its folder's own document for outsiders: docmap naming one asks it on
        # every change, so it is read, and it stays where it is.
        if f in docmap and Path(f).name == "README.md":
            continue
        flat = flat_page(f, have, docmap, read)
        # A page's own files are at home, but a page-shaped file in a subfolder with no page
        # of its own is a page in the wrong place.
        shaped = (not flat and not folder_page(f) and not reference_file(f)
                  and f.startswith("docs/") and owner_page(f, have, deep)
                  and (f in docmap or page_shaped(read(f))))
        if flat and depth_ok(page_folder(f), deep):
            continue
        if not flat and at_home(f, registers, deep, have) and not shaped:
            continue
        text, to = read(f), None
        # A page first: one that quotes the rulebook is still the repo's page, not a copy.
        if "/" in f and Path(f).name in RULES_NAMES:
            kind = "rules"
        elif folder_page(f) and not system_above(f, have, deep):
            kind, to = "page", page_home(f, have, deep)
        elif folder_page(f) or flat:
            kind, to = "deep", deep_home(f, deep, have)
        # The board naming a file makes it a page in any format and anywhere: fold-in asks
        # it on every change, so it is no stray, whatever its sections are called.
        elif f in docmap or (f.startswith("docs/") and page_shaped(text)):
            kind, to = "page", page_home(f, have, deep)
        elif rules and len([s for s in sentences(text) if s in rules]) >= 3:
            kind = "copy"
        else:
            kind = "stray"
        named = naming(root, f, files)
        out.append({"path": f, "kind": kind, "to": to,
                    "fold": bool(to and (to in have or (root / to).exists())),
                    "naming": sorted(named),
                    "named_at": [f"{n}:{i}" for n in sorted(named) for i in named[n]]})
    return out


def page_shapes(root: Path, files: list[str], not_docs: list[str], docmap: set[str],
                skip: set[str], read) -> list[dict]:
    """Pages in the wrong one of their two shapes, as {path, to, into, fold, named}: a page
    named for its folder with nothing else there to hold, which goes flat beside its parent's
    page (INTO false), and a flat page with a folder of its own name, which goes into it (INTO
    true). SKIP are the files with no home, reported already. NAMED is false where the flat
    page would be neither in DOCMAP nor page-shaped, so read as a note."""
    have, out = set(files), []
    def company(f: str) -> bool:
        # An ignored datasheet isn't tracked, but the folder on disk or the page's link says it's there.
        d = page_folder(f)
        return (any(g.startswith(f"{d}/") and g != f for g in have) or (root / d / DATASHEETS).is_dir()
                or any(t.startswith(f"{d}/") for t in link_targets(f, read(f))))
    for f in files:
        if f in skip or matches(f, not_docs):
            continue
        if folder_page(f) and not old_layout(f):
            to = f"{page_folder(f)}.md"
            if not company(f) and to not in have and flat_spot(to, have):
                out.append({"path": f, "kind": "shape", "to": to, "into": False, "fold": False,
                            "named": f in docmap or page_shaped(read(f))})
        elif flat_page(f, have, docmap, read) and company(f):
            to = f"{page_folder(f)}/{Path(f).stem}.md"
            out.append({"path": f, "kind": "shape", "to": to, "into": True, "fold": to in have, "named": True})
    return out


def misfiled_seams(files: list[str], board: dict) -> list[dict]:
    """Each page filed in a system's folder whose docmap globs cover a file another system's
    page also covers, as {path, other}: a seam filed under one side, which the reading list
    would climb from as that side's part. A board page under a system is its system's, whatever
    its globs reach, so none is listed."""
    docmap = board.get("docmap") if isinstance(board.get("docmap"), dict) else {}
    boards = board_pages(board)
    # A system is docs/<system> in a code repo, docs/<genre>/<page> in a metarepo.
    n = 1 if GENRES is None else 2

    def system_of(k: str) -> str:
        return "/".join(page_folder(k).split("/")[:n + 1])
    tops = {k: system_of(k) for k in docmap
            if k.startswith("docs/") and k.endswith(".md") and page_folder(k).count("/") == n}
    have, out = set(files), []
    for p, globs in docmap.items():
        if (not isinstance(globs, list) or not p.startswith("docs/") or page_folder(p).count("/") < n + 1
                or any(same_page(b, p) for b in boards)):
            continue
        system = system_of(p)
        # A folder no page owns is no system: the page is misplaced, which doc_homes reports.
        if not folder_owner(system, have):
            continue
        other = next((t for f in files if matches(f, globs)
                      for t, s in tops.items() if s != system and matches(f, docmap[t] or [])), "")
        if other:
            out.append({"path": p, "other": other})
    return out


def shape_fix(e: dict) -> str:
    """What to do with a page in the wrong shape, shared by survey and update."""
    if e["into"]:
        return (f"has a folder of its own name, {page_folder(e['path'])}/: "
                f"{'fold it into' if e['fold'] else 'move it to'} {e['to']}")
    return (f"flat at {e['to']}: its folder holds nothing else"
            + ("" if e["named"] else "; name it in docmap, or it reads as a note there"))


# RULES.md (Documentation, The findings record): the owner's answer to each file finding, kept
# on trunk so a yes outlives the chat it was given in. An id is `<kind>:<path>`, the kind as
# survey's --json gives it, so a new kind of finding needs no new record.
REMAP = f"{DIR}/redocument.md"
# The kinds survey and update both show with an id, so both count the same findings. A stray,
# a genre and an old board file go to redocument's remap, not to an answer here.
FINDING_KINDS = ("rules", "copy", "reserved", "page", "deep", "shape", "contract")
# The findings jig carries out itself on a recorded yes: a rename, never an edit.
MOVE_KINDS = ("shape", "page")


def finding_id(e: dict) -> str:
    return f"{e['kind']}:{e['path']}"


def is_finding(e: dict) -> bool:
    """Whether E is one survey and update show with an id. A page with no destination (a
    metarepo page in no genre) is the remap's, and a page whose only problem is the old
    contract is redocument's: update lists neither."""
    if e.get("kind") not in FINDING_KINDS:
        return False
    if e["kind"] == "page":
        return bool(e.get("to"))
    if e["kind"] == "contract":
        return any(not p.startswith("old contract") for p in e.get("problems", []))
    return True


def entry_problem(i: str, v) -> str:
    """Why a findings entry is no answer, or "" when it is one."""
    if not isinstance(v, str):
        return "not a string"
    v = v.strip()
    if i.startswith("deep:") and v.startswith("exception:"):
        # One exception record per finding: the homes check reads deep_subsystems.
        return f"a deep page's exception is its folder in {CONFIG} deep_subsystems, with its rationale"
    if v == "approved" or any(v.startswith(p) and v[len(p):].strip() for p in ("deferred:", "exception:")):
        return ""
    if any(v.startswith(p) for p in ("deferred:", "exception:")):
        return "nothing after its colon: say where, or the owner's reason"
    return 'not "approved", "deferred: <where>" or "exception: <the owner\'s reason>"'


def findings_record(board: dict) -> dict[str, str]:
    """The board's findings entries that count as answers."""
    rec = board.get("findings")
    return ({k: v.strip() for k, v in rec.items() if not entry_problem(k, v)}
            if isinstance(rec, dict) else {})


def outcome_label(outcome: str | None) -> str:
    return "not answered" if outcome is None else "approved, not done" if outcome == "approved" else outcome


def tagged(e: dict, rec: dict) -> dict:
    """E with its id and its recorded outcome, as survey's --json carries them."""
    if not is_finding(e):
        return e
    i = finding_id(e)
    return {**e, "id": i, "outcome": rec.get(i)}


def state_tag(e: dict, rec: dict) -> str:
    return f"  [{finding_id(e)}: {outcome_label(rec.get(finding_id(e)))}]" if is_finding(e) else ""


def file_findings(root: Path, files: list[str], board: dict, read) -> dict[str, dict]:
    """Every file finding survey and update show with an id, by id: the homes, the shapes and
    the page contract, judged on FILES as READ gives them."""
    not_docs = board.get("not_docs") or []
    deep = board.get("deep_subsystems") if isinstance(board.get("deep_subsystems"), dict) else {}
    docmap = named_pages(board)
    homes = doc_homes(root, files, not_docs, read, deep, docmap)
    out = {finding_id(h): h for h in homes if is_finding(h)}
    out.update({finding_id(e): e for e in page_shapes(root, files, not_docs, docmap,
                                                      {h["path"] for h in homes}, read)})
    at, have = {h["path"]: h for h in homes}, set(files)
    for f in files:
        if (f.endswith(".md") and (folder_page(f) or flat_page(f, have, docmap, read))
                and (f not in at or at[f]["kind"] == "deep") and not matches(f, not_docs)):
            e = {"path": f, "kind": "contract", "problems": page_problems(read(f))}
            if is_finding(e):
                out[finding_id(e)] = e
    return out


def remap_rows(text: str) -> list[tuple[list[str], list[str]]]:
    """The remap table's rows as (old paths, new paths), read by its `Old path(s)` and `New
    path` columns: `same` keeps each old path where it is."""
    cols, out = None, []
    for line in text.splitlines():
        if not line.lstrip().startswith("|"):
            cols = None
            continue
        cells = table_cells(line)
        if cols is None:
            low = [c.lower() for c in cells]
            o = next((i for i, c in enumerate(low) if c.startswith("old path")), None)
            n = next((i for i, c in enumerate(low) if c.startswith("new path")), None)
            cols = (o, n) if o is not None and n is not None else False
            continue
        if not cols or SEPARATOR.match(line.strip()) or len(cells) <= max(cols):
            continue
        olds = re.findall(r"`([^`]+)`", cells[cols[0]])
        new = cells[cols[1]]
        out.append((olds, olds if new.strip().lower() == "same" else re.findall(r"`([^`]+)`", new)))
    return out


def remap_end(root: Path, files: list[str], rows: list) -> tuple[list[str], "callable"]:
    """The tracked files as the remap will leave them, and a reader for them: a row's old paths
    give way to its new ones, and a new page reads as its one old page did. A page alone in its
    folder today may get company from another row, which makes its folder form right."""
    gone, born = set(), {}
    for olds, news in rows:
        if olds == news:
            continue
        gone.update(o for o in olds if o not in news)
        for n in news:
            if n not in files:
                born.setdefault(n, olds[0] if len(olds) == 1 else "")
    end = [f for f in files if f not in gone] + [n for n in born if n not in files]

    def read(f: str) -> str:
        p = root / (born.get(f) or f)
        return p.read_text(errors="replace") if born.get(f, f) and p.is_file() else ""
    return end, read


def remap_contradictions(root: Path, files: list[str], board: dict, text: str) -> list[dict]:
    """Each page the remap keeps at a path survey moves it from, judged on the tree the remap
    leaves, with no exception recorded."""
    rows = remap_rows(text)
    kept = [p for olds, news in rows for p in news if p in olds or p in files]
    if not kept:
        return []
    end, read = remap_end(root, files, rows)
    found, rec, out = file_findings(root, end, board, read), findings_record(board), []
    for p in dict.fromkeys(kept):
        for kind in MOVE_KINDS:
            e = found.get(f"{kind}:{p}")
            if e and e.get("to") and not rec.get(f"{kind}:{p}", "").startswith("exception:"):
                out.append({"id": f"{kind}:{p}", "path": p, "to": e["to"]})
    return out


def contradiction_fix(c: dict, trunk: str) -> str:
    return (f"{REMAP} keeps {c['path']} where it is, and survey moves it to {c['to']}: move it "
            f"in the remap, or record the owner's exception on {trunk} in {CONFIG} findings, "
            f"\"{c['id']}\": \"exception: <the owner's reason>\"")


def approved_moves(root: Path, files: list[str], board: dict, read) -> tuple[list[dict], list[str]]:
    """The approved moves jig can carry out now, and the approvals and deferrals whose finding
    no longer fires. A kind this jig doesn't compute is never dropped: another jig may."""
    raw = board.get("findings") if isinstance(board.get("findings"), dict) else {}
    if not raw:
        return [], []
    rec, found = findings_record(board), file_findings(root, files, board, read)
    moves = [e for i, e in found.items() if rec.get(i) == "approved" and e["kind"] in MOVE_KINDS
             and e.get("to") and not e.get("fold") and not (root / e["to"]).exists()]
    # jig changes an entry only where it acted itself: its own move (carry_out), or an approval
    # or deferral whose finding no longer fires, which is settled. An exception is the owner's
    # reason, which no tree can rebuild: it stays until the owner drops it or records it again
    # at the page's new path, and survey lists it while it answers nothing.
    gone = [i for i, v in raw.items() if i.partition(":")[0] in FINDING_KINDS and i not in found
            and not (isinstance(v, str) and v.strip().startswith("exception:"))]
    return moves, gone


def carry_out(root: Path, board: dict, moves: list[dict], gone: list[str]) -> None:
    """Make each approved move with git mv, rename the board keys naming it, drop its entry and
    every gone one from BOARD, and move the other entries on its old path to its new one, so an
    exception recorded for the page goes with it."""
    rec = board.get("findings") if isinstance(board.get("findings"), dict) else {}
    for i in [finding_id(e) for e in moves] + gone:
        rec.pop(i, None)
    for e in moves:
        (root / e["to"]).parent.mkdir(parents=True, exist_ok=True)
        git("mv", e["path"], e["to"], check=True)
        for d in (root / e["path"]).parents:
            if d == root or any(d.iterdir()):
                break
            d.rmdir()
        if isinstance(board.get("docmap"), dict) and e["path"] in board["docmap"]:
            board["docmap"] = {(e["to"] if k == e["path"] else k): v for k, v in board["docmap"].items()}
        if isinstance(board.get("boards"), list):
            board["boards"] = [e["to"] if b == e["path"] else b for b in board["boards"]]
        rec = {(f"{k.split(':', 1)[0]}:{e['to']}" if k.split(":", 1)[-1] == e["path"] else k): v
               for k, v in rec.items()}
    if rec:
        board["findings"] = rec
    else:
        board.pop("findings", None)


# RULES.md (Documentation): a repo's terms are a section of its README, one heading per term,
# so `README.md § <term>` names one and sync's term report, which reads headings, sees it.
GLOSSARY_HOME = "## Glossary"
GLOSSARY_SEED = (f"{GLOSSARY_HOME}\n\n<!-- One term per ### heading: what it means, and what it "
                 "is not. -->\n")
# A term written as a bold word opening its paragraph, then a dash or colon on that line:
# `**mote** — …`, `**operation** (registry op) — …`, `**seam:** …`.
BOLD_TERM = re.compile(r"^\*\*([^*]+?)(:?)\*\*(.*)$")
TERM_MARK = re.compile(r"\s[—–-]\s|[—–]|:")


def glossary_section(text: str) -> list[str] | None:
    """The lines of README's Glossary section, or None when it has none."""
    lines = text.splitlines()
    start = next((i for i, l in enumerate(lines) if l.strip() == GLOSSARY_HOME), None)
    if start is None:
        return None
    end = next((j for j in range(start + 1, len(lines)) if re.match(r"#{1,2}\s", lines[j])), len(lines))
    return lines[start + 1:end]


def glossary_unheaded(text: str) -> list[str]:
    """Terms in README's Glossary section that are bold words in a paragraph, not headings."""
    lines = glossary_section(text) or []
    out = []
    for i, line in enumerate(lines):
        starts = i == 0 or not lines[i - 1].strip()
        m = BOLD_TERM.match(line.strip()) if starts else None
        if m and (m.group(2) or TERM_MARK.search(m.group(3))):
            out.append(m.group(1).strip())
    return out


def glossary_terms(text: str) -> list[str]:
    """The ### term headings of README's Glossary section: in a metarepo, the only part of the
    README that pararepos cite, so the only part a release reports or M3 asks a line for."""
    return [m.group(1) for l in glossary_section(text) or []
            if (m := re.match(r"###\s+(.+?)\s*$", l))]


def glossary_text(text: str) -> list[str] | None:
    """README's Glossary section without its blank lines, which git's output may have trimmed."""
    section = glossary_section(text)
    return None if section is None else [l for l in section if l.strip()]


def home_fix(h: dict) -> str:
    """What to do with a rules file or a copy, shared by survey and update."""
    at = ", ".join(h["named_at"]) or "nothing"
    if h["kind"] == "reserved":
        return (f"a page under the reserved name {DATASHEETS}/, which holds vendor documents: "
                f"rename its folder, and repoint what names it ({at})")
    if h["kind"] == "rules":
        return ("a second rulebook: fold what still binds into AGENTS.md or a page's Invariants, "
                f"repoint what names it ({at}), then delete it. A package's own rules file may "
                "stay on the owner's word: ask, don't presume the delete")
    return (f"a copy of {DIR}/RULES.md, which update keeps current: delete it, and point what "
            f"names it ({at}) at {DIR}/RULES.md")


# What a repo may already have for coordinating parallel work, under its standard
# name, and the jig concept each one maps to. The survey reports these so that
# adoption speaks the repo's language, not jig's.
COORDINATION = [
    ("CODEOWNERS", "owns / shares",
     ["CODEOWNERS", ".github/CODEOWNERS", "docs/CODEOWNERS", ".gitlab/CODEOWNERS"]),
    ("pull-request template", "the handoff note",
     [".github/PULL_REQUEST_TEMPLATE.md", ".github/pull_request_template.md",
      ".gitlab/merge_request_templates"]),
    ("git hooks (husky / pre-commit / lefthook)", "the hooks",
     [".husky", ".pre-commit-config.yaml", "lefthook.yml", ".lefthook.yml"]),
    ("agent instructions", "AGENTS.md",
     ["CLAUDE.md", "AGENTS.md", ".cursorrules", ".cursor/rules", ".windsurfrules",
      ".github/copilot-instructions.md", "GEMINI.md", ".kiro/steering"]),
    ("decision records (ADRs)", f"{DIR}/specs/ decisions + {WORKAROUNDS}",
     ["docs/adr", "docs/decisions", "adr", "decisions"]),
    ("changelog", f"{DIR}/decisions.md: `jig update --merge-log` merges a root CHANGELOG.md into it",
     ["CHANGELOG.md", "CHANGES.md", "HISTORY.md"]),
    ("handoff / round records", f"{DIR}/handoffs/",
     [".claude/handoffs", "handoffs", "docs/handoffs", "records", "docs/records"]),
    ("skills directory", ".claude/skills/ (kept as is)",
     [".claude/skills", "skills", ".cursor/skills"]),
]


def coordination_report(root: Path) -> dict:
    out: dict = {"found": [], "worktrees": 0, "open_branches": [], "homebrew_boards": [],
                 "git_hooks": []}
    for label, maps_to, paths in COORDINATION:
        hits = [p for p in paths if (root / p).exists()]
        if hits:
            out["found"].append({"what": label, "maps_to": maps_to, "at": hits})
    out["worktrees"] = max(0, len([l for l in git("worktree", "list", "--porcelain").splitlines()
                                   if l.startswith("worktree ")]) - 1)
    trunk = Board.trunk_name(root)
    out["open_branches"] = [b.strip("* ").strip() for b in
                            git("branch", "--no-merged", trunk).splitlines() if b.strip()]
    out["git_hooks"] = foreign_hooks()
    out["homebrew_boards"] = board_like_json(root, tracked(root))
    return out


def board_like_json(root: Path, files: list[str]) -> list[str]:
    """Tracked JSON in any root dot-folder whose entries carry owns, shares or lanes: a
    homebrew board, or jig's own under a name this copy doesn't know. Not only the tooling
    dirs — ai-dev kept its board in .aidev/, and a narrower check missed it."""
    out = []
    for f in files:
        if f.endswith(".json") and f.startswith(".") and "/" in f and f not in (CONFIG, JOBS):
            try:
                txt = (root / f).read_text(errors="replace")
            except OSError:
                continue
            if '"owns"' in txt or '"shares"' in txt or '"lanes"' in txt:
                out.append(f)
    return out


def board_build(f: str) -> bool:
    return any(fnmatch.fnmatchcase(Path(f).name, b) for b in BOARD_BUILD)


def unpaged_build(board: dict, files: list[str]) -> list[tuple[str, str]]:
    """Each board-build file in FILES no registered board page's docmap covers, with the page
    docmap maps it to when there is one: that page is the board's, missing only from boards
    (an old-layout repo after update), and needs listing, not writing."""
    docmap = board.get("docmap") if isinstance(board.get("docmap"), dict) else {}
    pages = board_pages(board)
    globs = [g for p in pages for g in page_globs(docmap, p)]
    return [(f, next((p for p, gs in docmap.items() if isinstance(gs, list) and matches(f, gs)), ""))
            for f in files if board_build(f) and not matches(f, globs)]


def unpaged_fix(f: str, page: str) -> str:
    if page:
        return f"docmap maps {f} to {page}, which {CONFIG} boards doesn't list: add it to boards"
    return (f"write the board's page with /jig:hardware, list it in {CONFIG} boards, and map "
            f"{f} to it in docmap")


def board_refusals(board: dict, trunk: str, at: str) -> list[str]:
    """Every board has a page: a board-build file the branch adds or changes that no registered
    board page's docmap covers, and a registered board page the branch deletes or moves. A
    boards entry naming a page that is nowhere yet is survey's to report: the page may be on
    another job's branch, and refusing here would hold every job until that one merges. A repo
    that builds for no board has nothing here to refuse."""
    rng = f"{trunk}...{at}"
    changed = git("-c", "core.quotePath=false", "diff", "--name-only", "--no-renames",
                  "--diff-filter=AM", rng).splitlines()
    out = [f"{f} builds for a board no page covers: {unpaged_fix(f, page)}"
           for f, page in unpaged_build(board, changed)]
    gone = set(git("-c", "core.quotePath=false", "diff", "--name-only", "--no-renames",
                   "--diff-filter=D", rng).splitlines())
    # Flat to folder or back is the same page: boards names it in either form.
    there = set(git("-c", "core.quotePath=false", "ls-tree", "-r", "--name-only", at).splitlines())
    out += [f"{p} is a board page {CONFIG} boards lists, and this branch deletes or moves it: "
            "keep it, or move its boards and docmap entries with it on trunk first"
            for p in board_pages(board) if set(page_forms(p)) & gone and not set(page_forms(p)) & there]
    return out


def board_pages(board: dict) -> list[str]:
    """The pages config.json's boards names: a board is what a page is, never where it sits."""
    boards = board.get("boards")
    return [b for b in boards if isinstance(b, str)] if isinstance(boards, list) else []


def named_pages(board: dict) -> set[str]:
    """The files the board names as pages, docmap's keys and boards: a flat file is a page
    when one of these names it, whatever its sections."""
    docmap = board.get("docmap") if isinstance(board.get("docmap"), dict) else {}
    return {f for p in set(docmap) | set(board_pages(board)) for f in page_forms(p)}


# Markdown link targets: inline `[t](target "title")` and reference definitions `[d]: target`.
# A target may sit in <...> so it can hold spaces; a bare one with a space is accepted too,
# because a board page is read by people, and a link that renders for them counts.
# A bare target may hold one level of balanced parentheses, as CommonMark allows: a vendor's
# `qx-20(rev1).pdf` is one file, not `qx-20(rev1`.
MD_INLINE = re.compile(r"""\]\(\s*(<[^>]*>|(?:[^()\n]|\([^()\n]*\))*?)(?:\s+"[^"]*"|\s+'[^']*')?\s*\)""")
MD_REFDEF = re.compile(r"""^ {0,3}\[[^\]]+\]:\s*(<[^>]*>|.*?)(?:\s+"[^"]*"|\s+'[^']*')?\s*$""", re.M)


def link_targets(page: str, text: str) -> list[str]:
    """Every local link in a page, as a repo-relative path. A leading / is the repo root."""
    out = []
    for raw in MD_INLINE.findall(text) + MD_REFDEF.findall(text):
        target = urllib.parse.unquote(raw.strip().strip("<>").split("#")[0])
        if not target or "://" in target or target.startswith("mailto:"):
            continue
        base = "" if target.startswith("/") else os.path.dirname(page)
        out.append(os.path.normpath(os.path.join(base, target.lstrip("/"))))
    return out


def shared_home(a: str, b: str, have: set[str]) -> str:
    """The datasheets/ of the nearest folder above both A and B that has a page of its own,
    docs/datasheets/ at the top."""
    common = os.path.commonpath([a, b]).split("/")
    while len(common) > 1 and not folder_owner("/".join(common), have):
        common.pop()
    return f"{'/'.join(common)}/{DATASHEETS}/"


def datasheet_links(root: Path, files: list[str], pages: list[str], deep: dict,
                    not_docs: list[str]) -> tuple[list[str], list[tuple[str, str]], list[tuple[str, str, str]]]:
    """Files in a page's folder, or in docs/datasheets/, that no page or note there links;
    links into a datasheets/ folder that point at nothing on disk (disk, not git: an ignored
    datasheet that was fetched is present); and links into the datasheets/ of a page that is
    not the linker's own or above it, with the shared folder the file belongs in."""
    have = set(files)
    notes = [f for f in files if f.endswith(".md") and f not in pages and f.startswith("docs/")
             and not reference_file(f) and not matches(f, not_docs) and owner_page(f, have, deep)]
    linked, missing, misplaced = set(), [], []
    for page in pages + notes:
        text = (root / page).read_text(errors="replace") if (root / page).exists() else ""
        for path in link_targets(page, text):
            linked.add(path)
            if not reference_file(path):
                continue
            if not (root / path).exists() and (page, path) not in missing:
                missing.append((page, path))
            owner = path[:path.index(f"/{DATASHEETS}/")]
            here = page_folder(page) if page in pages else os.path.dirname(page)
            if here != owner and not here.startswith(f"{owner}/"):
                misplaced.append((page, path, shared_home(owner, here, have)))
    pool = f"docs/{DATASHEETS}/"
    unlinked = [f for f in files if f not in linked and f not in pages and not matches(f, not_docs)
                and not f.startswith(OLD_BOARDS)
                and (f.startswith(pool) or (f.startswith("docs/") and not folder_page(f)
                                            and owner_page(f, have, deep)))]
    return unlinked, missing, misplaced


def cmd_survey(root: Path, args) -> int:
    files = tracked(root)
    md = [f for f in files if f.endswith(".md")]
    src = [f for f in files
           if f.endswith(SRC_EXT)
           and not f.startswith((".", f"{DIR}/"))
           and not re.search(r"(^|/)\.", f)
           and not re.search(r"(^|/)(tests?|__tests__|node_modules|vendor|build|dist|scripts)/", f)
           and not re.search(r"\.(test|spec)\.", f)]
    # Survey runs on repos that have no board yet; then nothing is declared.
    try:
        board = Board.load(root).data
    except SystemExit:
        board = {}
    not_docs = board.get("not_docs") or []
    report: dict = {"markdown": [], "homeless": [], "oversized": [], "present": {},
                    "src_count": len(src), "not_docs": not_docs,
                    # "docs-src/" reads like a directory but matches nothing; say so, or
                    # the files it meant to cover are back on the homeless list unexplained.
                    "not_docs_unmatched": [g for g in not_docs
                                          if not any(matches(f, [g]) for f in files)]}

    deep = board.get("deep_subsystems") if isinstance(board.get("deep_subsystems"), dict) else {}
    # A trailing slash or a missing docs/ approves no folder, silently; say so.
    report["deep_unmatched"] = [k for k in deep if not any(f.startswith(f"{k}/") or f == f"{k}.md" for f in files)]
    docmap = named_pages(board)
    homes = {h["path"]: h for h in doc_homes(root, files, not_docs, deep=deep, docmap=docmap)}
    for f in md:
        raw = (root / f).read_text(errors="replace").splitlines() if (root / f).exists() else []
        n = len([l for l in raw
                 if l.strip() and not l.lstrip().startswith(("#", "<!--", "-->", "|"))])
        last = git("log", "-1", "--format=%ad", "--date=short", "--", f)
        home = homes.get(f)
        entry = {"path": f, "lines": n, "last_commit": last,
                 "inbound": len(home["naming"]) if home else inbound(root, f, files)}
        report["markdown"].append(entry)
        if home:
            report["homeless"].append({**entry, **{k: home[k] for k in ("kind", "to", "fold", "naming", "named_at")}})
        if f in ("AGENTS.md", "CLAUDE.md") and n > 40:  # rule lines, not raw lines
            report["oversized"].append(entry)

    # The spec template and the ledgers are made on first use, so their absence is no gap.
    for name in ("AGENTS.md", "CLAUDE.md", f"{DIR}/scripts/check.sh", f"{DIR}/scripts/setup.sh",
                 f"{DIR}/jig.py", f"{DIR}/RULES.md", CONFIG, JOBS):
        report["present"][name] = (root / name).exists()
    common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
    hook = common / "hooks" / "pre-commit"
    report["present"]["git hooks"] = hook.exists() and "jig hook" in hook.read_text()

    report["coordination"] = coordination_report(root)
    report["docmap_present"] = bool(board.get("docmap"))
    # The fold-in asks about a page only when docmap names it, so a board page left out
    # of docmap is never checked against the code that targets that board.
    boards = board_pages(board)
    report["boards_unmapped"] = [f for f in boards if not any(same_page(k, f) for k in (board.get("docmap") or {}))]
    report["boards_missing"] = [f for f in boards if page_in(f, set(files)) not in files]
    report["boards_unpaged"] = [{"path": f, "page": p} for f, p in unpaged_build(board, files)]
    have = set(files)

    def read(f: str) -> str:
        return (root / f).read_text(errors="replace") if (root / f).is_file() else ""
    flats = {f for f in md if flat_page(f, have, docmap, read)}
    pages = [f for f in md if (folder_page(f) or f in flats) and f not in homes and not matches(f, not_docs)]
    report["page_shapes"] = page_shapes(root, files, not_docs, docmap, set(homes), read)
    report["seams_misfiled"] = misfiled_seams(files, board)
    report["datasheets_unlinked"], report["datasheets_missing"], report["datasheets_misplaced"] = datasheet_links(
        root, files, pages, deep, not_docs)
    report["datasheets_orphan"] = [f for f in files if reference_file(f) and not f.endswith(".md")
                                   and not f.startswith(OLD_BOARDS) and not matches(f, not_docs)
                                   and not reference_file(f, have)]
    report["old_boards"] = [] if GENRES is not None else old_board_rows(
        files, lambda f: (root / f).read_text(errors="replace") if (root / f).is_file() else "")
    report["genres"] = None if GENRES is None else list(GENRES)
    report["not_docs_hiding"] = meta_hidden(root, files, not_docs, read)
    report["decision_placement"] = placement_hints(root, Board.trunk_name(root))
    readme = root / "README.md"
    report["glossary_unheaded"] = glossary_unheaded(readme.read_text(errors="replace")) \
        if "README.md" in files and readme.is_file() else []
    report["page_contract"] = [
        {"path": f, "problems": probs} for f in md
        if (folder_page(f) or f in flats) and (f not in homes or homes[f]["kind"] == "deep")
        and not matches(f, not_docs)
        and (probs := page_problems((root / f).read_text(errors="replace") if (root / f).exists() else ""))]
    product = product_pages(root, md)
    sids = scope_ids(at_rev(Board.trunk_name(root), ROADMAP))
    report["project_in_product"] = [
        {"path": f, "problems": probs} for f in product
        if (probs := (project_sections(read(f)) if f != LOG else []) + project_prose(read(f), sids))]
    rec = findings_record(board)
    report["homeless"] = [tagged(e, rec) for e in report["homeless"]]
    report["page_shapes"] = [tagged(e, rec) for e in report["page_shapes"]]
    report["page_contract"] = [tagged({**e, "kind": "contract"}, rec) for e in report["page_contract"]]
    finds = {e["id"]: e for e in report["homeless"] + report["page_shapes"] + report["page_contract"]
             if "id" in e}
    report["remap_contradictions"] = remap_contradictions(
        root, files, board, at_rev(Board.trunk_name(root), REMAP))
    raw_rec = board.get("findings") if isinstance(board.get("findings"), dict) else {}
    report["findings_not_counted"] = [{"id": k, "why": w} for k, v in raw_rec.items()
                                      if (w := entry_problem(k, v))]
    # An exception jig never drops, so one whose finding is gone waits for the owner. During a
    # redocument run the pages are mid-move and its step 6 settles them: not listed until then.
    report["exceptions_unused"] = [] if at_rev(Board.trunk_name(root), REMAP) else [
        {"id": k, "outcome": v} for k, v in rec.items()
        if v.startswith("exception:") and k.partition(":")[0] in FINDING_KINDS and k not in finds]
    if args.json:
        print(json.dumps(report, indent=2))
        return 0

    print(f"{len(md)} markdown files ({len(src)} source files). Line counts are rule lines:\n"
          "blank lines, headings and table rows are not counted.\n")
    missing = [k for k, v in report["present"].items() if not v]
    print("jig pieces present: " + (", ".join(k for k, v in report["present"].items() if v) or "none"))
    if missing:
        print("                 missing: " + ", ".join(missing))
    if report["oversized"]:
        print("\nToo long to be always-loaded (cut to 40 lines, move the rest):")
        for e in report["oversized"]:
            print(f"  {e['path']:<40} {e['lines']} lines")
    for kind, title in (("rules", "Agent instruction files off root"),
                        ("copy", f"Copies of {DIR}/RULES.md"),
                        ("reserved", f"Pages named {DATASHEETS}, a reserved name")):
        found = [e for e in report["homeless"] if e["kind"] == kind]
        if found:
            print(f"\n{title}:")
            for e in found:
                print(f"  {e['path']}: {home_fix(e)}{state_tag(e, rec)}")
    misplaced = [e for e in report["homeless"] if e["kind"] == "page"]
    if misplaced:
        have = set(files)
        print(f"\nPages outside the docs tree ({DIR}/RULES.md, Documentation); move each, "
              "or nest it\nunder its system's folder if it is a subsystem:")
        for e in misplaced:
            # A folder page owns its own folder: what it sits in is the folder above.
            p = e["path"]
            inside = owner_page(os.path.dirname(p) if folder_page(p) else p, have, deep)
            # At a metarepo's root, nothing in the path says which genre: the remap picks one.
            to = e["to"] or f"docs/<genre>/{Path(e['path']).name}"
            print(f"  {e['path']} → {to}{' (fold it in: that page exists)' if e['fold'] else ''}"
                  + (f" (a subsystem candidate: it sits in {inside}'s folder)" if inside else "")
                  + state_tag(e, rec))
    if report["decision_placement"]:
        print("\nPages two pararepos' decisions touch, and no decision here does: the ruling is "
              "probably the metarepo's:")
        for line in report["decision_placement"]:
            print(f"  {line}")
    for e in report["not_docs_hiding"]:
        print(f"\n`not_docs` glob {e['glob']} hides {len(e['pages'])} page{'s' if len(e['pages']) > 1 else ''} "
              f"of this metarepo ({', '.join(e['pages'][:3])}{' …' if len(e['pages']) > 3 else ''}): "
              "drop it from not_docs so they convert")
    ungenred = [e for e in report["homeless"] if e["kind"] == "genre"]
    if ungenred:
        print(f"\nPages under docs/ in no genre folder ({DIR}/RULES.md, Metarepo and pararepos): "
              "a metarepo's\npages are docs/<genre>/<name>.md:")
        for e in ungenred:
            g = e["path"].split("/")[1] if e["path"].count("/") > 1 else ""
            print(f"  {e['path']}: " + (f"{g}/ is no genre {META} declares ({', '.join(GENRES or ())}): "
                                        f"move it under one, or add {g} to genres" if g else
                                        f"needs a genre: move it to docs/<genre>/{Path(e['path']).name}"))
    if report["old_boards"]:
        print(f"\nBoard files in the old {OLD_BOARDS} layout ({DIR}/RULES.md, Documentation): each "
              "board is a\nsystem now. Move each file (/jig:redocument carries the moves), and list "
              f"each page\nunder boards in {CONFIG}:")
        for e in report["old_boards"]:
            print(f"  {e['path']} → {e['to'] or '? (' + e['why'] + ')'}"
                  + (f"   + boards: {e['to']}" if e["board"] else ""))
    if report["page_shapes"]:
        print(f"\nPages in the wrong shape ({DIR}/RULES.md, Documentation): a page is one file, "
              "flat in its\nparent's folder, until it holds another; then it moves into a folder "
              "named for it:")
        for e in report["page_shapes"]:
            print(f"  {e['path']}: {shape_fix(e)}{state_tag(e, rec)}")
    if report["seams_misfiled"]:
        print(f"\nPages in one system's folder that cover another's files ({DIR}/RULES.md, "
              "Documentation):")
        for e in report["seams_misfiled"]:
            print(f"  {e['path']}: covers files of two systems (also {e['other']}'s): a seam "
                  "lives in their nearest shared folder")
    below = [e for e in report["homeless"] if e["kind"] == "deep"]
    if below:
        print(f"\nPages below a subsystem ({DIR}/RULES.md, Documentation); fold each into its "
              f"subsystem's page,\nor propose it to the owner with its rationale for {CONFIG} deep_subsystems:")
        for e in below:
            print(f"  {e['path']}: {deep_fix(e, deep)}{state_tag(e, rec)}")
    strays = [e for e in report["homeless"] if e["kind"] == "stray" and not e["to"]]
    for e in (e for e in report["homeless"] if e["kind"] == "stray" and e["to"]):
        print(f"\n{e['path']} → {e['to']}: a repo's terms are a section of its README, one "
              f"### heading per term ({DIR}/RULES.md, Documentation)")
    if strays:
        linked = sorted((e for e in strays if e["inbound"] > 0),
                        key=lambda e: -e["inbound"])
        cold = sorted((e for e in strays if e["inbound"] == 0),
                      key=lambda e: -e["lines"])
        if linked:
            print("\nNo home in the taxonomy, but other files point at them — these are"
                  "\nmisfiled, not stale. Give each a home; do not drop them:")
            for e in linked:
                print(f"  {e['path']:<44} {e['lines']:>5} lines  {e['inbound']:>4} inbound"
                      f"  last {e['last_commit'] or '?'}")
        if cold:
            print("\nNo home and nothing links them — written once, never read since."
                  "\nGive each a job or let git keep it:")
            for e in cold:
                print(f"  {e['path']:<44} {e['lines']:>5} lines  last {e['last_commit'] or '?'}")
        print(f"\nIf a directory ships markdown as code, list it under `not_docs` in {CONFIG}"
              " as a glob such as `dir/**`.")
    if report["deep_unmatched"]:
        print(f"\n{CONFIG} deep_subsystems keys that name no tracked folder (no trailing /, "
              "and the path starts at docs/):")
        for k in report["deep_unmatched"]:
            print(f"  {k}")
    if report["not_docs_unmatched"]:
        print("\n`not_docs` globs that match no tracked file (a directory needs `/**`):")
        for g in report["not_docs_unmatched"]:
            print(f"  {g}")
    if src and not report["docmap_present"]:
        print("\nNo docmap on the board: handoff cannot tell which docs page a change touches."
              f"\nMap pages to globs in {CONFIG} (see Fold-in in {DIR}/RULES.md).")
    if report["boards_missing"]:
        print(f"\n{CONFIG} boards entries that name no tracked page:")
        for f in report["boards_missing"]:
            print(f"  {f}")
    if report["boards_unpaged"]:
        print("\nBoard-build files no board page covers: jig gate refuses a branch that changes one:")
        for e in report["boards_unpaged"]:
            print(f"  {e['path']}: {unpaged_fix(e['path'], e['page'])}")
    if report["boards_unmapped"]:
        print("\nBoard pages no docmap entry names: no handoff will ask whether they still"
              "\nmatch the code. Map each to the code that targets its board:")
        for f in report["boards_unmapped"]:
            print(f"  {f}")
    if report["glossary_unheaded"]:
        terms = report["glossary_unheaded"]
        print(f"\nTerms in README.md § Glossary written as bold words, not headings: {len(terms)} "
              f"({', '.join(terms[:5])}{' …' if len(terms) > 5 else ''}).\nMake each a `### <term>` "
              f"heading, so `README.md § <term>` names it ({DIR}/RULES.md, Documentation).")
    if report["page_contract"]:
        print(f"\nPages off the page contract ({DIR}/RULES.md, Documentation):")
        for e in report["page_contract"]:
            for p in e["problems"]:
                print(f"  {e['path']}: {p}" + ("" if p.startswith("old contract") else state_tag(e, rec)))
    if report["project_in_product"]:
        print(f"\nThe project in the product's pages and entries ({DIR}/RULES.md, Documentation): a "
              f"page or an entry says\nwhat the product does today; phases, order and parked work "
              f"live in {ROADMAP}:")
        for e in report["project_in_product"]:
            for p in e["problems"]:
                print(f"  {e['path']}: {p}")
    if report["datasheets_unlinked"]:
        print(f"\nFiles in a page's folder, or in docs/{DATASHEETS}/, that no page links: link each"
              "\nfrom the page that leans on it (a datasheet from its Components table), or drop it:")
        for f in report["datasheets_unlinked"]:
            print(f"  {f}")
    if report["datasheets_orphan"]:
        print(f"\nFiles in a {DATASHEETS}/ folder that is in no page's folder: move each into the "
              f"{DATASHEETS}/\nof the page that uses it, or of the nearest folder two pages share "
              f"(docs/{DATASHEETS}/ at the top):")
        for f in report["datasheets_orphan"]:
            print(f"  {f}")
    if report["datasheets_missing"]:
        print(f"\nPages linking a file under {DATASHEETS}/ that doesn't exist: fetch it again from"
              "\nthe source URL the page records, and check its hash:")
        for page, target in report["datasheets_missing"]:
            print(f"  {page:<40} -> {target}")
    if report["datasheets_misplaced"]:
        print(f"\nPages linking a datasheet in another page's {DATASHEETS}/: a datasheet two pages "
              "use lives in\nthe nearest folder both share. Move it there, and relink both pages:")
        for page, target, home in report["datasheets_misplaced"]:
            print(f"  {page} -> {target}: move it to {home}")
    if report["findings_not_counted"]:
        print(f"\n{CONFIG} findings entries that count as no answer ({DIR}/RULES.md, Documentation):")
        for e in report["findings_not_counted"]:
            print(f"  {e['id']}: {e['why']}")
    if report["exceptions_unused"]:
        print(f"\n{CONFIG} findings exceptions that answer no finding now ({DIR}/RULES.md, "
              "Documentation): drop each on trunk, or record it at the page's new path:")
        for e in report["exceptions_unused"]:
            print(f"  {e['id']}: {e['outcome']}")
    if report["remap_contradictions"]:
        print(f"\nRemap rows that keep a page where survey moves it, with no exception recorded "
              f"({DIR}/RULES.md, Documentation):")
        for c in report["remap_contradictions"]:
            print(f"  {c['path']}: survey moves it to {c['to']}; move it in the remap, or record "
                  f"\"{c['id']}\": \"exception: <the owner's reason>\" in findings")
    co = report["coordination"]
    print("\nHow parallel work is coordinated today (and what each maps to in jig):")
    for f in co["found"]:
        print(f"  {f['what']:<42} -> {f['maps_to']:<32} {', '.join(f['at'])}")
    if co["git_hooks"]:
        print(f"  {'git hooks installed':<42} -> {'the hooks':<32} {', '.join(co['git_hooks'])}")
    if co["homebrew_boards"]:
        print(f"  {'a homebrew board (owns/shares/jobs)':<42} -> {'the board':<32} "
              f"{', '.join(co['homebrew_boards'])}")
    if co["worktrees"]:
        print(f"  {'git worktrees in use':<42} -> {'one per job':<32} {co['worktrees']} linked")
    if co["open_branches"]:
        n = len(co["open_branches"])
        print(f"  {'branches not merged into trunk':<42} -> {'jobs to adopt':<32} "
              f"{n}: {', '.join(co['open_branches'][:6])}{' …' if n > 6 else ''}")
    if not any([co["found"], co["git_hooks"], co["homebrew_boards"], co["worktrees"],
                co["open_branches"]]):
        print("  none found — a single-session repo; jobs need no setup until a second session starts")
    homes_line = dict(DOC_HOMES)
    if GENRES is not None:
        homes_line["docs/"] = (
            "the definitions this metarepo holds: docs/<genre>/<name>.md each page, in a genre folder "
            f"({', '.join(GENRES) if GENRES else f'any folder under docs/, until {META} declares genres'}); "
            "a genre has no page, its term is a ### heading in README.md § Glossary; a page holding "
            "other files moves into docs/<genre>/<name>/<name>.md; decision registers stay where they are")
    print("\nDoc homes: " + "; ".join(f"{k} = {v}" for k, v in homes_line.items()))
    old = old_board(root)
    # A repo already on jig with old pages has a migration of its own; adopt would replan the repo.
    old_pages = any(p.startswith("old contract") for e in report["page_contract"] for p in e["problems"]) \
        or any(h["kind"] in ("page", "deep") and old_contract((root / h["path"]).read_text(errors="replace"))
               for h in report["homeless"] if (root / h["path"]).is_file())
    outside = (any(h["kind"] in ("page", "genre") for h in report["homeless"])
               or bool(report["not_docs_hiding"]))
    # A repo on jig never adopts again: redocument converts pages, update fixes them in place.
    on_jig = (root / CONFIG).exists()
    # A deep page is folded or approved, not edited where it sits, as update leaves it.
    in_place = [e for e in report["page_contract"] if e["path"] not in homes]
    project = (f", and move the project listed above to {ROADMAP} on the owner's word"
               if report["project_in_product"] else "")
    # A finding unanswered, or approved and not yet carried out, still stands: the last line
    # never says there is nothing to do while one does.
    unanswered = len([e for e in finds.values() if e["outcome"] is None])
    approved = len([e for e in finds.values() if e["outcome"] == "approved"])
    remapped = len(report["remap_contradictions"])
    counts = [f"{n} finding{'s' if n != 1 else ''} {what}"
              for n, what in ((unanswered, "not answered"), (approved, "approved and not done")) if n]
    unused = len(report["exceptions_unused"])
    counts += [f"{unused} exception{'s' if unused != 1 else ''} answering no finding"] if unused else []
    counts += [f"{remapped} remap row{'s' if remapped != 1 else ''} keeping a page survey moves"] if remapped else []
    standing = (", ".join(counts) + ": run /jig:update to record an answer to each, and carry "
                "out the approved moves" if counts and on_jig else "")
    verdict = (f"An older jig's board is at {old}: run /jig:update first, not /jig:adopt or /jig:init."
          if old else "Pages in the old Now / Rules / Checks shape: run /jig:redocument to convert them."
          if old_pages else f"Board pages in the old {OLD_BOARDS} layout: run /jig:redocument to move them."
          if report["old_boards"] else "Pages outside the docs tree: run /jig:redocument to convert them."
          if outside and on_jig else "Pages off the page contract where they sit: run /jig:update "
          "to review each in place." if in_place and on_jig
          else "On jig already, no page to convert: give each file above its home" + project + "."
          if report["homeless"] and on_jig else f"On jig already{project or ': nothing to do'}."
          if on_jig else "Run /jig:adopt to turn this into a migration plan.")
    if standing:
        verdict = (f"On jig already: {standing}." if verdict.endswith(": nothing to do.")
                   else f"{verdict} {standing[0].upper()}{standing[1:]}.")
    print(verdict)
    return 0

# ------------------------------------------------------------------- metarepo

# A metarepo holds a set of repos' shared definitions, decisions and conventions: docs only.
# Pararepos cite it at a released tag. Everything here is off unless .jig/meta.json exists.
META = f"{DIR}/meta.json"
META_DEFAULTS = {
    "name": "",
    "entry_files": [f"{DIR}/decisions.md", "README.md"],
    "tag_pattern": r"^v\d+\.\d+(\.\d+)?$",
    "decision_prefix": "D-",
    "pararepos": [],
}
# A metarepo's pages, in any genre, at any depth: entry_files' glob for them.
META_GENRE_ENTRY = "docs/**/*.md"
DECISION_STATUSES = ("open", "proposed", "accepted", "superseded", "rejected")
# Before the log, a register row's Status cell, whole: a word alone, with a note in
# parentheses, or "superseded by D-12". Whole-cell, because a Decision cell often starts with a
# status word ("Open question: …").
# A register row may also be struck: project scope, not a decision, which --merge-log leaves out.
ROW_STATUSES = (*DECISION_STATUSES, "struck")
STATUS_CELL = re.compile(rf"(?:{'|'.join(ROW_STATUSES)})(?:\s*\(.*\)|\s+by\s+\S+)?")
# A commit's subject starts with the ids it touches (D-022: …, GLOSSARY: …), so git log is
# the decision index. A branch's entry isn't numbered yet: its subject leads with D-?<slug>.
SUBJECT_ID = r"(?:[A-Z][A-Z0-9_-]*|[A-Za-z][\w-]*\?[a-z0-9]+(?:-[a-z0-9]+)*)"
SUBJECT_IDS = re.compile(rf"^{SUBJECT_ID}(?:, ?{SUBJECT_ID})*: \S")
# The release log before .jig/decisions.md: read only for tags made before it, and by update's
# migration.
CHANGELOG = "CHANGELOG.md"


def is_entry(path: str, entry_files: list[str]) -> bool:
    """entry_files are jig's globs, never git pathspecs: git's `**` misses a file directly
    under the folder. jig's own files never count, or a `**/*.md` would make M3 ask the
    hubnode's trunk bookkeeping for a log line that M4 then refuses on trunk. The decision log
    is the exception, always: it is the metarepo's decisions, which pararepos cite."""
    return path == LOG or (not path.startswith(f"{DIR}/") and matches(path, entry_files))


def entry_paths(rev: str, cwd: str | None = None) -> list[str]:
    """The tracked files at rev that its meta.json's entry_files name."""
    meta = {**META_DEFAULTS, **json.loads(git("show", f"{rev}:{META}", cwd=cwd) or "{}")}
    # Unquoted, so a non-ASCII name reaches the glob as itself.
    names = git("-c", "core.quotePath=false", "ls-tree", "-r", "--name-only", rev, cwd=cwd)
    return [f for f in names.splitlines() if is_entry(f, meta["entry_files"])]


def load_meta(trunk: str) -> dict | None:
    """The metarepo config from TRUNK, like the board: a branch can't switch its own gates off."""
    raw = git("show", f"{trunk}:{META}")
    if not raw:
        return None
    try:
        return {**META_DEFAULTS, **json.loads(raw)}
    except ValueError:
        return None


def reviewed_commits() -> set[str]:
    """Every commit `jig reviewed` has recorded in this clone, on any branch."""
    log = git_common() / "jig" / "reviewed.log"
    return set(log.read_text().split()) if log.exists() else set()


def counts_reviewed(commit: str, done: set[str], board: "Board") -> bool:
    """A commit is reviewed when `jig reviewed` recorded it, or when a recorded commit is its
    first-parent ancestor and nothing of the job's changed since (`changed_since`): `jig
    handoff` requires the review to be HEAD, so the note is always committed after it."""
    for c in git("rev-list", "--first-parent", commit).splitlines():
        if c in done:
            return not changed_since(c, commit, board)
    return False


def merging_commits() -> list[str]:
    """The commits a merge in progress brings in. pre-merge-commit runs before git writes
    MERGE_HEAD, but git names what it merges in GIT_REFLOG_ACTION ("merge <ref>...")."""
    head = git("rev-parse", "-q", "--verify", "MERGE_HEAD")
    if head:
        # An octopus writes one line per head; rev-parse reads only the first.
        f = Path(git("rev-parse", "--git-path", "MERGE_HEAD"))
        heads = [l.split()[0] for l in f.read_text().splitlines() if l.strip()] if f.is_file() else []
        return heads or [head]
    action = os.environ.get("GIT_REFLOG_ACTION", "")
    if AUTO_MERGE and action.startswith("merge "):
        return [c for c in (git("rev-parse", "-q", "--verify", f"{r}^{{commit}}")
                            for r in action.split()[1:] if not r.startswith("-")) if c]
    if AUTO_MERGE and action.startswith("pull"):
        # A pull merges what it just fetched: FETCH_HEAD's lines not marked not-for-merge.
        fetched = git_common() / "FETCH_HEAD"
        lines = fetched.read_text().splitlines() if fetched.exists() else []
        return [l.split()[0] for l in lines if l and "not-for-merge" not in l]
    return []


def meta_rules(root: Path, board: "Board", meta: dict, staged: bool) -> list[str]:
    """M1–M5: what may be committed to a metarepo."""
    out: list[str] = []
    trunk = board.trunk
    branch = git("branch", "--show-current")
    paths = changed_paths(trunk, staged)
    merging = merging_commits()
    # A detached HEAD at trunk (or behind it) is trunk all the same: `git push origin
    # HEAD:main` lands what is committed there.
    trunk_side = on_trunk(trunk, branch)
    # M1 docs only: the checker and its scripts live in .jig/, like any jig repo's
    for p in paths:
        if p.endswith(SRC_EXT) and not p.startswith(f"{DIR}/"):
            out.append(f"M1 a metarepo holds no code: {p}")
    if merging:
        # M5 main takes only merges of reviewed branches. A job's sync of trunk, and the
        # gate's scratch merge, are merges into something else.
        done = reviewed_commits() if trunk_side else set()
        for c in (merging if trunk_side else []):
            if not counts_reviewed(c, done, board):
                out.append(f"M5 {c[:12]} has no review on record: review it on its branch "
                           f"(`jig reviewed`), then merge")
        return out
    entry = meta["entry_files"]
    # The log's rules start once trunk has it, or with the change that merges the old files into
    # it; a branch that only adds a log beside them can't switch the old rules off.
    by_log = has_log(trunk) or migrated_here(trunk, staged, meta)
    # M2, before the log: a decision row carries its status and date
    rx = re.compile(rf"^\+\s*\|\s*{re.escape(meta['decision_prefix'])}\d+\s*\|(.*)$", re.M)
    md = [p for p in paths if p.endswith(".md")] if not by_log else []
    diff = git("diff", "-U0", base(trunk), *(["--cached"] if staged else []), "--", *md) if md else ""
    for m in rx.finditer(diff):
        cells = [c.lower() for c in table_cells(m.group(1))]
        if not (any(STATUS_CELL.fullmatch(c) for c in cells)
                and any(re.fullmatch(r"\d{4}-\d{2}-\d{2}", c) for c in cells)):
            out.append(f"M2 a decision row needs a Status cell that is exactly a status "
                       f"({'/'.join(ROW_STATUSES)}), optionally `(note)` or "
                       f"`by {meta['decision_prefix']}…`, and a date (YYYY-MM-DD): "
                       f"{m.group(0)[1:].strip()}")
    # M3 a change to what pararepos cite is recorded where they will read it. Judged on the
    # branch since it left trunk, not this commit: a release sees whole branches, so a line
    # an earlier commit added covers this one, and a commit dropping the only line is caught.
    # No renames: a cited file deleted, or moved out of the entry set, is a change too.
    # Trunk's upstream counts as trunk: a pull of it into the branch moves the base, though
    # the local trunk is stale. A deleted log is a change to it, but no line.
    since = (git("merge-base", "HEAD", trunk, f"{trunk}@{{u}}") or git("merge-base", trunk, "HEAD")
             or "HEAD")
    branch_paths = git("-c", "core.quotePath=false", "diff", "--name-only", "--no-renames", since,
                       *(["--cached"] if staged else [])).splitlines()
    record = LOG if by_log else CHANGELOG
    cited = [p for p in branch_paths if p and p != record and is_entry(p, entry)]
    # A README's prose is the metarepo's own; pararepos cite only its Glossary section.
    if "README.md" in cited and glossary_text(at_rev(since, "README.md")) == glossary_text(
            in_index("README.md", staged)):
        cited.remove("README.md")
    if cited and (record not in branch_paths or not in_index(record, staged)):
        out.append(f"M3 {', '.join(cited)} changed: add a line{' or an entry' if by_log else ''} "
                   f"to {record} under ## Unreleased")
    # M4 nothing lands on main except merges; jig's own bookkeeping (the board, handoffs) is
    # the exception, since the hubnode keeps it on trunk. The decision log isn't bookkeeping:
    # a decision is reviewed work, so it comes in by a merge like the pages that cite it.
    # The roadmap's view is that bookkeeping too, where the repo keeps a roadmap.
    keeps = (ROADMAP_VIEW,) if in_index(ROADMAP, staged) or at_rev(trunk, ROADMAP) else ()
    if trunk_side and paths and not all((p.startswith(f"{DIR}/") and p != LOG) or p in keeps
                                      for p in paths):
        out.append(f"M4 {trunk} takes only merges of reviewed branches: commit on a branch")
    return out


def check_subject(msg_file: str, meta: dict) -> list[str]:
    """M6, from the commit-msg hook. Merge commits are exempt: their branches carry the ids."""
    if merging_commits() or os.environ.get("GIT_REFLOG_ACTION", "").startswith("merge"):
        return []
    lines = [l for l in Path(msg_file).read_text().splitlines() if l and not l.startswith("#")]
    subject = lines[0] if lines else ""
    if SUBJECT_IDS.match(subject):
        return []
    return [f"M6 a subject starts with the ids it touches ({meta['decision_prefix']}022: …, "
            f"GLOSSARY: …): {subject!r}"]


def meta_problems(root: Path, meta: dict, trunk: str, rev: str = "") -> list[str]:
    """What makes the metarepo's history unreleasable. Shared by release and pre-push,
    because a fast-forward runs no hook and a hand-made tag skips the release. REV is the
    commit to judge as trunk, when it isn't trunk's ref: what a push sends to it."""
    out: list[str] = []
    pat = re.compile(meta["tag_pattern"])
    tags = [t for t in git("tag", "--list").splitlines() if pat.match(t)]
    released = []
    for t in tags:
        if made_by_release(t):
            released.append(t)
        else:
            out.append(f"tag {t} was not made by jig release: its {LOG} has no "
                       f"`## {t} - <date>` heading. Delete it (`git tag -d {t}`)")
    last = latest_tag(released)
    rng = f"{last}..{rev or trunk}" if last else rev or trunk
    done = reviewed_commits()
    board = Board.load(root)
    for line in git("rev-list", "--first-parent", "--parents", rng).splitlines():
        commit, *parents = line.split()
        if len(parents) > 1:
            if not counts_reviewed(parents[1], done, board):
                out.append(f"{commit[:12]} merges {parents[1][:12]}, which has no review on record")
            continue
        if not parents:
            continue                      # the root commit predates the gates
        files = git("diff", "--name-only", parents[0], commit).splitlines()
        if all(f.startswith(f"{DIR}/") and f != LOG for f in files):
            continue
        if not git("show", f"{parents[0]}:{META}"):
            continue                      # init --meta's own commit: nothing was gated yet
        out.append(f"{commit[:12]} is on {trunk} without a reviewed merge "
                   f"({git('log', '-1', '--format=%s', commit)}): a fast-forward, or a commit "
                   f"made with the hooks off")
    return out


def yanked_pin(loc: Path, pin: str, name: str) -> list[str]:
    """A warning when the pinned release was yanked, with its line saying why and what to pin."""
    text = git("show", f"{pin}:{LOG}", cwd=str(loc))
    head = re.search(rf"^## {re.escape(pin)} - \S+ \[YANKED\][ \t]*\n+(.*)", text, re.M)
    if not head:
        # A yank is added later, on the metarepo's trunk: the pin's own copy can't carry it.
        text = git("show", f"HEAD:{LOG}", cwd=str(loc))
        head = re.search(rf"^## {re.escape(pin)} - \S+ \[YANKED\][ \t]*\n+(.*)", text, re.M)
    return [f"{name} {pin}, the pin, is yanked: {head.group(1).strip()}"] if head else []


def made_by_release(tag: str, cwd: str | None = None) -> bool:
    """Whether TAG carries the heading `jig release` writes: in the log at the tag, or, for a
    tag made before the log, in that tag's CHANGELOG.md, so an old pin still validates."""
    log = re.compile(rf"^## {re.escape(tag)} - \d{{4}}-\d{{2}}-\d{{2}}( \[YANKED\])?[ \t]*$", re.M)
    old = re.compile(rf"^## {re.escape(tag)} — \d{{4}}-\d{{2}}-\d{{2}}\s*$", re.M)
    return bool(log.search(git("show", f"{tag}:{LOG}", cwd=cwd))
                or old.search(git("show", f"{tag}:{CHANGELOG}", cwd=cwd)))


def version_key(tag: str) -> tuple[int, ...]:
    return tuple(int(n) for n in re.findall(r"\d+", tag))


def latest_tag(tags: list[str]) -> str:
    return max(tags, key=version_key) if tags else ""


def cmd_meta_init(root: Path, args) -> int:
    """`jig init --meta`."""
    path = root / META
    if path.exists():
        print(f"{META} already exists")
    else:
        data = json.loads(json.dumps(META_DEFAULTS))
        data["name"] = getattr(args, "name", None) or root.name
        if getattr(args, "prefix", None):
            data["decision_prefix"] = args.prefix
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2) + "\n")
        print(f"wrote {META}")
    genres = None
    if getattr(args, "genres", None):
        genres = list(GENRE_TEMPLATES.get(args.genres) or
                      dict.fromkeys(g.strip() for g in args.genres.split(",") if g.strip()))
        if not genres or any("/" in g for g in genres):
            die(f"--genres: a template ({', '.join(GENRE_TEMPLATES)}) or folder names, a,b,c", 2)
        data = json.loads(path.read_text())
        data["genres"] = genres
        # The pages in the genre folders are what pararepos cite, and what M3 asks a line for.
        entry = data.setdefault("entry_files", list(META_DEFAULTS["entry_files"]))
        if not matches("docs/a/b.md", entry):
            entry.append(META_GENRE_ENTRY)
        path.write_text(json.dumps(data, indent=2) + "\n")
        print(f"genres in {META}: {', '.join(genres)}")
    meta = {**META_DEFAULTS, **json.loads(path.read_text())}
    # The decision log is every repo's, written by init before this.
    if "README.md" in meta["entry_files"] and not (root / "README.md").exists():
        (root / "README.md").write_text(f"# {meta['name'] or root.name}\n")
        print("wrote README.md")
    readme = root / "README.md"
    if "README.md" in meta["entry_files"] and readme.exists() and not glossary_section(readme.read_text()):
        text = readme.read_text()
        readme.write_text(text.rstrip("\n") + "\n\n" + GLOSSARY_SEED)
        print(f"added {GLOSSARY_HOME} to README.md")
    # Each genre is a term of the ecosystem's definition, defined once there: it has no page.
    if genres and readme.exists() and glossary_section(readme.read_text()) is not None:
        lines = readme.read_text().splitlines()
        start = lines.index(GLOSSARY_HOME)
        end = next((j for j in range(start + 1, len(lines)) if re.match(r"#{1,2}\s", lines[j])), len(lines))
        have = set(glossary_terms(readme.read_text()))
        new = [f"### {g}\n\nTODO: what its pages define, and what they are not.\n"
               for g in genres if g not in have]
        if new:
            body = "\n".join(lines[:end]).rstrip("\n") + "\n\n" + "\n".join(new)
            rest = "\n".join(lines[end:])
            readme.write_text(body + ("\n" + rest + "\n" if rest else ""))
            print(f"added a ### heading per genre to README.md {GLOSSARY_HOME}")
    release_script(root, meta=True)
    print(f"Commit these on {Board.trunk_name(root)}. From then on {Board.trunk_name(root)} "
          "takes only reviewed merges, and only `jig release` tags.")
    return 0


# ---------------------------------------------------------------- decision log

# Every repo keeps one log: decision entries and Keep a Changelog lines, grouped by release.
# Open entries change in place under ## Open. An entry says what holds now, so a reversed one is
# removed by the commit adding the entry that supersedes it, and git keeps its text. A release's
# change lines are what that version told its readers, so they are frozen.
LOG = f"{DIR}/decisions.md"
LOG_SEED = (
    "# Decisions and changes\n\n"
    "This log follows Keep a Changelog (https://keepachangelog.com/en/1.1.0/) plus decision entries, "
    "and versions follow Semantic Versioning (https://semver.org/).\n"
    "A breaking change is one that a reader taking the release must act on, and it is released "
    "as a major version.\n\n"
    "## Open\n\n## Unreleased\n")
LOG_STATUSES = ("Accepted", "Open", "Proposed")
CHANGE_GROUPS = ("Added", "Changed", "Deprecated", "Removed", "Fixed", "Security")
RELEASE_HEADING = re.compile(r"^## (v\d+\.\d+(?:\.\d+)?) - (\d{4}-\d{2}-\d{2})( \[YANKED\])?[ \t]*$")
# A status belongs on the line under the heading, where it can change without renaming the entry.
HEADING_STATUS = re.compile(rf"(?i)(?:^(?:{'|'.join(DECISION_STATUSES)})\s*[:—–-]|[(\[]\s*(?:"
                            rf"{'|'.join(DECISION_STATUSES)})\b|(?:\s[—–-]|:)\s*(?:{'|'.join(DECISION_STATUSES)})"
                            rf"\s*$)")


def log_prefix(trunk: str) -> str:
    """The repo's decision id prefix: a metarepo's decision_prefix, D- anywhere else."""
    meta = load_meta(trunk)
    return meta["decision_prefix"] if meta else META_DEFAULTS["decision_prefix"]


def placeholder_re(prefix: str) -> str:
    """A branch's id for an entry not numbered yet, `D-?store-ro`: numbered by `jig merge`."""
    return rf"{re.escape(prefix)}\?[a-z0-9]+(?:-[a-z0-9]+)*"


def released_lines(text: str) -> set[int]:
    """The 0-based numbers of the lines inside a release section of a log, its heading included."""
    out, inside = set(), False
    for n, line in enumerate(text.splitlines()):
        if line.startswith("## "):
            inside = bool(RELEASE_HEADING.match(line))
        if inside:
            out.add(n)
    return out


def log_prefix_of(text: str) -> str:
    """The id prefix a log's own entry headings use, where no config says it: a cached copy."""
    m = re.search(r"^### ([A-Za-z][\w]*-)(?:\d|\?)", text, re.M)
    return m.group(1) if m else META_DEFAULTS["decision_prefix"]


def log_id_re(prefix: str) -> str:
    return rf"(?:{re.escape(prefix)}\d+|{placeholder_re(prefix)})"


def log_entries(text: str, prefix: str) -> list[dict]:
    """The log's decision entries in file order: id, title, section (Open, Unreleased, a
    version, or '' above them all), the status line, the line number and the block's text."""
    head = re.compile(rf"^### ({log_id_re(prefix)})(?![\w?-])[ \t]*(.*?)[ \t]*$")
    out: list[dict] = []
    section = ""
    lines = text.splitlines()
    for n, line in enumerate(lines):
        if line.startswith("## "):
            m = RELEASE_HEADING.match(line)
            section = m.group(1) if m else line[3:].strip()
        if line.startswith(("## ", "### ")) and out and out[-1]["end"] is None:
            out[-1]["end"] = n
        m = head.match(line)
        if m:
            status = next((l.strip() for l in lines[n + 1:] if l.strip()), "")
            if status.startswith("#"):
                status = ""
            out.append({"id": m.group(1), "title": m.group(2), "section": section,
                        "status": status, "line": n + 1, "start": n, "end": None})
    for e in out:
        e["block"] = "\n".join(lines[e["start"]:e["end"] if e["end"] is not None else len(lines)]).rstrip()
    return out


def status_parts(status: str, prefix: str) -> tuple[str, str, str, list[str]] | None:
    """(status, who, date, superseded ids) from `Accepted (Dave, 2026-11-10). Supersedes D-007.`
    Who is any text before the last date, as a register row's note was: `Proposed (runtime team,
    from the 2026-10-27 research, 2026-10-27).` So every row the old M2 took converts to a line
    this one takes."""
    ids = log_id_re(prefix)
    m = re.fullmatch(rf"({'|'.join(LOG_STATUSES)}) \((?:(.+), )?(\d{{4}}-\d{{2}}-\d{{2}})\)\."
                     rf"(?: Supersedes ({ids}(?:,? (?:and )?{ids})*)\.)?", status)
    if not m:
        return None
    return m.group(1), (m.group(2) or "").strip(), m.group(3), re.findall(ids, m.group(4) or "")


def release_sections(text: str) -> dict[str, tuple[str, bool, list[str]]]:
    """Each release section: version → (date, yanked, its lines up to the next section)."""
    out: dict[str, tuple[str, bool, list[str]]] = {}
    cur = None
    for line in text.splitlines():
        if line.startswith("## "):
            m = RELEASE_HEADING.match(line)
            cur = m.group(1) if m else None
            if m:
                out[cur] = (m.group(2), bool(m.group(3)), [])
            continue
        if cur:
            out[cur][2].append(line)
    return out


def trimmed(lines: list[str]) -> list[str]:
    while lines and not lines[0].strip():
        lines = lines[1:]
    while lines and not lines[-1].strip():
        lines = lines[:-1]
    return lines


def log_problems(text: str, prefix: str, trunk: str = "") -> list[str]:
    """M2 for the log: every entry's heading, status line and supersedes links, and which
    section may hold which status. With TRUNK, a link to an entry the log removed resolves
    through trunk's history of the log."""
    out: list[str] = []
    entries = log_entries(text, prefix)
    known = {e["id"] for e in entries}
    seen: set[str] = set()
    for e in entries:
        at = f"{LOG}:{e['line']} {e['id']}"
        if e["id"] in seen:
            out.append(f"M2 {at} is a second entry with that id: an id names one decision")
        seen.add(e["id"])
        if HEADING_STATUS.search(e["title"]):
            out.append(f"M2 {at}: the heading is the id and title only; the status goes on the "
                       f"line under it")
        parts = status_parts(e["status"], prefix)
        if parts is None:
            out.append(f"M2 {at} needs a status line under its heading: `Accepted (who, "
                       f"YYYY-MM-DD).`, or under ## Open `Open (YYYY-MM-DD).` / `Proposed (YYYY-MM-DD).`, "
                       f"optionally ending `Supersedes {prefix}007.`")
            continue
        status, who, _, sup = parts
        if status == "Accepted" and not who:
            out.append(f"M2 {at}: an accepted entry says who decided: `Accepted (who, YYYY-MM-DD).`")
        if e["section"] == "Open" and status == "Accepted":
            out.append(f"M2 {at} is accepted: move it out of ## Open, to ## Unreleased")
        elif e["section"] not in ("Open", "") and status != "Accepted":
            where = "## Unreleased" if e["section"] == "Unreleased" else f"release {e['section']}"
            out.append(f"M2 {at} is {status.lower()}: {where} holds accepted entries only; it "
                       f"belongs under ## Open")
        elif e["section"] == "":
            out.append(f"M2 {at} sits above ## Open: an entry belongs under ## Open, ## Unreleased "
                       f"or a release")
        for s in sup:
            if s not in known and not (trunk and in_log_history(s, trunk)):
                out.append(f"M2 {at} supersedes {s}, which has no entry in {LOG}"
                           + (f" or in {trunk}'s history of it" if trunk else ""))
            elif s == e["id"]:
                out.append(f"M2 {at} supersedes itself")
    return out


def replaced(e: dict, prefix: str) -> list[str]:
    """The ids entry E supersedes once it is accepted: a proposal names what it would replace,
    and retires nothing until it is accepted."""
    parts = status_parts(e["status"], prefix)
    return parts[3] if parts and parts[0] == "Accepted" else []


def shallow(cwd: str | None = None) -> bool:
    return git("rev-parse", "--is-shallow-repository", cwd=cwd) == "true"


def history_re(want: str) -> str:
    """An ERE for git's -G: the heading of entry WANT, whole, so D-001 is not D-0010. A
    number id only: a D-?slug is no history, and its `?` would be a quantifier."""
    return rf"^### {want}($|[^0-9A-Za-z_?-])"


def in_log_history(want: str, rev: str) -> bool:
    """Whether the log at some commit in REV's history had an entry WANT. A shallow clone
    can't say, so the link passes there: refusing every log commit in it would be worse."""
    if "?" in want:
        return False
    if shallow():
        return True
    # Merges diffed too: `jig merge` numbers a job's D-?slug in the merge commit alone.
    return bool(git("log", "-m", "-E", f"-G{history_re(want)}", "--format=%h", "-1", rev, "--", LOG))


def removed_entries(old: str, new: str) -> tuple[str, list[dict]]:
    """OLD with each entry block NEW no longer has taken out, and those of them outside
    ## Open that no accepted entry in NEW supersedes: only that removes one."""
    prefix = log_prefix_of(old)
    now = log_entries(new, prefix)
    gone = [e for e in log_entries(old, prefix) if e["id"] not in {n["id"] for n in now}]
    named = {s for e in now for s in replaced(e, prefix)}
    struck = struck_ids(old, new, prefix)
    lines = old.splitlines()
    for e in reversed(gone):
        del lines[e["start"]:e["start"] + e["block"].count("\n") + 1]
    return "\n".join(lines), [e for e in gone if e["id"] not in named and e["section"] != "Open"
                              and id_number(e["id"], prefix) not in struck]


def removed_lines(text: str) -> set[str]:
    """The change lines under ## Unreleased, ### Removed."""
    out, section, group = set(), "", ""
    for line in text.splitlines():
        if line.startswith("## "):
            section, group = line[3:].strip(), ""
        elif line.startswith("### "):
            group = line[4:].strip()
        elif section == "Unreleased" and group == "Removed" and line.startswith("- "):
            out.add(line.rstrip())
    return out


def struck_ids(old: str, new: str, prefix: str) -> set[int]:
    """The numbers of the ids NEW's added `- D-040: …` lines under ## Unreleased ### Removed
    open with: a project entry struck from the log has no product successor, so that line is
    what lets it go, even from a release. Only the line's own id: one it mentions later in a
    sentence is a change line about something else."""
    rx = re.compile(rf"- {re.escape(prefix)}(\d+):")
    return {int(m.group(1)) for line in removed_lines(new) - removed_lines(old) if (m := rx.match(line))}


def id_number(eid: str, prefix: str) -> int | None:
    m = re.fullmatch(rf"{re.escape(prefix)}(\d+)", eid)
    return int(m.group(1)) if m else None


def touches_dropped(lines: list[str], keep: bool = False) -> list[str]:
    """LINES without each entry's Touches line, the one right under its status line (KEEP: the
    line stays, its pages emptied). Touches says what an entry is about, not what it decided,
    so a released entry may gain or change it: that is how the backfill reaches a release."""
    out = []
    for i, l in enumerate(lines):
        if (l.startswith("Touches:") and i > 1 and lines[i - 2].startswith("### ")
                and re.match(rf"(?:{'|'.join(LOG_STATUSES)}) \(", lines[i - 1])):
            if keep:
                out.append("Touches:")
            continue
        out.append(l)
    return out


def frozen_problems(old: str, new: str, trunk: str, only: set[str] | None = None) -> list[str]:
    """A commit may remove a superseded entry from a released section, in the commit adding the
    entry superseding it, or a struck one, in the commit adding a ### Removed line naming it; add or change an entry's Touches line (M2 checks its pages); and add
    ` [YANKED]` to a release heading with one line under it saying why. Anything else in a
    released section, its change lines above all, is frozen. ONLY: judge those releases alone."""
    out: list[str] = []
    old, bare = removed_entries(old, new)
    if only is not None:
        bare = [e for e in bare if e["section"] in only]
    out += [f"{LOG}: {e['id']} is removed from release {e['section']}, and no entry in the log "
            f"supersedes it: an entry is removed only by the commit adding the accepted one "
            f"that says `Supersedes {e['id']}.`, or, struck as project scope, by the commit adding "
            f"under ## Unreleased ### Removed the line `- {e['id']}: project scope, not a product "
            f"decision.`: add it in the same commit" for e in bare if e["section"] not in ("Unreleased", "")]
    prefix = log_prefix_of(new)
    have = {id_number(e["id"], prefix) for e in log_entries(new, prefix)}
    out += [f"{LOG}: the ### Removed line for {prefix}{n:03d} strikes an entry the log still has: "
            f"remove the entry in the same commit, or drop the line"
            for n in sorted(struck_ids(old, new, prefix) & have) if only is None]
    after = release_sections(new)
    for version, (day, yanked, body) in release_sections(old).items():
        if only is not None and version not in only:
            continue
        if version not in after:
            out.append(f"{LOG}: release {version} is gone; a released section is never edited or removed")
            continue
        day2, yanked2, body2 = after[version]
        # A removed block leaves its blank lines either side: one blank is as good as two.
        was, now = (trimmed([l for i, l in enumerate(b) if l.strip() or i and b[i - 1].strip()])
                    for b in (touches_dropped(body), touches_dropped(body2)))
        if yanked2 and not yanked and now and not now[0].startswith("#"):
            now = trimmed(now[1:])
        if day2 != day or (yanked and not yanked2) or was != now:
            out.append(f"{LOG}: release {version} is frozen on {trunk}: add a new accepted entry that "
                       f"supersedes what changed and remove the old one; a release's change lines stay, and only "
                       f"` [YANKED]` and its one line, or an entry's Touches line, may be added to a release")
    return out


def outside_open_deleted(old: str, new: str) -> bool:
    """Whether NEW drops or rewrites a line of OLD outside ## Open: elsewhere the log only grows,
    but for an entry NEW supersedes, which it removes, and an entry's Touches line, which may
    change."""
    old, bare = removed_entries(old, new)
    if bare:
        return True
    a, b = touches_dropped(old.splitlines(), keep=True), touches_dropped(new.splitlines(), keep=True)
    section, where = "", []
    for line in a:
        if line.startswith("## "):
            section = line[3:].strip()
        where.append(section)
    ops = difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes()
    return any(where[i] != "Open" and a[i].strip()
               for tag, i1, i2, _, _ in ops if tag in ("replace", "delete") for i in range(i1, i2))


def log_rules(trunk: str, staged: bool, trunk_side: bool = False) -> list[str]:
    """M2 and the released sections, in every repo, whenever a change touches the log. On trunk
    an id is a number: a D-?<slug> that got there would be released as one."""
    new = in_index(LOG, staged)
    since = since_trunk(trunk)
    old = at_rev(since, LOG)
    # A branch can hold trunk commits its local trunk lacks (made from origin's, or pulled):
    # a release HEAD has beyond the merge base is trunk's too. Only the releases `--merge-log`
    # writes from the merge base's CHANGELOG.md, before the base had a log, are the branch's.
    head = at_rev("HEAD", LOG) if since != "HEAD" else old
    converted = set() if old else converted_versions(trunk, since)
    beyond = set(release_sections(head)) - set(release_sections(old)) - converted
    if not new:
        if old or (head and (beyond or not unconverting(trunk, since, staged))):
            return [f"{LOG} is the repo's decision log: it is never deleted"]
        return []
    prefix = log_prefix(trunk)
    out = log_problems(new, prefix, trunk) + frozen_problems(old, new, trunk)
    if beyond:
        out += frozen_problems(head, new, trunk, only=beyond)
    out += touches_problems(old, new, prefix, trunk, staged)
    if trunk_side:
        out += [f"M2 {LOG}:{e['line']} {e['id']} isn't numbered, and {trunk} takes numbers only: "
                f"`jig merge --number` numbers what a merge in progress brings in"
                for e in log_entries(new, prefix) if "?" in e["id"]]
    return out


def on_trunk(trunk: str, branch: str) -> bool:
    """On trunk, or a detached HEAD at trunk or behind it: `git push origin HEAD:main` lands
    what is committed there."""
    return branch == trunk or (not branch and subprocess.run(
        ["git", "merge-base", "--is-ancestor", "HEAD", trunk], capture_output=True).returncode == 0)


def number_placeholders(root: Path, trunk: str) -> list[str]:
    """`jig merge`: number each `D-?<slug>` entry the merge brings into the log, after the
    highest number the log has, in every file the merge changes. Only ids with an entry: the
    same text elsewhere (a test, a rule's example) is no decision. Called with the merge
    staged, before its commit; the merge message lists each number, so git log keeps the map."""
    prefix = log_prefix(trunk)
    files = [f for f in git("-c", "core.quotePath=false", "diff", "--cached", "--name-only",
                            "--diff-filter=AMR", "HEAD").splitlines() if f]
    texts = dict(head_texts_at(":", files))
    log = texts.get(LOG) or git("show", f":{LOG}")
    had = {e["id"] for e in log_entries(git("show", f"HEAD:{LOG}"), prefix)}
    found = [e["id"] for e in log_entries(log, prefix) if "?" in e["id"] and e["id"] not in had]
    if not found:
        return []
    nums = [m.group(1) for m in re.finditer(rf"^### {re.escape(prefix)}(\d+)", log, re.M)]
    # Above every number the log names now or ever did, so a rejected entry's is never given
    # again, and above every number an open job holds from a counter over the log.
    board = Board.load(root)
    held = [n for k, v in (board.data.get("reserve") or {}).items()
            if isinstance(v, dict) and matches(LOG, v.get("files") or [])
            for j in board.jobs.values() for n in held_numbers(j).get(k, ())]
    top = max([highest_id(log, prefix, history=True), *held])
    width = max([3, *(len(n) for n in nums)])
    given = {p: f"{prefix}{top + i:0{width}d}" for i, p in enumerate(dict.fromkeys(found), 1)}
    ph = re.compile(rf"(?<![\w-])(?:{'|'.join(map(re.escape, given))})(?![\w-])")
    for f, text in texts.items():
        new = ph.sub(lambda m: given[m.group(0)], text)
        if new != text:
            (root / f).write_text(new)
            git("add", "--", str(root / f), check=True)
    lines = [f"{p} → {n}" for p, n in given.items()]
    msg = Path(git("rev-parse", "--path-format=absolute", "--git-path", "MERGE_MSG"))
    if msg.is_file():
        msg.write_text(msg.read_text().rstrip("\n") + "\n\nNumbered: " + ", ".join(lines) + "\n")
    return lines


def numbers_given(trunk: str) -> set[int]:
    """In a merge on trunk, the numbers `jig merge` gave the job's D-?<slug> entries: an index
    entry whose title is a placeholder entry's in what is merged in, numbered where that side
    has no such number. A counter over the log takes them as the job's own (R6)."""
    merging = merging_commits()
    if len(merging) != 1:
        return set()
    prefix = log_prefix(trunk)
    theirs = log_entries(git("show", f"{merging[0]}:{LOG}"), prefix)
    titles = {e["title"] for e in theirs if "?" in e["id"]}
    had = {e["id"] for e in theirs}
    return {int(e["id"][len(prefix):]) for e in log_entries(git("show", f":{LOG}"), prefix)
            if e["title"] in titles and e["id"] not in had and e["id"][len(prefix):].isdigit()}


def head_texts_at(rev: str, paths: list[str]) -> list[tuple[str, str]]:
    """PATHS' text at REV (':' the index), binary files left out."""
    out = []
    for p in paths:
        body = subprocess.run(["git", "show", f"{rev}{p}" if rev == ":" else f"{rev}:{p}"],
                              capture_output=True).stdout
        if body and b"\0" not in body:
            out.append((p, body.decode(errors="replace")))
    return out


def removed_entry(want: str, prefix: str, rev: str = "HEAD",
                  cwd: str | None = None) -> tuple[str, dict, dict | None] | None:
    """Entry WANT as it stood in the last commit of REV's history whose log had it, that
    commit, and the accepted entry superseding it in the commit that removed it."""
    if "?" in want:
        return None
    # First parent, merges diffed against it: a job's D-?slug is numbered only in its merge.
    for c in git("log", "-m", "--first-parent", "-E", f"-G{history_re(want)}", "--format=%H", rev,
                 "--", LOG, cwd=cwd).splitlines():
        here = log_entries(git("show", f"{c}:{LOG}", cwd=cwd), prefix)
        if any(e["id"] == want for e in here):
            return c, next(e for e in here if e["id"] == want), None
        had = next((e for e in log_entries(git("show", f"{c}^:{LOG}", cwd=cwd), prefix) if e["id"] == want), None)
        if had:
            by = next((e for e in here if want in replaced(e, prefix)), None)
            return git("rev-parse", f"{c}^", cwd=cwd), had, by
    return None


def holds_now(want: str, text: str, prefix: str, rev: str | None = None,
              cwd: str | None = None) -> str | None:
    """The entry in log TEXT that holds in place of WANT: each accepted supersedes link
    followed forward, and with REV, through git where TEXT no longer has a link's entry."""
    entries = log_entries(text, prefix)
    have = {e["id"] for e in entries}
    by = {s: e["id"] for e in entries for s in replaced(e, prefix)}
    cur, seen = want, set()
    while cur not in seen:
        seen.add(cur)
        if cur in by:
            cur = by[cur]
        elif rev and cur not in have and (found := removed_entry(cur, prefix, rev, cwd)) and found[2]:
            cur = found[2]["id"]
        else:
            break
    return cur if cur != want and cur in have else None


def cmd_decision(root: Path, args) -> int:
    """Print a decision entry and its supersedes chain. A superseded entry is removed from the
    log, so one the log doesn't have is read from git, and its chain walked to what holds now."""
    if args.peers:
        return cmd_peers(root, args)
    board = Board.load(root)
    prefix = log_prefix(board.trunk)
    path = root / LOG
    entries = log_entries(path.read_text() if path.exists() else "", prefix)
    by_id = {e["id"]: e for e in entries}
    want = args.id
    if want not in by_id:
        # D-12 and D-012 are one decision, as R6 counts it.
        want = next((i for i in by_id if decision_id(i) == decision_id(want)), want)
    if want not in by_id:
        steps, cur = [], want
        while cur and cur not in by_id and len(steps) < 50 and (found := removed_entry(cur, prefix)):
            steps.append(found)
            cur = found[2]["id"] if found[2] else ""
        if not steps and shallow():
            die(f"no entry {args.id} in {LOG}, and this clone is shallow: its text may be in the "
                f"history it lacks (`git fetch --unshallow`)", 1)
        if not steps:
            die(f"no entry {args.id} in {LOG} or in its history", 1)
        commit, e, by = steps[0]
        print(e["block"])
        where = e["section"] if e["section"] not in ("Open", "Unreleased", "") else f"## {e['section'] or 'Open'}"
        print(f"\n{want} was removed from {LOG}; it stood last at {commit[:7]}, in {where}.")
        for _, old, by in steps:
            if by:
                print(f"  {old['id']} is superseded by {by['id']} {by['title']}")
        if cur in by_id:
            print(f"What holds now is {cur} {by_id[cur]['title']}: `jig decision {cur}` reads it.")
        return 0
    sups = {e["id"]: (status_parts(e["status"], prefix) or ("", "", "", []))[3] for e in entries}
    # Only an accepted entry holds in place of what it names.
    later = {old: e["id"] for e in entries for old in replaced(e, prefix)}
    chain, cur = [], want
    while cur in by_id and cur not in chain:
        chain.insert(0, cur)
        cur = next((s for s in sups.get(cur, []) if s in by_id), None)
    cur = later.get(want)
    while cur and cur not in chain:
        chain.append(cur)
        cur = later.get(cur)

    def where(e: dict) -> str:
        return "## Open" if e["section"] == "Open" else e["section"] or "above ## Open"

    print(by_id[want]["block"])
    if len(chain) > 1:
        print("\nChain, oldest first:")
        for i in chain:
            e = by_id[i]
            mark = "  ← this one" if i == want else ""
            print(f"  {i} {e['title']} ({where(e)}){mark}")
    if want in later:
        last = chain[-1]
        print(f"\n{want} is superseded by {later[want]}; what holds now is {last} {by_id[last]['title']}.")
    for s in sups.get(want, []):
        if s not in by_id:
            print(f"\n{want} supersedes {s}, which is removed from {LOG}: `jig decision {s}` reads it from git.")
    return 0


# ------------------------------------------------------------- what a decision touches
# Two entries that rule on one situation differently contradict each other, and only a reader
# can tell. jig.py picks the pairs a reader must see side by side: entries whose Touches lines
# name the same page, or a page and one below it. It never judges a pair.

SELF = "."     # this repo, in a page key
META_KEY = "meta"   # a pararepo's metarepo, in a page key
# The page in parentheses holds no blank or parenthesis, so an answer may hold both.
PAIR_LINE = re.compile(r"^- \[[ xX]\] (\S+) vs (\S+) § (\S+) \(([^()\s]+)\): (.*)$")
PAIR_SHAPED = re.compile(r"^- \[.\] \S+ vs \S+ § ")
UNREAD = "not read for peers"


def entry_touches(block: str) -> list[str] | None:
    """The pointers on an entry's `Touches:` line, the line right under its status line; None
    when it has no such line."""
    lines = [l.strip() for l in block.splitlines()[1:] if l.strip()]
    m = re.match(r"Touches:(.*)$", lines[1]) if len(lines) > 1 else None
    if not m:
        return None
    return [p for p in (x.strip().strip("`").strip().rstrip(".") for x in m.group(1).split(",")) if p]


def rule_sentence(block: str) -> str:
    """An entry's first body sentence, after its status and Touches lines: what it rules."""
    lines = [l.strip() for l in block.splitlines()[1:] if l.strip()]
    body = lines[2:] if entry_touches(block) is not None else lines[1:]
    text = " ".join(body)
    m = re.match(r"(.+?[.!?])(?=\s|$)", text)
    return (m.group(1) if m else text)[:240]


def page_key(path: str) -> str:
    """A page by what it stands for, so its flat and folder forms are one: docs/a/b for
    docs/a/b.md and docs/a/b/b.md alike."""
    if path.startswith("docs/") and path.endswith(".md") and not reference_file(path):
        return page_folder(path)
    return path


def split_pointer(ptr: str, names: dict[str, str]) -> tuple[str, str]:
    """(repo key, path) for a pointer, in the forms RULES.md gives a pointer: `<repo>:<path>`,
    `<repo>/<path>`, or a path of the writer's own (key ''). `docs/…` is always a path: a repo
    named docs is reached as `docs:<path>`. A `<repo>:` NAMES doesn't know keys as `?<repo>`."""
    m = re.match(r"([\w.-]+):(.+)$", ptr)
    if m:
        return names.get(m.group(1).casefold(), f"?{m.group(1)}"), m.group(2)
    head, _, rest = ptr.partition("/")
    if rest and head != "docs" and head.casefold() in names:
        return names[head.casefold()], rest
    return "", ptr


def touch_key(ptr: str, writer: str, names: dict[str, str]) -> tuple[str, str]:
    """(repo, page key) for a pointer written in WRITER's log."""
    repo, path = split_pointer(ptr, names)
    return repo or writer, page_key(path)


def keys_meet(a: tuple[str, str], b: tuple[str, str]) -> bool:
    """One page, or one page above the other: a page's folder holds the pages below it, as
    pages_above climbs."""
    return a[0] == b[0] and (a[1] == b[1] or a[1].startswith(b[1] + "/") or b[1].startswith(a[1] + "/"))


def superseded_ids(entry: dict, prefix: str) -> set[str]:
    return set((status_parts(entry["status"], prefix) or ("", "", "", []))[3])


def live_entries(text: str, prefix: str) -> list[dict]:
    """The log's entries no other entry in it supersedes: a superseded one rules nothing now."""
    entries = log_entries(text, prefix)
    gone = {s for e in entries for s in superseded_ids(e, prefix)}
    return [e for e in entries if e["id"] not in gone]


def touch_names(root: Path, trunk: str) -> dict[str, str]:
    """The repo names a pointer may carry, each to its key: this repo's own, a pararepo's
    metarepo, a metarepo's registered pararepos."""
    names = {n.casefold(): SELF for n in this_repo_names(root) - {"this"}}
    para, meta = load_para(trunk), load_meta(trunk)
    if para:
        names[para["meta"].casefold()] = META_KEY
    for p in (meta or {}).get("pararepos", []):
        names.setdefault(p.casefold(), p)
    return names


def meta_cache(root: Path, para: dict) -> tuple[Path | None, str]:
    """The metarepo's cache at the pin, or None and why it can't be read: a cache at another
    pin rules on what the pararepo no longer cites."""
    for cache in (root / CACHE, main_root() / CACHE):
        if (cache / "PIN").is_file():
            at = (cache / "PIN").read_text().split("\n")[0]
            if at == para.get("pin"):
                return cache, ""
            return None, (f"{para['meta']}'s log: {CACHE}/ is at {at}, the pin is {para.get('pin')}: "
                          "run `jig sync`")
    return None, f"{para['meta']}'s log at the pin, which {CACHE}/ doesn't hold: run `jig sync`"


def peer_logs(root: Path, trunk: str) -> tuple[list[tuple[str, str, str]], list[str]]:
    """Every other repo's log whose entries can be peers, as (key of the repo that wrote it, how
    a line names it, its text): a pararepo's metarepo's at the pin, a metarepo's registered
    pararepos' on their trunks. And one line per log that could not be read."""
    logs, unread = [], []
    para, meta = load_para(trunk), load_meta(trunk)
    if para:
        cache, why = meta_cache(root, para)
        if cache and (cache / LOG).is_file():
            logs.append((META_KEY, f"{para['meta']}/{LOG}", (cache / LOG).read_text(errors="replace")))
        else:
            unread.append(why or f"{para['meta']}'s log, which its cache at the pin doesn't hold")
    for p in (meta or {}).get("pararepos", []):
        loc = repo_path(p)
        if loc is None or not loc.is_dir():
            unread.append(f"{p}, which `jig repos` doesn't list here")
            continue
        text = git("show", f"{Board.trunk_name(loc)}:{LOG}", cwd=str(loc))
        if text:
            logs.append((p, f"{p}/{LOG}", text))
    return logs, unread


def touching_entries(text: str, prefix: str, writer: str, label: str,
                     names: dict[str, str]) -> list[dict]:
    """A log's live entries, each with its pointers and page keys."""
    out = []
    for e in live_entries(text, prefix):
        ptrs = entry_touches(e["block"]) or []
        out.append({**e, "label": label, "writer": writer, "pointers": ptrs,
                    "keys": [touch_key(p, writer, names) for p in ptrs]})
    return out


def touching(root: Path, trunk: str, own: str) -> tuple[list[dict], list[str]]:
    """Every live entry in this repo's log OWN and in every peer log, and the logs not read."""
    names = touch_names(root, trunk)
    logs, unread = peer_logs(root, trunk)
    out = touching_entries(own, log_prefix(trunk), SELF, LOG, names)
    for writer, label, text in logs:
        out += touching_entries(text, log_prefix_of(text), writer, label, names)
    return out, unread


def peers_of(entry: dict, every: list[dict], prefix: str) -> list[tuple[dict, str]]:
    """ENTRY's peers, each with the pointer of ENTRY's they meet on. Not itself, nor what it
    supersedes or what supersedes it: a chain is one decision over time."""
    out = []
    for o in every:
        if o["writer"] == entry["writer"] and (o["id"] == entry["id"] or o["id"] in superseded_ids(entry, prefix)
                                               or entry["id"] in superseded_ids(o, prefix)):
            continue
        hit = next((p for p, k in zip(entry["pointers"], entry["keys"])
                    if any(keys_meet(k, ok) for ok in o["keys"])), None)
        if hit:
            out.append((o, hit))
    return out


def pair_lines(root: Path, trunk: str, rng: str) -> list[str]:
    """Fold-in: one line per peer of each entry the branch adds or changes, answered agrees,
    narrows or conflicts. Two of the branch's own entries that are peers get one line. Trunk's
    entries are read from trunk, so a branch can't drop a peer by editing it."""
    prefix = log_prefix(trunk)
    right = rng.partition("..")[2].lstrip(".") or "HEAD"
    edited = edited_decisions(root, prefix, rng)
    names = touch_names(root, trunk)
    head = log_entries(git("show", f"{right}:{LOG}", cwd=str(root)), prefix)
    gone = {s for e in head for s in superseded_ids(e, prefix)}
    changed = [e for e in touching_entries(git("show", f"{right}:{LOG}", cwd=str(root)), prefix, SELF, LOG, names)
               if e["id"] in edited and e["id"] not in gone]
    if not changed:
        return []
    every, unread = touching(root, trunk, git("show", f"{trunk}:{LOG}", cwd=str(root)))
    every += changed
    out, seen = [], set()
    for e in changed:
        for o, ptr in peers_of(e, every, prefix):
            pair = frozenset([(SELF, e["id"]), (o["writer"], o["id"])])
            if pair in seen:
                continue
            seen.add(pair)
            out.append(f"- [ ] {e['id']} vs {o['label']} § {o['id']} ({ptr}): ___")
    out += [f"- [ ] {UNREAD}: {u} — read it beside the changed entries, or why not: ___" for u in unread]
    return out


def pair_key(line: str) -> tuple[str, str, str] | None:
    m = PAIR_LINE.match(line.strip())
    return (m.group(1), m.group(2), m.group(3)) if m else None


def pair_problem(line: str) -> str:
    """Why a fold-in line shaped like a pair line isn't answered as one, or ''."""
    l = line.strip()
    if not PAIR_SHAPED.match(l):
        return ""
    m = PAIR_LINE.match(l)
    if not m:
        return "keep a pair line's shape: `<id> vs <log> § <id> (<page>): <answer>`"
    a = m.group(5).strip()
    if re.match(r"agrees\b", a, re.I):
        return ""
    w = re.match(r"(narrows|conflicts)\b[ \t]*:?[ \t]*(.*)$", a, re.I)
    if w:
        word = w.group(1).lower()
        return "" if re.search(r"\w", w.group(2)) else \
            f"{word} needs its {'how' if word == 'narrows' else 'resolution'}: `{word}: …`"
    return "answer agrees, narrows: <how>, or conflicts: <resolution>"


def gate_pairs(where: Path, trunk: str, fold: str) -> list[str]:
    """The pairs the job's entries make with trunk as the gate merged it, that the note's
    fold-in doesn't answer: a job that merged since the handoff ruled on the same page."""
    have = {k for l in fold.splitlines() if (k := pair_key(l))}
    return [l for l in pair_lines(where, trunk, f"{trunk}...HEAD")
            if (k := pair_key(l)) and k not in have]


def migrating_log(trunk: str, staged: bool) -> bool:
    """This change is `jig update --merge-log`: a register's rows or CHANGELOG.md's sections
    were there before it, and are gone after it."""
    meta = load_meta(trunk)
    prefix = (meta or {}).get("decision_prefix")
    return bool(olds := merged_files_at(since_trunk(trunk), meta)) and not any(
        holds_old_log(in_index(f, staged), f, prefix) for f in olds)


def merged_files_at(at: str, meta: dict | None) -> list[str]:
    """The files at AT `--merge-log` merges: CHANGELOG.md with its sections, and a register with
    rows (an entry file, or one named decisions.md). Not every table in a page is a register."""
    entry, prefix = (meta or {}).get("entry_files", []), (meta or {}).get("decision_prefix")
    return [f for f in git("ls-tree", "-r", "--name-only", at).splitlines()
            if (f == CHANGELOG or (f.endswith(".md") and not f.startswith(f"{DIR}/")
                                   and (f in entry or Path(f).name.lower() == "decisions.md")))
            and holds_old_log(at_rev(at, f), f, prefix)]


def converted_versions(trunk: str, since: str) -> set[str]:
    """The releases this branch's `--merge-log` wrote: in SINCE's CHANGELOG.md, and in the log as
    the commit adding it wrote it. A release trunk made later, under a version it reused, isn't;
    nor is anything when a remote's trunk has that commit, since then trunk converted."""
    added = git("log", "--diff-filter=A", "--format=%H", "--reverse", f"{since}..HEAD", "--", LOG).split()
    if not added:
        return set()
    remotes = [r for r in git("for-each-ref", "--format=%(refname)", "refs/remotes").split()
               if r.endswith(f"/{trunk}")]
    if any(subprocess.run(["git", "merge-base", "--is-ancestor", added[0], r],
                          capture_output=True).returncode == 0 for r in remotes):
        return set()
    was = {f"v{m.group(1)}" for l in at_rev(since, CHANGELOG).splitlines() if (m := OLD_RELEASE.match(l))}
    return was & set(release_sections(at_rev(added[0], LOG)))


def unconverting(trunk: str, since: str, staged: bool) -> bool:
    """Removing the log undoes the branch's `--merge-log`: every file it merged is back as it was."""
    olds = merged_files_at(since, load_meta(trunk))
    return bool(olds) and all(in_index(f, staged).strip() == at_rev(since, f).strip() for f in olds)


def migrated_ids(trunk: str, prefix: str | None) -> set[str]:
    """The ids of the register rows where the branch left trunk: the entries `--merge-log`
    writes from them, which may lack Touches."""
    was = since_trunk(trunk)
    rx = re.compile(r"^\s*\|\s*([A-Z][A-Z0-9]*-\d+)\s*\|")
    return {m.group(1) for f in merged_files_at(was, load_meta(trunk))
            for row in rows_in(at_rev(was, f), prefix) if (m := rx.match(row))}


def touches_problems(old: str, new: str, prefix: str, trunk: str, staged: bool) -> list[str]:
    """M2: an entry added or changed names the pages it touches, and each is a docs page. An
    entry as trunk has it is left alone until it changes. `jig update --merge-log` converting a
    register writes entries decided before Touches; they are backfilled from update's list. Only
    those: an entry a later commit on the branch adds names its pages."""
    root = Path.cwd()
    migrating = not log_entries(old, prefix) and migrating_log(trunk, staged)
    converted = migrated_ids(trunk, (load_meta(trunk) or {}).get("decision_prefix")) if migrating else set()
    names = touch_names(root, trunk)
    para, meta = load_para(trunk), load_meta(trunk)
    cache, _ = meta_cache(root, para) if para else (None, "")
    docmap = list((Board.load(root).data.get("docmap") or {})) if not meta else []
    was = {e["id"]: e["block"] for e in log_entries(old, prefix)}
    out = []
    for e in log_entries(new, prefix):
        if was.get(e["id"]) == e["block"] or e["id"] in converted:
            continue
        at = f"{LOG}:{e['line']} {e['id']}"
        ptrs = entry_touches(e["block"])
        if not ptrs:
            shared = f"`{para['meta']}/docs/<genre>/<page>.md` for what it shares, " if para else ""
            out.append(f"M2 {at} names no page it touches: under its status line, `Touches: "
                       f"{shared}docs/<page>.md` ({DIR}/RULES.md, Decision log)")
            continue
        for p in ptrs:
            repo, path = split_pointer(p, names)
            docs = path.startswith("docs/") and path.endswith(".md")
            if repo.startswith("?"):
                why = f"names {repo[1:]}, which is no repo jig knows here"
            elif repo == META_KEY:
                # With no cache at the pin, only its shape: the gate's checkout reads the cache.
                why = ("" if docs and (cache is None or any((cache / f).is_file() for f in page_forms(path)))
                       else "is no page in the metarepo at the pin")
            elif repo not in ("", SELF):
                why = "is a pararepo's page: a metarepo names only its own"
            elif not (docs or any(same_page(k, path) for k in docmap)):
                why = "is no docs page: a page under docs/" + ("" if meta else " or one docmap names")
            else:
                why = "" if any(body_now(f, staged) for f in page_forms(path)) else "is no page here"
            if why:
                out.append(f"M2 {at} touches {p}, which {why}" if why.startswith("is")
                           else f"M2 {at} touches {p}: it {why}")
    return out


def cmd_peers(root: Path, args) -> int:
    """`jig decision <id> --peers`: the entries a reader should read beside this one."""
    board = Board.load(root)
    prefix = log_prefix(board.trunk)
    path = root / LOG
    every, unread = touching(root, board.trunk, path.read_text() if path.exists() else "")
    mine = [e for e in every if e["writer"] == SELF]
    entry = next((e for e in mine if e["id"] == args.id), None) or \
        next((e for e in mine if decision_id(e["id"]) == decision_id(args.id)), None)
    if entry is None:
        die(f"no live entry {args.id} in {LOG}", 1)
    print(f"{entry['id']} {entry['title']}")
    print(f"  {rule_sentence(entry['block'])}")
    if not entry["pointers"]:
        print(f"\n{entry['id']} has no Touches line, so no peers can be found.")
        return 0
    found = peers_of(entry, every, prefix)
    print(f"\nPeers ({len(found)}):" if found else "\nNo peers.")
    for o, ptr in found:
        print(f"  {o['label']} § {o['id']} {o['title']} ({ptr})")
        print(f"      {rule_sentence(o['block'])}")
    for u in unread:
        print(f"not read: {u}")
    return 0


def placement_hints(root: Path, trunk: str) -> list[str]:
    """In a metarepo: each of its pages two pararepos' entries touch while none of its own
    does. A ruling two repos share is probably the metarepo's."""
    if not load_meta(trunk):
        return []
    path = root / LOG
    every, _ = touching(root, trunk, path.read_text() if path.exists() else "")
    ours = [k for e in every if e["writer"] == SELF for k in e["keys"]]
    by_page: dict[str, set[str]] = {}
    for e in every:
        for k in e["keys"]:
            if e["writer"] != SELF and k[0] == SELF:
                by_page.setdefault(k[1], set()).add(e["writer"])
    return [f"{page}: {', '.join(sorted(ws))} rule on it, and no entry here does"
            for page, ws in sorted(by_page.items())
            if len(ws) > 1 and not any(keys_meet((SELF, page), k) for k in ours)]


def untouched_entries(root: Path, trunk: str) -> list[str]:
    """`jig update`: each live entry with no Touches line, for the backfill."""
    path = root / LOG
    if not path.exists():
        return []
    return [f"{e['id']} {e['title']}" for e in live_entries(path.read_text(), log_prefix(trunk))
            if entry_touches(e["block"]) is None]


RELEASE = f"{DIR}/scripts/release.sh"
RELEASE_TODO = "# TODO: release protocol."
PUBLISH = f"{DIR}/scripts/publish.sh"
PUBLISH_TODO = "# TODO: publish steps."
VERSION = re.compile(r"^\d+\.\d+\.\d+$")


def release_script(root: Path, meta: bool = False) -> bool:
    """Add release.sh from the template if it's missing. A metarepo's has no build: jig runs
    its release steps itself, so the protocol is already defined."""
    dest = root / RELEASE
    src = Path(__file__).resolve().parent / "scripts" / "release.sh"
    if dest.exists() and not meta:
        return False
    if not dest.exists() and not src.exists():
        return False
    # init copies the template before `init --meta` runs, so a metarepo's may already be here.
    text = (dest if dest.exists() else src).read_text()
    if meta:
        text = "\n".join(l for l in text.splitlines() if not l.startswith(RELEASE_TODO)) + "\n"
    if dest.exists() and dest.read_text() == text:
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text)
    dest.chmod(0o755)
    return True


def publish_script(root: Path) -> bool:
    """Add publish.sh from the template, TODO line included, if it's missing."""
    dest = root / PUBLISH
    src = Path(__file__).resolve().parent / "scripts" / "publish.sh"
    if dest.exists() or not src.exists():
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(src.read_text())
    dest.chmod(0o755)
    return True


def protocol_missing(root: Path, board: "Board", meta: dict | None, para: dict | None) -> str:
    # A metarepo and a pararepo have a default release: jig's own checks, before the tag.
    if meta or para:
        return ""
    script = root / RELEASE
    if not script.exists():
        return f"no {RELEASE}"
    if any(l.startswith(RELEASE_TODO) for l in script.read_text().splitlines()):
        return f"{RELEASE} still holds the template's TODO"
    if not (board.data.get("release") or {}).get("artifacts"):
        return f"the board's release.artifacts is empty"
    return ""


def next_version(last: str, args, meta: dict | None) -> str:
    if args.version:
        if not VERSION.match(args.version):
            die(f"--version takes X.Y.Z, not {args.version}", 2)
        if last and version_key(args.version) <= version_key(last):
            die(f"--version {args.version} is not after {last}", 2)
        return args.version
    if not last:
        # --minor or --major says which part the first version counts from; a patch doesn't.
        if not (meta or args.minor or args.major):
            die("no v* tag yet: name the first version with --version X.Y.Z, or --minor for 0.1.0", 2)
        last = "v0.0.0"
    x, y, z = (version_key(last) + (0, 0, 0))[:3]
    if args.major:
        return f"{x + 1}.0.0"
    # A metarepo's changes are additions unless they rename or reverse, so minor is its default.
    if args.minor or (meta and not args.patch):
        return f"{x}.{y + 1}.0"
    return f"{x}.{y}.{z + 1}"


def released_log(text: str, tag: str) -> str:
    """The log with ## Unreleased named for this release, and an empty one above it for what
    comes next. A repo that never releases just grows Unreleased."""
    heading = f"## {tag} - {date.today().isoformat()}"
    if re.search(r"^## Unreleased[ \t]*$", text, re.M):
        return re.sub(r"^## Unreleased[ \t]*$", f"## Unreleased\n\n{heading}", text, count=1, flags=re.M)
    first = re.search(r"^## v\d", text, re.M)
    if first:
        return text[:first.start()] + f"## Unreleased\n\n{heading}\n\n" + text[first.start():]
    return text.rstrip("\n") + f"\n\n## Unreleased\n\n{heading}\n"


def cmd_release(root: Path, args) -> int:
    os.chdir(root)        # every git path below, `.` and `add -u` included, is the whole repo
    board = Board.load(root)
    trunk = board.trunk
    meta = load_meta(trunk)
    para = None if meta else load_para(trunk)
    kind = "metarepo" if meta else "pararepo" if para else "repo"
    print(f"jig release: {board.data.get('name') or root.name} ({kind})")
    if git("branch", "--show-current") != trunk:
        die(f"release from {trunk}", 2)
    if git("status", "--porcelain", "--untracked-files=no"):
        die("commit or stash first: a release names one commit", 2)
    missing = protocol_missing(root, board, meta, para)
    if missing:
        die(f"the release protocol isn't defined ({missing}): run /jig:release, which asks what "
            f"this repo builds and ships and fills in {RELEASE} and release.artifacts", 2)
    problems, loc = (meta_problems(root, meta, trunk) if meta else []), None
    if para:
        problems, loc = para_problems(root, para, trunk)
    left = release_waits_for()
    if not args.force:
        problems += staged_refusal("the release")
    # Released, a D-?<slug> would be frozen under its version and never get its number.
    log_now = (root / LOG).read_text() if (root / LOG).exists() else ""
    problems += [f"{LOG}:{e['line']} {e['id']} isn't numbered: a merge numbers it (`jig merge "
                 f"--number` while one is in progress); number it on a branch before releasing"
                 for e in log_entries(log_now, log_prefix(trunk)) if "?" in e["id"]]
    if problems:
        for p in problems:
            print(f"refused: {p}", file=sys.stderr)
        return 2
    pat = re.compile(meta["tag_pattern"] if meta else r"^v\d+\.\d+(\.\d+)?$")
    last = latest_tag([t for t in git("tag", "--list").splitlines() if pat.match(t)])
    if meta:
        # No rename detection: a cited file moved out of the set still changed what is cited.
        changed = [f for f in git("-c", "core.quotePath=false", "diff", "--name-only", "--no-renames",
                                  last, "HEAD").splitlines()
                   if is_entry(f, meta["entry_files"])] if last else entry_paths("HEAD")
        if not changed:
            die(f"nothing to release: no entry file changed since {last}", 2)
    version = next_version(last, args, meta)
    tag = f"v{version}"
    # A pararepo's release settles its sync buffer: every Open row goes to the metarepo in one
    # proposal, made before the build so a release never ships with drift nobody proposed.
    proposed = None
    if para and unproposed(root)[1]:
        proposed = buffer_proposal(root, para, loc, f"buffer-{tag}")

    def undo(why: str) -> int:
        # The tree was clean, so putting tracked files back loses only what the release wrote.
        git("checkout", "-q", "--", ".")
        if proposed:
            proposed[0].unlink()
            git("branch", "-D", proposed[1], cwd=str(loc))
        print(f"refused: {why}. Tracked files are back as they were; nothing is tagged.",
              file=sys.stderr)
        return 2

    env = {k: v for k, v in os.environ.items()
           if k not in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_PREFIX")}
    globs = (board.data.get("release") or {}).get("artifacts", [])
    # What the globs match before the build, by mtime: a file counts only if this run wrote it.
    before = {f: f.stat().st_mtime_ns for g in globs for f in root.glob(g) if f.is_file()}
    def run(script: Path, argv: list) -> int:
        # Piped, Python's stdout is block-buffered: flush so jig's lines come before the script's.
        sys.stdout.flush()
        cmd = ([str(script)] if os.access(script, os.X_OK) else ["bash", str(script)]) + argv
        return subprocess.run(cmd, cwd=root, env=env).returncode

    for script, argv in ((root / DIR / "scripts" / "check.sh", []), (root / RELEASE, [version])):
        if not script.exists():
            continue
        rc = run(script, argv)
        if rc:
            return undo(f"{script.relative_to(root)} exited {rc}")
    # Only files this run wrote count: last release's build left in dist/ proves nothing.
    made = {g: [f for f in root.glob(g) if f.is_file() and before.get(f) != f.stat().st_mtime_ns]
            for g in globs}
    empty = [g for g, fs in made.items() if not fs]
    if empty:
        return undo(f"this release made no file matching {', '.join(empty)}")
    log = root / LOG
    if log.exists():
        log.write_text(released_log(log.read_text(), tag))
        git("add", "--", LOG, check=True)
    elif meta:
        # A metarepo `jig update` hasn't moved to the log yet releases as it did.
        old = root / CHANGELOG
        text = old.read_text() if old.exists() else "# Changelog\n"
        heading = f"## {tag} — {date.today().isoformat()}"
        if re.search(r"^## Unreleased[ \t]*$", text, re.M):
            text = re.sub(r"^## Unreleased[ \t]*$", f"## Unreleased\n\n{heading}", text, count=1,
                          flags=re.M)
        else:
            text = text.rstrip("\n") + f"\n\n## Unreleased\n\n{heading}\n"
        old.write_text(text)
        git("add", "--", CHANGELOG, check=True)
    git("add", "-u", check=True)
    msg = f"release {tag}"
    if proposed:
        git("add", "--", str(proposed[0].relative_to(root)), check=True)
        msg += f"\n\nProposed the sync buffer's Open rows to {para['meta']} as {proposed[1]}."
    if left:
        msg += (f"\n\nReleased with {len(left)} staged file{'s' if len(left) > 1 else ''} left "
                f"unresolved: {', '.join(f.name for f in left)}")
    tree = git("write-tree", check=True)
    commit = git("rev-parse", "HEAD")
    if tree != git("rev-parse", "HEAD^{tree}") or left:
        # Written with plumbing, so no hook sees it: in a metarepo this is the one commit on
        # trunk that isn't a merge, and the tag beside it is what marks it.
        commit = git("commit-tree", tree, "-p", "HEAD", "-m", msg, check=True)
        git("update-ref", f"refs/heads/{trunk}", commit, check=True)
        git("reset", "-q")
    git("tag", "-a", tag, "-m", tag, commit, check=True)
    print(f"released {tag} at {commit[:12]}.")
    if proposed:
        print(f"proposed {', '.join(listed_rows(proposed[0].read_text()))} to {para['meta']} as "
              f"{proposed[1]} ({proposed[0].relative_to(root)}): write the change there; "
              f"`jig sync` closes the rows once {para['meta']} releases it.")
    # Overlapping globs match one file twice; publish.sh gets each file once, in glob order.
    built = list(dict.fromkeys(str(f.relative_to(root)) for fs in made.values() for f in sorted(fs)))
    for f in built:
        print(f"  {f}")
    publish = root / PUBLISH
    # The TODO line means the repo hasn't said what a release publishes yet: it never blocks.
    if not publish.exists() or any(l.startswith(PUBLISH_TODO)
                                   for l in publish.read_text().splitlines()):
        print("Push it: git push --follow-tags")
        return 0
    rc = run(publish, [version, *built])
    if rc:
        # The tag may already be pushed, so it stays: the release happened, the publish didn't.
        again = ([] if os.access(publish, os.X_OK) else ["bash"]) + [PUBLISH, version, *built]
        # The release may have run from a subfolder; the command works from anywhere.
        print(f"released {tag} at {commit[:12]}, but {PUBLISH} exited {rc}. Run it again:\n"
              f"  cd {shlex.quote(str(root))} && {shlex.join(again)}", file=sys.stderr)
        return 1
    return 0

# ------------------------------------------------------------------- pararepo

# A pararepo (code, firmware, hardware) cites a metarepo at a released tag. It reads a cache
# of the pinned docs, never a copy committed here, and writes the metarepo only by branch.
PARA = f"{DIR}/para.json"
CACHE = f"{DIR}/meta-cache"
HEADER_BEGIN = f"<!-- jig:meta — generated from {PARA} by `jig init --para`; edit that, not this -->"
HEADER_END = "<!-- jig:meta end -->"
# How a spec says what its contract change means for the metarepo: a proposal branch it waits
# for, a pointers branch it works ahead of (pointer rewrites only, no claim changes), a row of
# the buffer, or why none.
PROPOSAL = re.compile(r"^\s*-?\s*meta: (?:none — \S.*|buffered (?P<row>\S+)|"
                      r"(?P<meta>\S+) proposal (?P<branch>\S+)|"
                      r"(?P<pmeta>\S+) pointers (?P<pbranch>\S+))\s*$", re.M)
# The sync buffer: each metarepo claim this repo has moved away from, held until a release
# proposes them all at once. Rows are Open until the release that settles them is pinned.
BUFFER = f"{DIR}/ledgers/BUFFER.md"
BUFFER_STATES = ("Open", "Closed")
# A buffer proposal's spec lists the rows it carries under this heading, one `- <id>` each.
BUFFER_ROWS = re.compile(r"^## Buffer rows\s*\n((?:- \S+.*\n?)*)", re.M)


def buffer_rows(text: str) -> list[list[str]]:
    """The ledger's rows as cells, header and separator left out."""
    rows = [table_cells(l) for l in text.splitlines() if l.lstrip().startswith("|")]
    return [r for r in rows if r and r[0] != "Id" and not re.fullmatch(r":?-+:?", r[0])]


def listed_rows(spec: str) -> list[str]:
    m = BUFFER_ROWS.search(spec)
    return [l[2:].split()[0] for l in m.group(1).splitlines()] if m else []


def proposed_copy(spec: str) -> dict[str, list[str]]:
    """The rows a buffer proposal's spec carried, as they read when proposed. A row edited
    since went to the metarepo in its old form, so only an unchanged one counts as proposed."""
    listed = set(listed_rows(spec))
    return {r[0]: r for r in buffer_rows(spec) if r[0] in listed}


def proposed_rows(texts: list[str]) -> set[tuple[str, ...]]:
    return {tuple(r) for s in texts for r in proposed_copy(s).values()}


def load_para(trunk: str) -> dict | None:
    raw = git("show", f"{trunk}:{PARA}")
    try:
        return json.loads(raw) if raw else None
    except ValueError:
        return None


def para_header(para: dict) -> str:
    paths = ", ".join(f"`{p}`" for p in para.get("contract_paths", [])) or "none yet"
    return "\n".join([
        HEADER_BEGIN,
        f"- Shared definitions: metarepo `{para['meta']}` at `{para['pin']}`, read from "
        f"`{CACHE}/` (`jig sync` on trunk refreshes it and reports newer releases).",
        f"- Contract paths: {paths}. A change there needs a metarepo proposal "
        "(`jig propose`) or `meta: none — <reason>` in its spec.",
        "- The metarepo is written only by branch, via `jig propose`; nothing of it is copied here.",
        HEADER_END,
    ])


def with_header(text: str, header: str) -> str:
    # Any begin line, not just today's: the first one said "by `jig para-init`", and a header
    # still carrying it must be replaced, not left beside a second block.
    block = re.compile(rf"^<!-- jig:meta — .*?^{re.escape(HEADER_END)}\n?", re.M | re.S)
    if block.search(text):
        return block.sub(header + "\n", text, count=1)
    first, _, rest = text.partition("\n")
    return f"{first}\n\n{header}\n{rest}" if first.startswith("#") else f"{header}\n\n{text}"


def repos_file() -> Path:
    """The user's list of where their repos live. A path is one machine's layout, so it lives
    here, never in a repo; no hook or gate reads it."""
    if os.environ.get("JIG_CONFIG"):
        return Path(os.environ["JIG_CONFIG"]).expanduser()
    base = os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config"
    return Path(base) / "jig" / "repos.json"


REPO_KINDS = ("repo", "meta", "para")


def load_repos() -> dict:
    """{name: {"path": ..., "kind": repo|meta|para}}. An entry that is a bare path is the
    first format, read as a plain repo."""
    f = repos_file()
    try:
        raw = json.loads(f.read_text()) if f.exists() else {}
    except ValueError:
        die(f"{f} is not valid JSON", 2)
    if not isinstance(raw, dict):
        die(f"{f} should map names to repos", 2)
    out = {}
    for n, e in raw.items():
        e = e if isinstance(e, dict) else {"path": e}
        if isinstance(e.get("path"), str):
            out[n] = {"path": e["path"], "kind": e.get("kind", "repo")}
    return out


def save_repos(repos: dict) -> None:
    repos_file().parent.mkdir(parents=True, exist_ok=True)
    repos_file().write_text(json.dumps(repos, indent=2) + "\n")


def repo_identity(path: Path) -> set[str]:
    """The names a checkout answers to by itself: its board's name, its metarepo name."""
    names = set()
    for f, key in ((path / CONFIG, "name"), (path / LEGACY_BOARD, "name"), (path / META, "name")):
        try:
            names.add(json.loads(f.read_text()).get(key, "")) if f.exists() else None
        except ValueError:
            pass
    return names - {""}


def repo_path(name: str) -> Path | None:
    """Where a repo lives, by the name you gave it or the name it gives itself, so an alias
    never breaks a lookup that uses the real one (a pararepo naming its metarepo)."""
    repos = load_repos()
    if name in repos:
        return Path(repos[name]["path"])
    for e in repos.values():
        if name in repo_identity(Path(e["path"])):
            return Path(e["path"])
    # A human types the name, so `App` finds `app`, as a staged header's target does.
    for n, e in repos.items():
        if name_in(name, {n} | repo_identity(Path(e["path"]))):
            return Path(e["path"])
    return None


def near_duplicates(repos: dict) -> list[tuple[str, str]]:
    """Pairs of names a person reads as one (`NorthStar`, `north-star`): a file staged for one
    can land in the other."""
    def key(n: str) -> str:
        return re.sub(r"[\W_]", "", n.casefold())
    names = sorted(repos)
    return [(a, b) for i, a in enumerate(names) for b in names[i + 1:] if key(a) == key(b)]


def warn_near_duplicates(repos: dict, only: str | None = None) -> None:
    for a, b in near_duplicates(repos):
        if only and only not in (a, b):
            continue
        print(f"warning: {a} and {b} differ only in case or punctuation, and are two repos:\n"
              f"  {a:<24} {repos[a]['path']}\n  {b:<24} {repos[b]['path']}\n"
              f"  rename one (`jig repos rename {b} <new>`) if both are meant")


def cmd_repos(root: Path, args) -> int:
    repos = load_repos()
    here = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir") or ".").parent \
        if git("rev-parse", "--git-dir") else Path.cwd()
    here = here.resolve()
    mine = [n for n, e in repos.items() if Path(e["path"]).resolve() == here]
    if args.action == "add":
        kind = args.kind if args.kind in REPO_KINDS else None
        kind_form = kind is not None
        if kind is None and args.kind and args.path:      # the first form: add <name> <path>
            name, path, kind = args.kind, Path(args.path).expanduser().resolve(), "repo"
        elif kind:
            path = Path(args.path).expanduser().resolve() if args.path else here
            name = args.name or (sorted(repo_identity(path)) or [path.name])[0]
        else:
            die("usage: jig repos add repo|meta|para [--name N] [--path P]", 2)
        for old in [n for n, e in repos.items() if Path(e["path"]).resolve() == path and n != name]:
            del repos[old]                          # one entry per checkout; re-adding replaces
        # add <name> <path> re-points a name on purpose; add repo|meta|para must not take one
        if kind_form and name in repos and Path(repos[name]["path"]).resolve() != path:
            die(f"{name} already names {repos[name]['path']}: pick another --name, or rename that one", 2)
        repos[name] = {"path": str(path), "kind": kind}
        save_repos(repos)
        print(f"{name} ({kind}) → {path}")
        warn_near_duplicates(repos, name)
        old = old_board(path) if kind in ("meta", "para") else None
        if old:
            print(f"  {old} is an older jig's board: run `jig update` there, commit, then "
                  f"`jig init --{kind}{' <metarepo name>' if kind == 'para' else ''}`")
        elif kind == "meta" and not (path / META).exists():
            print(f"  not a metarepo yet: run `jig init --meta` there")
        elif kind == "para" and not (path / PARA).exists():
            print(f"  not a pararepo yet: run `jig init --para <metarepo name>` there")
        return 0
    if args.action == "rename":
        # rename <new> renames this folder's entry; rename <old> <new> any entry
        if not args.kind:
            die("usage: jig repos rename <new>  (this folder), or rename <old> <new>", 2)
        old, new = (args.kind, args.path) if args.path else (mine[0] if mine else None, args.kind)
        if not new or not old or old not in repos:
            die("this folder isn't registered: jig repos add repo|meta|para" if not old
                else f"no repo named {old}", 2)
        if new in repos and new != old:
            die(f"{new} already names {repos[new]['path']}", 2)
        repos[new] = repos.pop(old)
        save_repos(repos)
        print(f"{old} is now {new} → {repos[new]['path']}")
        warn_near_duplicates(repos, new)
        return 0
    for name, e in sorted(repos.items()):
        missing = "" if Path(e["path"]).is_dir() else "   (missing)"
        print(f"  {name:<24} {e['kind']:<5} {e['path']}{missing}{'   ← here' if name in mine else ''}")
    if not repos:
        print(f"no repos in {repos_file()}: jig repos add repo|meta|para")
    warn_near_duplicates(repos)
    # The same lookup staging and forwarding use, so an alias for the jig repo counts too.
    if repo_path("jig") is None:
        print(f"tool reports wait in {feedback_dir()} while the jig repo isn't registered")
    return 0


def meta_checkout(root: Path, para: dict) -> Path | None:
    """The metarepo's checkout, found by name in repos.json, or None when it isn't listed or
    can't be reached (offline, moved)."""
    p = repo_path(para.get("meta", ""))
    if p is None:
        return None
    # The clone's own top level: a plain folder inside this repo would answer with ours.
    top = git("rev-parse", "--show-toplevel", cwd=str(p)) if p.is_dir() else ""
    return p if top and Path(top).resolve() == p.resolve() else None


def released_tags(cwd: str) -> list[str]:
    """Tags the metarepo's own gates would accept: matching its pattern, with the heading
    the release writes."""
    meta = {**META_DEFAULTS, **json.loads(git("show", f"HEAD:{META}", cwd=cwd) or "{}")}
    pat = re.compile(meta["tag_pattern"])
    out = []
    for t in git("tag", "--list", cwd=cwd).splitlines():
        if pat.match(t) and made_by_release(t, cwd):
            out.append(t)
    return sorted(out, key=version_key)


def para_problems(root: Path, para: dict, trunk: str) -> tuple[list[str], Path | None]:
    """What makes a pararepo unreleasable: its default release, the checks jig already has.
    Warnings (a newer metarepo release, a cited path outside contract_paths) print as `jig
    sync` prints them and refuse nothing. Returns the refusals and the metarepo's checkout."""
    out: list[str] = []
    name, pin = para["meta"], para.get("pin") or ""
    # Trunk's files, not the hooks' view of a commit: a commit made with --no-verify is checked too.
    if para_header(para) not in git("show", f"{trunk}:AGENTS.md"):
        out.append(f"P1 the AGENTS.md header is generated from {PARA}: edit that, then "
                   "`jig init --para` regenerates it")
    tracked = git("ls-files", "--", f"{CACHE}/").splitlines()
    if tracked:
        out.append(f"P3 {', '.join(tracked)} is the metarepo's: pararepos cite it at a tag, never copy it")
    rows = buffer_rows(git("show", f"{trunk}:{BUFFER}"))
    for r in rows:
        if r[-1] not in BUFFER_STATES:
            out.append(f"P2 {BUFFER} row {r[0]} is {r[-1] or 'empty'}: a row is Open or Closed")
    for i in sorted({r[0] for r in rows if [x[0] for x in rows].count(r[0]) > 1}):
        out.append(f"P2 {BUFFER} has more than one row {i}: each row has an id of its own")
    loc = meta_checkout(root, para)
    if loc is None:
        return out + [f"can't reach {name} to check the pin against: run `jig repos add meta` in its checkout"], None
    # fill_cache below rewrites the cache: a tracked one would leave the tree dirty after a refusal.
    if tracked:
        return out, loc
    git("fetch", "-q", "--tags", cwd=str(loc))
    tags = released_tags(str(loc))
    # The cache can't vouch for the pin: fill_cache takes any commit-ish, `main` included.
    if pin not in tags:
        return out + [f"the pin {pin or '(none)'} in {PARA} is not a release of {name} "
                      f"({', '.join(tags) or 'none yet'}): a pararepo pins a release, never a branch "
                      "or a hand-made tag"], loc
    fill_cache(root, loc, pin)
    # As `jig sync`: until defer_until, what moved upstream is not reported.
    if date.today().isoformat() >= (para.get("defer_until") or ""):
        uncovered_paths(root, loc, para)
        for line in [*yanked_pin(loc, pin, name), *stale_pointers(root), *meta_citations(root, para, decision_ids(loc, pin), loc)]:
            print(line)
        if version_key(tags[-1]) > version_key(pin):
            print("\n".join(newer_release(root, loc, name, pin, tags[-1])))
    return out, loc


def fill_cache(root: Path, loc: Path, pin: str) -> None:
    if not git("rev-parse", "-q", "--verify", f"{pin}^{{commit}}", cwd=str(loc)):
        die(f"the metarepo has no tag {pin}: check \"pin\" in {PARA}", 2)
    cache = root / CACHE
    if cache.exists():
        shutil.rmtree(cache)
    cache.mkdir(parents=True)
    for f in dict.fromkeys([*entry_paths(pin, str(loc)), CHANGELOG]):
        body = git("show", f"{pin}:{f}", cwd=str(loc))
        if body:
            (cache / f).parent.mkdir(parents=True, exist_ok=True)
            (cache / f).write_text(body + "\n")
    (cache / "PIN").write_text(f"{pin}\ncached {date.today().isoformat()}\n")


def ignore_line(root: Path, line: str) -> None:
    ignore = root / ".gitignore"
    text = ignore.read_text() if ignore.exists() else ""
    if line not in text.splitlines():
        ignore.write_text(text + ("" if not text or text.endswith("\n") else "\n") + line + "\n")


def job_of_change(board: "Board", branch: str) -> dict | None:
    """The open job a change belongs to. On its branch, that job. A merge that commits on trunk
    (`jig merge`) brings the job in as MERGE_HEAD; the gate's scratch checkout is the job's
    commit, detached, with trunk merged into it. Either way the job is the one whose branch
    holds the side of the merge trunk doesn't already have; trunk's board still lists it. It
    must be one job: the branch tip itself, else the one branch whose own line (first parents)
    holds it. A job stacked on another holds its commits too, but off its own line; anything
    still ambiguous, or an octopus merge, belongs to no job, so no spec but the change's answers."""
    if branch and branch != board.trunk:
        return board.job_for_branch(branch)[1]
    merging = merging_commits()
    if len(merging) > 1:
        return None
    ours = [] if branch else [git("rev-parse", "-q", "--verify", "HEAD")]
    tips = {name: git("rev-parse", "-q", "--verify", f"refs/heads/{board.branch(name)}")
            for name in board.jobs}
    for c in filter(None, [*merging, *ours]):
        if is_ancestor(c, board.trunk):
            continue
        exact = [n for n, t in tips.items() if t == c]
        own = exact or [n for n, t in tips.items() if t and c in
                        git("rev-list", "--first-parent", t, f"^{board.trunk}").split()]
        return board.jobs[own[0]] if len(own) == 1 else None
    return None


def is_ancestor(a: str, b: str) -> bool:
    return subprocess.run(["git", "merge-base", "--is-ancestor", a, b],
                          capture_output=True).returncode == 0


def para_rules(root: Path, board: "Board", para: dict, staged: bool) -> list[str]:
    """P1–P3: what a pararepo may commit."""
    out: list[str] = []
    trunk = board.trunk
    paths = changed_paths(trunk, staged)
    # Deletes and both sides of a rename: P1, P2's contract test and P4 guard paths.
    diffed = changed_paths(trunk, staged, removed=True)
    # P1 the AGENTS.md header says what para.json says
    if "AGENTS.md" in diffed or PARA in diffed:
        try:
            now = json.loads(in_index(PARA, staged) or "null") or para
        except ValueError:
            return [f"P1 {PARA} is not valid JSON"]
        agents = in_index("AGENTS.md", staged)
        if para_header(now) not in agents:
            out.append(f"P1 the AGENTS.md header is generated from {PARA}: edit that, then "
                       "`jig init --para` regenerates it")
    # P2 a contract change carries its metarepo proposal, its buffer row, or says why it needs none
    touched = [p for p in diffed if matches(p, para.get("contract_paths", []))]
    rows = buffer_rows(in_index(BUFFER, staged))
    if BUFFER in paths:
        for r in rows:
            if r[-1] not in BUFFER_STATES:
                out.append(f"P2 {BUFFER} row {r[0]} is {r[-1] or 'empty'}: a row is Open or Closed")
        # Parallel jobs each appending "the next id" merge cleanly into two rows of one id.
        for i in sorted({r[0] for r in rows if [x[0] for x in rows].count(r[0]) > 1}):
            out.append(f"P2 {BUFFER} has more than one row {i}: each row has an id of its own")
    # An Open row is drift still owed to the metarepo: it closes only once proposed as it
    # stands, in a commit that changes no contract path (the one `jig sync` makes), and never
    # disappears. A deleted ledger isn't in `paths`, so the old rows are read whatever changed.
    now = {r[0]: r for r in rows}
    was = [r for r in buffer_rows(at_rev(base(trunk), BUFFER)) if r[-1] == "Open"]
    if was:
        specs_then = [at_rev(base(trunk), s) for s in git("ls-tree", "-r", "--name-only", base(trunk),
                                                         "--", f"{DIR}/specs/").splitlines()]
        sent = proposed_rows(specs_then)
    for r in was:
        n = now.get(r[0])
        if n is None:
            out.append(f"P2 {BUFFER} row {r[0]} is Open and is gone: an Open row stays until "
                       "`jig sync` closes it")
        elif n[-1] == "Closed" and (touched or tuple(r) not in sent or n[:-1] != r[:-1]):
            out.append(f"P2 {BUFFER} row {r[0]} closed by hand: `jig sync` closes a row once "
                       "the metarepo releases the proposal that carried it as it stands")
    # A pointer this change leaves dangling: the metarepo now points at nothing, so it is owed
    # what a contract change is.
    # The cache lives in the primary checkout: it is ignored, so a job's worktree has none.
    # Worse than at the base counts: a file lost is still news when its heading was already missing.
    broken = [f"{f} points to {gap}" for f, path, section, code in pointers(root, main_root())
              if any(d == path or d.startswith(f"{path}/") for d in diffed)
              for level, gap in [pointer_gap(path, section, code, body_now(path, staged))]
              if level > pointer_gap(path, section, code, body_at(base(trunk), path))[0]]
    if touched or broken:
        specs = {p for p in paths if p.startswith(f"{DIR}/specs/") and p.endswith(".md")}
        branch = git("branch", "--show-current")
        if branch and branch != trunk:
            specs |= {p for p in git("diff", "--name-only", f"{trunk}...HEAD", "--",
                                     f"{DIR}/specs/").splitlines() if p.endswith(".md")}
        ids = {r[0] for r in rows if r[-1] == "Open"}
        texts = [in_index(s, staged) for s in specs]
        # The job's own spec, from trunk's board and trunk's copy: whoever controls trunk put
        # the answer there, so a branch can't forge it. A spec that is one line is its own text.
        job = job_of_change(board, branch)
        if job and job.get("spec"):
            texts.append(at_rev(trunk, job["spec"]) or job["spec"])
        answered = any((not m.group("row") or m.group("row") in ids)
                       for t in texts for m in PROPOSAL.finditer(t))
        # A row added or changed in this commit answers it, the way R7's ledger row does.
        diff = git("diff", "-U0", base(trunk), *(["--cached"] if staged else []), "--", BUFFER) \
            if BUFFER in paths else ""
        rowed = any(r[-1] == "Open" for l in diff.splitlines() if l.startswith("+|")
                    for r in buffer_rows(l[1:]))
        answer = (f"add or edit its row in {BUFFER} in this commit (the first row creates the "
                  "file from jig's ledger template), or a spec in this change, or the job's own "
                  "spec on trunk, needs `meta: buffered <row id>`, `meta: <name> proposal "
                  "<branch>` (`jig propose`), `meta: <name> pointers <branch>` (`jig propose "
                  "--pointers`) or `meta: none — <reason>`")
        if not answered and not rowed and touched:
            out.append(f"P2 {', '.join(touched)} is a contract path: {answer}")
        if not answered and not rowed and broken:
            out.append(f"P2 this change leaves the metarepo pointing at nothing ({'; '.join(broken)}): {answer}")
    # P4 no contract change while a file for the metarepo waits unresolved
    waiting = [f.name for f in staged_files(main_root()) if name_in(read_staged(f)[0].get("target"), {para.get("meta", "")})]
    if touched and waiting:
        out.append(f"P4 {', '.join(touched)} is a contract path, and {', '.join(waiting)} for "
                   f"{para.get('meta')} is still staged: resolve it first")
    # P3 nothing of the metarepo is committed here: not the cache, not a checkout of it.
    # A nested checkout can only be staged as a gitlink, and it says whose it is itself.
    for p in paths:
        nested = root / p / META
        is_meta = (git("ls-files", "-s", "--", p).startswith("160000") and nested.exists()
                   and f'"{para.get("meta")}"' in nested.read_text(errors="replace"))
        if p.startswith(f"{CACHE}/") or is_meta:
            out.append(f"P3 {p} is the metarepo's: pararepos cite it at a tag, never copy it")
    return out


def cmd_para_init(root: Path, args) -> int:
    """`jig init --para <metarepo>`. Run again, it regenerates the header and cache from
    para.json."""
    path = root / PARA
    again = path.exists()
    para = json.loads(path.read_text()) if again else {
        "meta": args.meta, "pin": getattr(args, "pin", None), "defer_until": None,
        "contract_paths": getattr(args, "contract", None) or []}
    para.pop("location", None)          # an older para.json: where it lives is repos.json's
    if not para.get("meta"):
        die("first run needs --para <metarepo name>", 2)
    if getattr(args, "location", None):
        cmd_repos(root, argparse.Namespace(action="add", kind="meta", name=para["meta"],
                                           path=args.location))
    agents = root / "AGENTS.md"
    loc = meta_checkout(root, para)
    # A first run needs the metarepo to check the pin against. A re-run's header comes from
    # para.json alone, so it is written first, and only the cache waits for the metarepo.
    if loc is None and not again:
        die(f"can't find {para['meta']}: run `jig repos add meta` in its checkout", 2)
    if not para.get("pin"):
        if loc is None:
            die(f"can't find {para['meta']} to pick a pin: run `jig repos add meta` in its checkout", 2)
        tags = released_tags(str(loc))
        if not tags:
            die(f"{para['meta']} has no release yet: run `jig release` there first", 2)
        para["pin"] = tags[-1]
    path.write_text(json.dumps(para, indent=2) + "\n")
    agents.write_text(with_header(agents.read_text() if agents.exists() else "# AGENTS.md\n",
                                  para_header(para)))
    ignore_line(root, f"{CACHE}/")
    if loc is not None and loc.resolve().is_relative_to(root.resolve()):
        ignore_line(root, f"{loc.resolve().relative_to(root.resolve()).as_posix()}/")
    pin = para["pin"]
    if loc is None:
        why = f"can't find {para['meta']} (`jig repos add meta` in its checkout)"
    elif not git("rev-parse", "-q", "--verify", f"{pin}^{{commit}}", cwd=str(loc)):
        why = f"{para['meta']} has no tag {pin} here (`git -C {loc} fetch --tags`, or check \"pin\")"
    else:
        why = ""
        fill_cache(root, loc, pin)
    if why:
        print(f"warning: {why}: {CACHE}/ was not refreshed.", file=sys.stderr)
    print(f"wrote {PARA}, the AGENTS.md header{'' if why else f', and {CACHE}/ at {pin}'}.")
    print(f"Commit {PARA}, AGENTS.md and .gitignore on {Board.trunk_name(root)}.")
    return 0


def decision_prefix_at(loc: Path, rev: str) -> str:
    """The metarepo's decision_prefix at REV."""
    try:
        meta = {**META_DEFAULTS, **json.loads(git("show", f"{rev}:{META}", cwd=str(loc)) or "{}")}
    except ValueError:
        meta = META_DEFAULTS
    return meta["decision_prefix"]


def decision_ids(loc: Path, rev: str) -> str:
    """A regex for the metarepo's decision ids at REV, from its decision_prefix."""
    return re.escape(decision_prefix_at(loc, rev)) + r"\d+"


def changed_decisions(root: Path, prefix: str, rng: str) -> set[str]:
    """Each decision id whose entry in the log RNG adds, removes or edits, and each one such an
    entry supersedes. The one place a branch's decisions are read: where they live may move,
    the question doesn't."""
    out = edited_decisions(root, prefix, rng)
    now = {e["id"]: e for e in log_entries(git("show", f"{rng.partition('..')[2].lstrip('.') or 'HEAD'}:{LOG}",
                                                   cwd=str(root)), prefix)}
    # What changes an accepted entry is a new one that supersedes and removes it: the old id is news too.
    return out | {s for i in out if i in now for s in (status_parts(now[i]["status"], prefix) or ("", "", "", []))[3]}


def edited_decisions(root: Path, prefix: str, rng: str) -> set[str]:
    """Each decision id whose entry in the log RNG adds, removes or edits."""
    left, _, right = rng.partition("...") if "..." in rng else rng.partition("..")
    if "..." in rng:
        left = git("merge-base", left, right or "HEAD", cwd=str(root)) or left
    def entries(rev: str) -> dict[str, dict]:
        return {e["id"]: e for e in log_entries(git("show", f"{rev}:{LOG}", cwd=str(root)), prefix)}
    was, now = entries(left), entries(right or "HEAD")
    return {i for i in {*was, *now} if (was.get(i) or {}).get("block") != (now.get(i) or {}).get("block")}


def changed_rows(root: Path, meta: dict, rng: str) -> dict[str, set[str]]:
    """Before the log: each decision id whose register row RNG adds, removes or edits, with the
    files holding that row, read from every changed page as the old M2 read them."""
    md = [f for f in git("-c", "core.quotePath=false", "diff", "--name-only", "--no-renames", rng,
                         cwd=str(root)).splitlines()
          if f.endswith(".md") and f != CHANGELOG and not f.startswith(f"{DIR}/")]
    if not md:
        return {}
    row = re.compile(rf"^[+-]\s*\|\s*({re.escape(meta['decision_prefix'])}\d+)\s*\|")
    out: dict[str, set[str]] = {}
    f = ""
    # Fixed prefixes, whatever diff.noprefix or diff.mnemonicPrefix say: the headers are parsed.
    for line in git("-c", "core.quotePath=false", "--literal-pathspecs", "diff", "--no-renames",
                    "--no-ext-diff", "--no-color", "--src-prefix=a/", "--dst-prefix=b/",
                    rng, "--", *md, cwd=str(root)).splitlines():
        if line.startswith(("--- a/", "+++ b/")):
            f = line[6:]
        elif line.startswith(("--- ", "+++ ")):
            continue
        elif m := row.match(line):
            out.setdefault(m.group(1), set()).add(f)
    return out


def decision_citers(root: Path, trunk: str, rng: str) -> dict[str, list[str]]:
    """Each page whose text cites a decision whose entry RNG changed, with those ids: a
    metarepo's entry pages, or the docmap's pages anywhere else. An entry and the pages citing
    it are one home, and an entry is no file docmap can map. A passing mention is asked too:
    "no change because" answers it. The prefix and pages are trunk's, so a branch can't narrow
    them to escape the question."""
    meta = load_meta(trunk)
    rows: set[str] = {LOG}
    if meta and not has_log(trunk):
        # A metarepo `jig update` hasn't moved to the log yet: its register's rows, as before.
        by_row = changed_rows(root, meta, rng)
        changed, rows = set(by_row), {CHANGELOG, *(set().union(*by_row.values()) if by_row else ())}
    else:
        changed = changed_decisions(root, log_prefix(trunk), rng)
    if not changed:
        return {}
    head = git("-c", "core.quotePath=false", "ls-tree", "-r", "--name-only", "HEAD", cwd=str(root))
    docmap = set((Board.load(root).data.get("docmap") or {})) if not meta else set()
    out: dict[str, list[str]] = {}
    for page in head.splitlines():
        if page in rows or not (is_entry(page, meta["entry_files"]) if meta else page in docmap):
            continue
        text = git("show", f"HEAD:{page}", cwd=str(root))
        # Whole ids only: D-7 is not D-70, nor XD-7.
        hit = [d for d in sorted(changed) if re.search(rf"(?<![\w-]){re.escape(d)}(?![\w?-])", text)]
        if hit:
            out[page] = hit
    return out


def terms_changed(loc: Path, old: str, new: str) -> list[str]:
    """Decision ids and glossary headings that changed between two releases. Ids are matched
    by the metarepo's own decision_prefix, which may be lowercase."""
    # Only what a pararepo can read: the entry set release counts and the cache copies. Literal
    # paths, not entry_files globs, since git's `**` misses a file directly under the folder.
    paths = sorted((set(entry_paths(old, str(loc))) | set(entry_paths(new, str(loc)))) - {CHANGELOG})
    # The README's other headings (Install, Usage) are prose, not terms: only its Glossary counts.
    readme = "README.md" in paths
    log = LOG in paths
    regs = merged_registers(loc, old, new)
    paths = [f for f in paths if f not in ("README.md", LOG, *regs)]
    found = []
    if regs:
        # Across the merge into the log the same decisions changed shape, not meaning: only an
        # entry whose title or status differs from its row is news.
        prefix = decision_prefix_at(loc, new)
        def shape(title: str, status: str) -> tuple[str, str]:
            return title.strip(), re.sub(r" Supersedes .*$", "", status.strip())
        was = {}
        for r in regs:
            # Dated from history as the merge dated them, or every superseded row reads as news.
            rows = parse_register(git("show", f"{old}:{r}", cwd=str(loc)), decision_prefix_at(loc, old))[0]
            date_superseded(loc, r, rows, decision_prefix_at(loc, old), old)
            was |= {decision_id(e["id"]): shape(e["title"], e["status"]) for e in rows if e["word"] != "rejected"}
        entries = log_entries(git("show", f"{new}:{LOG}", cwd=str(loc)), prefix)
        now = {decision_id(e["id"]): (e["id"], shape(e["title"], e["status"]), e["status"]) for e in entries}
        for i, (shown, sh, status) in now.items():
            if was.get(i) != sh:
                found.append(shown)
                found += (status_parts(status, prefix) or ("", "", "", []))[3]
        found += [i for i in was if i not in now]
    elif log:
        # An entry added, edited or removed, and what a new entry supersedes: a pararepo cites
        # the old id, and needs to hear that it no longer holds.
        prefix = decision_prefix_at(loc, new)
        was, now = ({e["id"]: e for e in log_entries(git("show", f"{r}:{LOG}", cwd=str(loc)), prefix)}
                    for r in (old, new))
        for i in sorted({*was, *now}, key=lambda i: (now.get(i) or was[i])["line"]):
            if (was.get(i) or {}).get("block") != (now.get(i) or {}).get("block"):
                found.append(i)
                found += (status_parts((now.get(i) or {}).get("status", ""), prefix) or ("", "", "", []))[3]
    if paths:
        diff = git("--literal-pathspecs", "diff", old, new, "--", *paths, cwd=str(loc))
        found += re.findall(rf"^[+-]\s*\|\s*({decision_ids(loc, new)})\s*\|", diff, re.M)
        found += re.findall(r"^[+-]#{2,3} (.+?)\s*$", diff, re.M)
    if readme:
        was, now = (glossary_terms(git("show", f"{r}:README.md", cwd=str(loc))) for r in (old, new))
        found += [t for t in now if t not in was] + [t for t in was if t not in now]
    return list(dict.fromkeys(found))


def proposal_in(loc: Path, branch: str, tag: str) -> bool:
    """Whether a proposal is in a release: its branch is an ancestor of the tag, or, the branch
    deleted after its merge, a merge reachable from the tag names it. M4 makes every change to
    the metarepo's trunk a merge, and git's default subject names the branch."""
    tip = git("rev-parse", "-q", "--verify", f"refs/heads/{branch}^{{commit}}", cwd=str(loc))
    if tip:
        # A proposal `jig propose` just made sits on the metarepo's trunk with nothing of its
        # own, so it is an ancestor of every later tag. M4 keeps a real one off that line.
        on_trunk = tip in git("rev-list", "--first-parent", tag, cwd=str(loc)).split()
        return not on_trunk and subprocess.run(["git", "merge-base", "--is-ancestor", tip, tag],
                                               cwd=loc, capture_output=True).returncode == 0
    # git's own subject names the branch; `jig merge`'s names the job, whose board entry, read
    # just before that merge deleted it, names the branch.
    named = re.compile(rf"^Merge branch '{re.escape(branch)}'( into \S+)?$")
    for line in git("log", "--merges", "--format=%H %s", tag, cwd=str(loc)).splitlines():
        sha, _, subject = line.partition(" ")
        if named.match(subject):
            return True
        job = re.search(r"(?:^|: )merge (\S+)$", subject)
        if job:
            try:
                jobs = json.loads(git("show", f"{sha}^1:{JOBS}", cwd=str(loc)) or "{}")
            except ValueError:
                continue
            entry = jobs.get(job.group(1)) if isinstance(jobs, dict) else None
            if isinstance(entry, dict) and (entry.get("branch") or job.group(1)) == branch:
                return True
    return False


def unreleased_proposals(root: Path, para: dict, trunk: str, commit: str, named: list[str]) -> list[str]:
    """Why the job at COMMIT can't merge yet: a spec it builds on cites a metarepo proposal that
    isn't in trunk's pinned release, or a pointers branch the metarepo doesn't have. Its specs
    are the ones it changed and the ones the board and its note name, which may sit on trunk
    already (`jig propose` there, then `jig open`); a one-line board spec is its own text. Read
    at the commit, because the hubnode gates from trunk."""
    changed = [p for p in git("diff", "--name-only", f"{trunk}...{commit}", "--",
                              f"{DIR}/specs/").splitlines() if p.endswith(".md")]
    specs = list(dict.fromkeys([*filter(None, named), *changed]))
    found = [(s, m) for s in specs
             for m in PROPOSAL.finditer(git("show", f"{commit}:{s}") or git("show", f"{trunk}:{s}") or s)]
    cited = [(s, m) for s, m in found if m.group("branch")]
    ahead = [(s, m) for s, m in found if m.group("pbranch")]
    if not cited and not ahead:
        return []
    name, pin = para.get("meta", ""), para.get("pin", "")
    loc = meta_checkout(root, para)
    out = []
    # A pointers branch is work ahead, not a dependency: it needn't be released, only real, or
    # the answer is a free-text pass whose only failure signal is a dangling-pointer report.
    for spec, m in ahead:
        what = f"{spec} answers with pointers branch {m.group('pbranch')}"
        if m.group("pmeta") != name:
            out.append(f"{what} on {m.group('pmeta')}, but this repo's metarepo is {name}")
        elif loc is None:
            out.append(f"{what}, and {name} can't be reached to check it (see `jig repos`)")
        # Merged and deleted is real too, released or not: the metarepo's trunk then holds it.
        elif not git("rev-parse", "-q", "--verify", f"refs/heads/{m.group('pbranch')}", cwd=str(loc)) \
                and not proposal_in(loc, m.group("pbranch"), Board.trunk_name(loc)):
            out.append(f"{what}, which {name} has no branch for and hasn't merged: open it "
                       "with `jig propose --pointers`")
    for spec, m in cited:
        what = f"{spec} cites proposal {m.group('branch')}"
        if m.group("meta") != name:
            out.append(f"{what} on {m.group('meta')}, but this repo's metarepo is {name}")
        elif loc is None:
            out.append(f"{what}, and {name} can't be reached to check it (see `jig repos`)")
        elif not proposal_in(loc, m.group("branch"), pin):
            later = [t for t in released_tags(str(loc)) if version_key(t) > version_key(pin)
                     and proposal_in(loc, m.group("branch"), t)]
            out.append(f"{what}, released in {name} {later[0]} but this repo pins {pin}: bump the pin "
                       "(`jig sync` on trunk says how), then `jig sync` the job" if later else
                       f"{what}, which is not in {name} {pin}, the pin, nor in any release: "
                       "it merges once it's released and pinned")
    return out


def sync_meta(root: Path) -> int:
    """`jig sync` on a pararepo's trunk: refresh the cache, report what moved upstream."""
    os.chdir(root)        # its git paths, and the pin commit's, are the whole repo's
    para = json.loads((root / PARA).read_text())
    agents = root / "AGENTS.md"
    if para_header(para) not in (agents.read_text() if agents.exists() else ""):
        print("the AGENTS.md header is out of date: run `jig init --para`, and commit only what "
              "it changed")
    until = para.get("defer_until")
    if until and date.today().isoformat() < until:
        return 0
    loc = meta_checkout(root, para)
    name, pin = para["meta"], para["pin"]
    if loc is None:
        cached = (root / CACHE / "PIN").read_text().split("\n") if (root / CACHE / "PIN").exists() else []
        print(f"can't reach {name} (see `jig repos`): reading the cache "
              f"({' '.join(cached).strip() or 'empty'}). Newer releases are unknown until it's reachable.")
        return 0
    git("fetch", "-q", "--tags", cwd=str(loc))
    fill_cache(root, loc, pin)
    tags = released_tags(str(loc))
    latest = tags[-1] if tags else pin
    buffered = []          # (spec, branch, the rows it carried that are still Open, unchanged)
    still = {tuple(r) for r in buffer_rows((root / BUFFER).read_text() if (root / BUFFER).exists() else "")
             if r[-1] == "Open"}
    for spec in sorted((root / DIR / "specs").glob("*.md")):
        text = spec.read_text()
        for m in PROPOSAL.finditer(text):
            if m.group("branch") and m.group("meta") == name:
                first = next((t for t in sorted(set(tags) | {pin}, key=version_key)
                              if proposal_in(loc, m.group("branch"), t)), None)
                print(f"proposal {m.group('branch')} ({spec.relative_to(root)}): "
                      f"{'released by ' + first if first else 'not released'}")
                rows = [i for i, r in proposed_copy(text).items() if tuple(r) in still]
                if rows:
                    buffered.append((spec, m.group("branch"), rows))
            elif m.group("pbranch") and m.group("pmeta") == name:
                b = m.group("pbranch")
                first = next((t for t in sorted(set(tags) | {pin}, key=version_key)
                              if proposal_in(loc, b, t)), None)
                state = (f"released by {first}" if first else "merged, not released"
                         if proposal_in(loc, b, Board.trunk_name(loc)) else "open"
                         if git("rev-parse", "-q", "--verify", f"refs/heads/{b}", cwd=str(loc))
                         else "missing")
                print(f"pointers {b} ({spec.relative_to(root)}): {state}")
    uncovered_paths(root, loc, para)
    # The buffer settles when the metarepo releases its proposal: the pin moves to the first
    # release that holds one, and its rows close in that same commit. A pin already holding it
    # (bumped by hand) closes them where it stands.
    held = [pin] + [t for t in tags if version_key(t) > version_key(pin)]
    settles = next((t for t in held if any(proposal_in(loc, b, t) for _, b, _ in buffered)), None)
    if settles:
        closing = [(s, b, rows) for s, b, rows in buffered if proposal_in(loc, b, settles)]
        if git("status", "--porcelain", "--", PARA, "AGENTS.md", BUFFER) or git("diff", "--cached", "--name-only"):
            print(f"{name} {settles} releases {', '.join(b for _, b, _ in closing)}: commit or stash first, "
                  f"so jig sync can close its rows in a commit of their own")
        else:
            moved = settles != pin
            body = changes_report(root, loc, pin, settles) if moved else []
            ids = [i for _, _, rows in closing for i in rows]
            para["pin"] = settles
            (root / PARA).write_text(json.dumps(para, indent=2) + "\n")
            agents.write_text(with_header(agents.read_text() if agents.exists() else "# AGENTS.md\n",
                                          para_header(para)))
            ledger = (root / BUFFER).read_text().splitlines(keepends=True)
            for n, l in enumerate(ledger):
                r = buffer_rows(l)
                if r and r[0][0] in ids and r[0][-1] == "Open":
                    ledger[n] = re.sub(r"\bOpen(\s*\|?\s*)$", r"Closed\1", l.rstrip("\n")) + "\n"
            (root / BUFFER).write_text("".join(ledger))
            fill_cache(root, loc, settles)
            git("add", "--", PARA, "AGENTS.md", BUFFER, check=True)
            subject = f"meta: {name} {pin} → {settles}" if moved else f"meta: {name} {pin}: close {', '.join(ids)}"
            done = subprocess.run(["git", "commit", "-q", "-m", subject, "-m",
                                   "\n".join(body + ["", f"Closed {', '.join(ids)}: "
                                                      f"{', '.join(b for _, b, _ in closing)} released "
                                                      f"in {settles}."]).strip()],
                                  cwd=root)
            if done.returncode:
                die(f"the commit was refused: {PARA}, AGENTS.md and {BUFFER} are staged as jig wrote them", 1)
            print(f"{subject}: committed, closing {', '.join(ids)}.")
            pin = settles
    for line in [*yanked_pin(loc, pin, name), *stale_pointers(root), *meta_citations(root, para, decision_ids(loc, pin), loc)]:
        print(line)
    if version_key(latest) <= version_key(pin):
        print(f"{name} {pin} is the latest release")
        return 0
    print("\n".join(newer_release(root, loc, name, pin, latest)))
    return 0


def newer_release(root: Path, loc: Path, name: str, pin: str, latest: str) -> list[str]:
    major = version_key(latest)[0] > version_key(pin)[0]
    return [f"{name} {latest} is out; this repo pins {pin}{' (a major release)' if major else ''}.\n",
            *changes_report(root, loc, pin, latest),
            f"\nTo take it: set \"pin\" to \"{latest}\" in {PARA}, run `jig init --para {name}`, and commit "
            f"those alone as `meta: {name} {pin} → {latest}` with this report as the body."]


def merged_registers(loc: Path, old: str, new: str) -> list[str]:
    """The registers OLD held rows in that the merge into the log, between OLD and NEW, took."""
    if git("ls-tree", "--name-only", old, "--", LOG, cwd=str(loc)) or \
            not git("ls-tree", "--name-only", new, "--", LOG, cwd=str(loc)):
        return []
    prefix = decision_prefix_at(loc, old)
    return [f for f in entry_paths(old, str(loc)) if f != LOG and f.endswith(".md")
            and rows_in(git("show", f"{old}:{f}", cwd=str(loc)), prefix)]


def entries_moved(loc: Path, old: str, new: str) -> list[tuple[str, str | None]]:
    """Each entry file at OLD that NEW lacks, with where it went (None: removed). git's rename
    detection names the new path, so no changelog line has to be read for it. A register the
    merge into the log took went there."""
    paths = sorted((set(entry_paths(old, str(loc))) | set(entry_paths(new, str(loc)))) - {CHANGELOG})
    if not paths:
        return []
    regs = merged_registers(loc, old, new)
    out = []
    for line in git("-c", "core.quotePath=false", "--literal-pathspecs", "diff", "-M", "--name-status",
                    old, new, "--", *paths, cwd=str(loc)).splitlines():
        f = line.split("\t")
        if f[0].startswith("R"):
            out.append((f[1], f[2]))
        elif f[0] == "D":
            out.append((f[1], LOG if f[1] in regs else None))
    return out


def closed_row(path: str, line: str) -> bool:
    """A Closed BUFFER row cites the pin it was written at: history, not a use."""
    return path == BUFFER and line.lstrip().startswith("|") and table_cells(line)[-1:] == ["Closed"]


def used_in(text: str, whole: bool = False) -> list[str]:
    """This repo's files that use TEXT. Of jig's own files only specs and ledgers count: the
    rulebook's examples and the cache aren't the repo's use, but a spec or an Open BUFFER row is."""
    keep = (f"{DIR}/specs/", f"{DIR}/ledgers/", LOG)
    hits = git("grep", "-n", "--null", "-I", "-F", *(["-w"] if whole else []), "--", text).splitlines()
    return list(dict.fromkeys(f for f, _, line in (h.split("\0", 2) for h in hits)
                              if (not f.startswith(f"{DIR}/") or f.startswith(keep)) and not closed_row(f, line)))


def changes_report(root: Path, loc: Path, old: str, new: str) -> list[str]:
    out = ["Changed, in this repo's terms:"]
    for was, now in entries_moved(loc, old, new):
        users = used_in(was)
        out.append(f"  {was} ({'now ' + now if now else 'removed'}): "
                   + (f"used in {', '.join(users)}" if users else "not used here"))
    for term in terms_changed(loc, old, new):
        # An id as a whole word: D-1 is not a use of D-12. A heading's term may be inflected.
        users = used_in(term, bool(re.fullmatch(decision_ids(loc, new), term)))
        out.append(f"  {term}: " + (f"used in {', '.join(users)}" if users else "not used here"))
    return out


def head_texts(paths: list[str]) -> list[tuple[str, str]]:
    """PATHS' text at HEAD, read in one git call; binary files (a NUL byte) left out."""
    raw = subprocess.run(["git", "cat-file", "--batch"], capture_output=True,
                         input="".join(f"HEAD:{p}\n" for p in paths).encode()).stdout
    out, at = [], 0
    for p in paths:
        head_end = raw.index(b"\n", at)
        head = raw[at:head_end].split()
        if head[-1] == b"missing":
            at = head_end + 1
            continue
        size = int(head[2])
        body = raw[head_end + 1:head_end + 1 + size]
        at = head_end + 1 + size + 1
        if b"\0" not in body:
            out.append((p, body.decode(errors="replace")))
    return out


def meta_citations(root: Path, para: dict, ids: str, loc: Path | None = None) -> list[str]:
    """This repo's citations of the metarepo checked against the cache: the mirror of
    stale_pointers. A citation is `<meta>/<path> § <section>`; a section that is a decision id
    (IDS, the metarepo's prefix) names a row, any other a heading. A bare path that names an
    entry file at the pin and nothing here is named too, since it can't be told from this repo's
    own. Handoffs and Closed BUFFER rows cite the pin they were written at, so they are left out.
    Reported, never refused. Read at HEAD, as stale_pointers reads it."""
    cache, name, pin = root / CACHE, para["meta"], para["pin"]
    if not cache.is_dir():
        return []
    entries = [f.relative_to(cache).as_posix() for f in sorted(cache.rglob("*"))
               if f.is_file() and f.name != "PIN" and f != cache / CHANGELOG]
    sized = [l.split("\t", 1) for l in git("-c", "core.quotePath=false", "ls-tree", "-r", "-l", "HEAD").splitlines()]
    here = [p for _, p in sized]
    tracked = set(here)
    # A citation lives in prose: a blob over a megabyte (an image, a firmware build) isn't read.
    small = [p for meta, p in sized if meta.split()[1] == "blob" and meta.split()[3] != "-"
             and int(meta.split()[3]) <= 1 << 20]
    folders = {"/".join(p.split("/")[:k]) + "/" for p in here for k in range(1, p.count("/") + 1)}
    bare = sorted((e for e in entries if e not in tracked), key=len, reverse=True)
    # One plain alternation finds the candidates and the boundaries are checked after: a regex
    # per entry, or one with a lookbehind, over every line of a big repo is too slow for a sync.
    one = re.compile("|".join(map(re.escape, bare))) if bare else None
    rows = re.compile(rf"(?<!\w)({ids})(?!\w)")
    named = (f"{name.casefold()}/", f"{name.casefold()}:")
    out = []
    for f, text in head_texts([p for p in small if not p.startswith(f"{DIR}/")
                               or p.startswith((f"{DIR}/specs/", f"{DIR}/ledgers/", LOG))]):
        folded = text.casefold()
        if not any(t in folded for t in named) and not (one and one.search(text)):
            continue
        # A released section's change lines are frozen, and its entries change only by being
        # superseded: a citation there isn't fixed in place, so isn't named.
        frozen = released_lines(text) if f == LOG else set()
        for n, line in enumerate(text.splitlines(), 1):
            if closed_row(f, line) or n - 1 in frozen:
                continue
            for m in POINTER.finditer(line) if any(t in line.casefold() for t in named) else ():
                if not name_in(m.group("name"), {name}):
                    continue
                path = m.group("path").rstrip(".")
                # docs/ui.md is this repo's own page, whatever its metarepo is called.
                written = f"{m.group('name')}/{path}"
                if written in tracked or f"{written}/" in folders:
                    continue
                code = m.start() > 0 and line[m.start() - 1] == "`" and not m.group("shut")
                rest = m.group("rest")
                section = (rest.split("`")[0].strip() if code else rest) if rest else None
                target = cache / path
                body = target.read_text(errors="replace") if target.is_file() else "" if target.is_dir() else None
                row = rows.match(plain(section)) if section and body else None
                if row and (not code or row.group(1) == plain(section)):
                    # A decision is a log entry's heading, or a row in a register from before the log.
                    if not re.search(rf"^(?:\s*\|\s*{re.escape(row.group(1))}\s*\||### {re.escape(row.group(1))}(?!\w))",
                                     body, re.M):
                        # A superseded entry is removed from the log: the citation moves to its successor.
                        by = holds_now(row.group(1), body, log_prefix_of(body), pin if loc else None,
                                       str(loc) if loc else None)
                        out.append(f"{f}:{n} cites {name}/{path} § {row.group(1)}, which {name} {pin} has no row for"
                                   + (f": now {name}/{path} § {by}" if by else ""))
                    continue
                level, _ = pointer_gap(path, section or None, code, body)
                if level == NO_FILE:
                    out.append(f"{f}:{n} cites {name}/{path}, which {name} {pin} doesn't have")
                elif level == NO_HEADING:
                    out.append(f"{f}:{n} cites {name}/{path} § {shown_section(plain(section), code)}, "
                               f"which {name} {pin} has no heading for")
            for m in one.finditer(line) if one else ():
                before, after = line[m.start() - 1:m.start()], line[m.end():m.end() + 1]
                if not re.match(r"[\w./:-]", before) and not re.match(r"[\w/-]", after):
                    out.append(f"{f}:{n} cites {m.group(0)} bare: write it as `{name}/{m.group(0)}`")
    return list(dict.fromkeys(out))


def uncovered_paths(root: Path, loc: Path, para: dict) -> None:
    """Report this repo's files that a metarepo decision at the pin cites but contract_paths
    doesn't cover: the decision then describes behavior that can change with no P2 asking.
    A root file in ROOT_DOCS counts only after this repo's name. Only reported: the rule reads trunk's para.json, and adding a path is the owner's choice."""
    ids = decision_ids(loc, para['pin'])
    row = re.compile(rf"^\s*\|\s*({ids})\s*\|.*$", re.M)
    cited = [(m.group(1), m.group(0)) for f in sorted((root / CACHE).rglob("*.md"))
             for m in row.finditer(f.read_text(errors="replace"))]
    # The log's entries, each its whole block: a decision's text runs past its heading.
    log = root / CACHE / LOG
    prefix = decision_prefix_at(loc, para["pin"])
    cited += [(e["id"], e["block"]) for e in log_entries(log.read_text(errors="replace") if log.is_file() else "", prefix)]
    if not cited:
        return
    # "this" names this repo only in a pararepo's own pointers to the metarepo; in a metarepo
    # decision, this/AGENTS.md is the metarepo's own file.
    names = this_repo_names(root) - {"this"}
    for path in git("-c", "core.quotePath=false", "ls-files").splitlines():
        if path.startswith(f"{DIR}/") or matches(path, para.get("contract_paths", [])):
            continue
        # The path whole, alone or after this repo's name: another pararepo's docs/ui.md is not
        # this one's. A root file every repo has (AGENTS.md) named bare is about every repo, so
        # only this repo's name in front of it points here.
        cite = named_path(rf"{re.escape(path)}(?![\w/-])", bare=path not in ROOT_DOCS)
        ids = [i for i, line in cited
               if any(not m.group("name") or name_in(m.group("name"), names) for m in cite.finditer(line))]
        if ids:
            print(f"{path} is not a contract path, and {', '.join(dict.fromkeys(ids))} name it. "
                  f"If the decision describes something this repo can change there, add the path to "
                  f"\"contract_paths\" in {PARA}; if not, nothing is needed.")


def named_path(path: str, *, bare: bool = False) -> re.Pattern[str]:
    """PATH (a regex) after a repo's name, `app/docs/ui.md` or `app:docs/ui.md`, or alone when
    BARE. Whose name it is is name_in's call, so a name's case folds one way; a path's never does."""
    return re.compile(rf"(?<![\w./:-])(?:(?P<name>[\w.-]+)[/:]){'?' if bare else ''}{path}")


# A metarepo's pointer to a claim this repo owns: `<repo>/<path> § <section>`, the section
# optional. In a code span the section runs to the closing backtick; in prose, where it ends is
# unknown, so REST is the line's remainder and a heading that begins it is the section. REST is
# only looked at, so a later pointer on the line is still found.
POINTER = named_path(r"(?P<path>[\w.-]+(?:/[\w.-]+)*)(?:(?P<shut>`)?[ \t]*§[ \t]*(?=(?P<rest>[^\n]*)))?")
HEADING = re.compile(r"^ {0,3}#{1,6}[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*$", re.M)
# A row no longer in force points at what was, not at what must still be there.
DEAD_ROW = re.compile(r"^(?:superseded|rejected)\b")


def plain(text: str) -> str:
    """Heading text as read: code backticks and emphasis marks dropped, `_` inside a word kept."""
    return re.sub(r"`|\*+|(?<!\w)_+|_+(?!\w)", "", text).strip()


def pointers(root: Path, home: Path | None = None) -> list[tuple[str, str, str | None, bool]]:
    """Every pointer to this repo in HOME's cache (ROOT's by default), decision rows and pages
    alike, as (cache file, path, section, whether the section is a code span's whole text). The
    changelog is history: a path it names was true when written. `this/that` is prose, not a
    repo called this."""
    cache, names, out = (home or root) / CACHE, this_repo_names(root) - {"this"}, []
    for f in sorted(cache.rglob("*.md")):
        if f == cache / CHANGELOG:
            continue
        text = f.read_text(errors="replace")
        # In the log, a superseded entry is history, as a superseded row is: its lines are skipped.
        dead: set[int] = set()
        if f == cache / LOG:
            prefix = log_prefix_of(text)
            entries = log_entries(text, prefix)
            gone = {s for e in entries for s in (status_parts(e["status"], prefix) or ("", "", "", []))[3]}
            dead = {n for e in entries if e["id"] in gone
                    for n in range(e["start"], e["start"] + e["block"].count("\n") + 1)}
            # A released section's change lines are history too: a path one names was true then.
            live = {n for e in entries for n in range(e["start"], e["start"] + e["block"].count("\n") + 1)}
            dead |= {n for n in released_lines(text) if n not in live}
        for n, line in enumerate(text.splitlines()):
            if n in dead:
                continue
            if line.lstrip().startswith("|") and any(DEAD_ROW.match(c) for c in table_cells(line)):
                continue
            for m in POINTER.finditer(line):
                if not name_in(m.group("name"), names):
                    continue
                code = m.start() > 0 and line[m.start() - 1] == "`" and not m.group("shut")
                rest = m.group("rest")
                section = (rest.split("`")[0].strip() if code else rest) if rest else None
                out.append((f"{CACHE}/{f.relative_to(cache).as_posix()}", m.group("path").rstrip("."),
                            section or None, code))
    return list(dict.fromkeys(out))


def body_at(rev: str, path: str) -> str | None:
    """PATH's text at REV ('' the index); '' for a folder; None when neither is there."""
    if git("cat-file", "-t", f"{rev}:{path}") == "blob":
        return at_rev(rev, path)
    listed = git("ls-tree", "-r", "--name-only", rev, "--", path) if rev else git("ls-files", "--", path)
    return "" if listed else None


def body_now(path: str, staged: bool) -> str | None:
    if staged:
        return body_at("", path)
    return Path(path).read_text(errors="replace") if Path(path).is_file() else "" if Path(path).is_dir() else None


# A section's leading number, `2` or `2.1`: the Documentation rule makes it the rule's heading
# and its citation. Whole, so `2` is neither `2.1` nor `20`.
SECTION_NUMBER = re.compile(r"\d+(?:\.\d+)*")
# How badly a pointer misses, in order: P2 asks only when a change makes it worse.
RESOLVES, NO_HEADING, NO_FILE = 0, 1, 2


def section_number(text: str) -> str | None:
    """TEXT's leading number when it is one: it ends the text, or at a blank, or at a `.`, `,`,
    `;`, `:` or `)` that no word follows. `2-factor` and `2.a` are words."""
    m = SECTION_NUMBER.match(text)
    if not m:
        return None
    rest = text[m.end():]
    if not rest or rest[0].isspace() or rest[0] in ".,;:)" and not re.match(r"\w", rest[1:2]):
        return m.group(0)
    return None


def shown_section(want: str, code: bool) -> str:
    """A section as a report prints it: a number whole; prose words up to where the sentence or
    clause ends, a `.` inside a token never cutting."""
    if (number := section_number(want)) is not None:
        return number
    return want if code else re.split(r"[(,;:)|]|\.(?!\S)", want)[0].strip()


def pointer_gap(path: str, section: str | None, code: bool, body: str | None) -> tuple[int, str]:
    """How a pointer misses BODY, the file as it stands (None: no file), and what it lacks;
    (RESOLVES, '') if nothing. A numbered section names the heading with that number; any other
    prose section resolves when some heading begins it, a whole word or more."""
    if body is None:
        return NO_FILE, f"{path}, which this repo doesn't have"
    if not section:
        return RESOLVES, ""
    want, heads = plain(section), [plain(h) for h in HEADING.findall(body)]
    number = section_number(want)
    if number is not None:
        if number in {section_number(h) for h in heads}:
            return RESOLVES, ""
    elif want in heads or not code and any(h and re.match(rf"{re.escape(h)}(?!\w)", want) for h in heads):
        return RESOLVES, ""
    return NO_HEADING, f"{path} § {shown_section(want, code)}, which {path} has no heading for"


def dangling(root: Path) -> list[tuple[str, str, str | None, bool, int, str]]:
    """Each cached pointer that misses this repo's HEAD, as (cache file, path, section, code,
    level, gap), one per line a report prints: pointers into a missing file read the same."""
    seen, out = set(), []
    for f, path, section, code in pointers(root):
        level, gap = pointer_gap(path, section, code, body_at("HEAD", path))
        if level and (f, gap) not in seen:
            seen.add((f, gap))
            out.append((f, path, section, code, level, gap))
    return out


def stale_pointers(root: Path) -> list[str]:
    """Reported, never refused: the fix is the metarepo's, through the buffer."""
    return [f"{f} points to {gap}" for f, _, _, _, _, gap in dangling(root)]


def removed_by(commit: str) -> list[tuple[str, str | None]]:
    """What COMMIT took away: each deleted path with None, each renamed one with where it went."""
    out = []
    for line in git("-c", "core.quotePath=false", "show", "-M", "--name-status", "--format=",
                    commit).splitlines():
        cells = line.split("\t")
        if cells[0] == "D":
            out.append((cells[1], None))
        elif cells[0].startswith("R") and len(cells) == 3:
            out.append((cells[1], cells[2]))
    return out


def removal(path: str, section: str | None, code: bool, level: int) -> tuple[str, str] | None:
    """The newest commit in this repo's history before which the pointer missed less than it
    does now and after which it missed as much, and what the repo has instead ('deleted', or
    the new path); None when it never had it. The resolver decides both sides, so what counts
    as removed is what P2 would have asked about."""
    def misses(rev: str) -> int:
        return pointer_gap(path, section, code, body_at(rev, path))[0]
    for commit in git("log", "--format=%h", "--", path).splitlines():
        if misses(commit) >= level > misses(f"{commit}^"):
            if level == NO_HEADING:
                return commit, path
            new = next((n for o, n in removed_by(commit) if o == path or o.startswith(f"{path}/")), None)
            return commit, new or "deleted"
    return None


def naming_row(rows: list[list[str]], path: str, section: str | None = None,
               states: tuple[str, ...] = ("Open",)) -> list[str] | None:
    """The first row in one of STATES whose cells name PATH (and SECTION, for a heading)."""
    where = re.escape(path) + (rf"[ \t]*§[ \t]*{re.escape(section)}(?!\.?\w)" if section else r"(?![\w/-])")
    named = re.compile(rf"(?<![\w./-]){where}")
    return next((r for r in rows if r[-1] in states and any(named.search(c) for c in r[1:-1])), None)


def row_offer(claim: str, now: str) -> str:
    return f"offer a row for {BUFFER}: claim \"{claim}\", this repo now \"{now}\""


def buffer_offer(root: Path, claim: str, path: str, now: str, section: str | None = None) -> str:
    """What to do about a claim this repo moved away from: the Open row that already names PATH
    (and SECTION, for a heading), or the row to add to BUFFER.md, the owner's to accept. Never
    written here."""
    ledger = root / BUFFER
    row = naming_row(buffer_rows(ledger.read_text()) if ledger.exists() else [], path, section)
    if row:
        return f"Open row {row[0]} in {BUFFER} already names it"
    return row_offer(claim, now)


_BROUGHT: dict[str, dict[str, str]] = {}


def brought_by(trunk: str) -> dict[str, str]:
    """Which first-parent merge on TRUNK brought each commit in."""
    if trunk not in _BROUGHT:
        out: dict[str, str] = {}
        for m in reversed(git("rev-list", "--first-parent", "--merges", trunk).splitlines()):
            for c in git("rev-list", f"{m}^1..{m}^2").splitlines():
                out.setdefault(c, m)
        _BROUGHT[trunk] = out
    return _BROUGHT[trunk]


def trunk_answers(commit: str, trunk: str, spec_dirs: list[str]) -> list["re.Match"]:
    """The P2 answers that covered COMMIT on trunk, read the way P2 read them: the specs it
    touched; and, for a commit a merge brought in, the specs its branch changed and the spec of
    the job whose entry that merge deleted (`jig merge` deletes it there), as trunk held it then
    (a one-line spec is its own text). Update reads these so it never offers a BUFFER row for
    what an answer already covered."""
    def specs_of(*rng: str) -> list[str]:
        return [p for p in git("-c", "core.quotePath=false", *rng, "--name-only", "--diff-filter=ACMRT",
                               "--", *spec_dirs).splitlines() if p.endswith(".md")]
    full = git("rev-parse", "-q", "--verify", f"{commit}^{{commit}}") or commit
    texts = [at_rev(full, s) for s in specs_of("show", "--format=", full)]
    m = brought_by(trunk).get(full)
    if m:
        texts += [at_rev(f"{m}^2", s) for s in specs_of("diff", f"{m}^1...{m}^2")]
        try:
            before = json.loads(at_rev(f"{m}^1", JOBS) or "{}")
            after = json.loads(at_rev(m, JOBS) or "{}")
        except ValueError:
            before, after = {}, {}
        for name in [n for n in before if n not in after]:
            spec = (before[name] or {}).get("spec") or ""
            if spec:
                texts.append(at_rev(f"{m}^1", spec) or spec)
    return [x for t in texts for x in PROPOSAL.finditer(t)]


def pointer_cleanup(root: Path) -> list[str]:
    """Update's Metarepo pointers block: each cached pointer that dangles, and its fix. An older
    P2 let some of these through; the update that brings the fix is where the repo hears of them."""
    if not (root / CACHE).is_dir():
        return [f"no metarepo cache ({CACHE}): run `jig sync`, then update again"]
    out = []
    try:
        para = json.loads((root / PARA).read_text()) if (root / PARA).exists() else {}
    except ValueError:
        para = {}
    meta, pin = para.get("meta", ""), para.get("pin", "")
    loc = meta_checkout(root, para) if para else None
    olds = dict(LAYOUT)
    for f, path, section, code, level, gap in dangling(root):
        line = f"{f} points to {gap}: "
        found = removal(path, section, code, level)
        if found is None:
            out.append(line + "this repo never had it, so the metarepo's pointer is what's wrong; "
                       "fix it there with `jig propose`")
            continue
        commit, now = found
        what = (f"renamed to {now} in {commit}" if level == NO_FILE and now != "deleted"
                else f"removed in {commit}")
        # A branch answer from this repo's metarepo: its rewrite is pending until the pin holds
        # the branch. Once the pin holds it and the pointer still dangles, the rewrite missed it,
        # and nothing else will fix it. A metarepo out of reach can't say, so it stays pending.
        branches = [x.group("pbranch") or x.group("branch") for x in
                    trunk_answers(commit, Board.trunk_name(root), [f"{DIR}/specs/", *olds[f"{DIR}/specs/"]])
                    if (x.group("pbranch") or x.group("branch")) and (x.group("pmeta") or x.group("meta")) == meta]
        pinned = [b for b in branches if loc is not None and pin and proposal_in(loc, b, pin)]
        pending = [b for b in branches if b not in pinned]
        if pending:
            out.append(line + f"this repo {what}, and the metarepo's rewrite is pending on "
                       f"{pending[0]}: it resolves when the pin holds that branch")
            continue
        shown = shown_section(plain(section), code) if level == NO_HEADING else None
        where = f"{path} § {shown}" if shown else path
        missed = f"the metarepo's rewrite in {pinned[0]} missed it; " if pinned else ""
        out.append(line + f"this repo {what}; " + missed
                   + buffer_offer(root, f"{f}: the pointer to {where}", path, f"{now}, {commit}", shown))
    return out


def contract_removals(root: Path, trunk: str) -> list[str]:
    """Update's Contract removals block: each trunk commit that took a contract path away while
    nothing answered it, which an older P2 let through, and the one BUFFER.md row to offer for
    it. Each commit is judged by the contract_paths its parent's para.json held, which is what P2
    read then. Writes nothing."""
    olds = dict(LAYOUT)
    para_at = [PARA, *olds[PARA]]
    spec_dirs = [f"{DIR}/specs/", *olds[f"{DIR}/specs/"]]
    ledgers = [f"{d}BUFFER.md" for d in (f"{DIR}/ledgers/", *olds[f"{DIR}/ledgers/"])]
    rows = buffer_rows(at_rev(trunk, BUFFER))
    # The Metarepo pointers block already speaks for a path a cached pointer names.
    pointed = {p for _, p, _, _, _, _ in dangling(root)}
    # A path trunk has again, restored or re-added, was put back: nothing is owed.
    back = set(git("-c", "core.quotePath=false", "ls-tree", "-r", "--name-only", trunk).splitlines())
    try:
        today = json.loads(at_rev(trunk, PARA) or "{}").get("contract_paths") or []
    except ValueError:
        today = []
    out = []
    for line in git("log", "--no-merges", "-M", "--diff-filter=DR", "--format=%H %h %s", trunk).splitlines():
        commit, short, subject = (line.split(" ", 2) + [""])[:3]
        raw = next((b for p in para_at if (b := at_rev(f"{commit}^", p))), "")
        try:
            globs = (json.loads(raw) if raw else {}).get("contract_paths") or []
        except ValueError:
            continue
        gone = [(o, n) for o, n in removed_by(commit) if matches(o, globs) and o not in back
                and not any(o == p or o.startswith(f"{p}/") for p in pointed) and not naming_row(rows, o, states=BUFFER_STATES)]
        if not gone:
            continue
        writes = git("-c", "core.quotePath=false", "show", "-M", "--name-only", "--diff-filter=ACMRT",
                     "--format=", commit).splitlines()
        if any(matches(w, globs) for w in writes):
            continue                    # P2 asked then, and its answer covers the commit
        if trunk_answers(commit, trunk, spec_dirs):
            continue
        added = git("show", "--format=", "-U0", commit, "--", *ledgers)
        if any(r[-1] == "Open" for l in added.splitlines() if l.startswith("+|") for r in buffer_rows(l[1:])):
            continue
        what = "; ".join(f"{o} → {n}" if n else f"{o} deleted" for o, n in gone)
        pin = json.loads(raw).get("pin") or "the pin"
        now = "; ".join(f"moved to {n}" if n else "deleted" for _, n in gone)
        text = (f"{short} {subject}: {what}: "
                + row_offer(f"the contract at {pin}: {', '.join(o for o, _ in gone)}", f"{now}, {short}"))
        for n in [n for _, n in gone if n and not matches(n, today)]:
            text += f"; {n} isn't a contract path: add it to contract_paths if it still holds the contract"
        out.append(text)
    return out


def removal_blocks(root: Path, trunk: str, always: bool) -> list[str]:
    """A pararepo update's Metarepo pointers and Contract removals blocks. ALWAYS, as a planned
    update's report shows them; otherwise only a block with something in it, so a repo that is
    up to date still hears of what an older P2 let through until it answers it."""
    out = []
    pointed = pointer_cleanup(root) if always or (root / CACHE).is_dir() else []
    if pointed:
        out += ["\nMetarepo pointers (from the cache as the last `jig sync` left it; update "
                "changes none of them):", *(f"  {l}" for l in pointed)]
    removed = contract_removals(root, trunk)
    if removed or always:
        out += ["\nContract removals (trunk commits an older P2 let take a contract path away "
                "unanswered; update changes none of them):", *(f"  {l}" for l in removed or ["none"])]
    return out


def cmd_propose(root: Path, args) -> int:
    para = json.loads((root / PARA).read_text()) if (root / PARA).exists() else None
    if para is None and (old := old_board(root)):
        # init refuses an older layout too, so naming it here would send someone in a circle.
        die(f"this repo is on an older jig layout ({old}): run `jig update` first; then, if it "
            "isn't a pararepo yet, `jig init --para <metarepo name>`", 2)
    if para is None:
        die(f"not a pararepo (no {PARA}): a proposal is a pararepo's branch on its metarepo. "
            "`jig init --para <metarepo name>` makes this one", 2)
    loc = meta_checkout(root, para)
    if loc is None:
        die(f"can't find {para['meta']}: run `jig repos add meta` in its checkout", 2)
    if args.buffer:
        slug = args.slug or args.spec or f"buffer-{date.today().isoformat()}"
        made = buffer_proposal(root, para, loc, slug)
        if made is None:
            print(f"nothing to propose: {BUFFER} has no Open row that a proposal doesn't already carry as it stands.")
            return 0
        spec, branch = made
        print(f"made {branch} in {para['meta']} for every Open row of {BUFFER}, listed in "
              f"{spec.relative_to(root)}. Commit that spec.")
        print(f"Write the change there on that branch (git -C {loc} worktree add <dir> {branch}); "
              f"the rows close when `jig sync` takes the release that holds it.")
        return 0
    if not (args.spec and args.slug):
        die("usage: jig propose <spec> <slug> [--pointers], or jig propose --buffer [slug]", 2)
    spec = root / args.spec
    if not spec.exists():
        die(f"no spec at {args.spec}", 2)
    branch = open_proposal(para, loc, args.slug)
    line = f"- meta: {para['meta']} {'pointers' if args.pointers else 'proposal'} {branch}"
    text = spec.read_text()
    if re.search(r"^## Decisions\s*$", text, re.M):
        text = re.sub(r"^(## Decisions\s*\n)", rf"\1{line}\n", text, count=1, flags=re.M)
    else:
        text = text.rstrip("\n") + f"\n\n## Decisions\n{line}\n"
    spec.write_text(text)
    print(f"made {branch} in {para['meta']} and recorded it in {args.spec}.")
    print(f"Write the change there on that branch (git -C {loc} worktree add "
          f"<dir> {branch}); it lands by the metarepo's own review and release.")
    return 0


def open_proposal(para: dict, loc: Path, slug: str) -> str:
    branch = f"propose/{main_root().name}-{slug}"   # the repo's name, not a job's folder
    if git("rev-parse", "-q", "--verify", f"refs/heads/{branch}", cwd=str(loc)):
        die(f"{branch} already exists in {para['meta']}", 2)
    # A branch from the metarepo's trunk, made without checking anything out: main is untouched.
    git("branch", branch, Board.trunk_name(loc), cwd=str(loc), check=True)
    return branch


def unproposed(root: Path) -> tuple[list[str], list[str]]:
    """The buffer's table header and its Open rows not yet proposed as they stand. A row a
    proposal already carries unchanged waits for that one; an edited row goes again."""
    text = (root / BUFFER).read_text() if (root / BUFFER).exists() else ""
    lines = [l for l in text.splitlines() if l.lstrip().startswith("|")]
    sent = proposed_rows([s.read_text() for s in sorted((root / DIR / "specs").glob("*.md"))])
    return ([l for l in lines if not buffer_rows(l)],
            [l for l in lines if buffer_rows(l) and buffer_rows(l)[0][-1] == "Open"
             and tuple(buffer_rows(l)[0]) not in sent])


def buffer_proposal(root: Path, para: dict, loc: Path, slug: str) -> tuple[Path, str] | None:
    """Every Open row of the buffer not yet proposed, in one proposal: a metarepo branch, and a
    spec here that lists the rows by id, which is the record of what went. None when no row
    is left to propose."""
    head, open_ = unproposed(root)
    if not open_:
        return None
    spec = root / DIR / "specs" / f"{slug}.md"
    if spec.exists():
        die(f"{spec.relative_to(root)} already exists: name the proposal (`jig propose --buffer <slug>`)", 2)
    branch = open_proposal(para, loc, slug)
    ids = "".join(f"- {buffer_rows(l)[0][0]}\n" for l in open_)
    table = "\n".join([*head, *open_])
    spec.parent.mkdir(parents=True, exist_ok=True)
    spec.write_text(
        f"# Buffer proposal: {slug}\n\n"
        f"Each row is a claim of {para['meta']} at {para['pin']} that this repo has moved away from. "
        f"For each row, {para['meta']} decides where the claim lives (RULES.md: What the metarepo holds). "
        f"A contract gets the new text with its source; a claim this repo owns gets a pointer to "
        f"the \"This repo now\" source wherever {para['meta']} states it, never a copy "
        f"(RULES.md: Newer wins, Every copy).\n\n"
        f"## Buffer rows\n{ids}\n{table}\n\n## Decisions\n- meta: {para['meta']} proposal {branch}\n")
    return spec, branch


# -------------------------------------------------------------------- staging

# Where a chat drops a file meant for this repo, or another. Untracked: nothing in it is
# authoritative, and it can reach a contract only through `jig staging resolve`.
STAGING = f"{DIR}/staging"
KINDS = ("spec", "doc", "decisions", "user-story", "feature-request", "feedback", "roadmap")
HEADER_KEYS = ("staged", "target", "kind", "change", "destination", "source", "status")


def feedback_dir() -> Path:
    """Where a tool report waits when the jig repo isn't in repos.json: beside that list, so
    it survives a cleared temp folder and the same `jig staging` finds it from any repo."""
    return repos_file().parent / "feedback"


def staged_files(root: Path) -> list[Path]:
    d = root / STAGING
    # Markdown only: a .DS_Store or an editor's swap file is not a staged file.
    return sorted(f for f in d.iterdir() if f.is_file() and f.suffix == ".md") if d.exists() else []


def read_staged(path: Path) -> tuple[dict, str, list[str]]:
    """The header (a `key: value` block between --- lines), the body, and what's wrong."""
    text = path.read_text(errors="replace").replace("\r\n", "\n")
    m = re.match(r"---\n(.*?)\n---\n?(.*)", text, re.S)
    if not m:
        return {}, text, ["no header"]
    head = {}
    for line in m.group(1).splitlines():
        k, sep, v = line.partition(":")
        if sep:
            head[k.strip()] = v.strip()
    bad = [f"no {k}" for k in HEADER_KEYS if not head.get(k)]
    if head.get("kind") and head["kind"] not in KINDS:
        bad.append(f"kind {head['kind']!r} is not one of {', '.join(KINDS)}")
    if head.get("kind") == "feedback" and not head.get("from"):
        bad.append("no from: a report names the repo it came from")
    if head.get("change") and head["change"] not in ("new", "update"):
        bad.append(f"change {head['change']!r} is not new or update")
    if head.get("staged") and head["staged"] != "true":
        bad.append("staged is not true")
    if head.get("kind") == "roadmap" and head.get("destination") and head["destination"] != ROADMAP:
        bad.append(f"destination {head['destination']!r}: a roadmap change lands in {ROADMAP} only")
    if head.get("kind") == "roadmap" and head.get("change") == "new":
        bad.append(f"change new: a roadmap change is `change: update` to {ROADMAP}")
    return head, m.group(2), bad


def provenance(head: dict, path: Path) -> str:
    """What a landed file carries to say where it came from. The staged file's name makes it
    one file's mark: two files from the same session can't stand in for each other."""
    return f"Source: {head.get('source', '')} (staged as {path.name})"


def staged_summary(root: Path) -> str:
    files = staged_files(root)
    if not files:
        return ""
    kinds = [read_staged(f)[0].get("kind", "?") for f in files]
    return f"{len(files)} staged in {STAGING}: " + ", ".join(
        f"{kinds.count(k)} {k}" for k in dict.fromkeys(kinds))


def fallback_files() -> list[Path]:
    d = feedback_dir()
    return sorted(d.glob("*.md")) if d.is_dir() else []


def release_waits_for() -> list[Path]:
    """The main checkout's staging, since staged files are never committed, and any report in
    the fallback folder aimed at this repo: it is staged here in all but location."""
    return staged_files(main_root()) + [f for f in fallback_files()
                                        if names_this_repo(read_staged(f)[0].get("target"), main_root())]


def staged_refusal(what: str) -> list[str]:
    """Release waits while anything is staged. Reading it only refuses more, so a branch can't
    weaken it."""
    files = release_waits_for()
    return [f"{what} waits while {len(files)} file{'s' if len(files) > 1 else ''} sit in "
            f"{STAGING} or {feedback_dir()}: {', '.join(f.name for f in files)}. Resolve or "
            f"drop each (`jig staging resolve` / `drop`), or force it"] if files else []


def this_repo_names(root: Path) -> set[str]:
    names = {"this", Board.load(root, working_tree=True).data.get("name") or main_root().name}
    # and any alias you gave this checkout in repos.json
    names |= {n for n, e in load_repos().items() if Path(e["path"]).resolve() == main_root().resolve()}
    meta = root / META
    if meta.exists():
        names.add(json.loads(meta.read_text() or "{}").get("name", ""))
    return names - {""}


def name_in(name: str | None, names: set[str]) -> bool:
    """A human types a repo's name, so `App` and `app` are one repo."""
    return (name or "").casefold() in {n.casefold() for n in names - {""}}


def names_this_repo(name: str | None, root: Path) -> bool:
    return name_in(name, this_repo_names(root))


def bare_path(dest: str) -> bool:
    """A header's destination is a path and nothing else: prose around it is never guessed at.
    A space counts as prose: "see docs/x.md" would otherwise land as a file of that name."""
    return dest.endswith(".md") and not re.search(r"[\s:,;]", dest)


def decision_id(cell: str) -> str:
    """D-2 and D-002 are one decision: the number counts, as R6 counts it."""
    return re.sub(r"\d+", lambda m: str(int(m.group())), cell.strip())


def after_names(head: dict) -> list[str]:
    """The staged files this one waits for: names, comma- or space-separated, a YAML list's
    brackets and quotes tolerated, `a` read as `a.md` since staged files are Markdown."""
    names = [Path(n).name for n in re.split(r"[,\s\[\]'\"]+", head.get("after", "")) if n]
    return [n if n.endswith(".md") else f"{n}.md" for n in names]


def batch_order(files: list[Path]) -> tuple[list[Path], dict[str, set[str]], set[str]]:
    """Files in an order where each comes after those its `after:` names, name order within a
    level; then, last since no order gets them through, each file in an `after` cycle with the
    cycle's members, and the files that only wait on one."""
    names = {f.name: f for f in files}
    edges = {f.name: {n for n in after_names(read_staged(f)[0]) if n in names and n != f.name}
             for f in files}
    waits = {n: set(w) for n, w in edges.items()}
    out: list[Path] = []
    while waits:
        ready = sorted(n for n, w in waits.items() if not w)
        if not ready:
            break
        for n in ready:
            out.append(names[n])
            del waits[n]
        for w in waits.values():
            w.difference_update(ready)

    def reach(n: str) -> set[str]:
        seen, todo = set(), list(waits.get(n, ()))
        while todo:
            m = todo.pop()
            if m not in seen:
                seen.add(m)
                todo += waits.get(m, ())
        return seen
    reaches = {n: reach(n) for n in waits}
    cycles = {n: {m for m in r if n in reaches[m]} for n, r in reaches.items() if n in r}
    return out + [names[n] for n in sorted(waits)], cycles, set(waits) - set(cycles)


def stuck_note(name: str, cycles: dict[str, set[str]], blocked: set[str]) -> str:
    if name in cycles:
        return f"after: in a cycle with {', '.join(sorted(cycles[name] - {name}))}"
    return "after: waits on a cycle" if name in blocked else ""


def escapes(dest: str) -> bool:
    """A destination is relative to the target's root and stays under it: no absolute path,
    no home folder, no drive, no `..` climbing out. `resolve` and `check` judge it alike."""
    return (dest.startswith(("/", "~", "\\")) or bool(re.match(r"[A-Za-z]:", dest))
            or os.path.normpath(dest).split(os.sep)[0] == "..")


def fill_workflow(root: Path, text: str) -> tuple[str, str]:
    """A spec staged from a chat can't run `jig workflow` against this repo's config, so its
    `## Workflow` arrives empty: resolve writes the lines /jig:spec would, or refuses as it
    does. A section that holds anything but comments is the author's, and stays."""
    head = re.search(r"^##[ \t]+workflow\b.*$", text, re.I | re.M)
    nxt = re.search(r"^## ", text[head.end():], re.M) if head else None
    body = text[head.end():head.end() + nxt.start()] if nxt else text[head.end():] if head else ""
    if head and re.sub(r"<!--.*?-->", "", body, flags=re.S).strip():
        return text, ""
    steps, bad = workflow_steps(Board.load(root, working_tree=True).data)
    if bad:
        die("\n  ".join(["the spec's ## Workflow is empty, and `jig workflow` refuses:", *bad,
                         f"fix {CONFIG}, then resolve again"]), 1)
    lines = "\n".join(f"{k}: tier {v['tier']}, effort {v['effort']}" for k, v in steps.items())
    if not head:
        return text.rstrip("\n") + f"\n\n## Workflow\n{lines}\n", "; ## Workflow added"
    kept = body.strip("\n")
    rest = text[head.end() + nxt.start():] if nxt else ""
    return (text[:head.end()] + "\n" + (f"{kept}\n" if kept else "") + f"{lines}\n"
            + (f"\n{rest}" if rest else "")), "; ## Workflow filled"


def cmd_staging_check(args) -> int:
    """Headers only, from the plugin's copy outside any repo: a chat writes a batch from
    outside the target and can't run `jig staging` there."""
    files = [Path(f).expanduser() for f in args.file]
    if not files:
        die("which files? jig staging check <file>…", 2)
    batch = {f.name for f in files}
    _, cycles, blocked = batch_order([f for f in files if f.is_file()])
    bad = False
    for f in files:
        if not f.is_file():
            print(f"{f}: no such file")
            bad = True
            continue
        head, _, problems = read_staged(f)
        notes = []
        dest = head.get("destination", "")
        if dest and escapes(dest):
            problems.append(f"destination {dest!r} is outside the target: give a path relative "
                            "to its root")
        target = head.get("target", "")
        there = repo_path(target) if target and target != "this" else None
        if target and target != "this" and not there:
            problems.append(f"target {target!r} isn't in {repos_file()} (`jig repos` lists them)")
        # A warning only: the owner may keep both names on purpose.
        for a, b in near_duplicates(load_repos()):
            if name_in(target, {a, b}):
                notes.append(f"target {target!r}: {a} and {b} are both in the repos list; "
                             "make sure it is the one you mean")
        have = batch | ({p.name for p in staged_files(there)} if there else set())
        problems += [f"after {n}: not in this batch or the target's staging"
                     for n in after_names(head) if n not in have]
        if stuck := stuck_note(f.name, cycles, blocked):
            problems.append(f"{stuck}: no order resolves it; fix one header's after:")
        print(f"{f.name}: {'ok' if not problems else ''}".rstrip())
        for p in problems:
            print(f"    {p}")
        for n in notes:
            print(f"    warning: {n}")
        bad |= bool(problems)
    return 1 if bad else 0


def cmd_staging(root: Path, args) -> int:
    if args.action not in ("resolve", "drop"):
        files, cycles, blocked = batch_order(staged_files(root))
        waiting = fallback_files()
        if not files and not waiting:
            print(f"nothing staged in {STAGING}")
            return 0
        if files:
            print(staged_summary(root))
        if waiting:
            why = "" if repo_path("jig") else " (the jig repo isn't in repos.json)"
            print(f"{len(waiting)} waiting in {feedback_dir()}{why}:")
        bad = False
        for f in files + waiting:
            head, _, problems = read_staged(f)
            origin = f", from {head['from']}" if head.get("from") else ""
            waits = f", after {', '.join(after_names(head))}" if after_names(head) else ""
            print(f"  {f.name}: {head.get('change', '?')} {head.get('kind', '?')} for "
                  f"{head.get('target', '?')} → {head.get('destination', '?')}{origin}{waits}")
            for p in problems:
                print(f"      {p}")
                bad = True
            # A waited-for file that isn't staged is gone: resolved, dropped or forwarded.
            # `check`, which sees the batch before it is staged, catches a misspelt name.
            if stuck := stuck_note(f.name, cycles, blocked):
                print(f"      {stuck}")
                bad = True
        return 1 if bad else 0

    if not args.file:
        die(f"which file? jig staging {args.action} <file>", 2)
    # Staged files live in the main checkout only: they are never committed into a job. A
    # report whose jig repo wasn't registered waits in the fallback folder instead.
    name = Path(args.file).name
    path = main_root() / STAGING / name
    if not path.exists():
        path = feedback_dir() / name
    if not path.exists():
        die(f"no {args.file} in {STAGING} or {feedback_dir()}", 2)
    if args.action == "drop":
        # A staged file was never committed, so a record of dropping it would point at nothing.
        path.unlink()
        print(f"dropped {path.name}")
        return 0
    head, body, problems = read_staged(path)
    if problems:
        die(f"{path.name}: {'; '.join(problems)}", 2)
    still = [n for n in after_names(head)
             if n != path.name and ((main_root() / STAGING / n).exists() or (feedback_dir() / n).exists())]
    if still:
        _, cycles, blocked = batch_order(staged_files(main_root()) + fallback_files())
        stuck = stuck_note(path.name, cycles, blocked)
        die(f"{path.name} waits for {', '.join(still)}, still staged: "
            + (f"{stuck}, so no order resolves it; fix one header's after:" if stuck else
               f"resolve or drop {'it' if len(still) == 1 else 'them'} first"), 1)
    kind, change, dest = (head.get(k, "") for k in ("kind", "change", "destination"))
    mark = provenance(head, path)

    target = head["target"]
    if not names_this_repo(target, root):
        return forward(root, path, head)

    def done(msg: str) -> int:
        path.unlink()
        print(f"resolved {path.name}: {msg}")
        return 0

    def inside(rel: str) -> Path:
        """A destination stays inside the repo: no absolute path, no climbing out with .."""
        out = (root / rel).resolve()
        if escapes(rel) or not out.is_relative_to(root.resolve()):
            die(f"destination {rel!r} is outside this repo: give a path relative to its root", 2)
        return out

    def landed(rel: str) -> bool:
        f = inside(rel)
        return f.exists() and mark in f.read_text(errors="replace")

    if kind == "roadmap":
        # The roadmap carries no provenance lines, so the owner reads it as the plan; the
        # commit that applied the change on trunk carries the mark in its message instead.
        trunk = Board.load(root, working_tree=True).trunk
        if not git("log", trunk, "-F", f"--grep={mark}", "--format=%h", "--", ROADMAP):
            die(f"a roadmap change lands on {trunk}: show the owner the diff to {ROADMAP}, apply "
                f"it on a yes, `jig roadmap --write`, and commit with `{mark}` in the message, "
                "then resolve again", 1)
        return done(f"applied to {ROADMAP} on {trunk}")
    if kind == "feature-request" and change == "update" and bare_path(dest):
        # The header names the spec the request changes; another spec carrying the mark would
        # resolve it while the named one is never amended.
        if not landed(dest):
            die(f"a request resolves into a spec: amend {dest}, the spec it names, from it, "
                f"carrying `{mark}`, then resolve again", 1)
        return done(f"carried by {dest}")
    if kind in ("user-story", "feature-request", "feedback"):
        specs = [s for s in (root / DIR / "specs").glob("*.md") if mark in s.read_text()]
        if not specs:
            how = "write a new spec" if change == "new" else "amend the spec it extends"
            what = {"user-story": "a story", "feature-request": "a request"}.get(kind, "a report")
            die(f"{what} resolves into a spec: {how} under {DIR}/specs/ from it, carrying "
                f"`{mark}`, then resolve again", 1)
        return done(f"carried by {specs[0].relative_to(root)}")
    if kind in ("spec", "doc") and not bare_path(dest):
        die(f"destination {dest!r} isn't a path yet: find the page, put its path in the header, "
            "then resolve again", 1)
    if kind == "decisions" and not (root / LOG).exists():
        # A repo `jig update` hasn't moved to the log yet keeps its register of rows until it does.
        return resolve_register(root, path, dest, change, body, mark, inside, done)
    if kind == "decisions" and not bare_path(dest):
        die(f"destination {dest!r} in the header isn't a path: put {LOG} in `destination:`, "
            "then resolve again", 1)
    if kind == "decisions" and dest != LOG:
        # One log per repo: a second register would hold decisions nobody reads or cites.
        die(f"`destination:` is {dest}, not {LOG}: decisions land in the repo's one log; fix "
            "the header, then resolve again", 1)
    if kind == "spec" and not dest.startswith(f"{DIR}/specs/"):
        dest = f"{DIR}/specs/{Path(dest).name}"
    if dest in RULES_NAMES:
        # A root rules file is loaded on every agent turn, so a provenance line there costs
        # every load: like the roadmap, the trunk commit that changed it carries the mark.
        # --full-history sees a mark on a job's merge commit, the usual way the file arrives.
        trunk = Board.load(root, working_tree=True).trunk
        if git("log", trunk, "--full-history", "-F", f"--grep={mark}", "--format=%h", "--", dest):
            return done(f"applied to {dest} on {trunk}")
        if change == "new" and not inside(dest).exists():
            inside(dest).write_text(body.lstrip("\n"))
            step = f"wrote {dest} with no mark in it: commit it"
        else:
            step = f"needs judgment: edit {dest} with this file's content and commit the edit"
        die(f"{step}, on {trunk} or in a job merged to {trunk}, with `{mark}` in the commit "
            "message, never in the file, then resolve again", 1)
    prefix = log_prefix(Board.trunk_name(root))
    if change == "update":
        if kind == "decisions":
            # An accepted entry is never edited, so an update is an Open entry edited in place or
            # a new accepted entry that supersedes and removes it: the log shows it once it's done.
            text = inside(dest).read_text() if inside(dest).exists() else ""
            have = {e["id"]: e["block"] for e in log_entries(text, prefix)}
            missing = [e["id"] for e in log_entries(body, prefix) if have.get(e["id"]) != e["block"]]
            if missing:
                die(f"edit {dest} so it shows {', '.join(missing)} as staged (a released entry is "
                    f"superseded by a new accepted entry that removes it in the same commit, never edited), "
                    f"then resolve again", 1)
            return done(f"entries confirmed in {dest}")
        if not landed(dest):
            die(f"needs judgment: edit {dest} with this file's content, keeping `{mark}` in it "
                "as provenance, then resolve again", 1)
        return done(f"{dest} carries it")
    if kind == "decisions":
        log = inside(dest)
        entries = log_entries(body, prefix)
        first = next((i for i, l in enumerate(body.splitlines()) if l.startswith("### ")), None)
        rest = [l for l in body.splitlines()[:first] if l.strip() and not l.lstrip().startswith(("#", "<!--"))]
        if rest or not entries:
            die(f"{path.name} holds {'no decision entries' if not entries else 'lines before its first entry'}: "
                f"each decision is `### {prefix}?<slug> <title>` with its status line under it", 1)
        problems = log_problems("## Open\n\n" + "\n\n".join(e["block"] for e in entries
                                                                 if not e["status"].startswith("Accepted"))
                                + "\n\n## Unreleased\n\n" + "\n\n".join(e["block"] for e in entries
                                                                       if e["status"].startswith("Accepted")),
                                prefix)
        problems = [p for p in problems if "supersedes" not in p]
        if problems:
            die("\n  ".join([f"{path.name} isn't ready for the log:", *problems]), 1)
        text = log.read_text() if log.exists() else LOG_SEED
        have = {decision_id(e["id"]) for e in log_entries(text, prefix)}
        dupes = [e["id"] for e in entries if decision_id(e["id"]) in have]
        if dupes:
            die(f"{', '.join(dupes)} already in {dest}: stage it as `change: update`", 1)
        for e in entries:
            # Open questions are asked under ## Open; an accepted entry is this release's.
            section = "## Unreleased" if e["status"].startswith("Accepted") else "## Open"
            if not re.search(rf"^{section}[ \t]*$", text, re.M):
                text = text.rstrip("\n") + f"\n\n{section}\n"
            text = re.sub(rf"^{section}[ \t]*\n", lambda m: f"{m.group(0)}\n{e['block']}\n", text,
                          count=1, flags=re.M)
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(text)
        n = len(entries)
        return done(f"{n} entr{'ies' if n > 1 else 'y'} added to {dest}")
    out = inside(dest)
    if out.exists():
        die(f"{dest} exists: stage it as `change: update`, or pick another path", 1)
    out.parent.mkdir(parents=True, exist_ok=True)
    filled = ""
    if kind == "spec":
        first, _, rest = body.lstrip("\n").partition("\n")
        text, filled = fill_workflow(root, f"{first}\n\n{mark}\n{rest}" if first.startswith("#")
                                     else f"{mark}\n\n{body}")
        out.write_text(text)
    else:
        out.write_text(body.rstrip("\n") + f"\n\n---\n{mark}\n")
    return done(f"written to {dest}{filled}")


def resolve_register(root: Path, path: Path, dest: str, change: str, body: str, mark: str,
                     inside, done) -> int:
    """Staged decisions in a repo with no log yet: rows appended to the register, as before it."""
    if not bare_path(dest):
        die(f"destination {dest!r} in the header isn't a path: put only the register's "
            "path in `destination:`, then resolve again", 1)
    if (root / META).exists():
        # A misspelt register (DECISION.md) would start a second one nobody cites.
        entry = {**META_DEFAULTS, **json.loads((root / META).read_text() or "{}")}["entry_files"]
        if not is_entry(dest, entry):
            die(f"destination {dest} isn't a register {META}'s entry_files name "
                f"({', '.join(entry)}): fix the header, or add it there first", 1)
    reg = inside(dest)
    rows = decision_rows(body, root)
    if change == "update":
        text = reg.read_text() if reg.exists() else ""
        missing = [r for r in rows if r not in text]
        if missing or mark not in text:
            die(f"edit {reg.relative_to(root.resolve())} so it shows these rows and carries "
                f"`{mark}`, then resolve again", 1)
        return done(f"rows confirmed in {reg.relative_to(root)}")
    rest = [l for l in body.splitlines() if l.strip() and l.rstrip() not in rows
            and not l.lstrip().startswith(("|---", "| Id", "#", "<!--"))]
    if rest:
        die(f"{len(rest)} line{'s' if len(rest) > 1 else ''} in {path.name} aren't decision "
            "rows: apply them with the user, delete them from the staged file, then resolve "
            "again", 1)
    if not rows:
        die(f"no decision rows in {path.name}", 1)
    text = reg.read_text() if reg.exists() else "| Id | Decision | Status | Date |\n|---|---|---|---|\n"
    have = {decision_id(l.split("|")[1]) for l in text.splitlines() if l.startswith("|") and l.count("|") > 2}
    dupes = [r.split("|")[1].strip() for r in rows if decision_id(r.split("|")[1]) in have]
    if dupes:
        die(f"{', '.join(dupes)} already in {reg.name}: stage it as `change: update`", 1)
    reg.parent.mkdir(parents=True, exist_ok=True)
    reg.write_text(text.rstrip("\n") + "\n" + "\n".join(rows) + "\n")
    ids = ", ".join(r.split("|")[1].strip() for r in rows)
    # In a metarepo, M3 refuses the commit on a branch with no line yet: that's its rule
    # to enforce, not staging's line to write.
    also = f"; add `- {ids}. {mark}` to {CHANGELOG} (M3)" if (root / META).exists() else ""
    return done(f"{len(rows)} row{'s' if len(rows) > 1 else ''} appended to {reg.name}{also}")


def decision_rows(body: str, root: Path) -> list[str]:
    meta = root / META
    # A metarepo's ids are its decision_prefix, defaulted like everywhere else; a plain repo's
    # register has no configured prefix, so any uppercase one is taken.
    known = ({**META_DEFAULTS, **json.loads(meta.read_text() or "{}")}["decision_prefix"]
             if meta.exists() else None)
    prefix = re.escape(known) if known else r"[A-Z][A-Z0-9]*-"
    rx = re.compile(rf"^\s*\|\s*{prefix}\d+\s*\|")
    return [l.rstrip() for l in body.splitlines() if rx.match(l)]


def forward(root: Path, path: Path, head: dict) -> int:
    """A staged file is resolved in its target. From here it moves into the target's own
    staging, the one place jig writes in another repo, after checking both sides agree."""
    target = head["target"]
    there = repo_path(target)
    if not there:
        die(f"{target} isn't this repo and isn't in {repos_file()}: "
            f"jig repos add {target} <path>", 2)
    there = Path(there)
    if old := old_board(there):
        die(f"{target} at {there} is on an older jig layout ({old}): run `jig update` there "
            "first, then resolve again", 2)
    if not (there / DIR).is_dir():
        die(f"{target} is listed at {there}, but that isn't a jig repo (no {DIR}/): fix it "
            f"with `jig repos add {target} <path>`", 2)
    me = Board.load(root, working_tree=True).data.get("name") or main_root().name
    para = json.loads((root / PARA).read_text()) if (root / PARA).exists() else None
    meta = json.loads((root / META).read_text()) if (root / META).exists() else None
    if para and target == para.get("meta"):
        theirs = json.loads(git("show", f"HEAD:{META}", cwd=str(there)) or "{}")
        if me not in theirs.get("pararepos", []):
            die(f"{target}'s {META} doesn't list {me} as a pararepo: add it there "
                "first", 2)
    if meta and target in meta.get("pararepos", []):
        theirs = json.loads((there / PARA).read_text()) if (there / PARA).exists() else {}
        if theirs.get("meta") != meta.get("name"):
            die(f"{target}'s {PARA} doesn't cite {meta.get('name')}: run `jig init --para` there "
                "first", 2)
    dest = there / STAGING / path.name
    if dest.exists():
        die(f"{target} already has {STAGING}/{path.name}", 2)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(path), dest)
    print(f"forwarded {path.name} to {target}'s {STAGING}/; resolve it in a session there.")
    if para and target == para.get("meta"):
        print(f"If a spec here depends on it: jig propose <spec> <slug>.")
    return 0


# -------------------------------------------------------------------- roadmap

# The roadmap is optional: a repo without ROADMAP has no roadmap, and nothing below runs for it.
# Phases and scopes are the owner's decisions; their states are derived from specs and the
# handoffs that landed them, so the file never takes a progress edit.
ROADMAP = f"{DIR}/roadmap.md"
ROADMAP_VIEW = "ROADMAP.md"
SPECS = f"{DIR}/specs/"
HANDOFFS = f"{DIR}/handoffs/"


class Snapshot:
    """Where the roadmap's inputs are read from: a commit (trunk), the index (a merge being
    committed, which the view must describe), or the trunk checkout's files (`--write`, which
    a roadmap edit regenerates before it is committed)."""
    def __init__(self, rev: str = "", where: str = "rev"):
        self.rev, self.where = rev, where

    def ls(self, folder: str) -> list[str]:
        # Tracked files only, in both checkout modes: an untracked spec draft or note isn't
        # work merge or `jig roadmap` would see. An unmerged path is listed once per stage.
        args = (["ls-tree", "-r", "--name-only", self.rev, "--", folder] if self.where == "rev"
                else ["ls-files", "--", folder])
        out = git("-c", "core.quotePath=false", *args, cwd=str(main_root())).splitlines()
        return list(dict.fromkeys(p for p in out if p))

    def show(self, path: str) -> str:
        if self.where == "files":
            p = main_root() / path
            return p.read_text(errors="replace") if p.is_file() else ""
        return git("show", f"{':' if self.where == 'index' else self.rev + ':'}{path}")

    def landed(self, commit: str) -> bool:
        """The note's commit is in this tree's history. Mid-merge that history is both parents."""
        if self.where == "rev":
            return is_ancestor(commit, self.rev)
        merge = git("rev-parse", "-q", "--verify", "MERGE_HEAD", cwd=str(main_root()))
        return any(is_ancestor(commit, t) for t in ["HEAD"] + ([merge] if merge else []))


# Unindented, so a nested note under a scope is never a scope; no space or `/` in the name,
# since the id is <phase>/<scope> and is written on one line in specs.
SCOPE_LINE = re.compile(r"- `?([A-Za-z0-9][\w.-]*)`?(?::\s*(.*))?")


# The one roadmap section that isn't a phase: parked work, in no order, each item naming the
# pages it will touch. Reserved by name, so no phase can be called it.
UP_NEXT = "Up next"
# `(touches docs/a.md, docs/b.md)` at the end of an Up next item or a scope: the pages the
# work will change, which reading-list and fold-in look items up by.
TOUCHES = re.compile(r"\s*\(touches\s+([^()]*)\)\s*$")


def split_touches(what: str) -> tuple[str, list[str]]:
    """An item's text without its `(touches …)`, and the pages it names."""
    m = TOUCHES.search(what)
    if not m:
        return what, []
    pages = [p.strip().strip("`") for p in m.group(1).split(",") if p.strip()]
    return what[:m.start()].rstrip(), pages


def parse_up_next(text: str, problems: list[str] | None = None) -> list[dict]:
    """The items under `## Up next`, each {id, what, touches, line}, in file order."""
    problems = [] if problems is None else problems
    items: list[dict] = []
    inside, fence = False, False
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.rstrip()
        if line.lstrip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        if m := re.match(r"##\s+(.+?)$", line):
            inside = m.group(1).strip().lower() == UP_NEXT.lower()
            continue
        if not inside or not line.strip() or line[0] in " \t":
            continue
        m = SCOPE_LINE.fullmatch(line)
        if not m:
            problems.append(f"line {n}: not an {UP_NEXT} item (- `<id>`: <what is parked> "
                            f"(touches docs/<page>.md), unindented): {line.strip()}")
            continue
        what, pages = split_touches((m.group(2) or "").strip())
        if any(i["id"] == m.group(1) for i in items):
            problems.append(f"line {n}: {UP_NEXT} item {m.group(1)} appears twice")
        if not pages:
            problems.append(f"line {n}: {UP_NEXT} item {m.group(1)} names no page: end it with "
                            "(touches docs/<page>.md, …)")
        items.append({"id": m.group(1), "what": what, "touches": pages, "line": n})
    return items


def remove_up_next(text: str, ids: set[str]) -> str:
    """TEXT without the Up next items IDS names, nested lines under each included."""
    out, inside, dropping = [], False, False
    for line in text.splitlines(keepends=True):
        if m := re.match(r"##\s+(.+?)\s*$", line):
            inside, dropping = m.group(1).strip().lower() == UP_NEXT.lower(), False
        elif inside and line.strip() and line[0] not in " \t":
            m = SCOPE_LINE.fullmatch(line.rstrip())
            dropping = bool(m and m.group(1) in ids)
        if not dropping:
            out.append(line)
    return "".join(out)


def page_moves(rev: str) -> dict[str, str]:
    """The docs pages the index renames from REV, old path to new. A move between a page's two
    forms is no move: both name the page."""
    out = {}
    for line in git("-c", "core.quotePath=false", "diff", "--cached", "-M", "--name-status",
                    rev, "--", "docs/").splitlines():
        parts = line.split("\t")
        if parts[0].startswith("R") and len(parts) == 3 and not same_page(parts[1], parts[2]):
            out[parts[1]] = parts[2]
    return out


def retarget_touches(text: str, moves: dict[str, str]) -> str:
    """TEXT with each `(touches …)` page MOVES renames written at its new path."""
    if not moves:
        return text

    def fix(m: re.Match) -> str:
        pages = [p.strip() for p in m.group(1).split(",") if p.strip()]
        new = [next((to for old, to in moves.items() if same_page(p.strip("`"), old)), p) for p in pages]
        return m.group(0).replace(m.group(1), ", ".join(new)) if new != pages else m.group(0)
    return "".join(TOUCHES.sub(fix, line.rstrip("\n")) + ("\n" if line.endswith("\n") else "")
                   for line in text.splitlines(keepends=True))


def parse_roadmap(text: str, problems: list[str] | None = None) -> list[dict]:
    """Phases in file order, each {name, exit: [(ticked, text)], scopes: [(id, what)]}.
    Anything it can't read is added to PROBLEMS by line, never dropped quietly: a scope lost
    to a typo would read as a phase with less work in it. Fenced code is skipped, so a roadmap
    that quotes an example doesn't grow phases. `## Up next` is no phase: parse_up_next reads it."""
    problems = [] if problems is None else problems
    phases: list[dict] = []
    part, fence, ids, skip = "", False, set(), False
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.rstrip()
        if line.lstrip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        if m := re.match(r"##\s+(.+?)$", line):
            skip = m.group(1).strip().lower() == UP_NEXT.lower()
            if skip:
                continue
            if any(p["name"] == m.group(1) for p in phases):
                problems.append(f"line {n}: phase {m.group(1)} appears twice")
            phases.append({"name": m.group(1), "exit": [], "scopes": [], "line": n, "headed": False})
            part = ""
        elif skip or not phases:
            continue
        elif re.fullmatch(r"(?i)exit when:", line.strip()):
            part, phases[-1]["headed"] = "exit", True
        elif re.fullmatch(r"(?i)scopes:", line.strip()):
            part, phases[-1]["headed"] = "scopes", True
        elif part == "exit" and (m := re.match(r"\s*- \[([ xX])\]\s*(.*)", line)):
            phases[-1]["exit"].append((m.group(1) != " ", m.group(2).strip()))
        elif part == "scopes" and line.strip():
            m = SCOPE_LINE.fullmatch(line)
            if not m:
                problems.append(f"line {n}: not a scope (- `<scope>`: <what it is>, unindented, "
                                f"its name with no space or /): {line.strip()}")
                continue
            sid = f"{phases[-1]['name']}/{m.group(1)}"
            if sid in ids:
                problems.append(f"line {n}: scope {sid} appears twice")
            ids.add(sid)
            phases[-1]["scopes"].append((sid, (m.group(2) or "").strip()))
    for p in phases:
        if not p["headed"]:
            problems.append(f"line {p['line']}: phase {p['name']} has neither `Exit when:` nor "
                            f"`Scopes:` (every `## ` heading but ## {UP_NEXT} is a phase)")
    return phases


def roadmap_scopes(text: str) -> set[str]:
    return {sid for p in parse_roadmap(text) for sid, _ in p["scopes"]}


def spec_scopes(text: str) -> list[str]:
    """The scopes a spec's `Scope:` line takes, in its order."""
    m = re.search(r"^Scope:[ \t]*(.*)$", text, re.M)
    return [s.strip().strip("`") for s in m.group(1).split(",") if s.strip()] if m else []


def is_spec(path: str) -> bool:
    # _template.md is the shape a spec starts from, not a task: its placeholder takes nothing.
    return path.startswith(SPECS) and path.endswith(".md") and not Path(path).name.startswith("_")


def complete_specs(snap: Snapshot) -> set[str]:
    """Specs with a landed handoff that isn't partial: its work is in this tree's history."""
    done: set[str] = set()
    for n in snap.ls(HANDOFFS):
        body = snap.show(n)
        spec = re.search(r"^Spec: (\S+)", body, re.M)
        commit = re.search(r"^Commit: (\w+)", body, re.M)
        if not spec or not commit or re.search(r"^Partial: yes", body, re.M):
            continue
        s = os.path.normpath(spec.group(1))
        if s not in done and snap.landed(commit.group(1)):
            done.add(s)
    return done


def roadmap_state(snap: Snapshot) -> list[dict] | None:
    """The roadmap with every scope's specs and state and every phase's state, or None
    when this tree has no roadmap."""
    text = snap.show(ROADMAP)
    if not text:
        return None
    phases = parse_roadmap(text)
    takes: dict[str, list[str]] = {}
    for f in snap.ls(SPECS):
        if is_spec(f):
            for s in spec_scopes(snap.show(f)):
                takes.setdefault(s, []).append(f)
    done = complete_specs(snap)
    # A note may name its spec by file name alone; the spec's path or its name both count.
    finished = lambda f: f in done or Path(f).name in done
    current = None
    for p in phases:
        p["scopes"] = [{"id": sid, "what": what, "specs": [(f, finished(f)) for f in takes.get(sid, [])]}
                       for sid, what in p["scopes"]]
        for s in p["scopes"]:
            s["state"] = ("open" if not s["specs"] else
                          "done" if all(ok for _, ok in s["specs"]) else "taken")
        # A phase with nothing in it has nothing to finish, so it is never done: it would
        # otherwise read as finished work.
        p["empty"] = not p["scopes"] and not p["exit"]
        if not p["empty"] and all(s["state"] == "done" for s in p["scopes"]) and all(t for t, _ in p["exit"]):
            p["state"] = "done"
        elif current is None:
            p["state"] = current = "current"
        else:
            p["state"] = "next"
    return phases


def roadmap_view(snap: Snapshot, phases: list[dict]) -> str:
    """ROADMAP.md as SNAP's roadmap renders it, Up next included."""
    return render_roadmap(phases, parse_up_next(snap.show(ROADMAP)))


def render_roadmap(phases: list[dict], up_next: list[dict] | None = None) -> str:
    """ROADMAP.md: plain Markdown tables, which every forge and previewer renders. Up next
    follows the phases: parked work, in no order, each item with the pages it touches."""
    line = " → ".join(f"{p['name']} ✓" if p["state"] == "done" else
                      f"**{p['name']}** (current)" if p["state"] == "current" else p["name"]
                      for p in phases)
    out = ["# Roadmap", "",
           f"_Generated by `jig roadmap --write` from [{ROADMAP}]({ROADMAP}): edit that file, "
           "not this one._", "", line]
    for p in phases:
        out += ["", f"## {p['name']} ({p['state']}{', empty' if p['empty'] else ''})", ""]
        if p["exit"]:
            out += ["Exit when:"] + [f"- [{'x' if t else ' '}] {what}" for t, what in p["exit"]] + [""]
        if not p["scopes"]:
            out.append("_No scopes._")
            continue
        cols = [[s for s in p["scopes"] if s["state"] == st] for st in ("open", "taken", "done")]
        out += ["| Open | Taken | Done |", "|---|---|---|"]
        for i in range(max(len(c) for c in cols)):
            out.append("| " + " | ".join(scope_cell(c[i]) if i < len(c) else "" for c in cols) + " |")
    if up_next:
        out += ["", f"## {UP_NEXT}", ""]
        out += [f"- **{i['id']}**" + (f": {i['what']}" if i["what"] else "")
                + (" — touches " + ", ".join(f"[{p}]({p})" for p in i["touches"]) if i["touches"] else "")
                for i in up_next]
    return "\n".join(out) + "\n"


def scope_cell(s: dict) -> str:
    name = s["id"].split("/", 1)[1]
    cell = f"**{name}**" + (f": {s['what']}" if s["what"] else "")
    cell += "".join(f"<br>[{Path(f).stem}]({f}){' ✓' if ok else ''}" for f, ok in s["specs"])
    return cell.replace("|", "\\|")


def cmd_roadmap(root: Path, args) -> int:
    board = Board.load(root, working_tree=True)
    trunk = board.trunk
    if args.write:
        if git("branch", "--show-current") != trunk or not is_main_worktree(root):
            die(f"write {ROADMAP_VIEW} in the {trunk} checkout: R5 keeps it on {trunk}")
        snap = Snapshot(where="files")
        phases = roadmap_state(snap)
        if phases is None:
            die(f"no {ROADMAP}: this repo keeps no roadmap")
        (main_root() / ROADMAP_VIEW).write_text(roadmap_view(snap, phases))
        print(f"wrote {ROADMAP_VIEW}; commit it on {trunk}")
        return 0
    snap = Snapshot(trunk)
    phases = roadmap_state(snap)
    if phases is None:
        print(f"no roadmap: {trunk} has no {ROADMAP}")
        return 0
    problems: list[str] = []
    parse_roadmap(snap.show(ROADMAP), problems)
    up_next = parse_up_next(snap.show(ROADMAP), problems)
    have = set(snap.ls("docs/"))
    problems += [f"{iid} touches {page}, which {trunk} has no page for: re-point it"
                 for iid, page in sorted(dead_touches(snap.show(ROADMAP), have))]
    for x in problems:
        print(f"{ROADMAP} {x}")
    for p in phases:
        print(f"{p['name']}  {p['state']}"
              + ("  (empty: no scopes and no exit boxes)" if p["empty"] else ""))
        for t, what in p["exit"]:
            print(f"  [{'x' if t else ' '}] {what}")
        for s in p["scopes"]:
            specs = ", ".join(f"{f} ({'complete' if ok else 'in progress'})" for f, ok in s["specs"])
            print(f"  {s['id']:<24} {s['state']:<6} {specs}")
    if up_next:
        print(UP_NEXT)
        for i in up_next:
            print(f"  {i['id']:<24} {i['what']}  (touches {', '.join(i['touches']) or 'nothing'})")
    view = git("show", f"{trunk}:{ROADMAP_VIEW}")
    if view != render_roadmap(phases, up_next).strip():
        print(f"\n{ROADMAP_VIEW} on {trunk} is {'stale' if view else 'missing'}: "
              f"`jig roadmap --write` in the {trunk} checkout, then commit it")
    return 1 if problems else 0


# The project's files: a page or a decision entry that names one goes stale whenever the plan
# moves, and is released to pararepos as if it were the product (RULES.md, Documentation).
# These are never product text, so the hook refuses them; ROADMAP.md may be a product's own
# word, so only survey lists it.
PROJECT_PATHS = re.compile(r"\.jig/(?:specs|handoffs)/|\.jig/roadmap\.md")
PLAN_PATHS = re.compile(r"\.jig/(?:specs|handoffs)/|\.jig/roadmap\.md|(?<![\w./-])ROADMAP\.md")


def product_file(path: str, meta: dict | None = None) -> bool:
    """A file that describes the product only: a docs page, the decision log, or a metarepo's
    entry file."""
    return (path == LOG or (path.startswith("docs/") and path.endswith(".md") and not reference_file(path))
            or (meta is not None and path.endswith(".md") and is_entry(path, meta.get("entry_files", []))))


def scope_ids(text: str) -> list[str]:
    return [sid for p in parse_roadmap(text) for sid, _ in p["scopes"]]


def scope_quoted(sids: list[str]) -> list[re.Pattern]:
    """A scope id in code quotes, which no product sentence writes: `alpha/screen`. Bare, the
    words may be the product's ("the v1/api endpoint"), so survey lists those."""
    return [re.compile(rf"`{re.escape(sid)}`") for sid in sids]


def scope_bare(sids: list[str]) -> list[re.Pattern]:
    return [re.compile(rf"(?<![\w./-]){re.escape(sid)}(?![\w/-])") for sid in sids]


def added_lines(trunk: str, staged: bool, files: list[str]) -> list[tuple[str, int, str]]:
    """(path, line number, text) for each line the change adds to FILES. Renames are followed,
    so a moved page's old lines aren't new; the prefixes are fixed, whatever the user's diff
    settings."""
    # Both sides of every rename are in the pathspec, or git can't see the rename.
    gone = [f for f in changed_paths(trunk, staged, removed=True) if f.endswith(".md") and f not in files]
    diff = git("-c", "core.quotePath=false", "diff", "-M", "-U0", "--no-ext-diff", "--no-color",
               "--src-prefix=a/", "--dst-prefix=b/", base(trunk), *(["--cached"] if staged else []),
               "--", *files, *gone)
    out, at, n, want = [], "", 0, set(files)
    for line in diff.splitlines():
        if line.startswith("+++ "):
            at = line[6:] if line.startswith("+++ b/") and line[6:] in want else ""
        elif m := re.match(r"@@ -\S+ \+(\d+)", line):
            n = int(m.group(1))
        elif line.startswith("+") and at:
            out.append((at, n, line[1:]))
            n += 1
    return out


def dead_touches(text: str, have: set[str]) -> set[tuple[str, str]]:
    """(item or scope id, page) for each `(touches …)` page HAVE holds in neither form."""
    out = set()
    for i in parse_up_next(text):
        out |= {(i["id"], t) for t in i["touches"] if page_in(t, have) not in have}
    for p in parse_roadmap(text):
        for sid, what in p["scopes"]:
            out |= {(sid, t) for t in split_touches(what)[1] if page_in(t, have) not in have}
    return out


def boundary_rules(trunk: str, branch: str, staged: bool, paths: list[str],
                   meta: dict | None) -> list[str]:
    """References run one way: a page or a decision entry never names a spec, a handoff, the
    roadmap, or a scope of it. A roadmap is .jig/roadmap.md's, never a page, and the pages it
    names exist."""
    out = []
    keeps = bool(at_rev(trunk, ROADMAP)) or (branch == trunk and bool(in_index(ROADMAP, staged)))
    for f in paths:
        # The generated root view is jig's only where trunk keeps a roadmap, as R5 says.
        if f == ROADMAP or (f == ROADMAP_VIEW and keeps) or Path(f).name.lower() != "roadmap.md":
            continue
        if f.startswith("docs/") or (meta and is_entry(f, meta.get("entry_files", []))):
            out.append(f"{f} is a roadmap among the product's pages: phases, scopes and parked work "
                       f"are the project's, and live in {ROADMAP} only")
    moved = ROADMAP in paths or any(f.startswith("docs/") for f in changed_paths(trunk, staged, removed=True))
    if branch == trunk and keeps and moved:
        # A page an item names must still be there: renamed or gone, the item is re-pointed in
        # the same commit. Only what this commit breaks is refused.
        now = set(git("-c", "core.quotePath=false", "ls-files").splitlines())
        before = set(git("-c", "core.quotePath=false", "ls-tree", "-r", "--name-only", "HEAD").splitlines())
        broke = dead_touches(in_index(ROADMAP, staged), now) - dead_touches(at_rev("HEAD", ROADMAP), before)
        out += [f"{ROADMAP}: {iid} touches {page}, which this commit leaves with no page: re-point "
                "its (touches …) in this commit" for iid, page in sorted(broke)]
    files = [f for f in paths if product_file(f, meta)]
    if not files:
        return out
    # On trunk the commit's own roadmap counts too, so a scope added with its page is known.
    sids = scope_ids(at_rev(trunk, ROADMAP)) + (scope_ids(in_index(ROADMAP, staged)) if branch == trunk else [])
    names = scope_quoted(sids)
    for at, n, text in added_lines(trunk, staged, files):
        hit = PROJECT_PATHS.search(text) or next((m for r in names if (m := r.search(text))), None)
        if hit:
            what = "the decision log" if at == LOG else "a page"
            out.append(f"{at} line {n} names {hit.group(0)}, the project's: {what} describes the "
                       f"product, and a spec, a handoff or the roadmap cites it, never the other "
                       f"way: {clip(text.strip())}")
    return out


def roadmap_rules(board: "Board", branch: str, staged: bool, paths: list[str],
                  guarded: list[str]) -> list[str]:
    """Scopes a spec cites must be the roadmap's. On trunk the commit's own roadmap counts, so
    one commit can add a scope and the spec taking it, or drop one and re-point its specs."""
    trunk = board.trunk
    on_trunk = branch == trunk
    old = at_rev(trunk, ROADMAP)
    text = in_index(ROADMAP, staged) if on_trunk else old
    if not text and not old:
        return []
    known = roadmap_scopes(text)
    out, named = [], set()
    if on_trunk and ROADMAP in paths:
        problems: list[str] = []
        parse_roadmap(text, problems)
        parse_up_next(text, problems)
        out += [f"{ROADMAP} {x}" for x in problems]
    if on_trunk and ROADMAP in guarded:
        dropped = roadmap_scopes(old) - known
        for f in git("-c", "core.quotePath=false", "ls-files", "--", SPECS).splitlines():
            if is_spec(f) and (gone := [s for s in spec_scopes(in_index(f, staged)) if s in dropped]):
                named.add(f)
                out.append(f"{ROADMAP} drops {', '.join(gone)}, which {f} still takes: re-point "
                           "its Scope: line in this commit")
    for f in paths:
        if is_spec(f) and f not in named and (bad := [s for s in spec_scopes(in_index(f, staged))
                                                      if s not in known]):
            out.append(f"{f} takes {', '.join(bad)}, which {ROADMAP} on {trunk} doesn't have: "
                       "a scope is <phase>/<scope> from it")
    return out


# --------------------------------------------------------------------- update

# Where each of jig's own files lives now, and every path it has lived at. A row ending in
# "/" is a folder: every tracked file under an old folder moves, and board globs under it
# are rewritten. Any other row is one file, so after jig's two scripts leave `scripts/`,
# `scripts/**` on the board still means the repo's own scripts.
# Layouts, oldest first: claude-lane's .claude/claude-lane/, the tool jig grew from; eaec973's
# .jig/ with specs/, ledgers/ and scripts/ at root; ai-dev's .aidev/, the same with root
# ledgers; 62c8d9f's visible jig/ (every 0.2.x repo); .jig/ now.
CLAUDE_LANE = ".claude/claude-lane/"
LAYOUT = [
    (CONFIG, [LEGACY_BOARD, "jig/lanes.json", ".aidev/lanes.json", f"{CLAUDE_LANE}manifests/board.json"]),
    (f"{DIR}/jig.py", ["jig/jig.py", ".aidev/aidev.py", f"{CLAUDE_LANE}claude-lane.py"]),
    (f"{DIR}/RULES.md", ["jig/RULES.md", ".aidev/RULES.md", f"{CLAUDE_LANE}README.md"]),
    (f"{DIR}/handoffs/", ["jig/handoffs/", ".aidev/handoffs/", f"{CLAUDE_LANE}manifests/handoffs/"]),
    (f"{DIR}/specs/", ["jig/specs/", "specs/"]),
    (f"{DIR}/ledgers/", ["jig/ledgers/", "ledgers/"]),
    (WORKAROUNDS, ["WORKAROUNDS.md"]),
    (DEFERRED, ["DEFERRED.md"]),
    (f"{DIR}/scripts/", ["jig/scripts/"]),
    (f"{DIR}/scripts/check.sh", ["scripts/check.sh"]),
    (f"{DIR}/scripts/format.sh", ["scripts/format.sh"]),
    (f"{DIR}/staging/", ["jig/staging/"]),
    (META, ["jig/meta.json"]),
    (PARA, ["jig/para.json"]),
    ("docs/", ["jig/docs/"]),
]
# Written from the running copy, never renamed: their content is jig's, not the repo's.
TOOL_FILES = (f"{DIR}/jig.py", f"{DIR}/RULES.md", f"{DIR}/docs-page.md")
# jig's folder under its old names. Nothing moves by this alone — a file there that no row
# names stays and is flagged — but a board glob over the whole folder meant jig's folder.
OLD_DIRS = ("jig/", ".aidev/", CLAUDE_LANE)
# An old tool's files that nothing of jig's replaces: claude-lane's rendered board and log, and
# its hook installer. They are removed, and the dry run says so first.
GONE = (f"{CLAUDE_LANE}LANES.md", f"{CLAUDE_LANE}install-hooks.sh")
OLD_IGNORES = (".jig/worktrees/", ".aidev/worktrees/")
# reference_files: ignore. The old line covered docs/hardware/'s two homes; vendor documents now
# sit in a datasheets/ folder at any depth. Left as it was, a datasheet moved to the new homes
# would surface as untracked. PDFs only: a note beside them is the repo's own, and committed.
OLD_REFERENCE_IGNORE = "docs/hardware/*/**/*.[pP][dD][fF]"
REFERENCE_IGNORES = ("docs/**/datasheets/**/*.[pP][dD][fF]",)
# Untracked folders a jig/ repo kept: files waiting in staging, a pararepo's cache. No git mv
# moves them, and staged work left behind would be lost to every refusal that counts it.
OLD_UNTRACKED = (("jig/staging/", f"{DIR}/staging/"), ("jig/meta-cache/", f"{DIR}/meta-cache/"))
# A stale path in a comment misleads a reader; one in code can break the repo's checks.
COMMENT = ("#", "//", "/*", "*", "--", ";", "<!--")
# The skill template an old init copied into .claude/skills/_skill-template/. It never changed.
OLD_SKILL_TEMPLATE = "f8518f049c4a1552a5e3c55a94b59c1b904b8525b3c0aeb761cd8d9c0efe69a2"
# Coded changes that are neither a move nor a missing board key: (what it does,
# needed(root, after) -> bool, apply(root, here) -> None), where `after` is the tracked paths
# once the moves are made and `here` is the folder holding the running jig.py. Each is keyed
# on something it can see in the repo, never on a version.
SETUP = f"{DIR}/scripts/setup.sh"


def add_setup(root: Path, here: Path) -> None:
    dest = root / SETUP
    if dest.exists():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(here / "scripts" / "setup.sh", dest)
    dest.chmod(0o755)
    git("add", "--", SETUP, check=True)


def ensure_staging(root: Path) -> None:
    """.jig/staging/ always exists, so a chat has one folder to be granted; it holds only its
    .gitignore when empty."""
    ignore = root / STAGING / ".gitignore"
    if not ignore.exists():
        ignore.parent.mkdir(parents=True, exist_ok=True)
        ignore.write_text(f"# Staged files are never committed: see Staging in {DIR}/RULES.md.\n*\n!.gitignore\n")


def add_release(root: Path, here: Path) -> None:
    if release_script(root, meta=(root / META).exists()):
        git("add", "--", RELEASE, check=True)


def add_publish(root: Path, here: Path) -> None:
    if publish_script(root):
        git("add", "--", PUBLISH, check=True)


def meta_pattern_old(root: Path) -> bool:
    f = root / META
    try:
        return f.exists() and json.loads(f.read_text()).get("tag_pattern") == r"^v\d+\.\d+$"
    except ValueError:
        return False


def widen_meta_pattern(root: Path, here: Path) -> None:
    f = root / META
    data = json.loads(f.read_text())
    data["tag_pattern"] = META_DEFAULTS["tag_pattern"]
    f.write_text(json.dumps(data, indent=2) + "\n")
    git("add", "--", META, check=True)


REVIEW_LEDGER = "docs/REVIEW_LEDGER.md"
# A review ledger's row is taken when its last word on the finding is "taken" ("taken by …",
# "deferred then taken"); "not taken" is not. Only taken rows are in the code, so only they go.
TAKEN = re.compile(r"(?:.*\bthen\s+)?taken\b")
STATUS_COLUMNS = ("what happened", "status")
SEPARATOR = re.compile(r"^\|\s*:?-")      # |---|, | --- |, |:--|


def table_cells(line: str) -> list[str]:
    """A GFM table row's cells, as GitHub reads them: `\\|` is a literal pipe, and a `|` in
    backticks still splits."""
    s = line.strip()
    s = s[1:] if s.startswith("|") else s
    s = s[:-1] if s.endswith("|") and not s.endswith("\\|") else s
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", s)]


def split_ledger(text: str) -> tuple[list[str], list[list[str]], int, list[str]]:
    """A review ledger without its taken rows: the whole text kept, the tables that have a
    status column (header, separator, untaken rows), how many rows were dropped, and the rows
    kept because their cell count isn't the header's."""
    lines, out, tables, dropped, malformed = text.splitlines(), [], [], 0, []
    col = width = None
    for i, line in enumerate(lines):
        cells = [c.lower() for c in table_cells(line)]
        if line.startswith("|") and i + 1 < len(lines) and SEPARATOR.match(lines[i + 1]):
            # A findings table names the finding before what happened to it; a status in the
            # first column is a tally of the statuses, not a finding.
            col = next((n for n, c in enumerate(cells) if c in STATUS_COLUMNS and n > 0), None)
            width = len(cells)
            if col is not None:
                tables.append([line, lines[i + 1]])
        elif not line.startswith("|"):
            col = None
        elif col is not None and not SEPARATOR.match(line):
            # A row of another width has its status in some other cell, or none: a guess
            # could drop an untaken finding, so it stays and is named.
            if len(cells) != width:
                malformed.append(f"{REVIEW_LEDGER}: row `{table_cells(line)[0]}` has {len(cells)} "
                                 f"cells, its header {width}: kept, check it")
            elif TAKEN.match(cells[col]):
                dropped += 1
                continue
            tables[-1].append(line)
        out.append(line)
    return out, tables, dropped, malformed


def ledger_step(root: Path) -> str:
    _, tables, dropped, malformed = split_ledger((root / REVIEW_LEDGER).read_text(errors="replace"))
    kept = sum(len(t) - 2 for t in tables) - len(malformed)
    return (f"{REVIEW_LEDGER} → {DEFERRED}: its {kept} untaken row{'s' if kept != 1 else ''} "
            f"(deferred, rejected, open) carry over, its {dropped} taken row"
            f"{'s' if dropped != 1 else ''} are dropped, {len(malformed)} malformed kept, and the "
            f"file is removed")


def ledger_warnings(root: Path) -> list[str]:
    return split_ledger((root / REVIEW_LEDGER).read_text(errors="replace"))[3]


def fold_ledger(root: Path, here: Path) -> None:
    text, tables, _, _ = split_ledger((root / REVIEW_LEDGER).read_text(errors="replace"))
    dest = root / DEFERRED
    if dest.exists():
        body = dest.read_text().rstrip("\n") + f"\n\n## From {REVIEW_LEDGER}\n"
        for table in tables:
            body += "\n" + "\n".join(table) + "\n"
    else:
        body = "\n".join(text) + "\n"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(body)
    git("rm", "-q", "--", REVIEW_LEDGER, check=True)
    git("add", "--", DEFERRED, check=True)


def board_slug(text: str) -> str:
    """The board a hardware page names on its `- MCU / board:` line, as a file name; empty
    while that line is still the template's TODO."""
    m = re.search(r"^- MCU / board:\s*(.+)$", text, re.M)
    board = m.group(1).strip() if m else ""
    if not board or board.startswith("TODO"):
        return ""
    return re.sub(r"[^a-z0-9]+", "-", board.split("(")[0].lower()).strip("-")


def board_home(root: Path, slug: str) -> str:
    """Where an old single board page goes: flat, docs/<board>.md, since it moves alone;
    into the board's folder where it has one already, with files or its page in it."""
    folder = f"docs/{slug}/{slug}.md"
    return folder if (root / f"docs/{slug}").is_dir() else f"docs/{slug}.md"


def hardware_rows(root: Path, files: list[str]) -> list[tuple[str, list[str]]]:
    """A root HARDWARE.md, an older init's single page, moves to its board's page, a system
    like any other; rewrite_board registers it in boards. Only one that names a board: a page
    of TODOs is listed for review instead."""
    if "HARDWARE.md" not in files:
        return []
    slug = board_slug((root / "HARDWARE.md").read_text(errors="replace"))
    return [(board_home(root, slug), ["HARDWARE.md"])] if slug else []


def handoff_rows(root: Path, files: list[str]) -> tuple[list[tuple[str, list[str]]], set[str]]:
    """A note a jig wrote at a `/` name's path, `.jig/handoffs/<prefix>/<name>-<date>.md`,
    moves flat under its file-safe name; with the subfolders it empties, for the cleanup.
    Only a note whose header names that same path: update itself moves older tools' handoff
    folders here whole, subfolders included, and those stay as they are."""
    top = f"{DIR}/handoffs/"
    taken, rows, folders = set(files), [], set()
    for f in sorted(files):
        rel = f[len(top):] if f.startswith(top) else ""
        m = re.fullmatch(r"(.+/.+)-\d{4}-\d{2}-\d{2}(?:-\d+)?\.md", rel)
        if not m:
            continue
        try:
            first = (root / f).read_text(errors="replace").split("\n", 1)[0]
        except OSError:
            continue
        if first != f"# Handoff: {m.group(1)}":
            continue
        new = top + file_safe(rel)
        # A clash takes the day's next free -N, as `jig handoff` would; the note's Commit: line,
        # not its file name, says what was gated.
        if new in taken:
            base, n = re.fullmatch(r"(.*-\d{4}-\d{2}-\d{2})(?:-(\d+))?\.md", new).groups()
            i = int(n or 1) + 1
            while f"{base}-{i}.md" in taken:
                i += 1
            new = f"{base}-{i}.md"
        taken.add(new)
        rows.append((new, [f]))
        folders.add(top + rel.split("/")[0] + "/")
    return rows, folders


STEPS: list = [
    (f"add {STAGING}/ (its .gitignore), where chats drop files for this repo",
     lambda root, after: f"{STAGING}/.gitignore" not in after
     and not (root / STAGING / ".gitignore").exists(),
     lambda root, here: (ensure_staging(root), git("add", "-f", "--", f"{STAGING}/.gitignore"))),
    (f"add {SETUP} from the template, TODOs to fill: it runs in every new worktree and after "
     "every merge", lambda root, after: SETUP not in after and not (root / SETUP).exists()
     and (Path(__file__).resolve().parent / "scripts" / "setup.sh").exists(), add_setup),
    (f"add {RELEASE} from the template: the repo's release protocol, which /jig:release fills in "
     "on the first `jig release`", lambda root, after: RELEASE not in after
     and not (root / RELEASE).exists()
     and (Path(__file__).resolve().parent / "scripts" / "release.sh").exists(), add_release),
    (f"add {PUBLISH} from the template: what a release publishes after the tag, which "
     "/jig:release fills in", lambda root, after: PUBLISH not in after
     and not (root / PUBLISH).exists()
     and (Path(__file__).resolve().parent / "scripts" / "publish.sh").exists(), add_publish),
    (f"widen {META}'s tag_pattern to accept vX.Y.Z: every repo now releases with three parts",
     lambda root, after: meta_pattern_old(root), widen_meta_pattern),
    (ledger_step, lambda root, after: REVIEW_LEDGER in after, fold_ledger),
    (f"add {LOG}, the decision log: no CHANGELOG.md or register here to merge into it",
     lambda root, after: LOG not in after and not (root / LOG).exists() and not log_sources(root),
     lambda root, here: ((root / LOG).write_text(LOG_SEED), git("add", "--", LOG))),
]



def root_is_jigs(board_at: str, version: int) -> bool:
    """Whether a root specs/, ledgers/ or scripts/check.sh is jig's. Only eaec973's layout
    and ai-dev's put them there, and once jig's files left root, those paths are the repo's.
    eaec973's board is at .jig/ like today's, and with the spec template made on first use a
    new repo has no .jig/specs/ either; only the board's version tells them apart. The one
    place update reads it for anything but the ahead refusal. eaec973 took its root folders
    from claude-lane, so they are jig's beside its board too."""
    return board_at.startswith((".aidev/", CLAUDE_LANE)) or (board_at == LEGACY_BOARD and version < 3)


def plan_moves(files: list[str], board_at: str, version: int, extra: list | None = None) -> dict:
    """Which tracked files LAYOUT moves, which tool files it retires, and the (old, new)
    rows that apply. A file moves only when its new path is free: with both there, update
    can't tell which is current, so it leaves both and says so. A row applies when at least
    one file moved. `extra` rows apply on any layout: they come from what a file says, not
    where jig's folder is."""
    # A path under an old folder is jig's only while the board is in that folder: beside a
    # board at .jig/, a jig/ folder is the repo's own (a Python package, say).
    at_root = root_is_jigs(board_at, version)
    taken, moves, retire, rows, warn = set(files), {}, [], [], []
    for new, olds, always in [(n, o, False) for n, o in LAYOUT] + [(n, o, True) for n, o in extra or []]:
        for old in olds:
            # The one-file board is the one old path inside today's folder.
            home = next((d for d in (*OLD_DIRS, f"{DIR}/") if old.startswith(d)), None)
            if not always and not (board_at.startswith(home) if home else at_root):
                continue
            under = [f for f in files if f not in moves and f not in retire
                     and (f.startswith(old) if old.endswith("/") else f == old)]
            if not under:
                continue
            if new in TOOL_FILES:
                retire += under
                rows.append((old, new))
                continue
            if not old.endswith("/"):
                if new in taken:
                    warn.append(f"{old} and {new} both exist: both left as they are, not merged")
                    continue
                moves[old] = new
                taken.add(new)
                rows.append((old, new))
                continue
            # Units that move or stay together: a file alone, or a whole subfolder.
            units = [[f] for f in under]
            # specs/ and ledgers/ at root may hold the repo's own files too (JS spec tests).
            # At the top level jig only ever put Markdown there, one spec per file, so each
            # file is judged alone. A subfolder is one unit: with Markdown in it, it is task
            # material and moves whole; without, it is the repo's and stays.
            in_jigs = old.startswith(OLD_DIRS)
            if not in_jigs:
                top = [f for f in under if "/" not in f[len(old):]]
                subs: dict[str, list[str]] = {}
                for f in under:
                    if f not in top:
                        subs.setdefault(old + f[len(old):].split("/")[0] + "/", []).append(f)
                units = [[f] for f in top if f.endswith(".md")]
                for sub, held in subs.items():
                    if any(f.endswith(".md") for f in held):
                        units.append(held)
                    else:
                        top += held
                for f in [f for f in top if not f.endswith(".md")]:
                    warn.append(f"{f} is in {old} but isn't Markdown, so it isn't jig's: left there")
            moved = False
            for unit in units:
                dest = {f: new + f[len(old):] for f in unit}
                clash = [f for f in unit if dest[f] in taken]
                sub = not in_jigs and "/" in unit[0][len(old):]
                folder = old + unit[0][len(old):].split("/")[0] + "/" if sub else ""
                if clash and sub:
                    warn.append(f"{folder} and {new}{folder[len(old):]} both hold "
                                f"{clash[0][len(folder):]}: the whole folder is left as it is, never split")
                    continue
                if clash:
                    warn.append(f"{unit[0]} and {dest[unit[0]]} both exist: both left as they are, not merged")
                    continue
                if sub:
                    warn.append(f"{folder} holds Markdown, so it moves whole to "
                                f"{new}{folder[len(old):]}, its other files included: check it is jig's")
                moves.update(dest)
                taken |= set(dest.values())
                moved = True
            if moved:
                rows.append((old, new))
    home = next((d for d in OLD_DIRS if board_at.startswith(d)), None)
    gone = [f for f in files if home and f in GONE]
    after = sorted((set(files) - set(moves) - set(retire) - set(gone)) | set(moves.values())
                   | set(TOOL_FILES))
    for f in files:
        if home and f.startswith(home) and f not in moves and f not in retire and f not in gone:
            warn.append(f"{f} is at an old path no row names: left there, and its folder stays")
    return {"moves": moves, "retire": retire, "gone": gone, "rows": rows, "warn": warn,
            "after": after}


def from_claude_lane(data: dict) -> tuple[dict, list[str]]:
    """claude-lane's board.json in a jig board's keys, and what has no place in one. Its
    `main` is the trunk and its `baseline` the reserve counters; merged jobs are history,
    which git keeps."""
    out: dict = {}
    gone: list[str] = []
    for key, value in data.items():
        if key == "main":
            out["trunk"] = value
        elif key == "version":
            continue                      # claude-lane's own schema, not a jig layout
        elif key == "baseline" and isinstance(value, dict):
            reserve = out.setdefault("reserve", {})
            for counter, n in value.items():
                if isinstance(n, int):
                    reserve.setdefault(counter, {"next": n})
                else:
                    gone.append(f"board: baseline.{counter} (not a counter)")
        elif key == "reserve" and isinstance(value, dict):
            out.setdefault("reserve", {}).update(value)
        elif key == "lanes" and isinstance(value, dict):
            out["lanes"] = {}
            for name, job in value.items():
                if isinstance(job, dict) and job.get("state") == "merged":
                    gone.append(f"board: lanes.{name} (merged)")
                else:
                    out["lanes"][name] = job
        # Not BOARD_OPTIONAL: claude-lane boards predate those keys, so one by that name meant
        # something else there and is dropped with the rest.
        elif key in BOARD_DEFAULTS:
            out[key] = value
        else:
            gone.append(f"board: `{key}` (claude-lane's own; nothing in jig reads it)")
    return out, gone


def rewrite_board(data: dict, files: list[str], plan: dict) -> tuple[dict, list[str], list[str], list[str]]:
    """The config with every path rewritten to where its files went. Returns the new config,
    one line per edit, warnings, and what it drops: the jobs, every one merged (update
    refuses an open one), and the log, both history that git keeps."""
    moves, rows, after = plan["moves"], plan["rows"], plan["after"]
    folders = [(o, n) for o, n in rows if o.endswith("/")]
    folders += [(d, f"{DIR}/") for d in OLD_DIRS if any(o.startswith(d) for o, _ in rows)]
    folders.sort(key=lambda r: -len(r[0]))
    exact = {o: n for o, n in rows if not o.endswith("/")}
    edits: list[str] = []
    warn: list[str] = []

    def one(g: str) -> str:
        for o, n in folders:
            if g.startswith(o):
                return n + g[len(o):]
        return exact.get(g, g)

    def many(label: str, globs):
        if not isinstance(globs, list):
            return globs
        out = []
        for g in globs:
            # Only a glob whose files moved follows them: one over files that all stayed (a
            # repo's specs/*.spec.js) would point at nothing in jig's folder.
            ng = one(g) if any(matches(f, [g]) for f in [*moves, *plan["retire"]]) else g
            # Files that stayed behind (a collision, a non-Markdown file) are still the glob's.
            kept = ng != g and any(matches(f, [g]) for f in after)
            if ng != g:
                edits.append(f"{label}: `{g}` → `{ng}`" + (f", `{g}` kept: files stay there" if kept else ""))
            for x in ([g] if kept else []) + [ng]:
                if x not in out:
                    out.append(x)
        # A folder that moved out from under a broad glob (jig/** over jig/docs/) is still
        # covered after the move. A file row adds nothing: jig's file left that folder.
        for o, n in folders:
            held = [f for f in moves if f.startswith(o) and matches(f, globs)]
            if held and not all(matches(moves[f], out) for f in held) and f"{n}**" not in out:
                out.append(f"{n}**")
                edits.append(f"{label}: + `{n}**` ({o} moved to {n})")
        for g, ng in zip(globs, [one(g) for g in globs]):
            if any(matches(f, [g]) for f in files) and not any(matches(f, [ng]) for f in after):
                warn.append(f"board {label}: `{ng}` matched files before the update and matches none after")
        return out

    new = json.loads(json.dumps(data))
    if "payload" in new:              # the key's old name: the same globs, said for what they are
        new["not_docs"] = new.pop("payload")
        edits.append("payload: renamed not_docs")
    for key in ("common", "append_files", "not_docs"):
        if key in new:
            new[key] = many(key, new[key])
    for name, spec in (new.get("reserve") or {}).items():
        if isinstance(spec, dict) and "files" in spec:
            spec["files"] = many(f"reserve.{name}.files", spec["files"])
    if isinstance(new.get("docmap"), dict):
        docmap = {}
        for page, globs in new["docmap"].items():
            if one(page) != page:
                edits.append(f"docmap: `{page}` → `{one(page)}`")
            docmap[one(page)] = many(f"docmap[{one(page)}]", globs)
        new["docmap"] = docmap
    # A board page is registered, not inferred: the page update moves in becomes one.
    for o, n in rows:
        if o != "HARDWARE.md":
            continue
        if "boards" in new and not isinstance(new["boards"], list):
            warn.append(f"board key `boards` is not a list: kept as it is; {n} is a board page, "
                        "so make boards a list of page paths and add it")
        elif n not in new.setdefault("boards", []):
            new["boards"].append(n)
            edits.append(f"boards: + `{n}` (from HARDWARE.md)")
    gone = [f"board: lanes.{name} (merged)" for name in new.pop("lanes", None) or {}]
    log = new.pop("log", None)
    if log is not None:
        gone.append(f"board: log ({len(log)} line{'s' if len(log) != 1 else ''}; git log of "
                    f"{JOBS} records opens and merges now)")
    for name, spec in (new.get("reserve") or {}).items():
        if isinstance(spec, dict) and "next" in spec:
            del spec["next"]
            edits.append(f"reserve.{name}: `next` dropped (its pattern says what is taken)")
    for key, default in BOARD_DEFAULTS.items():
        if key not in new:
            new[key] = main_root().name if key == "name" else json.loads(json.dumps(default))
            if key != "version":
                edits.append(f"{key}: added, {json.dumps(default)}")
    if new.get("version") != STAMP:
        edits.append(f"version: {data.get('version', 'none')} → {STAMP}")
        new["version"] = STAMP
    for key in data:
        if key not in BOARD_DEFAULTS and key not in BOARD_OPTIONAL \
                and key not in ("lanes", "log", "payload"):
            warn.append(f"board key `{key}` is not one jig knows: kept, and the checker ignores it")
    return new, edits, warn, gone


def stale_references(root: Path, plan: dict, board_at: str) -> dict[str, list[tuple[int, str]]]:
    """Lines in the repo's own files that still name a path jig moved, keyed by where each
    file will be after the moves. Matched at a path boundary: example.com/specs/ is not one.
    A glob (or a `<placeholder>` path) is stale when a file that moved matches it. A file
    or a bare folder is stale when it no longer exists after the moves: a folder some files
    stayed in is still there."""
    olds = sorted({o for o, _ in plan["rows"]}
                  | {d for d in OLD_DIRS if any(o.startswith(d) for o, _ in plan["rows"])},
                  key=len, reverse=True)
    if not olds:
        return {}
    # `]` and `#` end a path, so a Markdown link's text and anchor are not part of it. A
    # path may start `/` (a .gitignore anchor) or `../` after a folder, as in
    # `$(dirname "$0")/../specs/x.md`; after `example.com/` it is a URL, not a path.
    pat = re.compile(r"(?:(?<![\w/.-])(?:\./|/)?|(?<![\w.-])(?:\.\./)+)((?:"
                     + "|".join(re.escape(o) for o in olds) + r")[^\s'\"`()|,;:\]#]*)")
    there = set(plan["after"])

    def stale(ref: str) -> bool:
        ref = re.sub(r"<[^<>/]*>", "*", ref).split(">")[0].split("<")[0].rstrip(".")
        if re.search(r"[*?]", ref):
            # A folder that keeps a .gitkeep is still there, but `specs/*.md` names its moved files.
            return any(matches(o, [ref]) for o in plan["moves"])
        if ref in there:
            return False
        inside = ref if ref.endswith("/") else ref + "/"
        return not any(f.startswith(inside) for f in there)
    back = {n: o for o, n in plan["moves"].items()}
    skip = {CONFIG, JOBS, board_at, *TOOL_FILES}
    # update rewrites these .gitignore lines itself.
    own_ignores = {*OLD_IGNORES, "jig/meta-cache/"}
    out: dict[str, list[tuple[int, str]]] = {}
    for f in plan["after"]:
        # Handoff notes anywhere — jig's or another tool's — record what was true then.
        if f in skip or "/handoffs/" in f"/{f}":
            continue
        path = root / back.get(f, f)
        try:
            text = path.read_text()
        except (OSError, UnicodeDecodeError):
            continue
        hits = [(i, line.strip()) for i, line in enumerate(text.splitlines(), 1)
                if any(stale(m) for m in pat.findall(line))
                and not (f == ".gitignore" and line.strip() in own_ignores)]
        if hits:
            out[f] = hits
    return out


def left_behind(root: Path, files: list[str], plan: dict, handled: list[str]) -> list[str]:
    """One warning per folder whose tracked files all move but which holds untracked or
    ignored files: `git mv` takes only what git tracks, so those stay in a folder that
    otherwise empties. `handled` are folders update deals with apart from this."""
    after, tracked_set = plan["after"], set(files)
    emptied = set()
    for o in plan["moves"]:
        parts = o.split("/")[:-1]
        for i in range(1, len(parts) + 1):
            d = "/".join(parts[:i]) + "/"
            if not any(f.startswith(d) for f in after):
                emptied.add(d)
                break
    out = []
    for d in sorted(emptied):
        stay = []
        for here, dirs, names in os.walk(root / d):
            rel = Path(here).relative_to(root).as_posix() + "/"
            for sub in sorted(dirs):
                path = rel + sub + "/"
                if any(path.startswith(h) for h in handled):
                    dirs.remove(sub)
                elif not any(f.startswith(path) for f in tracked_set):
                    # Wholly untracked: named once, not file by file. An empty one moves nothing.
                    if any(names for _, _, names in os.walk(root / path)):
                        stay.append(path)
                    dirs.remove(sub)
            stay += sorted(rel + n for n in names if rel + n not in tracked_set)
        if stay:
            out.append(f"{d} moves, but files git doesn't track stay in it: {', '.join(sorted(stay))}. "
                       "Move or delete each, or the folder stays with only them")
    return out


def superseded_kept(root: Path) -> list[tuple[str, str]]:
    """Each entry the log still holds that another supersedes: a log from when released sections
    were frozen kept it, and now the superseding commit removes it."""
    text = (root / LOG).read_text(errors="replace") if (root / LOG).is_file() else ""
    prefix = log_prefix_of(text)
    entries = log_entries(text, prefix)
    have = {e["id"] for e in entries}
    return [(LOG, f"{s} is superseded by {e['id']}: remove it; the entry superseding it names it")
            for e in entries for s in replaced(e, prefix) if s in have]


def files_to_review(root: Path, plan: dict, template: Path | None = None,
                    arriving: set[str] = frozenset()) -> list[tuple[str, str]]:
    """The repo's own files an old convention left behind, each with the edit proposed for
    it. update shows these and never applies them: they are the repo's."""
    back = {n: o for o, n in plan["moves"].items()}
    out = []
    hw = root / back.get("docs/HARDWARE.md", "docs/HARDWARE.md")
    if hw.exists():
        slug = board_slug(hw.read_text(errors="replace"))
        if not slug:
            out.append(("docs/HARDWARE.md", "still the template's TODOs: remove it"))
        else:
            out.append(("docs/HARDWARE.md", f"holds a board: rename it to "
                        f"{board_home(root, slug)}, list it under boards in {CONFIG}, one page per "
                        f"board as {DIR}/RULES.md "
                        "(Documentation) says, then check it against the code"))
    if "HARDWARE.md" in plan["after"] and (root / "HARDWARE.md").exists():
        slug = board_slug((root / "HARDWARE.md").read_text(errors="replace"))
        out.append(("HARDWARE.md", "still the template's TODOs: remove it" if not slug else
                    f"names a board, but {board_home(root, slug)} exists: fold one into the other"))
    tpl = root / ".claude/skills/_skill-template/SKILL.md"
    if tpl.exists():
        if hashlib.sha256(tpl.read_bytes()).hexdigest() == OLD_SKILL_TEMPLATE:
            out.append((".claude/skills/_skill-template/", "the old blank skill template, "
                        "unchanged: remove it — new skills start from the template jig ships"))
        else:
            out.append((".claude/skills/_skill-template/", "differs from the old template, "
                        "so it is the repo's now: left as it is"))
    if "GLOSSARY.md" in plan["after"] and (root / back.get("GLOSSARY.md", "GLOSSARY.md")).exists():
        meta = " and replace it in entry_files" if (root / META).exists() else ""
        out.append(("GLOSSARY.md", f"the glossary's home is README.md § Glossary now ({DIR}/RULES.md, "
                    f"Documentation): move each term there as a `### <term>` heading, delete the file"
                    f"{meta}, and repoint what names it"))
    for f, what in log_sources(root):
        out.append((f, f"{what}: merged into {LOG} on a yes — `jig update --merge-log` shows the "
                       f"log it would write, `jig update --apply --merge-log` writes it and removes "
                       f"the old files"))
    return out + agents_lines(root, template, arriving)


# AGENTS.md blocks jig cut from its template, by heading. A cut adds its heading here in the
# same commit: the repo reworded the block's lines, so only the heading still identifies it.
RETIRED_BLOCKS = ("## Lanes (parallel sessions)", "## Jobs (parallel sessions)")


def agents_lines(root: Path, template: Path | None, arriving: set[str]) -> list[tuple[str, str]]:
    """The lines of AGENTS.md that jig's template still needs there, each proposed by itself.
    The rest of the file is the repo's to word: jig keeps no copy of its own to diff it with.
    `arriving` is what this run puts in place, so the run that adds a script proposes its line."""
    mine = root / "AGENTS.md"
    # In the repo that ships the template, it is the product, not a default for that repo.
    if (not (template and template.exists() and mine.exists())
            or root.resolve() in template.resolve().parents):
        return []
    tpl = template.read_text().splitlines()
    text = mine.read_text(errors="replace")
    lines = text.splitlines()
    rulebook = next((l for l in tpl if l.startswith("- Rulebook ")), "")
    blocks = []
    for i, line in enumerate(lines):
        if line.strip() in RETIRED_BLOCKS:
            end = next((j for j in range(i + 1, len(lines)) if lines[j].startswith("## ")), len(lines))
            while end > i + 1 and not lines[end - 1].strip():
                end -= 1
            blocks.append((i, end))
    outside = "\n".join(l for k, l in enumerate(lines) if not any(i <= k < e for i, e in blocks))
    # A citation of one section, `.jig/RULES.md` (Documentation) or § Roles, doesn't load the
    # rulebook; a plain mention or an aside, `.jig/RULES.md` (the rulebook), does.
    has_rulebook = re.search(r"\.jig/RULES\.md(?!`?[ \t]*(?:\([A-Z]|§))", outside)
    out = []
    for i, end in blocks:
        fix = ("delete it, heading to the next heading: the Rulebook line is already outside it"
               if has_rulebook else f"replace it, heading to the next heading, with `{rulebook}`")
        out.append(("AGENTS.md", f"lines {i + 1}–{end}, `{lines[i].strip()}`, are a block jig "
                    f"retired: {fix}"))
    if not blocks and rulebook and not has_rulebook:
        out.append(("AGENTS.md", f"names no `{DIR}/RULES.md`: add under ## Workflow `{rulebook}`"))
    in_commands = False
    for line in tpl:
        if line.startswith("## "):
            in_commands = line.strip() == "## Commands"
            continue
        for script in re.findall(r"\.jig/scripts/[\w.-]+", line) if in_commands else []:
            if (script in arriving or (root / script).exists()) and script not in text:
                out.append(("AGENTS.md", f"names no `{script}`: add under ## Commands `{line.strip()}`"))
    return out


def para_pointers(root: Path) -> tuple[dict, list]:
    """The pararepo's para.json and its cached metarepo pointers; empty outside a pararepo."""
    try:
        para = json.loads((root / PARA).read_text()) if (root / PARA).exists() else {}
    except ValueError:
        para = {}   # check names a broken para.json; a proposal can go without its rows
    return para, pointers(root) if para else []


def move_lines(root: Path, board: dict, board_at: str, after: list[str], para: dict, cached: list,
               folder: str, group: list[dict], rec: dict) -> list[str]:
    """Every line moving GROUP out of FOLDER touches, for one commit, judged on AFTER."""
    moves = {h["path"]: h["to"] for h in group}
    folded = {h["path"] for h in group if h["fold"]}
    left = [moves.get(f, f) for f in after if f not in folded]
    emptied = [] if any(f.startswith(folder) for f in left) else [folder]
    lines = [f"{'fold' if h['fold'] else 'git mv'} {h['path']} {'into ' if h['fold'] else ''}{h['to']}"
             + state_tag(h, rec) for h in group]
    lines += [f"{CONFIG} docmap: {o}" for o in moves if o in (board.get("docmap") or {})]
    lines += [f"{PARA} contract_paths: {g}" for g in para.get("contract_paths", [])
              if any(matches(o, [g]) and not matches(n, [g]) for o, n in moves.items())]
    stale = stale_references(root, {"rows": [*moves.items(), *[(d, "") for d in emptied]],
                                    "moves": moves, "after": left}, board_at)
    lines += [f"{f}:{i}: {line}" for f, hits in stale.items() if f not in (PARA, BUFFER)
              for i, line in hits]
    ptrs = [(c, p, s) for c, p, s, _ in cached if p in moves]
    lines += [f"{c} points at {p}{f' § {s}' if s else ''}" for c, p, s in ptrs]
    if ptrs:
        lines.append(f"the move's commit carries a {BUFFER} row for each pointer, "
                     "and the next `jig release` proposes them")
    return lines


def home_findings(root: Path, plan: dict, board: dict, board_at: str,
                  reviewed: list[str]) -> list[tuple[str, str]]:
    """Survey's home findings for the repo as it will be after the moves, each with the edit
    proposed: a check of the shape finds any old convention, with no row to remember. Pages
    are proposed by folder, with everything a move would touch named. REVIEWED are files
    another row already proposes for."""
    back = {n: o for o, n in plan["moves"].items()}
    after = plan["after"]

    def read(f: str) -> str:
        p = root / back.get(f, f)
        return p.read_text(errors="replace") if p.is_file() else ""
    docmap = named_pages(board)
    homeless = doc_homes(root, after, board.get("not_docs") or [], read,
                         board.get("deep_subsystems"), docmap)
    homes = [h for h in homeless if h["path"] not in reviewed]
    rec = findings_record(board)
    out = [(h["path"], home_fix(h) + state_tag(h, rec)) for h in homes if h["kind"] in ("rules", "copy", "reserved")]
    # A metarepo page with no genre in its path has no move to propose: the remap places it.
    pages = [h for h in homes if h["kind"] == "page" and h["to"]]
    out += [(h["path"], f"a metarepo page in no genre folder ({DIR}/RULES.md, Metarepo and "
             "pararepos): /jig:redocument places it under docs/<genre>/")
            for h in homes if h["kind"] == "genre" or (h["kind"] == "page" and not h["to"])]
    found = sorted({f.split("/")[1] for f in after if f.startswith("docs/") and f.count("/") > 1})
    if GENRES == () and found:
        try:
            entry = {**META_DEFAULTS, **json.loads((root / META).read_text() or "{}")}["entry_files"]
        except ValueError:
            entry = []
        out.append((META, f"declare its genres, the folders under docs/ it has: "
                    f'"genres": {json.dumps(found)}'
                    + ("" if matches("docs/a/b.md", entry) else
                       f', and add "{META_GENRE_ENTRY}" to entry_files, so pararepos cite its pages')))
    deep = board.get("deep_subsystems") if isinstance(board.get("deep_subsystems"), dict) else {}
    para, cached = para_pointers(root)

    def commit_lines(folder: str, group: list[dict]) -> list[str]:
        return move_lines(root, board, board_at, after, para, cached, folder, group, rec)

    # A root file has no folder to empty: its group is the root's pages, under their own names.
    for folder in dict.fromkeys((os.path.dirname(h["path"]) + "/").lstrip("/") for h in pages):
        group = [h for h in pages if h["path"].startswith(folder) and "/" not in h["path"][len(folder):]]
        lines = commit_lines(folder, group)
        out.append((folder or ", ".join(h["path"] for h in group), f"{len(group)} page{'s' if len(group) > 1 else ''} outside the docs "
                    f"tree ({DIR}/RULES.md, Documentation). Ask whether each is a subsystem to "
                    "nest; then, in one commit:" + "".join(f"\n      {l}" for l in lines)))
    old = [r for r in old_board_rows(after, read) if r["to"]]
    if old:
        lines = commit_lines(OLD_BOARDS, old)
        lines += [f"{CONFIG} boards: + {r['to']}" for r in old if r["board"]]
        if any(f"/{DATASHEETS}/" in r["to"] for r in old):
            lines.append(f"each link into a moved part or a {DATASHEETS}/ folder: repoint it; a PDF "
                         f"the repo wrote (a schematic) goes back beside the page, not in {DATASHEETS}/")
        lost = [r for r in old_board_rows(after, read) if not r["to"]]
        out.append((OLD_BOARDS, f"board files in the old layout ({DIR}/RULES.md, Documentation): "
                    "each board is a system now, and /jig:redocument carries the moves. In one commit:"
                    + "".join(f"\n      {l}" for l in lines)
                    + "".join(f"\n      {r['path']}: {r['why']}" for r in lost)))
    for h in (h for h in homes if h["kind"] == "deep"):
        lines = commit_lines(os.path.dirname(h["path"]) + "/", [h])
        out.append((h["path"], f"below a subsystem ({DIR}/RULES.md, Documentation): {deep_fix(h, deep)}. "
                    "To fold it, in one commit:" + "".join(f"\n      {l}" for l in lines)))
    for e in page_shapes(root, after, board.get("not_docs") or [], docmap,
                         {h["path"] for h in homeless}, read):
        if e["path"] in reviewed:
            continue
        # docmap and boards name a page in either form, so the move needs no config edit.
        lines = [l for l in commit_lines(os.path.dirname(e["path"]) + "/", [e])
                 if not l.startswith(f"{CONFIG} docmap:")]
        out.append((e["path"], f"{shape_fix(e)} ({DIR}/RULES.md, Documentation). "
                    "On the owner's yes, in one commit:" + "".join(f"\n      {l}" for l in lines)))
    # A page at home but off the contract is fixed where it sits; redocument only converts.
    flats = {f for f in after if flat_page(f, set(after), docmap, read)}
    homeless_at = {h["path"] for h in homeless}
    deep_at = {h["path"] for h in homeless if h["kind"] == "deep"}
    for f in after:
        # A deep page is still a page: survey reads it against the contract, so update asks too.
        if ((folder_page(f) or f in flats) and (f not in homeless_at or f in deep_at) and f not in reviewed
                and not matches(f, board.get("not_docs") or [])):
            probs = [p for p in page_problems(read(f)) if not p.startswith("old contract")]
            if probs:
                out.append((f, f"off the page contract ({DIR}/RULES.md, Documentation): "
                            + "; ".join(probs) + ". On the owner's yes, edit it where it sits"
                            + state_tag({"kind": "contract", "path": f, "problems": probs}, rec)))
    strays = len([h for h in homes if h["kind"] == "stray"])
    if strays:
        out.append((f"{strays} document{'s have' if strays > 1 else ' has'} no home", "`/jig:survey`"))
    return out


def worktree_refusals(root: Path, old_folders: tuple) -> tuple[list[str], list[Path]]:
    """One line per worktree git records and per folder in an old worktrees folder, each with
    the command for its case, and the gate scratch checkouts update may remove itself. A repo
    folder renamed under its worktrees leaves records whose paths are gone and checkouts that
    moved with it: `remove` on such a record drops it and strands the checkout, so it gets
    `repair` first. update runs none of the refusals' commands: removal needs someone to look
    at uncommitted work. A gate checkout is jig's scratch, so only a tracked edit there needs
    that look."""
    def shown(p: Path) -> str:
        try:
            return p.relative_to(root).as_posix()
        except ValueError:
            return str(p)

    records: dict[str, Path] = {}
    store = git_common() / "worktrees"
    for rec in sorted(store.iterdir()) if store.is_dir() else []:
        try:
            records[rec.name] = Path((rec / "gitdir").read_text().strip()).parent
        except OSError:
            records[rec.name] = rec / "missing"
    # A checkout's .git file names its record: `gitdir: <common>/worktrees/<id>`. A branch
    # with `/` puts its checkout a level deeper (`feat/x`), so the search goes down until it
    # finds a checkout; reporting `feat` itself would lead someone to delete the checkout.
    folders: dict[Path, str | None] = {}

    def scan(d: Path) -> bool:
        if (d / ".git").exists():
            try:
                line = (d / ".git").read_text().strip()
                folders[d] = Path(line[len("gitdir:"):].strip()).name if line.startswith("gitdir:") else None
            except OSError:
                folders[d] = None
            return True
        try:
            subs = [s for s in sorted(d.iterdir()) if s.is_dir() and not s.is_symlink()]
        except OSError:
            return False                  # unreadable: reported as no checkout, to look at
        found = {s: scan(s) for s in subs}
        if not any(found.values()):
            return False
        # Beside a checkout, a folder with none in it is reported by its own name.
        folders.update({s: None for s, f in found.items() if not f})
        return True

    for base in [root / f for f in old_folders] + [git_common() / "jig" / "worktrees"]:
        for d in sorted(base.iterdir()) if base.is_dir() else []:
            if d.is_dir() and not scan(d):
                folders[d] = None
    out = []
    scratch: list[Path] = []
    claimed = set()
    gates = (git_common() / "jig" / "worktrees").resolve()
    for rid, path in records.items():
        if path.exists():
            claimed.add(path.resolve())
            # The gate's checkout is detached; a job named gate-x has a branch checked out.
            try:
                detached = not (store / rid / "HEAD").read_text().startswith("ref:")
            except OSError:
                detached = False
            if path.resolve().parent == gates and path.name.startswith("gate-") and detached:
                problem = gate_scratch_problem(path, shown(path))
                if problem:
                    out.append(f"gate scratch {problem}")
                else:
                    scratch.append(path)
                continue
            out.append(f"worktree {shown(path)}: `git worktree remove {shown(path)}`")
            continue
        moved = [d for d, i in folders.items() if i == rid]
        if moved:
            claimed.add(moved[0].resolve())
            out.append(f"worktree {shown(moved[0])} moved with the repo (git's record has {path}): "
                       f"`git worktree repair {shown(moved[0])}`, then `git worktree remove {shown(moved[0])}`")
        else:
            out.append(f"worktree {path} is gone, but git still records it: `git worktree prune`")
    for d, rid in folders.items():
        old = any((root / f.rstrip("/")) in d.parents for f in old_folders)
        if old and d.resolve() not in claimed:
            out.append(f"{shown(d)} is not a checkout git knows: look, then delete it")
    return out, scratch


def cmd_update(root: Path, args) -> int:
    if getattr(args, "merge_log", False):
        return cmd_merge_log(root, args.apply)
    if getattr(args, "sweep", False):
        return cmd_sweep(root, args.apply)
    here = Path(__file__).resolve().parent
    files = tracked(root)
    board_row = next(olds for new, olds in LAYOUT if new == CONFIG)
    spots = [p for p in [CONFIG, *board_row] if (root / p).exists()]
    if len(spots) != 1:
        if spots:
            why = [f"two boards, {' and '.join(spots)}: update can't tell which one the jobs are on"]
        else:
            why = [f"no board at any path jig has used ({', '.join([CONFIG, *board_row])})"]
            why += [f"board-like JSON: {f}" for f in board_like_json(root, files)]
            why += [f"a hook jig didn't write: {h}" for h in foreign_hooks()]
        return update_blocked(why)
    board_at = spots[0]
    try:
        data = json.loads((root / board_at).read_text())
        if not isinstance(data, dict):
            raise ValueError("not a JSON object")
    except ValueError as e:
        return update_blocked([f"{board_at} is not a valid board: {e}"])
    board_gone: list[str] = []
    if board_at.startswith(CLAUDE_LANE):
        data, board_gone = from_claude_lane(data)

    refused = []
    version = data.get("version") if isinstance(data.get("version"), int) else 0
    if version > STAMP:
        refused.append(f"repo is ahead; update the plugin ({board_at} is at version {version}, "
                       f"this jig writes {STAMP})")
    if refused:
        print(f"refused: {refused[0]}", file=sys.stderr)
        return 2
    if board_at == CONFIG:
        try:
            open_jobs = list(json.loads((root / JOBS).read_text()) if (root / JOBS).exists() else {})
        except ValueError as e:
            return update_blocked([f"{JOBS} is not valid JSON: {e}"])
    else:
        open_jobs = [n for n, l in (data.get("lanes") or {}).items()
                      if not isinstance(l, dict) or l.get("state") != "merged"]
    if open_jobs:
        refused.append(f"jobs are open: {', '.join(open_jobs)}. Merge each (`jig merge`), or close it "
                       f"by deleting its entry from {JOBS} on trunk, "
                       "first: update moves files their worktrees rely on")
    # Today's board is at .jig/ too, so .jig/worktrees/ is old only beside an older board.
    old_ignores = OLD_IGNORES if board_at != CONFIG or version < STAMP else OLD_IGNORES[1:]
    worktrees, gate_left = worktree_refusals(root, old_ignores)
    refused += worktrees
    # A tracked change mid-move would leave jig half-moved; a re-run must still see the old layout.
    dirty = git("status", "--porcelain", "--untracked-files=no")

    flat_rows, flat = handoff_rows(root, files)
    plan = plan_moves(files, board_at, version, hardware_rows(root, files) + flat_rows)
    new_board, edits, board_warn, gone = rewrite_board(data, files, plan)
    board_gone += gone
    warnings = plan["warn"] + board_warn
    # plan_moves sees tracked files only; `git mv` onto an untracked one dies mid-apply, with
    # the renames before it staged.
    occupied = [f"{n} (from {o})" for o, n in plan["moves"].items()
                if (root / n).exists() or (root / n).is_symlink()]
    # A script that finds the repo from its own folder (`cd "$(dirname "$0")/.."`) counts
    # levels, and a move that changes its depth breaks it. The line is the repo's to fix.
    selfref = re.compile(r"\$0\b|\$\{0\}|BASH_SOURCE|__file__|__FILE__|__dir__|__dirname|import\.meta\.url")
    for o, n in plan["moves"].items():
        if n.endswith(".md") or o.count("/") == n.count("/"):
            continue
        try:
            lines = (root / o).read_text().splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        hits = [f"{i}: {l.strip()}" for i, l in enumerate(lines, 1) if selfref.search(l)]
        if hits:
            warnings.append(f"{n} moves from {o}, {o.count('/')} folder(s) deep to "
                            f"{n.count('/')}, and finds paths from its own location: "
                            + "; ".join(hits))
    # With no stored next number, a counter's pattern is the only way to know what is taken.
    blind = [k for k, v in (new_board.get("reserve") or {}).items()
             if not (isinstance(v, dict) and v.get("pattern") and v.get("files"))]
    if blind:
        refused.append(f"reserve counters without a pattern and files: {', '.join(blind)}. Add "
                       f"both to each in {board_at} (\"reserve\": {{\"{blind[0]}\": {{\"pattern\": "
                       f"..., \"files\": [...]}}}}), then update again: the pattern is how jig "
                       "knows which numbers are taken")
    sources = {f"{DIR}/jig.py": Path(__file__).resolve(), f"{DIR}/RULES.md": here / "RULES.md",
               f"{DIR}/docs-page.md": here / "docs-page.md"}
    replace = []
    for dest, src in sources.items():
        if not src.exists():
            warnings.append(f"no {src.name} beside this jig.py: {dest} is left as it is")
        elif plan["retire"] or not (root / dest).exists() or (root / dest).read_bytes() != src.read_bytes():
            replace.append(dest)
    steps = [(s[0](root) if callable(s[0]) else s[0], *s[1:]) for s in STEPS
             if s[1](root, set(plan["after"]))]
    # Everything that leaves the repo, named before anything is applied: removed files stay in
    # git's history, but nobody should learn of a removal from the diff.
    removed = [f"{r} ({n} replaces it)" for o, n in plan["rows"] for r in plan["retire"]
               if r == o or (o.endswith("/") and r.startswith(o))]
    removed += [f"{g} (nothing of jig's replaces it)" for g in plan["gone"]]
    removed += [f"{REVIEW_LEDGER} (its untaken rows move to {DEFERRED})"
                for s in steps if s[2] is fold_ledger]
    warnings += [w for s in steps if s[2] is fold_ledger for w in ledger_warnings(root)]
    removed += board_gone
    ignore = root / ".gitignore"
    ignore_lines = ([l for l in ignore.read_text().splitlines() if l.strip() in old_ignores]
                    if ignore.exists() else [])
    untracked = [(o, n) for o, n in OLD_UNTRACKED if board_at.startswith("jig/")
                 and (root / o).is_dir() and any(f.is_file() and f.relative_to(root).as_posix() not in files
                                                 for f in (root / o).rglob("*"))]
    # A staged file left in jig/staging/ would sit where jig no longer reads.
    occupied += [f"{n}{f.relative_to(root / o).as_posix()} (from {f.relative_to(root).as_posix()})"
                 for o, n in untracked for f in sorted((root / o).rglob("*"))
                 if f.is_file() and (root / n / f.relative_to(root / o)).exists()]
    warnings += left_behind(root, files, plan, [o for o, _ in OLD_UNTRACKED] + list(old_ignores))
    if occupied:
        refused.append(f"untracked files where files would move: {', '.join(occupied)}. Look at "
                       "each, move or delete it, then update again")
    cache_line = [l for l in ignore.read_text().splitlines() if l.strip() == "jig/meta-cache/"] \
        if ignore.exists() and board_at.startswith("jig/") else []
    ref_line = [l for l in ignore.read_text().splitlines() if l.strip() == OLD_REFERENCE_IGNORE] \
        if ignore.exists() and new_board.get("reference_files") == "ignore" else []

    def ignored_by(*patterns: str) -> set[str]:
        return set(git("ls-files", "--others", "--ignored",
                       *[f"--exclude={p}" for p in patterns]).splitlines())
    # A vendor definition saved beside a board page was a PDF the old line hid.
    unignored = sorted(ignored_by(OLD_REFERENCE_IGNORE) - ignored_by(*REFERENCE_IGNORES)) \
        if ref_line else []
    hooks_dir = git_common() / "hooks"
    trunk = new_board.get("trunk", "main")
    stale_hooks = [n for n in HOOKS if not (hooks_dir / n).exists()
                   or (hooks_dir / n).read_text(errors="replace") != HOOK.format(dir=DIR, trunk=trunk, name=n)]
    if not (git_common() / "jig" / "enabled").exists():
        stale_hooks = stale_hooks or list(HOOKS)
    warnings += [f"hook {h} isn't jig's: install-hooks keeps it, running first, as {h}.local"
                 for h in foreign_hooks() if h in HOOKS]
    aidev_state = (git_common() / "aidev").exists()
    stale = stale_references(root, plan, board_at)
    for f, hits in stale.items():
        live = [line for _, line in hits if not line.startswith(COMMENT)]
        if live and not f.endswith(".md"):
            warnings.append(f"{f} names a path jig moved ({len(live)} line{'s' if len(live) > 1 else ''} "
                            "outside comments): code or config the repo's checks may run")
    arriving = set(plan["after"]) | set(replace) | {SETUP for s in steps if s[2] is add_setup}
    # The owner's recorded yeses, judged on the repo as the layout moves will leave it.
    back = {n: o for o, n in plan["moves"].items()}

    def read_after(f: str) -> str:
        p = root / back.get(f, f)
        return p.read_text(errors="replace") if p.is_file() else ""
    carried, gone_ids = approved_moves(root, plan["after"], new_board, read_after)
    review = files_to_review(root, plan, here.parent / "AGENTS.md", arriving)
    review += home_findings(root, plan, new_board, board_at, [f for f, _ in review])
    review += [(LOG, f"{e} has no Touches line: add one under its status line, naming the pages "
                f"it touches ({DIR}/RULES.md, Decision log)") for e in untouched_entries(root, trunk)]
    review += superseded_kept(root)
    review += project_review(root, files, [f for f, _ in review])
    have_ignores = {l.strip() for l in ignore.read_text().splitlines()} if ignore.exists() else set()
    if (new_board.get("reference_files") == "ignore" and not ref_line
            and not set(REFERENCE_IGNORES) <= have_ignores):
        # A line the repo wrote itself is its own: update rewrites only the one jig wrote.
        review.append((".gitignore", "reference_files is ignore, and no line is jig's for the "
                       "PDFs under datasheets/ folders: add " + ", ".join(f"`{g}`" for g in REFERENCE_IGNORES)
                       + ", or keep the repo's own line if it covers them"))

    # A metarepo's pages change only in a job (M4), and trunk is where the record is: the move
    # is the job's, and its entry drops on trunk once the move has merged and the finding is gone.
    jobs_moves = carried if (root / META).exists() else []
    carried = [] if jobs_moves else carried
    # What the moves touch beyond the rename, read before it: the session's to do.
    para, cached = para_pointers(root) if carried else ({}, [])
    left = [l for e in carried
            for l in move_lines(root, new_board, board_at, plan["after"], para, cached,
                                os.path.dirname(e["path"]) + "/", [e], {})
            if not l.startswith(("git mv ", "fold ", f"{CONFIG} docmap:"))]

    def carried_report(done: bool) -> None:
        if carried or gone_ids:
            print(f"\nIn {CONFIG} findings, {'done' if done else 'done by --apply'}:")
            for e in carried:
                print(f"  git mv {e['path']} {e['to']}  [{finding_id(e)}: approved]")
            for i in gone_ids:
                print(f"  {i}: the finding no longer fires; its entry is dropped")
        if jobs_moves:
            print(f"\nApproved in {CONFIG} findings, a job's in a metarepo (M4): open one for these "
                  "pages and move them there; each entry drops on the next --apply once its move "
                  f"is on {trunk}:")
            for e in jobs_moves:
                print(f"  git mv {e['path']} {e['to']}  [{finding_id(e)}]")
        if left and done:
            print("\nLeft for the session, in the same commit:")
            for line in left:
                print(f"  {line}")

    moved_board = board_at != CONFIG or not (root / JOBS).exists()
    actions = bool(plan["moves"] or replace or edits or moved_board or steps or ignore_lines
                   or stale_hooks or aidev_state or untracked or cache_line or ref_line or removed
                   or gate_left)
    if not actions:
        print("up to date")
        for w in warnings:
            print(f"warning: {w}")
        # The repo's own files are no layout action, but they are still the plan survey sent here.
        if review:
            print(f"\nRepo files to review (update applies none of these but the moves {CONFIG} "
                  "findings approves):")
            for f, what in review:
                print(f"  {f}: {what}")
        if board_at == CONFIG and (root / PARA).exists():
            for line in removal_blocks(root, trunk, always=False):
                print(line)
        if not (carried or gone_ids or jobs_moves):
            return 0
        # A recorded yes is carried out whether or not the layout is current.
        if args.apply and (refused or dirty):
            print("refused: " + ("; ".join(refused) or
                                 "commit or stash tracked changes first; update moves files by name"),
                  file=sys.stderr)
            return 2
        if not args.apply:
            carried_report(False)
            print("\nDry run: nothing changed. Run again with --apply to carry these out; it stages "
                  "and commits nothing.")
            return 0
        if not (carried or gone_ids):
            carried_report(False)
            return 0
        carry_out(root, data, carried, gone_ids)
        (root / CONFIG).write_text(json.dumps(data, indent=2) + "\n")
        git("add", "--", CONFIG, check=True)
        carried_report(True)
        print("\nApplied and staged; nothing is committed. Repoint what names a moved page, "
              "then commit on trunk.")
        return 0
    if refused:
        print(f"refused: the repo is behind this jig's layout ({board_at}, version "
              f"{data.get('version', 'none')}), but:", file=sys.stderr)
        for r in refused:
            print(f"  {r}", file=sys.stderr)
        if args.apply:
            return 2
        # The plan still prints, so the fix and what follows it are read together.
        sys.stderr.flush()
    if args.apply and dirty:
        print("refused: commit or stash tracked changes first; update moves files by name",
              file=sys.stderr)
        return 2

    print(f"jig update: {board_at} (version {data.get('version', 'none')}) → {CONFIG} and "
          f"{JOBS} (version {STAMP})")
    if plan["moves"]:
        print("\nMoves (renamed, never edited):")
        for o, n in plan["moves"].items():
            print(f"  {o} → {n}")
    if replace:
        print("\nWritten from this copy of jig:")
        for dest in replace:
            print(f"  {dest}")
    if removed:
        print("\nRemoved:")
        for r in removed:
            print(f"  {r}")
    if edits:
        print("\nBoard:")
        for e in edits:
            print(f"  {e}")
    if steps:
        print("\nSteps:")
        for s in steps:
            print(f"  {s[0]}")
    if ignore_lines or stale_hooks or aidev_state or untracked or cache_line or ref_line or gate_left:
        print("\nGit state:")
        for w in gate_left:
            print(f"  remove {os.path.relpath(w, root)} (gate scratch, removed on --apply)")
        for l in ignore_lines:
            print(f"  .gitignore: remove `{l.strip()}` (worktrees live in .git/jig/worktrees/ now)")
        for l in cache_line:
            print(f"  .gitignore: `{l.strip()}` → `{CACHE}/`")
        for l in ref_line:
            print(f"  .gitignore: `{l.strip()}` → " + ", ".join(f"`{g}`" for g in REFERENCE_IGNORES)
                  + " (reference_files: ignore; vendor documents sit in datasheets/ folders now)")
        for f in unignored:
            print(f"    {f}: ignored now, untracked after: commit it, or move a vendor copy into "
                  "a datasheets/ folder")
        for o, n in untracked:
            print(f"  move the untracked files in {o} to {n}")
        if stale_hooks:
            print(f"  hooks: rewrite {', '.join(stale_hooks)} to run {trunk}:{DIR}/jig.py")
        if aidev_state:
            print("  remove .git/aidev/ (ai-dev's markers; install-hooks writes .git/jig/)")

    def report() -> None:
        if warnings:
            print("\nWarnings:")
            for w in warnings:
                print(f"  {w}")
        if stale:
            print("\nStale references, as the files will be after the moves:")
            for f, hits in stale.items():
                print(f"  {f}  {len(hits)}")
                if not f.endswith(".md"):
                    for i, line in hits:
                        print(f"      {i}: {line}")
        if review:
            print(f"\nRepo files to review (update applies none of these but the moves {CONFIG} "
                  "findings approves):")
            for f, what in review:
                print(f"  {f}: {what}")
        if board_at == CONFIG and (root / PARA).exists():
            print("\n".join(removal_blocks(root, trunk, always=True)))

    if not args.apply:
        report()
        carried_report(False)
        if refused:
            print("\nDry run: nothing changed, and --apply refuses until the above is fixed.")
            return 2
        print("\nDry run: nothing changed. Run again with --apply to apply it; it stages and commits nothing.")
        return 1 if warnings else 0

    # The board last: while it sits at its old path, a re-run still sees the old layout.
    for o, n in sorted(plan["moves"].items(), key=lambda m: m[0] == board_at):
        (root / n).parent.mkdir(parents=True, exist_ok=True)
        git("mv", o, n, check=True)
    carry_out(root, new_board, carried, gone_ids)
    (root / CONFIG).parent.mkdir(parents=True, exist_ok=True)
    (root / CONFIG).write_text(json.dumps(new_board, indent=2) + "\n")
    if not (root / JOBS).exists():
        (root / JOBS).write_text("{}\n")
    blobs = {dest: sources[dest].read_bytes() for dest in replace}
    for r in plan["retire"] + plan["gone"]:
        git("rm", "-q", "-f", r, check=True)
    for dest, blob in blobs.items():
        (root / dest).write_bytes(blob)
    for s in steps:
        s[2](root, here)
    for o, n in untracked:
        for f in sorted(p for p in (root / o).rglob("*") if p.is_file()):
            dest = root / n / f.relative_to(root / o)
            if not dest.exists():
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(f), dest)
    if ignore_lines or cache_line or ref_line:
        raw = ignore.read_bytes().decode()
        gone = "|".join(re.escape(l) for l in old_ignores)
        raw = re.sub(rf"(?m)^[ \t]*(?:{gone})[ \t]*(?:\r?\n|\Z)", "", raw)
        raw = re.sub(rf"(?m)^[ \t]*{re.escape(OLD_REFERENCE_IGNORE)}[ \t]*$",
                     lambda _: "\n".join(REFERENCE_IGNORES), raw)
        ignore.write_bytes(re.sub(r"(?m)^[ \t]*jig/meta-cache/[ \t]*$", f"{CACHE}/", raw).encode())
    git("add", "--", CONFIG, JOBS, *replace,
        *([".gitignore"] if ignore_lines or cache_line or ref_line else []), check=True)
    # git mv leaves a flattened note's subfolder behind, empty.
    for folder in ({o for o, _ in plan["rows"] if o.endswith("/")} | flat
                   | {o for o, _ in untracked} | {d for d in OLD_DIRS if board_at.startswith(d)}):
        for d, _, _ in sorted(os.walk(root / folder), key=lambda w: -len(w[0])):
            try:
                Path(d).rmdir()
            except OSError:
                pass
    if aidev_state:
        shutil.rmtree(git_common() / "aidev")
    for w in gate_left:
        if not remove_checkout(w):
            warnings.append(f"git couldn't remove {os.path.relpath(w, root)}: "
                            f"`git worktree remove --force {os.path.relpath(w, root)}`")
    cmd_install_hooks(root, argparse.Namespace(replace=False))
    report()
    carried_report(True)
    check = root / DIR / "scripts" / "check.sh"
    passed = True
    if check.exists():
        rc = subprocess.run([str(check)] if os.access(check, os.X_OK) else ["bash", str(check)],
                            cwd=root).returncode
        passed = rc == 0
        print(f"\n{DIR}/scripts/check.sh {'passed' if passed else f'FAILED (exit {rc})'}")
    print("\nApplied and staged; nothing is committed. Fix what the check and the stale "
          "references show, then commit on trunk.")
    return 0 if passed else 1


# ------------------------------------------------------- the log, from what came before it

# A release heading as an old CHANGELOG.md wrote it: `## v0.3.0 — date`, or Keep a Changelog's
# `## [0.3.0] - date`. Its Unreleased may be `## [Unreleased]`.
OLD_RELEASE = re.compile(r"^## \[?v?(\d+\.\d+(?:\.\d+)?)\]?[ \t]*[—–-][ \t]*(\d{4}-\d{2}-\d{2})(.*)$")
OLD_UNRELEASED = re.compile(r"^## \[?unreleased\]?[ \t]*$", re.I)
# What jig's old seeds wrote into the two files: no owner wrote it, so it needs no new home.
OLD_SEED = re.compile(r"^(?:# Changelog|# Decisions|Every change to an entry file adds a line here; "
                      r"`jig release` turns Unreleased into the next version\.|"
                      r"<!-- One row per decision\..*-->)[ \t]*$")
DATE = re.compile(r"\d{4}-\d{2}-\d{2}")


def id_numbers(text: str, prefix: str) -> set[int]:
    """Every decision number TEXT names, a range (`D-029–D-044`, `D-029-044`) as each in it."""
    p = re.escape(prefix)
    out = {int(n) for n in re.findall(rf"(?<![\w-]){p}(\d+)(?!\d)", text)}
    for a, b in re.findall(rf"(?<![\w-]){p}(\d+)[ \t]*[–—-][ \t]*(?:{p})?(\d+)(?!\d)", text):
        if 0 < int(b) - int(a) < 1000:
            out |= set(range(int(a), int(b) + 1))
    return out


def highest_id(text: str, prefix: str, history: bool = False) -> int:
    """The highest decision number ever written in the log: its text, and with HISTORY every
    version of it on this branch, so a rejected entry's number is never given again."""
    seen = id_numbers(text, prefix)
    if history:
        seen |= {int(n) for n in re.findall(rf"(?<![\w-]){re.escape(prefix)}(\d+)(?!\d)",
                                            git("log", "-p", "--format=", "HEAD", "--", LOG))}
    return max(seen, default=0)


def rows_in(text: str, prefix: str | None) -> list[str]:
    """A register's decision rows: the repo's prefix, or any uppercase one where none is set."""
    p = re.escape(prefix) if prefix else r"[A-Z][A-Z0-9]*-"
    rx = re.compile(rf"^\s*\|\s*{p}\d+\s*\|")
    return [l.rstrip() for l in text.splitlines() if rx.match(l)]


def old_prefix(root: Path) -> str | None:
    meta = root / META
    return ({**META_DEFAULTS, **json.loads(meta.read_text() or "{}")}["decision_prefix"]
            if meta.exists() else None)


def old_registers(root: Path) -> list[str]:
    """The decision registers to merge: a metarepo's entry files, or a file named DECISIONS.md
    anywhere outside .jig/, that hold decision rows."""
    meta = root / META
    entry = json.loads(meta.read_text() or "{}").get("entry_files", []) if meta.exists() else []
    return [f for f in tracked(root) if not f.startswith(f"{DIR}/") and f.endswith(".md")
            and (f in entry or Path(f).name.lower() == "decisions.md")
            and rows_in((root / f).read_text(errors="replace"), old_prefix(root))]


def old_log_files(root: Path) -> list[tuple[str, str]]:
    """The files a log would be merged from, each with a line saying what it holds."""
    out = []
    if (root / CHANGELOG).is_file():
        n = sum(1 for l in (root / CHANGELOG).read_text(errors="replace").splitlines() if OLD_RELEASE.match(l))
        out.append((CHANGELOG, f"the release log, {n} release section{'s' if n != 1 else ''}"))
    for f in old_registers(root):
        n = len(rows_in((root / f).read_text(errors="replace"), old_prefix(root)))
        out.append((f, f"a decision register, {n} row{'s' if n != 1 else ''}"))
    return out


def log_is_seed(root: Path) -> bool:
    return (root / LOG).is_file() and (root / LOG).read_text() == LOG_SEED


def log_sources(root: Path) -> list[tuple[str, str]]:
    """What `--merge-log` would fold into the log. None once the log holds anything but the
    seed: the merge is done once, and a seed `jig init` wrote is still empty."""
    return old_log_files(root) if not (root / LOG).exists() or log_is_seed(root) else []


def register_header(lines: list[str]) -> list[str]:
    """A register's header row: its first cell names the id column, `Id` or `#`."""
    for l in lines:
        if l.lstrip().startswith("|"):
            cells = table_cells(l)
            if cells and cells[0].strip().lower() in ("id", "#"):
                return cells
    return []


def row_entry(cells: list[str], header: list[str]) -> dict:
    """One register row as an entry: id, title, status line, extra lines, and where it goes."""
    named = {h.strip().lower(): i for i, h in enumerate(header)} if header else {}
    status_i = next((i for i, c in enumerate(cells) if STATUS_CELL.fullmatch(c.lower())), None)
    dates = [i for i, c in enumerate(cells) if DATE.fullmatch(c)]
    title_i = named.get("decision", next((i for i in range(1, len(cells)) if i not in (status_i, *dates)), None))
    status = cells[status_i] if status_i is not None else ""
    word = status.lower().split()[0].split("(")[0] if status else ""
    note = re.search(r"\((.*)\)", status)
    by = re.search(r"\bby\s+(\S+)", status, re.I)
    # A row with a date it was accepted and one it was superseded keeps the first: the decision's.
    day = min((cells[i] for i in dates), default="0000-00-00")
    who = (note.group(1).strip() if note else "")
    title = cells[title_i] if title_i is not None else ""
    rest = [f"{header[i] if i < len(header) and header[i] else 'Note'}: {c}" for i, c in enumerate(cells)
            if i not in (0, status_i, title_i, *dates) and c]
    if word in ("open", "proposed"):
        line, where = f"{word.capitalize()} ({who + ', ' if who else ''}{day}).", "Open"
    else:
        # A superseded decision was accepted once; the entry superseding it says so.
        line, where = f"Accepted ({who or 'not recorded'}, {day}).", ""
    if HEADING_STATUS.search(title):
        # A title starting with a status word would read as a status: it moves to the body.
        title, rest = "Decision", [cells[title_i], *rest]
    return {"id": cells[0].strip(), "title": title, "status": line, "rest": rest, "where": where,
            "word": word, "who": who, "day": day if dates else "",
            "by": by.group(1) if by and word == "superseded" else None,
            # What the old M2 refused stays refused: no status cell, or no date.
            "bad": status_i is None or not dates}


def paragraphs(lines: list[tuple[int, str]]) -> list[list[tuple[int, str]]]:
    """Leftover lines as notes: blank-separated paragraphs, a heading keeping what follows it
    together until the next heading, since a section is one thing to place."""
    out: list[list[tuple[int, str]]] = []
    cur: list[tuple[int, str]] = []
    section = False
    last = None
    for n, l in lines:
        gap = last is not None and n > last + 1
        if l.lstrip().startswith("#"):
            if cur:
                out.append(cur)
            cur, section = [(n, l)], True
        elif gap and not section and cur:
            out.append(cur)
            cur = [(n, l)]
        else:
            cur.append((n, l))
        last = n
    if cur:
        out.append(cur)
    return out


def as_written(paras: list[list[tuple[int, str]]]) -> str:
    """Leftover paragraphs as the old file had them: each one's own lines, one blank line where
    the old file had a gap inside it, and a blank line between them. Only their own: a heading's
    paragraph can span a table the log took, and the lines between are not leftovers."""
    out = []
    for para in paras:
        lines: list[str] = []
        for i, (n, l) in enumerate(para):
            if i and n > para[i - 1][0] + 1:
                lines.append("")
            lines.append(l)
        out.append("\n".join(lines))
    return "\n\n".join(out) + "\n"


def accepted_before(root: Path, f: str, ids: set[str], prefix: str | None,
                    rev: str = "HEAD") -> dict[str, dict]:
    """For each superseded row in IDS, the row as F's newest revision in git up to REV had it
    while accepted. Superseding overwrote the row's status and date cells, so only history still
    says who accepted it and when. Accepted only: a proposed or open row's note says who asked,
    not who accepted. F's own path only: a moved register is left to the owner."""
    out: dict[str, dict] = {}
    for c in git("log", "--format=%H", rev, "--", f, cwd=str(root)).splitlines():
        if len(out) == len(ids):
            break
        old = parse_register(git("show", f"{c}:{f}", cwd=str(root)), prefix)[0]
        for e in old:
            k = decision_id(e["id"])
            if k in ids and k not in out and e["word"] == "accepted" and e["day"]:
                out[k] = e
    return out


def date_superseded(root: Path, f: str, found: list[dict], prefix: str | None,
                    rev: str = "HEAD") -> list[str]:
    """FOUND's superseded rows given the status line F's history says they had, in place, and
    a line for each one history couldn't date or name the accepter of."""
    gone = {decision_id(e["id"]) for e in found if e["word"] == "superseded"}
    then = accepted_before(root, f, gone, prefix, rev) if gone else {}
    said = []
    for e in found:
        if e["word"] != "superseded":
            continue
        was = then.get(decision_id(e["id"]))
        if was:
            e["status"] = f"Accepted ({was['who'] or 'not recorded'}, {was['day']})."
        if not was or not was["who"]:
            said.append(f"{e['id']}: superseded, and {f}'s history in git doesn't say who accepted it"
                        + ("" if was else " or when") + f": check `{e['status']}` before committing")
    return said


def grouped(lines: list[str]) -> list[str]:
    """A release section's change lines under a Keep a Changelog group, as RULES.md's log has
    them. Lines under no group get `### Changed`: an entry's block runs to the next `### `, so
    bare lines would read as the last entry's. A guessed Added or Fixed would freeze a guess."""
    lines = trimmed(lines)
    first = next((i for i, l in enumerate(lines) if l.startswith("### ")), len(lines))
    if any(l.strip() for l in lines[:first]):
        return ["### Changed", "", *lines]
    return lines


def parse_register(text: str, prefix: str | None) -> tuple[list[dict], list[list[tuple[int, str]]]]:
    """A register's entries, and its other lines as notes: nothing the owner wrote is dropped."""
    lines = text.splitlines()
    rows = set(rows_in(text, prefix))
    rule = lambda l: l.lstrip().startswith("|") and all(re.fullmatch(r":?-+:?", c) for c in table_cells(l))
    # Each row is read against its own table's header, since two tables may order or name their
    # columns differently. A table with none takes the nearest decision table's header above,
    # then the file's first Id header. A decision table's header row and separator are known by
    # the decision row under them, whatever the header says: a note's own table keeps its lines.
    fallback = register_header(lines)
    entries, table, header, near = [], set(), None, None
    for i, l in enumerate(lines):
        under = i + 1 < len(lines) and rule(lines[i + 1])
        if not l.lstrip().startswith("|"):
            header = None
        elif l.rstrip() in rows:
            entries.append(row_entry(table_cells(l), header or near or fallback))
            near = header or near
            if under:
                table.add(i + 2)
        elif under:
            header = table_cells(l)
            if i + 2 < len(lines) and lines[i + 2].rstrip() in rows:
                table |= {i + 1, i + 2}
    left = [(n, l) for n, l in enumerate(lines, 1)
            if l.strip() and l.rstrip() not in rows and not OLD_SEED.match(l) and n not in table]
    return entries, paragraphs(left)


def merged_log(root: Path) -> dict:
    """The log `--merge-log` writes, what it says about each row, and what found no home."""
    prefix = old_prefix(root)
    old = (root / CHANGELOG).read_text(errors="replace") if (root / CHANGELOG).is_file() else ""
    sections: list[list] = []      # [heading, body lines, is a release]
    preamble: list[tuple[int, str]] = []
    unreleased: list[str] = []
    cur = None
    for n, line in enumerate(old.splitlines(), 1):
        m = OLD_RELEASE.match(line)
        if m:
            yank = " [YANKED]" if "YANKED" in m.group(3) else ""
            cur = [f"## v{m.group(1)} - {m.group(2)}{yank}", [], True]
            sections.append(cur)
        elif OLD_UNRELEASED.match(line):
            cur = None
            unreleased.append("")      # one Unreleased, however the old file spelled it
        elif line.startswith("## "):
            cur = [line.rstrip(), [], False]
            sections.append(cur)
        elif cur is not None:
            cur[1].append(line)
        elif unreleased:
            unreleased.append(line)
        elif line.strip() and not OLD_SEED.match(line):
            preamble.append((n, line))
    entries: list[dict] = []
    homeless: list[tuple[str, list[tuple[int, str]]]] = []
    if preamble:
        homeless += [(CHANGELOG, p) for p in paragraphs(preamble)]
    keep: dict[str, str] = {}          # an old file's leftover, kept in it after the merge
    rejected: list[str] = []
    struck: list[str] = []
    undated: list[str] = []
    for f in old_registers(root):
        found, notes = parse_register((root / f).read_text(errors="replace"), prefix)
        p = prefix or (re.match(r"[A-Z][A-Z0-9]*-", found[0]["id"]).group(0) if found else "D-")
        undated += date_superseded(root, f, found, prefix)
        by_num = {}
        for e in found:
            if e["word"] in ("rejected", "struck"):
                (rejected if e["word"] == "rejected" else struck).append(e["id"])
                continue
            entries.append(e)
            by_num[int(re.sub(r"\D", "", e["id"]) or 0)] = e
        for para in notes:
            nums = id_numbers("\n".join(l for _, l in para), p)
            if len(nums) == 1 and (e := by_num.get(next(iter(nums)))) and not para[0][1].lstrip().startswith("#"):
                e["rest"] += [""] + [l for _, l in para]
            else:
                homeless.append((f, para))
        mine = [para for g, para in homeless if g == f]
        if mine:
            keep[f] = as_written(mine)
    if preamble:
        keep[CHANGELOG] = as_written(paragraphs(preamble))
    p = prefix or (re.match(r"[A-Z][A-Z0-9]*-", entries[0]["id"]).group(0) if entries else "D-")
    # Every row the register holds must come out as an entry or be named as left out, whatever
    # its table's shape: a row read wrong is lost with its register file.
    taken = {decision_id(e["id"]) for e in entries} | {decision_id(x) for x in rejected + struck}
    lost = [f"{f}: row {table_cells(r)[0].strip()} came out as no entry: jig couldn't read its table; "
            "give the table an Id header and a separator"
            for f in old_registers(root) for r in rows_in((root / f).read_text(errors="replace"), prefix)
            if decision_id(table_cells(r)[0]) not in taken]
    # A row a struck row superseded would come back accepted, since nothing in the log retires it.
    gone_live = [f"{e['id']} is superseded by {e['by']}, which is struck: strike {e['id']} too "
                 f"(Status `struck`), or un-strike {e['by']}"
                 for e in entries if e["by"] and decision_id(e["by"]) in {decision_id(x) for x in struck}]
    by_id = {decision_id(e["id"]): e for e in entries}
    for e in entries:
        new = by_id.get(decision_id(e["by"])) if e["by"] else None
        if new:
            new["status"] = new["status"][:-1] + f". Supersedes {e['id']}."
    for e in entries:
        if e["where"]:
            continue
        # An accepted row goes to the oldest release whose lines name it, ranges included.
        num = int(re.sub(r"\D", "", e["id"]) or 0)
        hit = [sec for sec in sections if sec[2] and num in id_numbers("\n".join(sec[1]), p)]
        e["where"] = hit[-1][0] if hit else "Unreleased"

    def blocks(where: str) -> list[str]:
        out = []
        for e in entries:
            if e["where"] == where:
                out += [f"### {e['id']} {e['title']}".rstrip(), e["status"], *([""] + e["rest"] if e["rest"] else []), ""]
        return out
    head = LOG_SEED.replace("## Open\n\n## Unreleased\n", "")
    if rejected:
        # Their numbers stay taken: numbering starts above every id the log has ever named.
        head += f"Rejected before this log, and left out of it: {', '.join(rejected)} (git keeps their rows).\n\n"
    if struck:
        head += (f"Struck as project scope before this log, and left out of it: {', '.join(struck)} "
                 "(git keeps their rows).\n\n")
    text = head + "## Open\n\n" + "\n".join(blocks("Open")) + "\n## Unreleased\n\n"
    text += "\n".join(blocks("Unreleased") + grouped(unreleased[1:])) + "\n"
    for heading, body, release in sections:
        lines = grouped(body) if release else trimmed(body)
        text += f"\n{heading}\n\n" + "\n".join(blocks(heading) + lines) + "\n"
    text = re.sub(r"\n{3,}", "\n\n", text)
    placed: dict[str, list[str]] = {}
    for e in entries:
        placed.setdefault(e["where"].replace("## ", ""), []).append(e["id"])
    notes = [f"{', '.join(ids)} → {w}" for w, ids in placed.items()]
    notes += [f"{', '.join(rejected)}: rejected, left out (their numbers stay taken)"] if rejected else []
    notes += [f"{', '.join(struck)}: struck as project scope, left out (their numbers stay taken)"] if struck else []
    return {"text": text, "notes": notes, "homeless": homeless, "keep": keep, "prefix": p,
            "struck_live": gone_live, "undated": undated, "lost": lost}


def names_of(root: Path, gone: list[str]) -> list[tuple[str, int]]:
    """The repo's files that still name a merged file, to repoint: jig's own copies aside."""
    if not gone:
        return []
    # The merge rewrites the config and meta.json itself.
    skip = (f"{DIR}/jig.py", f"{DIR}/RULES.md", f"{DIR}/docs-page.md", LOG, CONFIG, META)
    hits = git("grep", "-c", "-F", *[a for g in gone for a in ("-e", g)], "--").splitlines()
    out = []
    for h in hits:
        f, _, n = h.rpartition(":")
        if f in gone or f in skip or f.startswith((f"{DIR}/handoffs/", f"{DIR}/meta-cache/")):
            continue
        out.append((f, int(n)))
    return out


def board_rewrite(root: Path, merged: set[str], prefix: str) -> tuple[dict, list[str]]:
    """The board after the merge: append_files and a reserve counter over MERGED name the log
    instead, the counter counting every number the log names, a rejected one's included."""
    data = json.loads((root / CONFIG).read_text())
    said = []
    appends = list(dict.fromkeys(LOG if a in merged else a for a in data.get("append_files", [])))
    if appends != data.get("append_files", []):
        said.append(f"{CONFIG} append_files: {data.get('append_files')} → {appends}")
        data["append_files"] = appends
    for k, v in (data.get("reserve") or {}).items():
        if isinstance(v, dict) and any(f in merged for f in v.get("files") or []):
            data["reserve"][k] = {**v, "files": [LOG], "pattern": rf"(?<![\w-]){re.escape(prefix)}(\d+)(?!\d)"}
            said.append(f"{CONFIG} reserve.{k}: files {v.get('files')} → [{LOG}], counting every id the log names")
    return data, said


def stale_board_names(root: Path) -> set[str]:
    """Once the log exists: the old files the board still names that hold no old log any more."""
    data = json.loads((root / CONFIG).read_text())
    meta = root / META
    entry = json.loads(meta.read_text() or "{}").get("entry_files", []) if meta.exists() else []
    named = set(data.get("append_files", [])) | {f for v in (data.get("reserve") or {}).values()
                                                 if isinstance(v, dict) for f in v.get("files") or []}
    old = {f for f in named if f == CHANGELOG or Path(f).name.lower() == "decisions.md" or f in entry}
    return {f for f in old if f != LOG and not ((root / f).is_file() and holds_old_log(
        (root / f).read_text(errors="replace"), f, old_prefix(root)))}


def cmd_merge_log(root: Path, apply: bool) -> int:
    """`jig update --merge-log`: fold a root CHANGELOG.md and the decision register into the log,
    on the owner's yes. Their words are kept: what has no place in the log stays where it was.
    The board is the hubnode's, on trunk: merged on a branch, it is rewritten there after."""
    if not (root / CONFIG).exists():
        die("run `jig update --apply` first: the merge runs on the current layout", 2)
    trunk = Board.trunk_name(root)
    on_trunk_now = git("branch", "--show-current") == trunk
    if (root / LOG).exists() and not log_is_seed(root):
        stale = stale_board_names(root)
        if not stale:
            print(f"{LOG} exists: nothing to merge")
            return 0
        data, said = board_rewrite(root, stale, log_prefix_of((root / LOG).read_text()))
        print("The board still names files the log took:")
        for line in said:
            print(f"  {line}")
        if not apply:
            print("Dry run: nothing changed. On trunk: jig update --apply --merge-log")
            return 0
        if not on_trunk_now:
            die(f"the board is edited on {trunk} only (R5): run this there", 2)
        (root / CONFIG).write_text(json.dumps(data, indent=2) + "\n")
        git("add", "--", CONFIG, check=True)
        print(f"\nRewritten {CONFIG}. Staged, nothing committed: commit it on {trunk}.")
        return 0
    sources = log_sources(root)
    if not sources:
        print(f"no CHANGELOG.md or decision register to merge: `jig update --apply` writes an empty {LOG}")
        return 0
    meta = root / META
    # In a metarepo the merge changes its own files, which trunk takes only as a reviewed merge.
    branch_needed = meta.exists() and on_trunk_now
    job = (f"open a job for it on {trunk} (`jig open merge-log --shares "
           f"{' '.join(f for f, _ in sources)}`), run this in its worktree, and merge it; then run "
           f"`jig update --apply --merge-log` on {trunk} again, for the board")
    if apply and branch_needed:
        die(f"in a metarepo the merge is a change to its files (M4): {job}", 2)
    have = set(tracked(root))
    untracked = [f for f, _ in sources if f not in have]
    if untracked:
        die(f"{', '.join(untracked)} isn't tracked: commit it, or move it aside, then merge", 2)
    if apply and git("status", "--porcelain", "--untracked-files=no"):
        die("commit or stash tracked changes first: the merge removes files by name", 2)
    m = merged_log(root)
    text, keep = m["text"], m["keep"]
    gone = [f for f, _ in sources if f not in keep]
    problems = [f"M2 {f}: row {e['id']} has no status cell or no date, as the old M2 asked"
                for f in old_registers(root)
                for e in parse_register((root / f).read_text(errors="replace"), old_prefix(root))[0] if e["bad"]]
    problems += m["lost"] + log_problems(text, m["prefix"]) + m["struck_live"]
    print("Merging into " + LOG + ":")
    for f, what in sources:
        print(f"  {f} ({what}), " + ("kept for what has no home" if f in keep else "removed after"))
    for n in m["notes"]:
        print(f"  {n}")
    for line in m["undated"]:
        print(f"  {line}")
    for f, para in m["homeless"]:
        print(f"  no home, move by hand: {f}:{para[0][0]}–{para[-1][0]} `{para[0][1].strip()[:60]}`")
    entry = json.loads(meta.read_text() or "{}").get("entry_files", []) if meta.exists() else None
    kept_entry = [LOG, *[e for e in entry if e not in gone and e != LOG]] if entry is not None else None
    if entry is not None:
        print(f"  {META} entry_files: {entry} → {kept_entry}")
    # What a kept file holds is no log any more: lines are appended to the log now.
    data, said = board_rewrite(root, {f for f, _ in sources}, m["prefix"])
    for line in said:
        print(f"  {line}" + ("" if on_trunk_now else f" (on {trunk}, after the merge)"))
    refs = names_of(root, [f for f, _ in sources])
    for f, n in refs:
        print(f"  repoint what names the old files: {f} ({n} line{'s' if n != 1 else ''})")
    if problems:
        print("refused: the merged log wouldn't pass M2; fix these rows first:", file=sys.stderr)
        for p in problems:
            print(f"  {p}", file=sys.stderr)
        return 2
    if not apply:
        print(f"\n--- {LOG}, as it would be written ---\n{text}")
        print("Dry run: nothing changed. On the owner's yes: "
              + (job if branch_needed else "jig update --apply --merge-log"))
        return 0
    (root / LOG).write_text(text)
    for f in gone:
        git("rm", "-q", "--", f, check=True)
    for f, rest in keep.items():
        (root / f).write_text(rest)
    if entry is not None:
        d = json.loads(meta.read_text())
        d["entry_files"] = kept_entry
        meta.write_text(json.dumps(d, indent=2) + "\n")
    if on_trunk_now:
        (root / CONFIG).write_text(json.dumps(data, indent=2) + "\n")
    git("add", "--", LOG, *keep, *([META] if entry is not None else []),
        *([CONFIG] if on_trunk_now else []), check=True)
    print(f"\nWritten {LOG}" + (f"; {', '.join(gone)} removed" if gone else "")
          + (f"; {', '.join(keep)} kept, holding only what has no home: move it by hand" if keep else "")
          + ". Staged, nothing committed: commit it here"
          + ("" if on_trunk_now or not said else
             f"; once it merges, `jig update --apply --merge-log` on {trunk} rewrites the board")
          + (", then repoint what names the old files" if refs else "") + ".")
    return 0


# ---------------------------------------------------------------- project sweep

# Words that mark a decision as the project's: an order, a phase, a delivery queue. Words only,
# since "phase" and "launch" have product meanings too: update lists, and the owner sorts.
SCOPE_WORDS = re.compile(r"(?i)\bprioriti|\bphases?\b|\bmilestones?\b|\bdemo\b|\blaunch|"
                         r"\buntil\b[^.]*\bpasses\b|\bpending delivery\b|\bsprints?\b|\bfirst,? then\b")
# Plan and register files a repo kept before jig, by name, and where what each holds goes.
PLAN_FILES = {
    **{n: f"the project's plan: its items go to {ROADMAP}, parked work under ## {UP_NEXT} "
          "naming the pages it touches; remove the file once it is empty"
       for n in ("TODO.md", "BACKLOG.md", "STATUS.md", "PLAN.md", "ROADMAP.md")},
    "FEATURES.md": "the product: each feature goes to its system's page under docs/, and each "
                   f"row's who and why to a decision entry in {LOG}; remove the file once it is empty",
    **{n: "rules for agents: what still binds goes to AGENTS.md (40 lines at most) or a skill; "
          "remove the file once it is empty"
       for n in ("RULES.md", "CONVENTIONS.md", "CONTRIBUTING.md")},
}


def product_pages(root: Path, files: list[str]) -> list[str]:
    """The files that describe the product, as survey and update read them for the project: docs
    pages, the decision log and a metarepo's entry files, less what not_docs sets aside."""
    try:
        not_docs = Board.load(root).data.get("not_docs") or []
    except SystemExit:
        not_docs = []
    meta = load_meta(Board.trunk_name(root))
    return [f for f in files if f.endswith(".md") and product_file(f, meta)
            and (f == LOG or not matches(f, not_docs))]


def plan_files(root: Path, files: list[str], reviewed: list[str]) -> list[tuple[str, str]]:
    """The repo's plan and register files, each with where its content goes. ROADMAP.md is jig's
    generated view where a roadmap exists, and a copy of jig carries its own RULES.md."""
    try:
        board = Board.load(root).data
    except SystemExit:
        board = {}
    skip = named_pages(board)
    not_docs = board.get("not_docs") or []
    out = []
    for f in files:
        name = Path(f).name.upper()
        what = next((v for k, v in PLAN_FILES.items() if k.upper() == name), None)
        if (what is None or f in reviewed or f in skip or matches(f, not_docs)
                or f.startswith((f"{DIR}/", ".claude/"))
                or (root / f).parent.joinpath("jig.py").exists()
                or (name == "ROADMAP.MD" and f == ROADMAP_VIEW and (root / ROADMAP).exists())):
            continue
        out.append((f, what))
    return out


def scope_candidates(root: Path) -> list[tuple[str, str]]:
    """Decision entries, or before --merge-log a register's rows and notes, whose text reads as
    the project's. The owner sorts each: strike, split or keep."""
    ask = "strike, split or keep (/jig:update says how)"
    out = []
    text = (root / LOG).read_text(errors="replace") if (root / LOG).is_file() else ""
    for e in log_entries(text, log_prefix_of(text)):
        if m := SCOPE_WORDS.search(e["block"]):
            out.append((LOG, f"{e['id']} {e['title']} reads as project scope (\"{m.group(0)}\"): {ask}"))
    for f, _ in log_sources(root):
        if f == CHANGELOG:
            continue
        entries, notes = parse_register((root / f).read_text(errors="replace"), old_prefix(root))
        for e in entries:
            body = " ".join([e["title"], *e["rest"]])
            if e["word"] not in ("rejected", "struck") and (m := SCOPE_WORDS.search(body)):
                out.append((f, f"row {e['id']} {clip(e['title'])} reads as project scope "
                            f"(\"{m.group(0)}\"): {ask}; a struck row's Status cell says Struck, "
                            "and --merge-log leaves it out"))
        for para in notes:
            if m := SCOPE_WORDS.search(" ".join(l for _, l in para)):
                out.append((f, f"lines {para[0][0]}–{para[-1][0]} `{clip(para[0][1].strip())}` read as "
                            f"project scope (\"{m.group(0)}\"): to {ROADMAP}, or delete them, before "
                            "--merge-log"))
    return out


def project_review(root: Path, files: list[str], reviewed: list[str]) -> list[tuple[str, str]]:
    """The project in the product, for update's Repo files to review: each page's Undefined
    entry as the Up next item `--sweep` would write, project sections and plan prose on pages,
    decision entries that read as scope, and the repo's plan and register files."""
    sids = scope_ids(at_rev(Board.trunk_name(root), ROADMAP))
    out = []
    for s in undefined_sweep(root, files, at_rev(Board.trunk_name(root), ROADMAP)):
        out += [(s["page"], f"## Undefined entry → {ROADMAP} ## {UP_NEXT}, on a yes "
                 f"(`jig update --sweep`): {i['line']}") for i in s["items"]]
        if s["prose"]:
            out.append((s["page"], "## Undefined holds text besides its entries: move it by hand"))
    for f in product_pages(root, files):
        if not (root / f).is_file():
            continue
        text = (root / f).read_text(errors="replace")
        heads = [] if f == LOG else [p for p in project_sections(text) if not p.startswith("## Undefined")]
        out += [(f, p) for p in heads + project_prose(text, sids)]
    return out + scope_candidates(root) + plan_files(root, files, reviewed)


def undefined_sections(text: str) -> list[tuple[int, int]]:
    """(start, end) line indexes of each `## Undefined` section, outside fenced code."""
    lines, out, fence, start = text.splitlines(), [], False, None
    for n, line in enumerate(lines):
        if line.lstrip().startswith(("```", "~~~")):
            fence = not fence
        m = None if fence else re.match(r"^ {0,3}##[ \t]+(.*?)[ \t#]*$", line)
        if m:
            if start is not None:
                out.append((start, n))
            start = n if m.group(1).strip().lower() == "undefined" else None
    if start is not None:
        out.append((start, len(lines)))
    return out


def undefined_sweep(root: Path, files: list[str], roadmap: str) -> list[dict]:
    """Each page's `## Undefined` section: {page, items: [{id, line, there}], prose, span}. An
    entry `<what> — stops at <where>; parked <date>.` becomes the Up next item
    `` - `<page>-<what>`: <what>; stops at <where>; parked <date> (touches <page>) ``. One the
    roadmap already holds, same text and page, keeps its id and is `there`."""
    have = parse_up_next(roadmap)
    taken = {i["id"] for i in have}
    out = []
    for page in product_pages(root, files):
        if page == LOG:
            continue
        text = (root / page).read_text(errors="replace") if (root / page).is_file() else ""
        lines = text.splitlines()
        for a, b in undefined_sections(text):
            entries: list[str] = []
            prose = False
            for line in lines[a + 1:b]:
                if re.match(r"^[-*+][ \t]+\S", line):
                    entries.append(re.sub(r"^[-*+][ \t]+", "", line).strip())
                elif line.strip() and entries and line[0] in " \t":
                    entries[-1] += " " + line.strip()
                elif line.strip() and not re.fullmatch(r"\s*<!--.*-->\s*", line):
                    prose = True
            items = []
            for e in entries:
                what = re.sub(r"\s+—\s+stops at\s+", "; stops at ", e, count=1).rstrip(" .")
                same = next((i for i in have if i["what"] == what and page in i["touches"]), None)
                if same:
                    iid = same["id"]
                else:
                    words = re.findall(r"[a-z0-9]+", f"{Path(page).stem.lower()} {what.split(';')[0].lower()}")[:4]
                    base_id = "-".join(words) or "parked"
                    iid, k = base_id, 2
                    while iid in taken:
                        iid, k = f"{base_id}-{k}", k + 1
                taken.add(iid)
                items.append({"id": iid, "there": bool(same),
                              "line": f"- `{iid}`: {what} (touches {page})"})
            out.append({"page": page, "items": items, "prose": prose, "span": (a, b)})
    return out


def without_sections(text: str, spans: list[tuple[int, int]]) -> str:
    """TEXT with each span of lines removed, and the blank lines it leaves at the end."""
    lines = text.splitlines()
    for a, b in sorted(spans, reverse=True):
        lines[a:b] = []
    return "\n".join(trimmed(lines)) + "\n"


def with_up_next(text: str, items: list[str]) -> str:
    """The roadmap TEXT with ITEMS appended under ## Up next, which is added when it has none."""
    lines = text.splitlines()
    heads, fence = [], False
    for n, l in enumerate(lines):
        if l.lstrip().startswith("```"):
            fence = not fence
        elif not fence and re.match(r"##\s+(.+?)\s*$", l):
            heads.append(n)
    at = next((n for n in heads if lines[n][2:].strip().lower() == UP_NEXT.lower()), None)
    if at is None:
        return "\n".join(trimmed(lines) + ["", f"## {UP_NEXT}", *items]).lstrip("\n") + "\n"
    end = next((n for n in heads if n > at), len(lines))
    while end > at + 1 and not lines[end - 1].strip():
        end -= 1
    return "\n".join(lines[:end] + items + lines[end:]) + "\n"


def cmd_sweep(root: Path, apply: bool) -> int:
    """`jig update --sweep`: each page's ## Undefined entries to Up next items, on the owner's
    yes. The roadmap is written on trunk (R5); the pages wherever they may change, which in a
    metarepo is a job (M4), so there the sweep is two runs: trunk first, then the job."""
    if not (root / CONFIG).exists():
        die("run `jig update --apply` first: the sweep runs on the current layout", 2)
    trunk = Board.trunk_name(root)
    on_trunk_now = git("branch", "--show-current") == trunk
    roadmap = at_rev(trunk, ROADMAP)
    found = undefined_sweep(root, tracked(root), roadmap)
    if not found:
        print("no ## Undefined section on any page: nothing to sweep")
        return 0
    new = [i for s in found for i in s["items"] if not i["there"]]
    movable = [s for s in found if not s["prose"]]
    pages_here = not ((root / META).exists() and on_trunk_now)
    for s in found:
        print(f"{s['page']}: ## Undefined" + (", kept: it holds text besides its entries, to move by hand"
                                               if s["prose"] else ", removed" if pages_here else ""))
        for i in s["items"]:
            print(f"  → {ROADMAP} ## {UP_NEXT}: {i['line']}" + ("  (already there)" if i["there"] else ""))
    job = (f"open a job for the pages on {trunk} (`jig open project-sweep --shares "
           f"{' '.join(dict.fromkeys(s['page'] for s in movable))}`), and run `jig update --apply --sweep` in its "
           "worktree: it removes the sections whose entries the roadmap holds")
    if not apply:
        print("\nDry run: nothing changed. On the owner's yes: jig update --apply --sweep"
              + (f" on {trunk}" if new and not on_trunk_now else "")
              + ("" if pages_here else f"; then, in a metarepo, the pages are a job's (M4): {job}"))
        return 0
    if git("status", "--porcelain", "--untracked-files=no"):
        die("commit or stash tracked changes first: the sweep edits pages by name", 2)
    if new and not on_trunk_now:
        die(f"{ROADMAP} is edited on {trunk} only (R5): run `jig update --apply --sweep` there "
            "first; it writes the items, then this run removes the sections", 2)
    written = []
    if new:
        if not roadmap and (root / ROADMAP_VIEW).is_file():
            die(f"{ROADMAP_VIEW} is the repo's own, and with {ROADMAP} it would be jig's generated "
                f"view: move what it holds into {ROADMAP} first (`jig update` lists it)", 2)
        text = roadmap or "# Roadmap\n"
        (root / ROADMAP).write_text(with_up_next(text, [i["line"] for i in new]))
        written.append(ROADMAP)
    if pages_here:
        # Every span is a line range of the page as read, so a page's sections go in one write.
        spans: dict[str, list[tuple[int, int]]] = {}
        for s in movable:
            spans.setdefault(s["page"], []).append(s["span"])
        for page, ss in spans.items():
            (root / page).write_text(without_sections((root / page).read_text(errors="replace"), ss))
            written.append(page)
    if written:
        git("add", "--", *written, check=True)
    print(f"\nWritten {', '.join(written) or 'nothing'}. Staged, nothing committed: commit it here"
          + (f"; `jig roadmap --write` regenerates {ROADMAP_VIEW}" if ROADMAP in written else "")
          + ("" if pages_here else f". The pages are a job's in a metarepo (M4): {job}") + ".")
    return 0


def update_blocked(why: list[str]) -> int:
    print("blocked: the repo would not work after an update, so nothing was changed", file=sys.stderr)
    for w in why:
        print(f"  {w}", file=sys.stderr)
    print("The fix is a change to jig that recognizes this layout (a LAYOUT row, a board "
          "default, or a STEP).", file=sys.stderr)
    return 2


# ----------------------------------------------------------------------- main

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="jig", description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    i = sub.add_parser("init", help="create the board and install hooks")
    i.add_argument("--trunk", default="main")
    i.add_argument("--replace", action="store_true", help="see install-hooks --replace")
    i.add_argument("--no-hooks", action="store_true",
                   help="write the board only; a predecessor's hooks keep running")
    i.add_argument("--meta", action="store_true",
                   help="make this repo a metarepo: docs only, released by tag")
    i.add_argument("--name", help="with --meta: the metarepo's name (default: the folder)")
    i.add_argument("--prefix", help="with --meta: decision id prefix (default D-)")
    i.add_argument("--genres", help="with --meta: the folders under docs/ its pages sit in, a,b,c, "
                   f"or a template: {', '.join(GENRE_TEMPLATES)}")
    i.add_argument("--para", metavar="METAREPO", nargs="?", const="",
                   help="cite this metarepo at a released tag; alone, regenerate from para.json")
    i.add_argument("--location", help="with --para: the metarepo's checkout, recorded in repos.json")
    i.add_argument("--pin", help="with --para: the release to cite (default: the latest)")
    i.add_argument("--contract", nargs="*", help="with --para: globs whose changes need a metarepo proposal")
    ih = sub.add_parser("install-hooks", help="(re)write the git hooks")
    ih.add_argument("--replace", action="store_true",
                    help="remove a predecessor's hooks instead of chaining them as .local")
    sub.add_parser("status", help="jobs, states, how far behind trunk")

    o = sub.add_parser("open", help="hubnode: open a job")
    o.add_argument("name")
    o.add_argument("--spec", default="", help="the job's spec: a path, or a line")
    o.add_argument("--branch")
    o.add_argument("--owns", nargs="*")
    o.add_argument("--shares", nargs="*")
    o.add_argument("--after", nargs="*")
    o.add_argument("--reserve", nargs="*",
                   help="counter names to allocate (schema), or name=value a branch already holds")
    o.add_argument("--worktree", help="adopting: where the branch is already checked out")
    o.add_argument("--state", choices=STATES, help="adopting: its state (default building)")

    rs = sub.add_parser("reserve", help="hubnode: give an open job another number of a counter")
    rs.add_argument("name")
    rs.add_argument("counter")
    m = sub.add_parser("mark", help="hubnode: set a job's state")
    m.add_argument("name")
    m.add_argument("state")
    mg = sub.add_parser("merge", help="hubnode: merge a job and delete its entry in that commit")
    mg.add_argument("name", nargs="?")
    mg.add_argument("--number", action="store_true", help="in a merge in progress, its conflicts resolved: number the D-?<slug> ids it brings in")
    mg.add_argument("-m", "--message", help="appended to the merge commit: what shared files it touched")
    mg.add_argument("--subject", help="the ids the subject leads with, e.g. `D-001, D-002`; `: merge <job>` is added unless it's already there")
    c = sub.add_parser("check", help="run the rules here")
    c.add_argument("--staged", action="store_true")
    sub.add_parser("job", help="print this branch's manifest")
    dc = sub.add_parser("decision", help="print a decision entry and its supersedes chain")
    dc.add_argument("id")
    dc.add_argument("--peers", action="store_true", help="the live entries touching the same pages, here and across the metarepo")
    sub.add_parser("sync", help="bring in the upstream: trunk on a job; the metarepo on a pararepo's trunk")
    rv = sub.add_parser("reviewed", help="record that HEAD has had its review")
    rv.add_argument("--tier", type=int, help="the model tier the review ran at")
    rv.add_argument("--effort", type=int, help="the effort it ran at")
    rv.add_argument("--ran", help="what it ran on, in the tool's own words")
    sub.add_parser("workflow", help="the steps in effect: each one's model tier and effort")
    h = sub.add_parser("handoff", help="write the handoff note for HEAD")
    h.add_argument("--spec", help="path to the spec this delivers")
    h.add_argument("--partial", action="store_true",
                   help="this chunk doesn't finish its spec: the roadmap keeps it taken")
    rm = sub.add_parser("roadmap", help="the roadmap's phases and scopes, and their states on trunk")
    rm.add_argument("--write", action="store_true", help=f"regenerate {ROADMAP_VIEW} in the trunk checkout")
    rl = sub.add_parser("reading-list", help="what to read before touching these files")
    rl.add_argument("paths", nargs="+")
    g = sub.add_parser("gate", help="verify a job (or this branch) is mergeable")
    g.add_argument("name", nargs="?")
    sv = sub.add_parser("survey", help="inventory the repo against the jig shape")
    sv.add_argument("--json", action="store_true")
    rl_ = sub.add_parser("release", help="run this repo's release protocol, then tag vX.Y.Z")
    bump = rl_.add_mutually_exclusive_group()
    bump.add_argument("--major", action="store_true", help="in a metarepo: a rename or a reversed decision")
    bump.add_argument("--minor", action="store_true")
    bump.add_argument("--patch", action="store_true", help="the default, except in a metarepo")
    bump.add_argument("--version", help="X.Y.Z: the first release, or a jump")
    rl_.add_argument("--force", action="store_true", help="release though files are staged")
    pp = sub.add_parser("propose", help="pararepo: open a proposal branch on the metarepo for a spec")
    pp.add_argument("spec", nargs="?")
    pp.add_argument("slug", nargs="?")
    pp.add_argument("--buffer", action="store_true", help="every Open row of the sync buffer, in one proposal")
    pp.add_argument("--pointers", action="store_true",
                    help="record it as pointer rewrites worked ahead of, not a proposal to wait for")
    st = sub.add_parser("staging", help="list staged files, resolve or drop one, or check headers")
    st.add_argument("action", nargs="?", choices=["resolve", "drop", "check"])
    st.add_argument("file", nargs="*")
    rp = sub.add_parser("repos", help="list, or add to, where your repos live (user config)")
    rp.add_argument("action", nargs="?", choices=["add", "rename"])
    rp.add_argument("kind", nargs="?", help="add: repo, meta or para; rename: the new name")
    rp.add_argument("path", nargs="?", help="add: the checkout (default: this one)")
    rp.add_argument("--name", help="add: the name to call it by (default: its own)")
    up = sub.add_parser("update", help="bring this repo to the current jig layout (dry run)")
    up.add_argument("--apply", action="store_true", help="make the changes the dry run lists")
    up.add_argument("--merge-log", action="store_true", help=f"on the owner's yes: merge CHANGELOG.md and the decision register into {LOG}")
    up.add_argument("--sweep", action="store_true", help=f"on the owner's yes: move pages' ## Undefined entries to {UP_NEXT} in {ROADMAP}")
    hk = sub.add_parser("hook")
    hk.add_argument("name")
    hk.add_argument("rest", nargs="*")

    args = ap.parse_args(argv)
    if args.cmd == "repos":
        return cmd_repos(Path.cwd(), args)   # user config only: works outside any repo
    if args.cmd == "staging" and args.action == "check":
        return cmd_staging_check(args)       # headers only: runs outside any repo
    if args.cmd == "staging":
        if len(args.file) > 1:
            die(f"one file at a time: jig staging {args.action} <file>", 2)
        args.file = args.file[0] if args.file else None
    root = repo_root()
    # Every command that reads the docs tree reads it in the repo's own layout.
    load_genres(root)
    fn = {
        "init": cmd_init, "install-hooks": cmd_install_hooks, "status": cmd_status,
        "open": cmd_open, "reserve": cmd_reserve, "mark": cmd_mark, "merge": cmd_merge, "check": cmd_check, "decision": cmd_decision,
        "job": cmd_job, "sync": cmd_sync, "reviewed": cmd_reviewed,
        "handoff": cmd_handoff, "gate": cmd_gate, "hook": cmd_hook,
        "workflow": cmd_workflow,
        "survey": cmd_survey, "reading-list": cmd_reading_list, "update": cmd_update, "repos": cmd_repos, "staging": cmd_staging,
        "release": cmd_release, "propose": cmd_propose, "roadmap": cmd_roadmap,
    }[args.cmd]
    return fn(root, args)


if __name__ == "__main__":
    sys.exit(main())
