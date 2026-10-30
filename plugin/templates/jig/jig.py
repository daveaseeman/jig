#!/usr/bin/env python3
"""jig - parallel lanes on one repository.

Git hooks execute TRUNK's copy of this file, so a branch cannot weaken the
rules it is judged by. Stdlib only.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

DIR = ".jig"
BOARD = f"{DIR}/lanes.json"
WORKAROUNDS = f"{DIR}/ledgers/WORKAROUNDS.md"
DEFERRED = f"{DIR}/ledgers/DEFERRED.md"
STATES = ["claimed", "building", "ready", "gated", "merged", "parked"]
# The layout this copy of jig writes into the board's "version". Any change that adds a
# LAYOUT row, a board default or an update STEP bumps it. Nothing branches on it except
# update's refusal to take a newer repo back to an older jig.
STAMP = 6
BOARD_DEFAULTS = {
    "version": STAMP,
    "name": "",            # init and update fill it with the folder name; staging's targets match it
    "trunk": "main",
    "common": ["AGENTS.md", "docs/**", f"{DIR}/**"],
    "append_files": ["AGENTS.md", f"{DIR}/ledgers/**", "CHANGELOG.md"],
    "reserve": {},
    "docmap": {},
    "payload": [],
    "lanes": {},
    "log": [],
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
    """Where lanes are checked out, relative to the primary checkout. Inside .git/ because
    a worktree is git state, and tools that walk the repo (test runners, globbers) never
    look there — a visible folder would hand them every lane's full copy of the repo."""
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
    def __init__(self, root: Path, data: dict, path: Path):
        self.root, self.data, self.path = root, data, path

    @classmethod
    def load(cls, root: Path, *, working_tree: bool = False) -> "Board":
        """Read the board from TRUNK by default, so a branch cannot edit the rules
        it is judged by. working_tree=True is for the hubnode, who writes it."""
        path = main_root() / BOARD
        if not working_tree:
            raw = git("show", f"{cls.trunk_name(main_root())}:{BOARD}")
            if raw:
                return cls(main_root(), json.loads(raw), path)
        if not path.exists():
            die(f"no board at {BOARD}. Run: jig init", 2)
        return cls(main_root(), json.loads(path.read_text()), path)

    @staticmethod
    def trunk_name(root: Path) -> str:
        p = root / BOARD
        if p.exists():
            try:
                return json.loads(p.read_text()).get("trunk", "main")
            except Exception:
                pass
        return "main"

    def save(self) -> None:
        self.path.write_text(json.dumps(self.data, indent=2) + "\n")

    @property
    def trunk(self) -> str:
        return self.data.get("trunk", "main")

    @property
    def lanes(self) -> dict:
        return self.data.setdefault("lanes", {})

    def open_lanes(self) -> dict:
        return {n: l for n, l in self.lanes.items() if l.get("state") != "merged"}

    def lane_for_branch(self, branch: str) -> tuple[str, dict] | tuple[None, None]:
        for name, lane in self.lanes.items():
            if lane.get("branch") == branch:
                return name, lane
        return None, None

    def log(self, line: str) -> None:
        self.data.setdefault("log", []).append(f"{date.today().isoformat()}: {line}")


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


def changed_paths(trunk: str, staged: bool) -> list[str]:
    args = ["diff", "--name-only", "--diff-filter=ACMRT", base(trunk)]
    args += ["--cached"] if staged else []
    return [p for p in git(*args).splitlines() if p]


def at_rev(rev: str, path: str) -> str:
    return git("show", f"{rev}:{path}")


def in_index(path: str, staged: bool) -> str:
    if not staged:
        return (Path(path).read_text(errors="replace") if Path(path).exists() else "")
    return git("show", f":{path}")


def existed_on_trunk(trunk: str, path: str) -> bool:
    return bool(git("ls-tree", "-r", "--name-only", trunk, "--", path))


def check_rules(root: Path, board: Board, *, staged: bool) -> list[str]:
    """Return a list of refusals. Empty means pass."""
    out: list[str] = []
    branch = git("branch", "--show-current")
    trunk = board.trunk
    name, lane = board.lane_for_branch(branch)
    paths = changed_paths(trunk, staged)
    meta = load_meta(trunk)
    if meta is not None:
        out += meta_rules(root, board, meta, staged)
    para = load_para(trunk)
    if para is not None:
        out += para_rules(root, board, para, staged)

    # R1 the trunk checkout stays on trunk (only when lanes are open: solo, one checkout
    # with a feature branch is normal and nobody else's tree is being moved)
    if board.open_lanes() and is_main_worktree(root) and branch and branch != trunk:
        out.append(
            f"R1 the {trunk} checkout stays on {trunk}; it is on {branch}. "
            f"Work in a worktree: {worktrees_dir()}/{branch}"
        )

    # R5 the board is the hubnode's
    if BOARD in paths and branch != trunk:
        out.append(f"R5 the board is the hubnode's: {BOARD} is edited on {trunk} only")

    # R7 a workaround needs its ledger row — lane or not; code only, prose may quote it. Only
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

    # R6 on a lane branch always; on trunk only while lanes are open, since solo
    # there is nobody to collide with and the numbers are yours
    if lane is not None or board.open_lanes():
        out += reserved_refusals(root, board, lane, name, staged)

    if lane is None:
        if branch and branch != trunk and board.open_lanes():
            out.append(
                f"R2 branch {branch} is on no lane. Ask the hubnode to open one, "
                f"or work on {trunk}"
            )
        return out

    # R2 a lane is built in its worktree
    wt = lane.get("worktree")
    if wt:
        expect = (main_root() / wt).resolve()
        here = Path(git("rev-parse", "--show-toplevel")).resolve()
        if expect.exists() and here != expect:
            out.append(f"R2 lane {name} is built in {wt}, not here")

    common = board.data.get("common", [])
    owns, shares = lane.get("owns", []), lane.get("shares", [])
    others = {n: l for n, l in board.open_lanes().items() if n != name}

    for p in paths:
        if p.startswith(f"{DIR}/handoffs/"):
            continue
        # R4 another open lane's owns wins, even over this lane's lists
        for on, ol in others.items():
            if matches(p, ol.get("owns", [])):
                out.append(f"R4 {p} is owned by lane {on}: ask the hubnode before touching it")
                break
        else:
            # R3 only this lane's files, or a file new to the repository
            if matches(p, owns) or matches(p, shares) or matches(p, common):
                continue
            if not existed_on_trunk(trunk, p):
                continue
            out.append(f"R3 {p} is not lane {name}'s: ask the hubnode to add it to shares")

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


def reserved_refusals(root: Path, board: "Board", lane: dict | None,
                      name: str | None, staged: bool) -> list[str]:
    """R6. A scarce number (migration step, section number) belongs to one lane.
    A number is taken when the branch makes it exist where the base did not: the
    pattern's matches are counted per file at the base and in the index, and only a
    count that rose is a take. Editing or moving a heading nets to zero."""
    out: list[str] = []
    trunk = board.trunk
    for counter, spec in (board.data.get("reserve") or {}).items():
        if not isinstance(spec, dict) or not spec.get("pattern"):
            continue                      # allocation only; nothing to enforce against
        pat = re.compile(spec["pattern"], re.M)
        globs = spec.get("files") or ["**"]
        held = (lane or {}).get("reserved", {}).get(counter)
        before: dict[str, int] = {}
        after: dict[str, int] = {}
        touched = git("diff", "--name-only", "--no-renames", base(trunk),
                      *(["--cached"] if staged else [])).splitlines()
        files = [p for p in touched if p and matches(p, globs)]
        for p in files:
            for m in pat.finditer(at_rev(base(trunk), p)):
                before[m.group(1)] = before.get(m.group(1), 0) + 1
            for m in pat.finditer(in_index(p, staged)):
                after[m.group(1)] = after.get(m.group(1), 0) + 1
        for got in sorted(after):
            if after[got] <= before.get(got, 0):
                continue
            if held is None:
                out.append(f"R6 this change takes {counter} {got}, but this branch holds no "
                           f"{counter}: ask the hubnode to reserve one")
            elif str(held) != got:
                out.append(f"R6 this change takes {counter} {got}, but lane {name} holds "
                           f"{counter} {held}")
    return out


def cmd_init(root: Path, args) -> int:
    (root / DIR).mkdir(exist_ok=True)
    ensure_staging(root)
    path = root / BOARD
    if path.exists():
        print(f"{BOARD} already exists")
    else:
        data = json.loads(json.dumps(BOARD_DEFAULTS))
        data["trunk"] = args.trunk
        data["name"] = main_root().name
        path.write_text(json.dumps(data, indent=2) + "\n")
        print(f"wrote {BOARD}")
    if getattr(args, "no_hooks", False):
        print("hooks not installed (--no-hooks). Run `jig install-hooks` to cut over.")
        return 0
    return cmd_install_hooks(root, args)


HOOK = """#!/bin/sh
# jig hook ({dir}/jig.py). Delete to disable; `jig install-hooks` rewrites it.
# Runs TRUNK's copy of the checker, so a branch cannot weaken its own rules.
[ -x "$0.local" ] && {{ "$0.local" "$@" || exit $?; }}
copy=$(mktemp "${{TMPDIR:-/tmp}}/jig.XXXXXX") || exit 0
git show {trunk}:{dir}/jig.py > "$copy" 2>/dev/null || {{ rm -f "$copy"; exit 0; }}
python3 "$copy" hook {name} "$@"
status=$?
rm -f "$copy"
exit $status
"""


HOOKS = ("pre-commit", "pre-merge-commit", "pre-push", "post-checkout", "post-merge",
         "commit-msg")
# ai-dev was jig under its old name; its hooks are ours to rewrite, not a predecessor's to keep.
HOOK_MARKERS = ("# jig hook", "# aidev hook")


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
    # A pararepo's cache of the pinned metarepo docs is gitignored, so a new worktree has none.
    cache, main_cache = root / CACHE, main_root() / CACHE
    if (root / PARA).exists() and not cache.exists() and main_cache.exists() and cache != main_cache:
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
        if board.open_lanes() and is_main_worktree(root):
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
        problems = meta_problems(root, meta, board.trunk) if meta else []
        # The refs git is pushing arrive on stdin; trunk is refused by where it lands, not by
        # which branch happens to be checked out (`git push origin feat:main`).
        pushed = [l.split()[2] for l in sys.stdin.read().splitlines() if len(l.split()) == 4]
        if f"refs/heads/{board.trunk}" in pushed:
            problems += staged_refusal(f"pushing {board.trunk}")
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
    if not board.lanes:
        print("no lanes open")
        return 0
    print(f"trunk: {trunk}")
    for name, l in board.lanes.items():
        if l.get("state") == "merged" and not args.all:
            continue
        br = l.get("branch", name)
        behind = git("rev-list", "--count", f"{br}..{trunk}") or "?"
        wt = root / l.get("worktree", "")
        dirty = ""
        if wt.exists():
            dirty = " dirty" if git("status", "--porcelain", cwd=str(wt)) else " clean"
        hs = l.get("handoffs", [])
        print(f"  {name:<20} {l.get('state',''):<9} behind:{behind}{dirty}"
              f"  handoffs:{len(hs)}  after:{','.join(l.get('after',[])) or '-'}")
    for k, v in (board.data.get("reserve") or {}).items():
        nxt = (v.get("next", 0) if isinstance(v, dict) else v) + 1
        guard = "" if (isinstance(v, dict) and v.get("pattern")) else "  (not enforced)"
        print(f"reserve {k}: next free {nxt}{guard}")
    return 0


def cmd_open(root: Path, args) -> int:
    board = Board.load(root, working_tree=True)
    if git("branch", "--show-current") != board.trunk:
        die(f"open a lane from {board.trunk} (the hubnode's checkout)")
    if args.name in board.lanes:
        die(f"lane {args.name} already exists")
    branch = args.branch or args.name
    owns = args.owns or []
    # R4 pre-check: a file another open lane already changed is shared, never owned
    conflicts = []
    for p in owns:
        for on, ol in board.open_lanes().items():
            changed = git("diff", "--name-only", f"{board.trunk}...{ol.get('branch', on)}").splitlines()
            if any(matches(c, [p]) for c in changed):
                conflicts.append(f"{p} (changed by open lane {on})")
    if conflicts:
        die("these cannot be owns; put them in shares:\n  " + "\n  ".join(conflicts))

    existing = bool(git("rev-parse", "--verify", "-q", f"refs/heads/{branch}"))
    reserve = {}
    for kv in args.reserve or []:
        k, _, explicit = kv.partition("=")
        counters = board.data.setdefault("reserve", {})
        entry = counters.get(k, {})
        if isinstance(entry, int):
            entry = {"next": entry}
        if explicit:
            # adopting a branch that already holds this number: record it, and make
            # sure the counter never hands it out again
            val = int(explicit)
            entry["next"] = max(int(entry.get("next", 0)), val)
        else:
            seen = highest_on_trunk(board, k, entry)
            val = max(int(entry.get("next", 0)), seen) + 1
            entry["next"] = val
        counters[k] = entry
        reserve[k] = val
        if not entry.get("pattern"):
            print(f"note: counter '{k}' allocates but does not enforce. Add \"pattern\" and "
                  f"\"files\" to reserve.{k} in {BOARD} so the hook refuses a lane that takes "
                  f"a number it does not hold.")

    worktree = args.worktree or f"{worktrees_dir()}/{branch}"
    state = args.state or ("building" if existing else "claimed")
    board.lanes[args.name] = {
        "brief": args.brief or "",
        "branch": branch,
        "worktree": worktree,
        "state": state,
        "after": args.after or [],
        "owns": owns,
        "shares": args.shares or [],
        "reserved": reserve,
        "opened": date.today().isoformat(),
        "handoffs": [],
    }
    board.log(f"{'adopted' if existing else 'opened'} {args.name} (branch {branch})")
    board.save()

    if not (root / worktree).exists():
        if existing:
            if git("worktree", "list", "--porcelain").find(f"refs/heads/{branch}") >= 0:
                die(f"branch {branch} is checked out somewhere already: pass --worktree <path>")
            add = ["worktree", "add", worktree, branch]
        else:
            add = ["worktree", "add", "-b", branch, worktree, board.trunk]
        # stderr passes through: the post-checkout hook sets the worktree up, and what
        # setup.sh printed, or why it failed, belongs in front of whoever opened the lane.
        subprocess.run(["git", *add], stdout=subprocess.DEVNULL)
    verb = "adopted" if existing else "opened"
    print(f"lane {args.name} {verb}. worktree: {worktree}  state: {state}")
    if reserve:
        print("reserved: " + ", ".join(f"{k}={v}" for k, v in reserve.items()))
    print(f"\n--- kickoff ---\nLane: {args.name}\nBranch: {branch}\nWorktree: {worktree}\n"
          f"Brief: {args.brief or '(see board)'}\n"
          f"Owns: {', '.join(owns) or '-'}\nShares: {', '.join(args.shares or []) or '-'}\n"
          f"Read {DIR}/RULES.md, then `python3 {DIR}/jig.py check`.")
    return 0


def cmd_mark(root: Path, args) -> int:
    board = Board.load(root, working_tree=True)
    if args.name not in board.lanes:
        die(f"no lane {args.name}")
    if args.state not in STATES:
        die(f"state must be one of {', '.join(STATES)}")
    board.lanes[args.name]["state"] = args.state
    board.log(f"{args.name} -> {args.state}")
    board.save()
    print(f"{args.name}: {args.state}")
    return 0


def cmd_log(root: Path, args) -> int:
    board = Board.load(root, working_tree=True)
    if args.message:
        board.log(args.message)
        board.save()
    for line in board.data.get("log", [])[-args.n:]:
        print(line)
    return 0


def cmd_check(root: Path, args) -> int:
    board = Board.load(root)
    refusals = check_rules(root, board, staged=args.staged)
    for r in refusals:
        print(r)
    if not refusals:
        print("ok")
    return 1 if refusals else 0


def cmd_lane(root: Path, args) -> int:
    board = Board.load(root)
    name, lane = board.lane_for_branch(git("branch", "--show-current"))
    if not name:
        print("no lane for this branch")
        return 1
    print(json.dumps({name: lane}, indent=2))
    return 0


# --------------------------------------------------------------- sync + merge

CONFLICT = re.compile(
    r"^<<<<<<< .*?\n(?P<ours>.*?)^\|\|\|\|\|\|\| .*?\n(?P<base>.*?)^=======\n"
    r"(?P<theirs>.*?)^>>>>>>> .*?\n",
    re.S | re.M,
)


def resolve_appends(path: Path) -> bool:
    """Resolve conflicts where both sides only added at the same spot. True if clean."""
    text = path.read_text()
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
    path.write_text("".join(out))
    return ok


def cmd_sync(root: Path, args) -> int:
    board = Board.load(root)
    trunk = board.trunk
    name, lane = board.lane_for_branch(git("branch", "--show-current"))
    if not name:
        die("not on a lane branch")
    if git("status", "--porcelain"):
        die("commit or stash first: the tree is dirty")
    p = subprocess.run(["git", "-c", "merge.conflictStyle=diff3", "merge", trunk],
                       stdout=subprocess.PIPE, text=True)
    if p.returncode == 0:
        print(f"merged {trunk}; nothing to resolve")
        return 0
    conflicted = git("diff", "--name-only", "--diff-filter=U").splitlines()
    append_files = board.data.get("append_files", [])
    stuck = []
    for f in conflicted:
        if matches(f, append_files) and resolve_appends(root / f):
            git("add", "--", f)
        else:
            stuck.append(f)
    if stuck:
        print(f"resolve by hand, then `git commit` and `./{DIR}/scripts/setup.sh`:", file=sys.stderr)
        for f in stuck:
            print(f"  {f}", file=sys.stderr)
        return 1
    git("commit", "--no-edit", check=True)
    # git runs post-merge only for a merge it finished itself, not this one.
    run_setup(root)
    print(f"merged {trunk}; append conflicts resolved automatically")
    return 0


# ---------------------------------------------------------- review + handoff

def review_marker(root: Path) -> Path:
    common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
    d = common / "jig" / "reviewed"
    d.mkdir(parents=True, exist_ok=True)
    return d / (git("branch", "--show-current") or "detached").replace("/", "%")


def cmd_reviewed(root: Path, args) -> int:
    """Record that HEAD has had its adversarial review. Called by the review skill."""
    head = git("rev-parse", "HEAD")
    review_marker(root).write_text(head + "\n")
    # Every review ever, for a metarepo's gate: a merge's second parent must be one of them.
    with open(git_common() / "jig" / "reviewed.log", "a") as log:
        log.write(head + "\n")
    print(f"recorded review of {head[:12]}")
    return 0


NOTE = """# Handoff: {lane}

Commit: {head}
Date: {today}
Spec: {spec}

## Built
<!-- what this delivers, in a few lines -->

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->

## Review
<!-- findings from the adversarial review, and what you did about each -->

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
{foldin}

## Shared files changed
<!-- each shared/common file, and why this lane had to touch it -->

## Test by hand
<!-- what a person should click or watch -->

## Left
<!-- what remains on this lane -->
"""


def foldin_lines(root: Path, board: Board, branch: str) -> str:
    """One line per documentation page covering the code this branch changed."""
    trunk = board.trunk
    rng = f"{trunk}...HEAD" if branch and branch != trunk else "HEAD~1..HEAD"
    changed = [f for f in git("diff", "--name-only", rng).splitlines()
               if f and not f.startswith((".", f"{DIR}/"))]
    # A file docmap names is asked about whatever its type (sdkconfig, a devicetree
    # overlay); only source files are flagged when no page covers them.
    pages, unowned = {}, []
    for f in changed:
        owners = doc_owners(board, f)
        for page in owners:
            pages.setdefault(page, []).append(f)
        if not owners and f.endswith(SRC_EXT):
            unowned.append(f)
    if not pages and not unowned:
        return "- [ ] no code changed — nothing to fold in"
    out = [f"- [ ] {page} — updated / no change because ___   ({len(fs)} file"
           f"{'s' if len(fs) > 1 else ''})" for page, fs in sorted(pages.items())]
    out += [f"- [ ] UNOWNED {f} — add to docmap, or no page needed because ___"
            for f in sorted(unowned)]
    return "\n".join(out)


def cmd_handoff(root: Path, args) -> int:
    board = Board.load(root)
    branch = git("branch", "--show-current")
    name, lane = board.lane_for_branch(branch)
    if not name:
        name = branch or "work"          # solo: no lane, the branch is the unit
    if git("status", "--porcelain"):
        die("commit everything first: a handoff names one commit")
    head = git("rev-parse", "HEAD")
    marker = review_marker(root)
    seen = marker.read_text().strip() if marker.exists() else ""
    if seen != head:
        die("no adversarial review on record for this commit.\n"
            f"  Review {head[:12]}, then: python3 {DIR}/jig.py reviewed")
    (root / DIR / "handoffs").mkdir(parents=True, exist_ok=True)
    path = root / DIR / "handoffs" / f"{name}-{date.today().isoformat()}.md"
    i = 2
    while path.exists():
        path = root / DIR / "handoffs" / f"{name}-{date.today().isoformat()}-{i}.md"
        i += 1
    path.write_text(NOTE.format(lane=name, head=head, today=date.today().isoformat(),
                                spec=args.spec or "(none)",
                                foldin=foldin_lines(root, board, branch)))
    print(f"wrote {path.relative_to(root)}")
    if lane is not None:
        print("Fill every heading, commit it, then tell the hubnode the lane and the commit.")
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
            owners = [p for p in doc_owners(board, f) if (root / p).exists()]
            want += [p for p in owners if p not in want]
            if not owners and f.endswith(SRC_EXT):
                unowned.append(f)
    print("Read first:")
    for core in ("AGENTS.md", f"{DIR}/RULES.md"):
        if (root / core).exists():
            print(f"  {core}")
    for page in want:
        print(f"  {page}")
    if not want:
        print("  (no documentation page covers these files)")
    if unowned:
        print("\nNot covered by any page — the work may be undocumented:")
        for f in sorted(set(unowned)):
            print(f"  {f}")
    return 0


def cmd_gate(root: Path, args) -> int:
    """Hubnode-side verification. Prints what to run; refuses what it can decide."""
    board = Board.load(root, working_tree=True)
    trunk = board.trunk
    name = args.name or git("branch", "--show-current") or trunk
    lane = board.lanes.get(name)
    if args.name and lane is None:
        die(f"no lane {args.name}")
    bad = []
    if not args.force:
        bad += staged_refusal("the merge")
    elif staged_files(main_root()) and lane is not None:
        board.log(f"gate {name} forced with {len(staged_files(main_root()))} staged files")
        board.save()
    for dep in (lane or {}).get("after", []):
        if board.lanes.get(dep, {}).get("state") != "merged":
            bad.append(f"R8 lane {name} builds after {dep}, which has not merged")
    branch = (lane or {}).get("branch", name)
    listing = git("ls-tree", "-r", "--name-only", branch, "--", f"{DIR}/handoffs/")
    notes = sorted(n for n in listing.splitlines()
                   if Path(n).name.startswith(f"{name}-") and n.endswith(".md"))
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
        if open_lines:
            print(f"the fold-in in {note} is unanswered:", file=sys.stderr)
            for l in open_lines[:10]:
                print(f"  {l.strip()}", file=sys.stderr)
            return 1
    m = re.search(r"^Commit: (\w+)", body, re.M)
    commit = m.group(1) if m else branch
    label = f"lane {name}" if lane is not None else name
    print(f"{label}: gate {commit[:12]} from {note} on {branch}")
    print("Run the project checks against that exact commit, in a scratch checkout —")
    print("not the working tree, which may already have moved on:\n")
    scratch = f"{worktrees_dir()}/gate-{name}"
    print(f"  git worktree add --detach {scratch} {commit}")
    print(f"  cd {scratch} && git merge {trunk} && ./{DIR}/scripts/check.sh")
    print(f"  cd - && git worktree remove {scratch}\n")
    if lane is not None:
        print(f"Then: jig mark {name} gated")
    else:
        print("Then merge it. (No lane: solo work, so there is no board state to mark.)")
    return 0



# --------------------------------------------------------------------- survey

HOMES = {
    "AGENTS.md": "rules, always loaded",
    "CLAUDE.md": "pointer to AGENTS.md",
    "README.md": "for people outside",
}
BOARD_PAGES = "docs/hardware/"
HOME_DIRS = {
    "docs/": f"what the code is now; docs/<system>/<system>.md each system, {BOARD_PAGES}<board>.md each board",
    f"{DIR}/specs/": "a task in flight",
    f"{DIR}/ledgers/": "WORKAROUNDS.md patches that are in the code; DEFERRED.md review findings that are not",
    f"{DIR}/staging/": "chat-born files waiting to be resolved (untracked)",
    f"{DIR}/": "everything jig makes: checker, rulebook, board, scripts, handoffs",
    ".claude/skills/": "reusable know-how",
}
# Tooling directories. Their contents are a tool's own records, not documents
# looking for a home, so the stray check skips them entirely.
TOOL_DIRS = (".claude/", ".github/", ".gitlab/", ".vscode/", ".devcontainer/")
SRC_EXT = (".c", ".h", ".cpp", ".ino", ".rs", ".ts", ".tsx", ".js", ".jsx", ".py", ".go", ".swift")
CODE_EXT = SRC_EXT + (".sh", ".cmake", ".kconfig")


def tracked(root: Path) -> list[str]:
    return [p for p in git("ls-files").splitlines() if p]


def inbound(root: Path, path: str, files: list[str]) -> int:
    """How many other tracked files mention this one by name."""
    base = Path(path).name
    hits = git("grep", "-l", "-F", "--", base)
    return len([h for h in hits.splitlines() if h and h != path])


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
    ("changelog", "the board log", ["CHANGELOG.md", "CHANGES.md", "HISTORY.md"]),
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
        if f.endswith(".json") and f.startswith(".") and "/" in f and f != BOARD:
            try:
                txt = (root / f).read_text(errors="replace")
            except OSError:
                continue
            if '"owns"' in txt or '"shares"' in txt or '"lanes"' in txt:
                out.append(f)
    return out


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
    payload = board.get("payload") or []
    report: dict = {"markdown": [], "homeless": [], "oversized": [], "present": {},
                    "src_count": len(src), "payload": payload,
                    # "docs-src/" reads like a directory but matches nothing; say so, or
                    # the files it meant to cover are back on the homeless list unexplained.
                    "payload_unmatched": [g for g in payload
                                          if not any(matches(f, [g]) for f in files)]}

    for f in md:
        raw = (root / f).read_text(errors="replace").splitlines() if (root / f).exists() else []
        n = len([l for l in raw
                 if l.strip() and not l.lstrip().startswith(("#", "<!--", "-->", "|"))])
        last = git("log", "-1", "--format=%ad", "--date=short", "--", f)
        entry = {"path": f, "lines": n, "last_commit": last, "inbound": inbound(root, f, files)}
        report["markdown"].append(entry)
        at_home = (f in HOMES or any(f.startswith(d) for d in HOME_DIRS)
                   or f.startswith(TOOL_DIRS) or matches(f, payload))
        if not at_home:
            report["homeless"].append(entry)
        if f in ("AGENTS.md", "CLAUDE.md") and n > 40:  # rule lines, not raw lines
            report["oversized"].append(entry)

    # The spec template and the ledgers are made on first use, so their absence is no gap.
    for name in ("AGENTS.md", "CLAUDE.md", f"{DIR}/scripts/check.sh", f"{DIR}/scripts/setup.sh",
                 f"{DIR}/jig.py", f"{DIR}/RULES.md", BOARD):
        report["present"][name] = (root / name).exists()
    common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
    hook = common / "hooks" / "pre-commit"
    report["present"]["git hooks"] = hook.exists() and "jig hook" in hook.read_text()

    report["coordination"] = coordination_report(root)
    report["docmap_present"] = bool(board.get("docmap"))
    # The fold-in asks about a page only when docmap names it, so a board page left out
    # of docmap is never checked against the code that targets that board.
    report["boards_unmapped"] = [f for f in md if f.startswith(BOARD_PAGES)
                                 and f not in (board.get("docmap") or {})]
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
    if report["homeless"]:
        linked = sorted((e for e in report["homeless"] if e["inbound"] > 0),
                        key=lambda e: -e["inbound"])
        cold = sorted((e for e in report["homeless"] if e["inbound"] == 0),
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
        print("\nIf a directory ships markdown as code, list it under `payload` on the board"
              " as a glob such as `dir/**`.")
    if report["payload_unmatched"]:
        print("\n`payload` globs that match no tracked file (a directory needs `/**`):")
        for g in report["payload_unmatched"]:
            print(f"  {g}")
    if src and not report["docmap_present"]:
        print("\nNo docmap on the board: handoff cannot tell which docs page a change touches."
              f"\nMap pages to globs in {BOARD} (see Fold-in in {DIR}/RULES.md).")
    if report["boards_unmapped"]:
        print("\nBoard pages no docmap entry names: no handoff will ask whether they still"
              "\nmatch the code. Map each to the code that targets its board:")
        for f in report["boards_unmapped"]:
            print(f"  {f}")
    co = report["coordination"]
    print("\nHow parallel work is coordinated today (and what each maps to in jig):")
    for f in co["found"]:
        print(f"  {f['what']:<42} -> {f['maps_to']:<32} {', '.join(f['at'])}")
    if co["git_hooks"]:
        print(f"  {'git hooks installed':<42} -> {'the hooks':<32} {', '.join(co['git_hooks'])}")
    if co["homebrew_boards"]:
        print(f"  {'a homebrew board (owns/shares/lanes)':<42} -> {'the board':<32} "
              f"{', '.join(co['homebrew_boards'])}")
    if co["worktrees"]:
        print(f"  {'git worktrees in use':<42} -> {'one per lane':<32} {co['worktrees']} linked")
    if co["open_branches"]:
        n = len(co["open_branches"])
        print(f"  {'branches not merged into trunk':<42} -> {'lanes to adopt':<32} "
              f"{n}: {', '.join(co['open_branches'][:6])}{' …' if n > 6 else ''}")
    if not any([co["found"], co["git_hooks"], co["homebrew_boards"], co["worktrees"],
                co["open_branches"]]):
        print("  none found — a single-session repo; lanes need no setup until a second session starts")
    print("\nHomes: " + "; ".join(f"{k} = {v}" for k, v in {**HOMES, **HOME_DIRS}.items()))
    print("Run /jig:adopt to turn this into a migration plan.")
    return 0

# ------------------------------------------------------------------- metarepo

# A metarepo holds a set of repos' shared definitions, decisions and conventions: docs only.
# Pararepos cite it at a released tag. Everything here is off unless .jig/meta.json exists.
META = f"{DIR}/meta.json"
META_DEFAULTS = {
    "name": "",
    "entry_files": ["DECISIONS.md", "GLOSSARY.md"],
    "tag_pattern": r"^v\d+\.\d+$",
    "decision_prefix": "D-",
    "pararepos": [],
}
DECISION_STATUSES = ("open", "proposed", "accepted", "superseded", "rejected")
# The Status cell, whole: a word alone, with a note in parentheses, or "superseded by D-12".
# Whole-cell, because a Decision cell often starts with a status word ("Open question: …").
STATUS_CELL = re.compile(rf"(?:{'|'.join(DECISION_STATUSES)})(?:\s*\(.*\)|\s+by\s+\S+)?")
# A commit's subject starts with the ids it touches (D-022: …, GLOSSARY: …), so git log is
# the decision index.
SUBJECT_IDS = re.compile(r"^[A-Z][A-Z0-9_-]*(?:, ?[A-Z][A-Z0-9_-]*)*: \S")
CHANGELOG = "CHANGELOG.md"


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


def merging_commits() -> list[str]:
    """The commits a merge in progress brings in. pre-merge-commit runs before git writes
    MERGE_HEAD, but git names what it merges in GIT_REFLOG_ACTION ("merge <ref>...")."""
    head = git("rev-parse", "-q", "--verify", "MERGE_HEAD")
    if head:
        return [head]
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
    # M1 docs only: the checker and its scripts live in .jig/, like any jig repo's
    for p in paths:
        if p.endswith(SRC_EXT) and not p.startswith(f"{DIR}/"):
            out.append(f"M1 a metarepo holds no code: {p}")
    if merging:
        # M5 main takes only merges of reviewed branches
        done = reviewed_commits()
        for c in merging:
            if c not in done:
                out.append(f"M5 {c[:12]} has no review on record: review it on its branch "
                           f"(`jig reviewed`), then merge")
        return out
    # M2 a decision row carries its status and date
    entry = meta["entry_files"]
    rx = re.compile(rf"^\+\s*\|\s*{re.escape(meta['decision_prefix'])}\d+\s*\|(.*)$", re.M)
    md = [p for p in paths if p.endswith(".md")]
    diff = git("diff", "-U0", base(trunk), *(["--cached"] if staged else []), "--", *md) if md else ""
    for m in rx.finditer(diff):
        cells = [c.strip().lower() for c in m.group(1).split("|")]
        if not (any(STATUS_CELL.fullmatch(c) for c in cells)
                and any(re.fullmatch(r"\d{4}-\d{2}-\d{2}", c) for c in cells)):
            out.append(f"M2 a decision row needs a status ({'/'.join(DECISION_STATUSES)}) and a "
                       f"date (YYYY-MM-DD): {m.group(0)[1:].strip()}")
    # M3 a change to what pararepos cite is recorded where they will read it
    if any(p in entry for p in paths) and CHANGELOG not in paths:
        out.append(f"M3 {', '.join(p for p in paths if p in entry)} changed: add a line to "
                   f"{CHANGELOG} under ## Unreleased")
    # M4 nothing lands on main except merges; jig's own bookkeeping (the board, handoffs) is
    # the exception, since the hubnode keeps it on trunk
    if branch == trunk and paths and not all(p.startswith(f"{DIR}/") for p in paths):
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


def meta_problems(root: Path, meta: dict, trunk: str) -> list[str]:
    """What makes the metarepo's history unreleasable. Shared by meta-release and pre-push,
    because a fast-forward runs no hook and a hand-made tag skips meta-release."""
    out: list[str] = []
    pat = re.compile(meta["tag_pattern"])
    tags = [t for t in git("tag", "--list").splitlines() if pat.match(t)]
    released = []
    for t in tags:
        heading = re.compile(rf"^## {re.escape(t)} — \d{{4}}-\d{{2}}-\d{{2}}\s*$", re.M)
        if heading.search(git("show", f"{t}:{CHANGELOG}")):
            released.append(t)
        else:
            out.append(f"tag {t} was not made by meta-release: its {CHANGELOG} has no "
                       f"`## {t} — <date>` heading. Delete it (`git tag -d {t}`)")
    last = latest_tag(released)
    rng = f"{last}..{trunk}" if last else trunk
    done = reviewed_commits()
    for line in git("rev-list", "--first-parent", "--parents", rng).splitlines():
        commit, *parents = line.split()
        if len(parents) > 1:
            if parents[1] not in done:
                out.append(f"{commit[:12]} merges {parents[1][:12]}, which has no review on record")
            continue
        if not parents:
            continue                      # the root commit predates the gates
        files = git("diff", "--name-only", parents[0], commit).splitlines()
        if all(f.startswith(f"{DIR}/") for f in files):
            continue
        if not git("show", f"{parents[0]}:{META}"):
            continue                      # meta-init's own commit: nothing was gated yet
        out.append(f"{commit[:12]} is on {trunk} without a reviewed merge "
                   f"({git('log', '-1', '--format=%s', commit)}): a fast-forward, or a commit "
                   f"made with the hooks off")
    return out


def version_key(tag: str) -> tuple[int, ...]:
    return tuple(int(n) for n in re.findall(r"\d+", tag))


def latest_tag(tags: list[str]) -> str:
    return max(tags, key=version_key) if tags else ""


def cmd_meta_init(root: Path, args) -> int:
    path = root / META
    if path.exists():
        print(f"{META} already exists")
    else:
        data = json.loads(json.dumps(META_DEFAULTS))
        data["name"] = args.name or root.name
        if args.prefix:
            data["decision_prefix"] = args.prefix
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2) + "\n")
        print(f"wrote {META}")
    meta = {**META_DEFAULTS, **json.loads(path.read_text())}
    seeds = {
        CHANGELOG: "# Changelog\n\nEvery change to an entry file adds a line here; "
                   "`jig meta-release` turns Unreleased into the next version.\n\n## Unreleased\n",
        "DECISIONS.md": "# Decisions\n\n<!-- One row per decision. A row needs a status "
                        f"({', '.join(DECISION_STATUSES)}) and a date. -->\n\n"
                        "| Id | Decision | Status | Date |\n|---|---|---|---|\n",
        "GLOSSARY.md": "# Glossary\n\n<!-- One term per heading: what it means, and what it is "
                       "not. -->\n",
    }
    for f, body in seeds.items():
        if f in (CHANGELOG, *meta["entry_files"]) and not (root / f).exists():
            (root / f).write_text(body)
            print(f"wrote {f}")
    cmd_install_hooks(root, argparse.Namespace(replace=False))
    print(f"Commit these on {Board.trunk_name(root)}. From then on {Board.trunk_name(root)} "
          "takes only reviewed merges, and only `jig meta-release` tags.")
    return 0


def cmd_meta_release(root: Path, args) -> int:
    board = Board.load(root)
    trunk = board.trunk
    meta = load_meta(trunk)
    if meta is None:
        die(f"no {META} on {trunk}: run `jig meta-init` and commit it first", 2)
    if git("branch", "--show-current") != trunk:
        die(f"release from {trunk}", 2)
    if git("status", "--porcelain"):
        die("commit or stash first: a release names one commit", 2)
    problems = meta_problems(root, meta, trunk)
    left = staged_files(main_root())
    if not args.force:
        problems += staged_refusal("the release")
    if problems:
        for p in problems:
            print(f"refused: {p}", file=sys.stderr)
        return 2
    pat = re.compile(meta["tag_pattern"])
    last = latest_tag([t for t in git("tag", "--list").splitlines() if pat.match(t)])
    changed = git("diff", "--name-only", last, "HEAD", "--", *meta["entry_files"]) if last \
        else " ".join(f for f in meta["entry_files"] if (root / f).exists())
    if not changed:
        die(f"nothing to release: no entry file changed since {last}", 2)
    major, minor = (version_key(last) + (0, 0))[:2] if last else (0, 0)
    tag = f"v{major + 1}.0" if args.major else f"v{major}.{minor + 1}"
    if left:
        changelog_line(root, f"- released with {len(left)} staged file{'s' if len(left) > 1 else ''} "
                             f"left unresolved: {', '.join(f.name for f in left)}")
    log = root / CHANGELOG
    text = log.read_text() if log.exists() else "# Changelog\n"
    heading = f"## {tag} — {date.today().isoformat()}"
    if re.search(r"^## Unreleased\s*$", text, re.M):
        text = re.sub(r"^## Unreleased\s*$", heading, text, count=1, flags=re.M)
    else:
        text = text.rstrip("\n") + f"\n\n{heading}\n"
    log.write_text(text)
    git("add", "--", CHANGELOG, check=True)
    # Written with plumbing, so no hook sees it: this is the one commit on trunk that isn't a
    # merge, and the tag beside it is what marks it.
    tree = git("write-tree", check=True)
    commit = git("commit-tree", tree, "-p", "HEAD", "-m", f"release: {tag}", check=True)
    git("update-ref", f"refs/heads/{trunk}", commit, check=True)
    git("tag", "-a", tag, "-m", tag, commit, check=True)
    print(f"released {tag} at {commit[:12]}. Push it: git push --follow-tags")
    return 0

# ------------------------------------------------------------------- pararepo

# A pararepo (code, firmware, hardware) cites a metarepo at a released tag. It reads a cache
# of the pinned docs, never a copy committed here, and writes the metarepo only by branch.
PARA = f"{DIR}/para.json"
CACHE = f"{DIR}/meta-cache"
HEADER_BEGIN = f"<!-- jig:meta — generated from {PARA} by `jig para-init`; edit that, not this -->"
HEADER_END = "<!-- jig:meta end -->"
# How a spec says what its contract change means for the metarepo: a proposal branch, or why none.
PROPOSAL = re.compile(r"^\s*-?\s*meta: (?:none — \S.*|\S+ proposal (\S+))\s*$", re.M)


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
        f"`{CACHE}/` (`jig para-sync` refreshes it and reports newer releases).",
        f"- Contract paths: {paths}. A change there needs a metarepo proposal "
        "(`jig para-propose`) or `meta: none — <reason>` in its spec.",
        "- The metarepo is written only by branch, via `jig para-propose`; nothing of it is copied here.",
        HEADER_END,
    ])


def with_header(text: str, header: str) -> str:
    block = re.compile(rf"^{re.escape(HEADER_BEGIN)}\n.*?^{re.escape(HEADER_END)}\n?", re.M | re.S)
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
    for f, key in ((path / BOARD, "name"), (path / META, "name")):
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
    return None


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
        if kind == "meta" and not (path / META).exists():
            print(f"  not a metarepo yet: run `jig meta-init` there")
        if kind == "para" and not (path / PARA).exists():
            print(f"  not a pararepo yet: run `jig para-init --meta <metarepo name>` there")
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
        return 0
    for name, e in sorted(repos.items()):
        missing = "" if Path(e["path"]).is_dir() else "   (missing)"
        print(f"  {name:<24} {e['kind']:<5} {e['path']}{missing}{'   ← here' if name in mine else ''}")
    if not repos:
        print(f"no repos in {repos_file()}: jig repos add repo|meta|para")
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
    meta-release writes."""
    meta = {**META_DEFAULTS, **json.loads(git("show", f"HEAD:{META}", cwd=cwd) or "{}")}
    pat = re.compile(meta["tag_pattern"])
    out = []
    for t in git("tag", "--list", cwd=cwd).splitlines():
        heading = re.compile(rf"^## {re.escape(t)} — \d{{4}}-\d{{2}}-\d{{2}}\s*$", re.M)
        if pat.match(t) and heading.search(git("show", f"{t}:{CHANGELOG}", cwd=cwd)):
            out.append(t)
    return sorted(out, key=version_key)


def fill_cache(root: Path, loc: Path, pin: str) -> None:
    if not git("rev-parse", "-q", "--verify", f"{pin}^{{commit}}", cwd=str(loc)):
        die(f"the metarepo has no tag {pin}: check \"pin\" in {PARA}", 2)
    meta = {**META_DEFAULTS, **json.loads(git("show", f"{pin}:{META}", cwd=str(loc)) or "{}")}
    cache = root / CACHE
    if cache.exists():
        shutil.rmtree(cache)
    cache.mkdir(parents=True)
    for f in [*meta["entry_files"], CHANGELOG]:
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


def para_rules(root: Path, board: "Board", para: dict, staged: bool) -> list[str]:
    """P1–P3: what a pararepo may commit."""
    out: list[str] = []
    trunk = board.trunk
    paths = changed_paths(trunk, staged)
    # P1 the AGENTS.md header says what para.json says
    if "AGENTS.md" in paths or PARA in paths:
        try:
            now = json.loads(in_index(PARA, staged) or "null") or para
        except ValueError:
            return [f"P1 {PARA} is not valid JSON"]
        agents = in_index("AGENTS.md", staged)
        if para_header(now) not in agents:
            out.append(f"P1 the AGENTS.md header is generated from {PARA}: edit that, then "
                       "`jig para-init` regenerates it")
    # P2 a contract change carries its metarepo proposal, or says why it needs none
    touched = [p for p in paths if matches(p, para.get("contract_paths", []))]
    if touched:
        specs = {p for p in paths if p.startswith(f"{DIR}/specs/") and p.endswith(".md")}
        branch = git("branch", "--show-current")
        if branch and branch != trunk:
            specs |= {p for p in git("diff", "--name-only", f"{trunk}...HEAD", "--",
                                     f"{DIR}/specs/").splitlines() if p.endswith(".md")}
        if not any(PROPOSAL.search(in_index(s, staged)) for s in specs):
            out.append(f"P2 {', '.join(touched)} is a contract path: a spec in this change "
                       "needs `meta: <name> proposal <branch>` (`jig para-propose`) or "
                       "`meta: none — <reason>`")
    # P4 no contract change while a file for the metarepo waits unresolved
    waiting = [f.name for f in staged_files(main_root()) if read_staged(f)[0].get("target") == para.get("meta")]
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
    path = root / PARA
    para = json.loads(path.read_text()) if path.exists() else {
        "meta": args.meta, "pin": args.pin, "defer_until": None,
        "contract_paths": args.contract or []}
    para.pop("location", None)          # an older para.json: where it lives is repos.json's
    if not para.get("meta"):
        die("first run needs --meta <name>", 2)
    if args.location:
        cmd_repos(root, argparse.Namespace(action="add", kind="meta", name=para["meta"],
                                           path=args.location))
    loc = meta_checkout(root, para)
    if loc is None:
        die(f"can't find {para['meta']}: run `jig repos add meta` in its checkout", 2)
    if not para.get("pin"):
        tags = released_tags(str(loc))
        if not tags:
            die(f"{para['meta']} has no release yet: run `jig meta-release` there first", 2)
        para["pin"] = tags[-1]
    path.write_text(json.dumps(para, indent=2) + "\n")
    fill_cache(root, loc, para["pin"])
    ignore_line(root, f"{CACHE}/")
    if loc.resolve().is_relative_to(root.resolve()):
        ignore_line(root, f"{loc.resolve().relative_to(root.resolve()).as_posix()}/")
    agents = root / "AGENTS.md"
    agents.write_text(with_header(agents.read_text() if agents.exists() else "# AGENTS.md\n",
                                  para_header(para)))
    print(f"wrote {PARA}, the AGENTS.md header, and {CACHE}/ at {para['pin']}.")
    print(f"Commit {PARA}, AGENTS.md and .gitignore on {Board.trunk_name(root)}.")
    return 0


def terms_changed(loc: Path, old: str, new: str) -> list[str]:
    """Decision ids and glossary headings that changed between two releases."""
    diff = git("diff", old, new, "--", ".", f":!{CHANGELOG}", cwd=str(loc))
    found = re.findall(r"^[+-]\s*\|\s*([A-Z][A-Z0-9]*-\d+)\s*\|", diff, re.M)
    found += re.findall(r"^[+-]#{2,3} (.+?)\s*$", diff, re.M)
    return list(dict.fromkeys(found))


def cmd_para_sync(root: Path, args) -> int:
    para = json.loads((root / PARA).read_text()) if (root / PARA).exists() else None
    if para is None:
        die(f"no {PARA}: run `jig para-init`", 2)
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
    for spec in sorted((root / DIR / "specs").glob("*.md")):
        for m in PROPOSAL.finditer(spec.read_text()):
            if m.group(1):
                landed = subprocess.run(["git", "merge-base", "--is-ancestor", m.group(1), latest],
                                        cwd=loc, capture_output=True).returncode == 0
                print(f"proposal {m.group(1)} ({spec.relative_to(root)}): "
                      f"{'released by ' + latest if landed else 'not released'}")
    if version_key(latest) <= version_key(pin):
        print(f"{name} {pin} is the latest release")
        return 0
    major = version_key(latest)[0] > version_key(pin)[0]
    print(f"{name} {latest} is out; this repo pins {pin}{' (a major release)' if major else ''}.\n")
    print("Changed, in this repo's terms:")
    for term in terms_changed(loc, pin, latest):
        # jig's own files (the rulebook's examples, the cache) are not the repo's use of a term.
        users = [f for f in git("grep", "-l", "-F", "--", term).splitlines()
                 if not f.startswith(f"{DIR}/")]
        print(f"  {term}: " + (f"used in {', '.join(users)}" if users else "not used here"))
    print(f"\nTo take it: set \"pin\" to \"{latest}\" in {PARA}, run `jig para-init`, and commit "
          f"those alone as `meta: {name} {pin} → {latest}` with this report as the body.")
    return 0


def cmd_para_propose(root: Path, args) -> int:
    para = json.loads((root / PARA).read_text()) if (root / PARA).exists() else None
    if para is None:
        die(f"no {PARA}: run `jig para-init`", 2)
    loc = meta_checkout(root, para)
    if loc is None:
        die(f"can't find {para['meta']}: run `jig repos add meta` in its checkout", 2)
    spec = root / args.spec
    if not spec.exists():
        die(f"no spec at {args.spec}", 2)
    branch = f"propose/{main_root().name}-{args.slug}"   # the repo's name, not a lane's folder
    meta_trunk = Board.trunk_name(loc)
    if git("rev-parse", "-q", "--verify", f"refs/heads/{branch}", cwd=str(loc)):
        die(f"{branch} already exists in {para['meta']}", 2)
    # A branch from the metarepo's trunk, made without checking anything out: main is untouched.
    git("branch", branch, meta_trunk, cwd=str(loc), check=True)
    line = f"- meta: {para['meta']} proposal {branch}"
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


# -------------------------------------------------------------------- staging

# Where a chat drops a file meant for this repo, or another. Untracked: nothing in it is
# authoritative, and it can reach a contract only through `jig staging resolve`.
STAGING = f"{DIR}/staging"
KINDS = ("spec", "doc", "decisions", "user-story")
HEADER_KEYS = ("staged", "target", "kind", "change", "destination", "source", "status")


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
    if head.get("change") and head["change"] not in ("new", "update"):
        bad.append(f"change {head['change']!r} is not new or update")
    if head.get("staged") and head["staged"] != "true":
        bad.append("staged is not true")
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


def staged_refusal(what: str) -> list[str]:
    """Release waits while anything is staged: the main checkout's folder, since staged files
    are never committed. Reading it only refuses more, so a branch can't weaken it."""
    files = staged_files(main_root())
    return [f"{what} waits while {len(files)} file{'s' if len(files) > 1 else ''} sit in "
            f"{STAGING}: {', '.join(f.name for f in files)}. Resolve or drop each "
            f"(`jig staging resolve`), or force it"] if files else []


def this_repo_names(root: Path) -> set[str]:
    names = {"this", Board.load(root, working_tree=True).data.get("name") or main_root().name}
    # and any alias you gave this checkout in repos.json
    names |= {n for n, e in load_repos().items() if Path(e["path"]).resolve() == main_root().resolve()}
    meta = root / META
    if meta.exists():
        names.add(json.loads(meta.read_text() or "{}").get("name", ""))
    return names - {""}


def cmd_staging(root: Path, args) -> int:
    if args.action != "resolve":
        files = staged_files(root)
        if not files:
            print(f"nothing staged in {STAGING}")
            return 0
        print(staged_summary(root))
        bad = False
        for f in files:
            head, _, problems = read_staged(f)
            print(f"  {f.name}: {head.get('change', '?')} {head.get('kind', '?')} for "
                  f"{head.get('target', '?')} → {head.get('destination', '?')}")
            for p in problems:
                print(f"      {p}")
                bad = True
        return 1 if bad else 0

    if not args.file:
        die("which file? jig staging resolve <file>", 2)
    # Staged files live in the main checkout only: they are never committed into a lane.
    path = main_root() / STAGING / Path(args.file).name
    if not path.exists():
        die(f"no {args.file} in {STAGING}", 2)
    head, body, problems = read_staged(path)
    if problems and not args.drop:
        die(f"{path.name}: {'; '.join(problems)}", 2)
    board = Board.load(root, working_tree=True)
    kind, change, dest = (head.get(k, "") for k in ("kind", "change", "destination"))
    source = head.get("source", "")
    mark = provenance(head, path)
    meta_here = (root / META).exists()

    if args.drop is not None:
        if not args.drop.strip():
            die("say why: --drop \"<reason>\"", 2)
        board.log(f"dropped staged {kind} for {head.get('target')} ({source}): {args.drop}")
        board.save()
        if meta_here:
            changelog_line(root, f"- dropped a staged {kind} from {source}: {args.drop}")
        path.unlink()
        print(f"dropped {path.name}; the reason is in the board log")
        return 0

    target = head["target"]
    if target not in this_repo_names(root):
        return forward(root, path, head)

    def done(msg: str) -> int:
        path.unlink()
        print(f"resolved {path.name}: {msg}")
        return 0

    def inside(rel: str) -> Path:
        """A destination stays inside the repo: no absolute path, no climbing out with .."""
        out = (root / rel).resolve()
        if Path(rel).is_absolute() or not out.is_relative_to(root.resolve()):
            die(f"destination {rel!r} is outside this repo: give a path relative to its root", 2)
        return out

    def landed(rel: str) -> bool:
        f = inside(rel)
        return f.exists() and mark in f.read_text(errors="replace")

    if kind == "user-story":
        specs = [s for s in (root / DIR / "specs").glob("*.md") if mark in s.read_text()]
        if not specs:
            how = "write a new spec" if change == "new" else "amend the spec it extends"
            die(f"a story resolves into a spec: {how} under {DIR}/specs/ from it, carrying "
                f"`{mark}`, then resolve again", 1)
        return done(f"carried by {specs[0].relative_to(root)}")
    if kind in ("spec", "doc") and not dest.endswith(".md"):
        die(f"destination {dest!r} isn't a path yet: find the page, put its path in the header, "
            "then resolve again", 1)
    if kind == "spec" and not dest.startswith(f"{DIR}/specs/"):
        dest = f"{DIR}/specs/{Path(dest).name}"
    if change == "update":
        if kind == "decisions":
            reg = inside(dest if dest.endswith(".md") else "DECISIONS.md")
            rows = decision_rows(body, root)
            text = reg.read_text() if reg.exists() else ""
            missing = [r for r in rows if r not in text]
            if missing or mark not in text:
                die(f"edit {reg.relative_to(root.resolve())} so it shows these rows and carries "
                    f"`{mark}`, then resolve again", 1)
            return done(f"rows confirmed in {reg.relative_to(root)}")
        if not landed(dest):
            die(f"needs judgment: edit {dest} with this file's content, keeping `{mark}` in it "
                "as provenance, then resolve again", 1)
        return done(f"{dest} carries it")
    if kind == "decisions":
        reg = inside(dest if dest.endswith(".md") else "DECISIONS.md")
        rows = decision_rows(body, root)
        rest = [l for l in body.splitlines() if l.strip() and l.rstrip() not in rows
                and not l.lstrip().startswith(("|---", "| Id", "#", "<!--"))]
        if rest:
            die(f"{len(rest)} line{'s' if len(rest) > 1 else ''} in {path.name} aren't decision "
                "rows: apply them with the user, delete them from the staged file, then resolve "
                "again", 1)
        if not rows:
            die(f"no decision rows in {path.name}", 1)
        text = reg.read_text() if reg.exists() else "| Id | Decision | Status | Date |\n|---|---|---|---|\n"
        have = {l.split("|")[1].strip() for l in text.splitlines() if l.startswith("|") and l.count("|") > 2}
        dupes = [r.split("|")[1].strip() for r in rows if r.split("|")[1].strip() in have]
        if dupes:
            die(f"{', '.join(dupes)} already in {reg.name}: stage it as `change: update`", 1)
        reg.write_text(text.rstrip("\n") + "\n" + "\n".join(rows) + "\n")
        ids = ", ".join(r.split("|")[1].strip() for r in rows)
        if meta_here:
            changelog_line(root, f"- {ids}. {mark}")
        else:
            board.log(f"decisions {ids} into {reg.relative_to(root.resolve())}. {mark}")
            board.save()
        return done(f"{len(rows)} row{'s' if len(rows) > 1 else ''} appended to {reg.name}")
    out = inside(dest)
    if out.exists():
        die(f"{dest} exists: stage it as `change: update`, or pick another path", 1)
    out.parent.mkdir(parents=True, exist_ok=True)
    if kind == "spec":
        first, _, rest = body.lstrip("\n").partition("\n")
        out.write_text(f"{first}\n\n{mark}\n{rest}" if first.startswith("#")
                       else f"{mark}\n\n{body}")
    else:
        out.write_text(body.rstrip("\n") + f"\n\n---\n{mark}\n")
    return done(f"written to {dest}")


def decision_rows(body: str, root: Path) -> list[str]:
    meta = root / META
    known = json.loads(meta.read_text() or "{}").get("decision_prefix") if meta.exists() else None
    prefix = re.escape(known) if known else r"[A-Z][A-Z0-9]*-"
    rx = re.compile(rf"^\s*\|\s*{prefix}\d+\s*\|")
    return [l.rstrip() for l in body.splitlines() if rx.match(l)]


def changelog_line(root: Path, line: str) -> None:
    log = root / CHANGELOG
    text = log.read_text() if log.exists() else "# Changelog\n\n## Unreleased\n"
    if not re.search(r"^## Unreleased\s*$", text, re.M):
        text = text.rstrip("\n") + "\n\n## Unreleased\n"
    log.write_text(re.sub(r"^(## Unreleased\s*\n)", lambda m: m.group(1) + line + "\n", text,
                          count=1, flags=re.M))


def forward(root: Path, path: Path, head: dict) -> int:
    """A staged file is resolved in its target. From here it moves into the target's own
    staging, the one place jig writes in another repo, after checking both sides agree."""
    target = head["target"]
    there = repo_path(target)
    if not there:
        die(f"{target} isn't this repo and isn't in {repos_file()}: "
            f"jig repos add {target} <path>", 2)
    there = Path(there)
    if not (there / DIR).is_dir():
        older = " (it has jig/: run `jig update` there first)" if (there / "jig" / "lanes.json").exists() else ""
        die(f"{target} is listed at {there}, but that isn't a jig repo (no {DIR}/){older}: fix it "
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
            die(f"{target}'s {PARA} doesn't cite {meta.get('name')}: run `jig para-init` there "
                "first", 2)
    dest = there / STAGING / path.name
    if dest.exists():
        die(f"{target} already has {STAGING}/{path.name}", 2)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(path), dest)
    print(f"forwarded {path.name} to {target}'s {STAGING}/; resolve it in a session there.")
    if para and target == para.get("meta"):
        print(f"If a spec here depends on it: jig para-propose <spec> <slug>.")
    return 0


# --------------------------------------------------------------------- update

# Where each of jig's own files lives now, and every path it has lived at. A row ending in
# "/" is a folder: every tracked file under an old folder moves, and board globs under it
# are rewritten. Any other row is one file, so after jig's two scripts leave `scripts/`,
# `scripts/**` on the board still means the repo's own scripts.
# Layouts, oldest first: eaec973's .jig/ with specs/, ledgers/ and scripts/ at root; ai-dev's
# .aidev/, the same with root ledgers; 62c8d9f's visible jig/ (every 0.2.x repo); .jig/ now.
LAYOUT = [
    (BOARD, ["jig/lanes.json", ".aidev/lanes.json"]),
    (f"{DIR}/jig.py", ["jig/jig.py", ".aidev/aidev.py"]),
    (f"{DIR}/RULES.md", ["jig/RULES.md", ".aidev/RULES.md"]),
    (f"{DIR}/handoffs/", ["jig/handoffs/", ".aidev/handoffs/"]),
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
TOOL_FILES = (f"{DIR}/jig.py", f"{DIR}/RULES.md")
# jig's folder under its old names. Nothing moves by this alone — a file there that no row
# names stays and is flagged — but a board glob over the whole folder meant jig's folder.
OLD_DIRS = ("jig/", ".aidev/")
OLD_IGNORES = (".jig/worktrees/", ".aidev/worktrees/")
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


STEPS: list = [
    (f"add {STAGING}/ (its .gitignore), where chats drop files for this repo",
     lambda root, after: f"{STAGING}/.gitignore" not in after
     and not (root / STAGING / ".gitignore").exists(),
     lambda root, here: (ensure_staging(root), git("add", "-f", "--", f"{STAGING}/.gitignore"))),
    (f"add {SETUP} from the template, TODOs to fill: it runs in every new worktree and after "
     "every merge", lambda root, after: SETUP not in after and not (root / SETUP).exists()
     and (Path(__file__).resolve().parent / "scripts" / "setup.sh").exists(), add_setup),
]


def root_is_jigs(board_at: str, version: int) -> bool:
    """Whether a root specs/, ledgers/ or scripts/check.sh is jig's. Only eaec973's layout
    and ai-dev's put them there, and once jig's files left root, those paths are the repo's.
    eaec973's board is at .jig/ like today's, and with the spec template made on first use a
    new repo has no .jig/specs/ either; only the board's version tells them apart. The one
    place update reads it for anything but the ahead refusal."""
    return board_at.startswith(".aidev/") or (board_at == BOARD and version < 3)


def plan_moves(files: list[str], board_at: str, version: int) -> dict:
    """Which tracked files LAYOUT moves, which tool files it retires, and the (old, new)
    rows that apply. A row moves only when its new path is free: with both there, update
    can't tell which is current, so it leaves both and says so."""
    # A path under an old folder is jig's only while the board is in that folder: beside a
    # board at .jig/, a jig/ folder is the repo's own (a Python package, say).
    at_root = root_is_jigs(board_at, version)
    taken, moves, retire, rows, warn = set(files), {}, [], [], []
    for new, olds in LAYOUT:
        for old in olds:
            home = next((d for d in OLD_DIRS if old.startswith(d)), None)
            if not (board_at.startswith(home) if home else at_root):
                continue
            under = [f for f in files if f not in moves and f not in retire
                     and (f.startswith(old) if old.endswith("/") else f == old)]
            if not under:
                continue
            if new in TOOL_FILES:
                retire += under
                rows.append((old, new))
                continue
            free = (not any(t.startswith(new) for t in taken) if new.endswith("/")
                    else new not in taken)
            if not free:
                warn.append(f"{old} and {new} both exist: both left as they are, not merged")
                continue
            # specs/ and ledgers/ at root may hold the repo's own files too (JS spec tests):
            # jig only ever put Markdown there.
            if old.endswith("/") and not old.startswith(OLD_DIRS):
                for f in [f for f in under if not f.endswith(".md")]:
                    warn.append(f"{f} is in {old} but isn't Markdown, so it isn't jig's: left there")
                under = [f for f in under if f.endswith(".md")]
            for f in under:
                moves[f] = new + f[len(old):] if old.endswith("/") else new
            taken |= set(moves.values())
            rows.append((old, new))
    after = sorted((set(files) - set(moves) - set(retire)) | set(moves.values()) | set(TOOL_FILES))
    for f in files:
        if f.startswith(board_at.split("/")[0] + "/") and board_at != BOARD \
                and f not in moves and f not in retire:
            warn.append(f"{f} is at an old path no row names: left there, and its folder stays")
    return {"moves": moves, "retire": retire, "rows": rows, "warn": warn, "after": after}


def rewrite_board(data: dict, files: list[str], plan: dict) -> tuple[dict, list[str], list[str]]:
    """The board with every path rewritten to where its files went. Returns the new board,
    one line per edit, and warnings."""
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
            ng = one(g)
            if ng != g:
                edits.append(f"{label}: `{g}` → `{ng}`")
            if ng not in out:
                out.append(ng)
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
    for key in ("common", "append_files", "payload"):
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
    for name, lane in (new.get("lanes") or {}).items():
        for key in ("owns", "shares"):
            if isinstance(lane, dict) and key in lane:
                lane[key] = many(f"lanes.{name}.{key}", lane[key])
    for key, default in BOARD_DEFAULTS.items():
        if key not in new:
            new[key] = main_root().name if key == "name" else json.loads(json.dumps(default))
            if key != "version":
                edits.append(f"{key}: added, {json.dumps(default)}")
    if new.get("version") != STAMP:
        edits.append(f"version: {data.get('version', 'none')} → {STAMP}")
        new["version"] = STAMP
    for key in data:
        if key not in BOARD_DEFAULTS:
            warn.append(f"board key `{key}` is not one jig knows: kept, and the checker ignores it")
    return new, edits, warn


def stale_references(root: Path, plan: dict, board_at: str) -> dict[str, list[tuple[int, str]]]:
    """Lines in the repo's own files that still name a path jig moved, keyed by where each
    file will be after the moves. Matched at a path boundary: example.com/specs/ is not one."""
    olds = sorted({o for o, _ in plan["rows"]}
                  | {d for d in OLD_DIRS if any(o.startswith(d) for o, _ in plan["rows"])},
                  key=len, reverse=True)
    if not olds:
        return {}
    pat = re.compile(r"(?<![\w/.-])(?:\./)?(?:" + "|".join(re.escape(o) for o in olds) + ")")
    back = {n: o for o, n in plan["moves"].items()}
    skip = {BOARD, board_at, ".gitignore", *TOOL_FILES}
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
        hits = [(i, line.strip()) for i, line in enumerate(text.splitlines(), 1) if pat.search(line)]
        if hits:
            out[f] = hits
    return out


def files_to_review(root: Path, plan: dict) -> list[tuple[str, str]]:
    """The repo's own files an old convention left behind, each with the edit proposed for
    it. update shows these and never applies them: they are the repo's."""
    back = {n: o for o, n in plan["moves"].items()}
    out = []
    hw = root / back.get("docs/HARDWARE.md", "docs/HARDWARE.md")
    if hw.exists():
        m = re.search(r"^- MCU / board:\s*(.+)$", hw.read_text(errors="replace"), re.M)
        board = (m.group(1).strip() if m else "")
        if not board or board.startswith("TODO"):
            out.append(("docs/HARDWARE.md", "still the template's TODOs: remove it"))
        else:
            slug = re.sub(r"[^a-z0-9]+", "-", board.split("(")[0].lower()).strip("-")
            out.append(("docs/HARDWARE.md", f"holds a board ({board}): rename it to "
                        f"{BOARD_PAGES}{slug}.md, one page per board as {DIR}/RULES.md "
                        "(Documentation) says, then check it against the code"))
    tpl = root / ".claude/skills/_skill-template/SKILL.md"
    if tpl.exists():
        if hashlib.sha256(tpl.read_bytes()).hexdigest() == OLD_SKILL_TEMPLATE:
            out.append((".claude/skills/_skill-template/", "the old blank skill template, "
                        "unchanged: remove it — new skills start from the template jig ships"))
        else:
            out.append((".claude/skills/_skill-template/", "differs from the old template, "
                        "so it is the repo's now: left as it is"))
    return out


def cmd_update(root: Path, args) -> int:
    here = Path(__file__).resolve().parent
    files = tracked(root)
    board_row = next(olds for new, olds in LAYOUT if new == BOARD)
    spots = [p for p in [BOARD, *board_row] if (root / p).exists()]
    if len(spots) != 1:
        if spots:
            why = [f"two boards, {' and '.join(spots)}: update can't tell which one the lanes are on"]
        else:
            why = [f"no board at any path jig has used ({', '.join([BOARD, *board_row])})"]
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

    refused = []
    version = data.get("version") if isinstance(data.get("version"), int) else 0
    if version > STAMP:
        refused.append(f"repo is ahead; update the plugin ({board_at} is at version {version}, "
                       f"this jig writes {STAMP})")
    if refused:
        print(f"refused: {refused[0]}", file=sys.stderr)
        return 2
    open_lanes = [n for n, l in (data.get("lanes") or {}).items()
                  if not isinstance(l, dict) or l.get("state") != "merged"]
    if open_lanes:
        refused.append(f"lanes are open: {', '.join(open_lanes)}. Merge or close every lane "
                       "first: update moves files their worktrees rely on")
    extra = [l[len("worktree "):] for l in git("worktree", "list", "--porcelain").splitlines()
             if l.startswith("worktree ")][1:]
    if extra:
        refused.append(f"worktrees besides the main checkout: {', '.join(extra)}. Remove each "
                       "with `git worktree remove <path>`, then `git worktree prune`")
    # A tracked change mid-move would leave jig half-moved; a re-run must still see the old layout.
    dirty = git("status", "--porcelain", "--untracked-files=no")

    plan = plan_moves(files, board_at, version)
    new_board, edits, board_warn = rewrite_board(data, files, plan)
    warnings = plan["warn"] + board_warn
    sources = {f"{DIR}/jig.py": Path(__file__).resolve(), f"{DIR}/RULES.md": here / "RULES.md"}
    replace = []
    for dest, src in sources.items():
        if not src.exists():
            warnings.append(f"no {src.name} beside this jig.py: {dest} is left as it is")
        elif plan["retire"] or not (root / dest).exists() or (root / dest).read_bytes() != src.read_bytes():
            replace.append(dest)
    steps = [s for s in STEPS if s[1](root, set(plan["after"]))]
    ignore = root / ".gitignore"
    # Today's board is at .jig/ too, so .jig/worktrees/ is old only beside an older board.
    old_ignores = OLD_IGNORES if board_at != BOARD or version < STAMP else OLD_IGNORES[1:]
    ignore_lines = ([l for l in ignore.read_text().splitlines() if l.strip() in old_ignores]
                    if ignore.exists() else [])
    untracked = [(o, n) for o, n in OLD_UNTRACKED if board_at.startswith("jig/")
                 and (root / o).is_dir() and any(f.is_file() for f in (root / o).rglob("*"))]
    cache_line = [l for l in ignore.read_text().splitlines() if l.strip() == "jig/meta-cache/"] \
        if ignore.exists() and board_at.startswith("jig/") else []
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
    review = files_to_review(root, plan)

    moved_board = board_at != BOARD
    actions = bool(plan["moves"] or replace or edits or moved_board or steps or ignore_lines
                   or stale_hooks or aidev_state or untracked or cache_line)
    if not actions:
        print("up to date")
        for w in warnings:
            print(f"warning: {w}")
        return 0
    if refused:
        print(f"refused: the repo is behind this jig's layout ({board_at}, version "
              f"{data.get('version', 'none')}), but:", file=sys.stderr)
        for r in refused:
            print(f"  {r}", file=sys.stderr)
        return 2
    if args.apply and dirty:
        print("refused: commit or stash tracked changes first; update moves files by name",
              file=sys.stderr)
        return 2

    print(f"jig update: {board_at} (version {data.get('version', 'none')}) → {BOARD} "
          f"(version {STAMP})")
    if plan["moves"]:
        print("\nMoves (renamed, never edited):")
        for o, n in plan["moves"].items():
            print(f"  {o} → {n}")
    if replace:
        print("\nWritten from this copy of jig:")
        for dest in replace:
            gone = [o for o, n in plan["rows"] if n == dest and o in plan["retire"]]
            print(f"  {dest}" + (f", replacing {', '.join(gone)}" if gone else ""))
    if edits:
        print("\nBoard:")
        for e in edits:
            print(f"  {e}")
    if steps:
        print("\nSteps:")
        for s in steps:
            print(f"  {s[0]}")
    if ignore_lines or stale_hooks or aidev_state or untracked or cache_line:
        print("\nGit state:")
        for l in ignore_lines:
            print(f"  .gitignore: remove `{l.strip()}` (worktrees live in .git/jig/worktrees/ now)")
        for l in cache_line:
            print(f"  .gitignore: `{l.strip()}` → `{CACHE}/`")
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
            print("\nRepo files to review (update never applies these):")
            for f, what in review:
                print(f"  {f}: {what}")
        template = here.parent / "AGENTS.md"
        if template.exists() and (root / "AGENTS.md").exists() and root.resolve() not in here.parents:
            diff = list(difflib.unified_diff(template.read_text().splitlines(),
                                             (root / "AGENTS.md").read_text().splitlines(),
                                             "template AGENTS.md", "AGENTS.md", lineterm=""))
            print("\nAGENTS.md against the template:" + ("" if diff else " the same"))
            for line in diff:
                print(f"  {line}")

    if not args.apply:
        report()
        print("\nDry run: nothing changed. Run again with --apply to apply it; it stages and commits nothing.")
        return 1 if warnings else 0

    # The board last: while it sits at its old path, a re-run still sees the old layout.
    for o, n in sorted(plan["moves"].items(), key=lambda m: m[0] == board_at):
        (root / n).parent.mkdir(parents=True, exist_ok=True)
        git("mv", o, n, check=True)
    (root / BOARD).parent.mkdir(parents=True, exist_ok=True)
    (root / BOARD).write_text(json.dumps(new_board, indent=2) + "\n")
    blobs = {dest: sources[dest].read_bytes() for dest in replace}
    for r in plan["retire"]:
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
    if ignore_lines or cache_line:
        raw = ignore.read_bytes().decode()
        gone = "|".join(re.escape(l) for l in old_ignores)
        raw = re.sub(rf"(?m)^[ \t]*(?:{gone})[ \t]*(?:\r?\n|\Z)", "", raw)
        ignore.write_bytes(re.sub(r"(?m)^[ \t]*jig/meta-cache/[ \t]*$", f"{CACHE}/", raw).encode())
    git("add", "--", BOARD, *replace, *([".gitignore"] if ignore_lines or cache_line else []),
        check=True)
    for folder in ({o for o, _ in plan["rows"] if o.endswith("/")}
                   | {o for o, _ in untracked} | {d for d in OLD_DIRS if board_at.startswith(d)}):
        for d, _, _ in sorted(os.walk(root / folder), key=lambda w: -len(w[0])):
            try:
                Path(d).rmdir()
            except OSError:
                pass
    if aidev_state:
        shutil.rmtree(git_common() / "aidev")
    cmd_install_hooks(root, argparse.Namespace(replace=False))
    report()
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
    ih = sub.add_parser("install-hooks", help="(re)write the git hooks")
    ih.add_argument("--replace", action="store_true",
                    help="remove a predecessor's hooks instead of chaining them as .local")
    s = sub.add_parser("status", help="lanes, states, how far behind trunk")
    s.add_argument("--all", action="store_true", help="include merged lanes")

    o = sub.add_parser("open", help="hubnode: open a lane")
    o.add_argument("name")
    o.add_argument("--brief", default="")
    o.add_argument("--branch")
    o.add_argument("--owns", nargs="*")
    o.add_argument("--shares", nargs="*")
    o.add_argument("--after", nargs="*")
    o.add_argument("--reserve", nargs="*",
                   help="counter names to allocate (schema), or name=value a branch already holds")
    o.add_argument("--worktree", help="adopting: where the branch is already checked out")
    o.add_argument("--state", choices=STATES, help="adopting: its state (default building)")

    m = sub.add_parser("mark", help="hubnode: set a lane's state")
    m.add_argument("name")
    m.add_argument("state")
    lg = sub.add_parser("log", help="append to or read the log")
    lg.add_argument("message", nargs="?")
    lg.add_argument("-n", type=int, default=20)
    c = sub.add_parser("check", help="run the rules here")
    c.add_argument("--staged", action="store_true")
    sub.add_parser("lane", help="print this branch's manifest")
    sub.add_parser("sync", help="merge trunk in, resolving append-only conflicts")
    sub.add_parser("reviewed", help="record that HEAD has had its review")
    h = sub.add_parser("handoff", help="write the handoff note for HEAD")
    h.add_argument("--spec", help="path to the spec this delivers")
    rl = sub.add_parser("reading-list", help="what to read before touching these files")
    rl.add_argument("paths", nargs="+")
    g = sub.add_parser("gate", help="verify a lane (or this branch) is mergeable")
    g.add_argument("name", nargs="?")
    g.add_argument("--force", action="store_true", help="gate though files are staged")
    sv = sub.add_parser("survey", help="inventory the repo against the jig shape")
    sv.add_argument("--json", action="store_true")
    mi = sub.add_parser("meta-init", help="make this repo a metarepo: docs only, released by tag")
    mi.add_argument("--name")
    mi.add_argument("--prefix", help="decision id prefix (default D-)")
    mr = sub.add_parser("meta-release", help="metarepo: validate, then tag the next version")
    mr.add_argument("--major", action="store_true", help="a rename or a reversed decision")
    mr.add_argument("--force", action="store_true", help="release though files are staged")
    pi = sub.add_parser("para-init", help="cite a metarepo at a released tag")
    pi.add_argument("--meta", help="the metarepo's name")
    pi.add_argument("--location", help="its checkout; recorded in repos.json, not the repo")
    pi.add_argument("--pin", help="the release to cite (default: the latest)")
    pi.add_argument("--contract", nargs="*", help="globs whose changes need a metarepo proposal")
    sub.add_parser("para-sync", help="refresh the cache; report newer metarepo releases")
    pp = sub.add_parser("para-propose", help="open a proposal branch on the metarepo for a spec")
    pp.add_argument("spec")
    pp.add_argument("slug")
    st = sub.add_parser("staging", help="list staged files, or resolve one")
    st.add_argument("action", nargs="?", choices=["resolve"])
    st.add_argument("file", nargs="?")
    st.add_argument("--drop", metavar="WHY", help="with resolve: drop it, recording why")
    rp = sub.add_parser("repos", help="list, or add to, where your repos live (user config)")
    rp.add_argument("action", nargs="?", choices=["add", "rename"])
    rp.add_argument("kind", nargs="?", help="add: repo, meta or para; rename: the new name")
    rp.add_argument("path", nargs="?", help="add: the checkout (default: this one)")
    rp.add_argument("--name", help="add: the name to call it by (default: its own)")
    up = sub.add_parser("update", help="bring this repo to the current jig layout (dry run)")
    up.add_argument("--apply", action="store_true", help="make the changes the dry run lists")
    hk = sub.add_parser("hook")
    hk.add_argument("name")
    hk.add_argument("rest", nargs="*")

    args = ap.parse_args(argv)
    if args.cmd == "repos":
        return cmd_repos(Path.cwd(), args)   # user config only: works outside any repo
    root = repo_root()
    fn = {
        "init": cmd_init, "install-hooks": cmd_install_hooks, "status": cmd_status,
        "open": cmd_open, "mark": cmd_mark, "log": cmd_log, "check": cmd_check,
        "lane": cmd_lane, "sync": cmd_sync, "reviewed": cmd_reviewed,
        "handoff": cmd_handoff, "gate": cmd_gate, "hook": cmd_hook,
        "survey": cmd_survey, "reading-list": cmd_reading_list, "update": cmd_update, "repos": cmd_repos, "staging": cmd_staging,
        "meta-init": cmd_meta_init, "meta-release": cmd_meta_release,
        "para-init": cmd_para_init, "para-sync": cmd_para_sync, "para-propose": cmd_para_propose,
    }[args.cmd]
    return fn(root, args)


if __name__ == "__main__":
    sys.exit(main())
