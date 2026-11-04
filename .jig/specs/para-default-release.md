# Bug: a pararepo has no default release, so the sync buffer can't settle through `jig release`

Source: maige-ecosystem hubnode session, 2026-11-03 (sync-buffer replay) (staged as feedback-maige-ecosystem-2026-11-03.md)
Report § 4. Owner (2026-11-03, quoted there): "I do want customizable releases in each repo, but
there should be a default, especially for para and meta repos. A para release should check its
contents against meta, jig has a whole system for this, so it technically already knows the
default release."

## 1. Why
- Why does a pararepo's `jig release` refuse? `protocol_missing` refuses the template's TODO line
  and, once that's gone, an empty `release.artifacts`. It runs before the buffer step.
- Why doesn't a metarepo's? It has a default: `init --meta` strips the TODO, `protocol_missing`
  skips the artifacts check for it, and `meta_problems` is the check its release runs instead.
- Why not a pararepo? `cmd_release` knows the kind (it prints "(pararepo)") but only meta gets a
  default. Root: the pin, P1–P4 and the buffer are already in jig; no release uses them.

## 2. Givens
- `[seen]` Scratch meta + para, template untouched: `jig release --version 0.1.0` → "the release
  protocol isn't defined (… still holds the template's TODO)", rc 2.
- `[seen]` TODO line deleted, nothing else: refused again, "the board's release.artifacts is
  empty", rc 2. The report's one-line stub alone would not have been enough.
- `[seen]` `jig propose --buffer` by hand, TODO in place: makes `propose/para-buffer-<date>`, rc 0.
- `[seen]` The template `release.sh` is all comments: `bash release.sh 9.9.9` exits 0.
- `[seen]` Pin set to `main`, with a defined protocol: the commit lands, `init --para` fills the
  cache at `main` (`PIN` reads `main`), and `jig release` tags v0.1.0, rc 0. A pararepo release
  checks nothing against its metarepo but the buffer.
- `[seen]` `staged_refusal` already refuses any staged file, so P4's case can't reach a tag.
- `[seen]` RULES.md *Release*: "Until `release.sh` has steps and `config.json` names its
  artifacts, the release refuses". *Metarepo and pararepos*: "A pararepo pins a release, never
  `main`", which nothing enforces.

## 3. One layer up
- Sibling: the metarepo release. Same command, with a kind default: no steps needed, and a
  history check (`meta_problems`) before the tag. A pararepo is the kind with none.
- Existing pattern: `meta_problems` returns refusal lines that `cmd_release` prints. A
  `para_problems` beside it, built from code that's already there (`released_tags`,
  `para_header`, `buffer_rows`, `BUFFER_STATES`), is the same shape.

## 4. Correction
Give a pararepo a default release: steps and artifacts become optional, and jig checks it
against its metarepo before tagging. A plain repo keeps refusing until `/jig:release`.

## 5. Spec

### Done when
In a pararepo, `jig release`:
- [ ] doesn't refuse the template's TODO or an empty `release.artifacts`. `release.sh` still runs
      (a no-op when untouched), and any globs still have to match.
- [ ] refuses, printing each as `refused: …` and tagging nothing, when:
  - the metarepo can't be reached (`jig repos add meta`)
  - the pin isn't in the metarepo's `released_tags` (`main`, a hand-made tag)
  - the `AGENTS.md` header isn't `para_header(para)` (P1)
  - a file under `.jig/meta-cache/` is tracked (P3)
  - a `BUFFER.md` row is neither Open nor Closed, or two rows share an id (P2's ledger checks)
- [ ] warns and goes on when the metarepo has a newer release than the pin, or a cited file isn't
      a contract path. It prints `jig sync`'s same lines.
- [ ] still settles the buffer as 0.5.0 does (see Open questions).

Smoke, in the existing meta + para fixture:
- [ ] A pararepo with `release.sh` untouched from the template and no artifacts tags v0.1.0,
      rc 0. With two Open rows, it also makes the one proposal branch.
- [ ] Pin set to `main`: refused, naming the pin, and no tag. A hand-edited header committed
      with `--no-verify`: refused, naming P1. Metarepo unregistered: refused, naming
      `jig repos add meta`.
- [ ] A pararepo with its own steps and an artifact glob runs them and checks the glob.
- [ ] A plain repo with the template's TODO still refuses (the existing case).
- [ ] RULES.md *Release* says a metarepo and a pararepo release with defaults, and lists the
      pararepo's. The `release` skill's *In a pararepo* says steps and artifacts are optional
      there. The `jig release` row in `marketing/FEATURES.md` says so too, edited first.
- [ ] Smoke passes, and the validator passes.

### Out of scope
- A default for a plain repo. The owner said "especially para and meta". Say if a plain repo
  should tag with `check.sh` alone.
- Re-walking a pararepo's history for P2 contract answers, the way `meta_problems` does for M4/M5.
- Refusing `main` as a pin at `init --para` or in the commit hook. The release check is where
  it costs a tag; the commit-time check can follow.

### Touches
`plugin/templates/jig/jig.py` (`protocol_missing`, `cmd_release`, new `para_problems`),
`plugin/templates/jig/RULES.md` (*Release*), `plugin/skills/release/SKILL.md`,
`marketing/FEATURES.md`, `tests/smoke.sh`.

### Alternatives considered
- Have `init --para` strip the TODO the way `init --meta` does (`release_script(meta=True)`).
  Rejected as the whole fix: existing pararepos already carry the TODO, and an empty
  `release.artifacts` refuses anyway. `[seen]`: repro 2.
- Read the cache's `PIN` when the metarepo can't be reached. Rejected: `fill_cache` takes any
  commit-ish, so the cache proves nothing about a release. `[seen]`: `PIN` read `main`.
- Refuse a pin behind the metarepo's latest release. Rejected: RULES.md lets a pararepo pin an
  older release and bump it in its own commit. `[seen]`.
- Users write the default checks into each `release.sh` by hand. Rejected: jig already has the
  checks, and the owner asked for a default. `[seen]`: the quote above.

## Decided
Owner, 2026-11-03: each recommendation below is taken. Build to it.

- **Does settling the buffer stay part of a pararepo release, or become its own step?** 0.5.0
  ties them, and `jig propose --buffer` also works by hand. Owner, 2026-11-02: "it doesn't have
  to update meta until the para is released". Recommendation: keep it tied. This fix is what
  lets it run, and the owner's earlier word matches it. Either way builds: if it's split off,
  the release drops `buffer_proposal` and instead warns with the Open rows no proposal carries.
  Everything else above stays.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
