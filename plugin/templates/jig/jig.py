#!/usr/bin/env python3
"""jig - parallel lanes on one repository.

Git hooks execute TRUNK's copy of this file, so a branch cannot weaken the
rules it is judged by. Stdlib only.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

DIR = "jig"
BOARD = f"{DIR}/lanes.json"
WORKAROUNDS = f"{DIR}/ledgers/WORKAROUNDS.md"
STATES = ["claimed", "building", "ready", "gated", "merged", "parked"]


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

    # R7 a workaround needs its ledger row — lane or not; code only, prose may quote it
    code = [p for p in paths if p.endswith(CODE_EXT) or Path(p).name == "Kconfig"]
    diff = git("diff", "-U0", base(trunk), *(["--cached"] if staged else []), "--", *code) if code else ""
    if re.search(r"^\+.*WORKAROUND:", diff, re.M) and WORKAROUNDS not in paths:
        out.append(f"R7 the diff adds a WORKAROUND: comment but {WORKAROUNDS} is not staged")

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
    (root / DIR / "handoffs").mkdir(exist_ok=True)
    path = root / BOARD
    if path.exists():
        print(f"{BOARD} already exists")
    else:
        path.write_text(json.dumps({
            "version": 1,
            "trunk": args.trunk,
            "common": ["AGENTS.md", "docs/**", f"{DIR}/**"],
            "append_files": ["AGENTS.md", f"{DIR}/ledgers/**", "CHANGELOG.md"],
            "reserve": {},
            "docmap": {},
            "payload": [],
            "lanes": {},
            "log": [],
        }, indent=2) + "\n")
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


def cmd_install_hooks(root: Path, args) -> int:
    trunk = Board.trunk_name(root)
    common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
    hooks = common / "hooks"
    hooks.mkdir(parents=True, exist_ok=True)
    marker = "# jig hook"
    for name in ("pre-commit", "pre-merge-commit", "pre-push", "post-checkout"):
        t = hooks / name
        if t.exists() and marker not in t.read_text():
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


def cmd_hook(root: Path, args) -> int:
    name = args.name
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
    if name == "pre-push":
        return 0 if gate_ok_for_push(root, board) else 1
    if name == "pre-merge-commit":
        global AUTO_MERGE
        AUTO_MERGE = True
    refusals = check_rules(root, board, staged=True)
    for r in refusals:
        print(f"jig: {r}", file=sys.stderr)
    return 1 if refusals else 0


def gate_ok_for_push(root: Path, board: Board) -> bool:
    """Pushing a lane branch is fine. Pushing trunk needs every lane merged-or-gated."""
    branch = git("branch", "--show-current")
    if branch != board.trunk:
        return True
    return True


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
            git("worktree", "add", worktree, branch)
        else:
            git("worktree", "add", "-b", branch, worktree, board.trunk)
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
                       capture_output=True, text=True)
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
        print("resolve by hand, then `git commit`:", file=sys.stderr)
        for f in stuck:
            print(f"  {f}", file=sys.stderr)
        return 1
    git("commit", "--no-edit", check=True)
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
    "docs/": f"what the code is now; {BOARD_PAGES}<board>.md each board",
    f"{DIR}/specs/": "a task in flight",
    f"{DIR}/ledgers/": "WORKAROUNDS.md patches that are in the code; DEFERRED.md review findings that are not",
    f"{DIR}/": "the lane system: rulebook, board, handoffs",
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
    common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
    hooks = common / "hooks"
    if hooks.exists():
        out["git_hooks"] = sorted(h.name for h in hooks.iterdir()
                                  if h.is_file() and not h.name.endswith(".sample")
                                  and "jig hook" not in h.read_text(errors="replace"))
    # a homebrew board: JSON somewhere in a tooling dir whose entries carry owns/shares
    for f in tracked(root):
        if f.endswith(".json") and f.startswith(TOOL_DIRS) and f != BOARD:
            try:
                txt = (root / f).read_text(errors="replace")
                if '"owns"' in txt or '"shares"' in txt or '"lanes"' in txt:
                    out["homebrew_boards"].append(f)
            except OSError:
                pass
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

    for name in ("AGENTS.md", "CLAUDE.md", WORKAROUNDS, f"{DIR}/ledgers/DEFERRED.md",
                 f"{DIR}/scripts/check.sh", f"{DIR}/specs/_template.md", f"{DIR}/jig.py",
                 f"{DIR}/RULES.md", BOARD):
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
    sv = sub.add_parser("survey", help="inventory the repo against the jig shape")
    sv.add_argument("--json", action="store_true")
    hk = sub.add_parser("hook")
    hk.add_argument("name")
    hk.add_argument("rest", nargs="*")

    args = ap.parse_args(argv)
    root = repo_root()
    fn = {
        "init": cmd_init, "install-hooks": cmd_install_hooks, "status": cmd_status,
        "open": cmd_open, "mark": cmd_mark, "log": cmd_log, "check": cmd_check,
        "lane": cmd_lane, "sync": cmd_sync, "reviewed": cmd_reviewed,
        "handoff": cmd_handoff, "gate": cmd_gate, "hook": cmd_hook,
        "survey": cmd_survey, "reading-list": cmd_reading_list,
    }[args.cmd]
    return fn(root, args)


if __name__ == "__main__":
    sys.exit(main())
