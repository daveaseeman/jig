# Documentation

One page per system, under `jig/docs/systems/`. The tree names the product's own parts, not its
files, so a rule that touches several files lives once. Every page has three headings:

- **Now** — what is true on trunk today.
- **Rules** — what binds, as if the text stood in `AGENTS.md`. Number every rule; the number
  is the heading (`### 31.1 …`), so a citation resolves by search wherever the text moves.
- **Checks** — one line per rule naming what holds it: a named test, "review", or "on screen".

When Now and Rules disagree, Rules wins and Now gets fixed. A moved rule leaves no forwarding
address behind — that is history, and git keeps it.

A **seam** page covers what crosses between two systems: in `docmap`, a page whose globs name
files from both sides.

Map files to pages with `docmap` in `jig/lanes.json`:

```json
"docmap": {"jig/docs/systems/storage.md": ["server/storage.py", "server/migrations/**"]}
```

`jig handoff` then asks for each page the change touched, and `jig reading-list <files>`
prints what to read before starting.
