# Metarepo (1 of 2): the docs repo a set of pararepos cites

## Intent
jig manages a *set* of repos: one **metarepo** — docs only: definitions, decisions,
conventions — and one or more **pararepos** (code, firmware, hardware) that cite it at a
tag. The metarepo points; it never copies. Drift is visible, never silent. Contamination in
either direction is a gate failure — the gates are strict on purpose.

Three rules do the work: a pararepo writes the metarepo only by branch, via `para-propose`;
the metarepo holds no code and no copied pararepo content; only `meta-release` tags, so a
pin can never point at something that didn't pass validation.

This spec builds the metarepo side. `jig/specs/para.md` builds the pararepo side on top of it;
it can't be tested without a released metarepo, so it comes second.

## Done when
- [ ] `tests/smoke.sh` gains a meta section in a throwaway metarepo, every case PASS or the
      expected refusal:
  - [ ] `meta-init` then `meta-release` tags `v0.1`; a second `meta-release` with no
        entry-file change refuses ("nothing to release").
  - [ ] Staging a `SRC_EXT` file outside `jig/` → refused. A change to `jig/jig.py` → accepted.
  - [ ] A decision row without status + date → refused.
  - [ ] Entry file changed without `CHANGELOG.md` staged → refused.
  - [ ] A direct (non-merge) commit on `main` → refused. A `--no-ff` merge of an unreviewed
        branch → refused by `pre-merge-commit`.
  - [ ] A fast-forward of an unreviewed branch onto `main` (no hook runs) → the next
        `meta-release` and `pre-push` refuse, naming the commit.
  - [ ] A commit subject without an id prefix (`E-022: …`, `GLOSSARY: …`) → refused.
  - [ ] `git tag v0.2` by hand → the next `meta-release` and `pre-push` fail, naming the tag.
- [ ] `claude plugin validate ./plugin` passes. `jig.py` is still one stdlib-only file.
- [ ] `grep -rnE 'Maige|maige|"E-' plugin` returns nothing.

## Out of scope
- The pararepo side: `para-init`, `para-sync`, `para-propose`, contract paths (`jig/specs/para.md`).
- Rendering or hosting the metarepo. It is markdown in git.
- Multi-metarepo. One per pararepo.
- Migrating an existing docs repo into a metarepo (that is `adopt`'s job later).

## Touches
- `plugin/templates/jig/jig.py`: `meta-init`, `meta-release`; a metarepo rule group in
  `check_rules`, gated on `jig/meta.json` (absent → nothing changes); one validator function
  that `meta-release` and the `pre-push` hook share; `install-hooks` adds `commit-msg` (it
  does nothing without `jig/meta.json`) for the subject-prefix rule.
- `plugin/templates/jig/`: `meta.json`, `CHANGELOG.md`, decision-row template.
- `plugin/templates/jig/RULES.md`: a "Metarepo and pararepos" section — the three rules and
  the metarepo gates. `jig/specs/para.md` adds the pararepo gates.
- `tests/smoke.sh`, `marketing/FEATURES.md` (one row per command and for the rule group).

## Alternatives considered
- Copy shared docs into each pararepo and diff them. Rejected: copies drift silently, which is
  the failure this exists to make visible — `[seen]`, the forwarding-address bloat in Daisy
  was the same mechanism.
- TOML for `meta`/`para` config. Changed to JSON: the board is JSON, `jig.py` already parses
  it, and `tomllib` is read-only and 3.11+. One format, one parser — `[seen]`.
- Validate tags from the Claude Code Stop hook. Rejected: enforcement lives in `jig.py` and
  git hooks (AGENTS.md); a tag pushed from a plain terminal would never be checked — `[seen]`.
- Trust hooks alone for "main is only reviewed merges". Rejected: a fast-forward merge runs no
  hook, so `meta-release` re-checks history before it tags — `[seen]`.
- Mark released tags with an annotated-tag message. Rejected in favour of a `CHANGELOG.md`
  heading: it lives in the tagged tree, reads in any git UI, and the release already writes
  it — `[assumed]`, either works; the choice is which is simpler to check.

## Decisions
- Config is `jig/meta.json`. Paths follow `jig/specs/jig-folder.md`; do that spec first.
- `meta.json`: `{"name": ..., "entry_files": [...], "tag_pattern": "^v\\d+\\.\\d+$",
  "decision_prefix": "E-", "pararepos": ["..."]}`.
- "No code" means no `SRC_EXT` file outside `jig/`: the metarepo's own checker and scripts
  live in `jig/` like any jig repo's.
- A released tag is one whose commit's `CHANGELOG.md` has a `## v<x.y> — <date>` heading,
  written by `meta-release` in the commit it tags. Any tag matching `tag_pattern` without
  that heading fails validation.
- `main` holds only `--no-ff` merges of reviewed branches. `pre-merge-commit` checks the
  review marker; `meta-release` and `pre-push` re-check every first-parent commit since the
  last tag, which catches fast-forwards.
- Tags `v<major>.<minor>`: minor for additions and clarifications, major for a rename or a
  reversed decision.
- Commit subjects start with the ids touched (`E-022: …`, `GLOSSARY: mote`) so `git log` is
  the decision index. Merge commits are exempt; the branch commits carry the ids.
- "Copied pararepo content deeper than a pointer" is a warning, not a refusal: the reviewer
  decides. Everything else refuses (exit 2).
- Our instance's names and prefix are configuration for those repos, not anything in
  `plugin/` (see `jig/specs/para.md`).
