#!/usr/bin/env python3
"""Draw README's "Who does what" pictures from jig.py's ROLES and FLOWS, light and dark.

    python3 scripts/roles_svg.py           write assets/roles-and-flows-{light,dark}.svg
    python3 scripts/roles_svg.py --check   exit 1, naming each SVG that differs from what it draws

The drawing is generated so it can't state the tables a second time by hand: change a role's
tier or a workflow's steps in jig.py, and the check fails until the pictures are redrawn.
"""
import importlib.util
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
JIG = ROOT / "plugin" / "templates" / "jig" / "jig.py"
OUT = {"light": ROOT / "assets" / "roles-and-flows-light.svg",
       "dark": ROOT / "assets" / "roles-and-flows-dark.svg"}

# One color per node and role, the same in both pictures; each theme has its own shade.
THEMES = {
    "light": {"bg": "#ffffff", "text": "#1f2328", "muted": "#59636e", "line": "#d1d9e0",
              "new": "#cf222e",
              "hubnode": "#9a6700", "spec": "#8250df", "bug": "#cf222e", "work": "#1a7f37",
              "review": "#bf3989", "check": "#0969da"},
    "dark": {"bg": "#0d1117", "text": "#e6edf3", "muted": "#9198a1", "line": "#3d444d",
             "new": "#f85149",
             "hubnode": "#d29922", "spec": "#ab7df8", "bug": "#f85149", "work": "#3fb950",
             "review": "#db61a2", "check": "#4493f8"},
}
LETTER = {"hubnode": "H", "spec": "S", "bug": "B", "work": "W", "review": "R", "check": "C"}
FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
BIG, SMALL = 13, 11          # the two type sizes
W = 880                      # the picture's width
PAD = 24


def load_jig():
    spec = importlib.util.spec_from_file_location("jig", JIG)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def text_w(s: str, size: int) -> float:
    # No font metrics in the stdlib: an average glyph is about 0.56 of the size in a UI sans.
    return len(s) * size * 0.56


def wrap(words: list[str], width: float, size: int) -> list[str]:
    lines, cur = [], ""
    for w in words:
        nxt = f"{cur}, {w}" if cur else w
        if cur and text_w(nxt, size) > width:
            lines.append(cur + ",")
            cur = w
        else:
            cur = nxt
    return lines + ([cur] if cur else [])


def t(x, y, s, size, fill, weight=400, anchor="start"):
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}">{escape(s)}</text>')


def sessions(jig, flow: str) -> list[tuple[str, str, str, str]]:
    """(link, step, owner, session letter) for each step of FLOW. ⇢ starts a session: R1, R2
    for each fresh review. → continues one that exists: the owner's, else the step before's."""
    out, have, reviews, prev = [], {}, 0, ""
    for link, part in jig.flow_steps(flow):
        for i, step in enumerate(part.split(" + ")):
            owner = jig.step_owner(step)
            if not owner:                   # a nested workflow: no session of its own
                out.append((link if i == 0 else "+", step, "", ""))
                continue
            if owner == "hubnode":          # the owner's one session, in every workflow
                letter = "H"
            elif i > 0:                     # "a + b": one session takes both in turn
                letter = prev
            elif link == "⇢" or (not link and owner not in have):
                if owner == "review":
                    reviews += 1
                    letter = f"R{reviews}"
                else:
                    letter = LETTER[owner]
            else:
                letter = have.get(owner) or prev or LETTER[owner]
            if i == 0:
                have[owner] = letter
            prev = letter
            out.append((link if i == 0 else "+", step, owner, letter))
    return out


def draw(jig, theme: str) -> str:
    c = THEMES[theme]
    roles = {k: v for k, v in jig.ROLES.items()}
    body: list[str] = []
    y = PAD

    # Roles: one card per node and role, and jig itself, three to a row.
    body.append(t(PAD, y + BIG, "Roles", BIG, c["text"], 600))
    y += BIG + 12
    cols, gap = 3, 12
    cw = (W - 2 * PAD - (cols - 1) * gap) / cols
    floor = jig.HUBNODE_FLOOR
    cards = [("hubnode", f"the owner's · {floor['tier']},{floor['effort']} or better", jig.HUBNODE_STEPS),
             ("subnode", "the role's settings", ["one role on one job, in its worktree"])]
    for name, r in roles.items():
        cards.append((name, f"{r['tier']},{r['effort']} · {r['session']}",
                      r["steps"] + ([f"then {r['then']}"] if r.get("then") else [])))
    cards.append(("jig itself", "no model", ["refuses steps out of order", "cleans up"]))
    lines = [wrap(steps, cw - 24, SMALL) for _, _, steps in cards]
    ch = 16 + BIG + 8 + SMALL + 10 + max(len(l) for l in lines) * (SMALL + 5) + 8
    for i, ((name, where, _), steps) in enumerate(zip(cards, lines)):
        x = PAD + (i % cols) * (cw + gap)
        top = y + (i // cols) * (ch + gap)
        col = c.get(name, c["muted"])
        dash = ' stroke-dasharray="4 3"' if name == "jig itself" else ""
        body.append(f'<rect x="{x:.1f}" y="{top:.1f}" width="{cw:.1f}" height="{ch:.1f}" rx="8" '
                    f'fill="none" stroke="{c["line"] if dash else col}" stroke-width="0.5"{dash}/>')
        if not dash:
            body.append(f'<circle cx="{x + 16:.1f}" cy="{top + 16 + BIG / 2 - 4:.1f}" r="4" fill="{col}"/>')
        body.append(t(x + (26 if not dash else 12), top + 16 + BIG - 3, name, BIG, c["text"], 600))
        body.append(t(x + 12, top + 16 + BIG + 8 + SMALL, where, SMALL, c["muted"]))
        for j, line in enumerate(steps):
            body.append(t(x + 12, top + 16 + BIG + 8 + SMALL + 10 + (j + 1) * (SMALL + 5) - 3,
                          line, SMALL, c["text"]))
    rows = (len(cards) + cols - 1) // cols
    y += rows * ch + (rows - 1) * gap + 28

    # Workflows: one row each, the steps as pills colored by their owner.
    body.append(t(PAD, y + BIG, "Workflows", BIG, c["text"], 600))
    body.append(f'<text x="{W - PAD}" y="{y + BIG:.1f}" font-size="{SMALL}" fill="{c["muted"]}" '
                f'text-anchor="end">→ continues a session that already exists, named by its letter'
                f'<tspan fill="{c["new"]}" dx="12">⇢</tspan> starts a new one</text>')
    y += BIG + 16
    left = PAD + 96
    for flow, f in jig.FLOWS.items():
        body.append(f'<line x1="{PAD}" y1="{y:.1f}" x2="{W - PAD}" y2="{y:.1f}" '
                    f'stroke="{c["line"]}" stroke-width="0.5"/>')
        y += 12
        body.append(t(PAD, y + 14, flow, BIG, c["text"], 600))
        x = left
        for link, step, owner, letter in sessions(jig, flow):
            if link:
                col = c["new"] if link == "⇢" else c["muted"]
                body.append(t(x + 7, y + 14, link, BIG, col, anchor="middle"))
                x += 14
            label_w = text_w(step, SMALL) + (text_w(letter, SMALL) + 4 if letter else 0)
            pw = label_w + 18
            if owner:
                col = c[owner]
                body.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{pw:.1f}" height="20" rx="10" '
                            f'fill="{col}" fill-opacity="0.14" stroke="{col}" stroke-width="0.5"/>')
            else:
                body.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{pw:.1f}" height="20" rx="10" '
                            f'fill="none" stroke="{c["text"]}" stroke-width="0.5"/>')
            body.append(t(x + 9, y + 14, step, SMALL, c["text"]))
            if letter:
                body.append(t(x + 9 + text_w(step, SMALL) + 4, y + 16, letter, SMALL,
                              c[owner], 600))
            x += pw + 4
        y += 20 + 8
        note = f["trigger"].replace("`", "") + (f" · {f['controls']}" if f["controls"] else "")
        body.append(t(left, y + SMALL, note, SMALL, c["muted"]))
        y += SMALL + 12
    y += PAD - 12
    head = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{y:.0f}" '
            f'viewBox="0 0 {W} {y:.0f}" font-family="{FONT}" role="img">\n'
            f'<rect width="{W}" height="{y:.0f}" fill="{c["bg"]}"/>\n')
    return head + "\n".join(body) + "\n</svg>\n"


def main(argv: list[str]) -> int:
    jig = load_jig()
    stale = []
    for theme, path in OUT.items():
        svg = draw(jig, theme)
        if "--check" in argv:
            if not path.exists() or path.read_text() != svg:
                stale.append(path.relative_to(ROOT).as_posix())
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(svg)
            print(f"wrote {path.relative_to(ROOT).as_posix()}")
    for s in stale:
        print(f"{s} differs from what scripts/roles_svg.py draws from jig.py's ROLES and FLOWS: "
              "run python3 scripts/roles_svg.py and commit it", file=sys.stderr)
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
