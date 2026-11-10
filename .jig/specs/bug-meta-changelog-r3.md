# bug-meta-changelog-r3

Source: maige-ecosystem hubnode session with Dave, 2026-11-10 (Claude) (staged as feedback-maige-ecosystem-2026-11-10-redocument-metarepo.md): "In a metarepo, M3 demands a changelog line that R3 refuses." Four jobs blocked at their first commit: "R3 … CHANGELOG.md not job redocument-echo's: ask the hubnode to add it to shares".

## Intent
In a metarepo, every job may append its `CHANGELOG.md` line without the hubnode listing it,
because M3 asks every job that changes an entry file for one.

## Why
- Why was the commit refused? M3 asks a job that changes an entry file for a `CHANGELOG.md` line;
  R3 refuses `CHANGELOG.md` unless the job owns or shares it, or it is `common`.
- Why isn't it common? `common` defaults to `AGENTS.md`, `docs/**`, `.jig/**`. `CHANGELOG.md` is
  only in `append_files`, which says how a merge resolves it, and `init --meta` adds nothing.
- Root: M3's demand comes from `meta.json`; the permission to meet it comes from per-job lists
  written by hand. One gate requires what another refuses.

## Givens
- `[seen]` Reproduced at 5e58ca0 (newer than the report's b9d48e5): a throwaway repo from
  `plugin/templates`, `jig init --meta`, `jig open gl --owns GLOSSARY.md` (no `--shares`). A
  `## mote` term plus a `CHANGELOG.md` line: `R3 CHANGELOG.md is not job gl's: ask the hubnode to
  add it to shares`. Without the line: `M3 GLOSSARY.md changed: add a line to CHANGELOG.md under
  ## Unreleased`.
- `[seen]` Same repo, `CHANGELOG.md` added to `common` on trunk: the same commit passes.
- `[seen]` `check_rules` loads `meta` from trunk before R3; R3 passes `owns`, `shares`, `common`
  or a file new to the repo, nothing else.
- `[seen]` `tests/smoke.sh` `emergejob` opens every metarepo job with `--owns … CHANGELOG.md`:
  jig's own test works around it.
- `[seen]` maige-ecosystem's `.jig/config.json` (read only): `common` is `AGENTS.md`, `.jig/**`;
  `append_files` holds `CHANGELOG.md`. Commit 86eeab3 adds `CHANGELOG.md` to four jobs' `shares`;
  the earlier job `alpha-input` (6dec3f1) listed it by hand.
- `[seen]` `STAMP`'s comment: a new config default bumps the layout and needs an update step.

## Design
R3 passes a metarepo's `CHANGELOG.md` as it passes `common`: `meta is not None and p ==
CHANGELOG`. R4 is unchanged. RULES.md's R3 line gains "in a metarepo, `CHANGELOG.md` too, where
M3 asks every job for its line"; the R3 row in `marketing/FEATURES.md` says the same.

## Done when
- [x] Smoke `metarepo`: a job opened with `--owns GLOSSARY.md` and no `--shares` commits a new
      term with its `CHANGELOG.md` line (the reported refusal is gone).
- [x] Smoke: `emergejob` opens its jobs without `CHANGELOG.md` in `--owns`, and every section
      using it passes.
- [x] Smoke `rules`: in a repo with no `meta.json`, a job changing `CHANGELOG.md` it doesn't
      own or share is still refused by R3.
- [x] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.

## Out of scope
- A job that owns `CHANGELOG.md`: R4 still blocks the others; that is the hubnode's choice.
- The `shares` maige-ecosystem already wrote: harmless, left as they are.

## Touches
- `plugin/templates/jig/jig.py` (`check_rules`, R3)
- `plugin/templates/jig/RULES.md` (R3)
- `tests/smoke.sh`
- `marketing/FEATURES.md` (R3 row)

## Alternatives considered
- `init --meta` adds `CHANGELOG.md` to `common` — rejected because existing metarepos keep the
  bug until a hand edit or a layout bump with an update step, and the permission would live apart
  from the M3 rule it answers — reason is [seen]
- R3 passes every `append_files` entry — rejected because `append_files` governs merges, not who
  may change a file, and outside a metarepo nothing asks for a changelog line — reason is [seen]
- A hubnode-skill step to share `CHANGELOG.md` per job — rejected because it is the step that was
  missed four times at once — reason is [seen]

## Decisions
- The exemption reads the `CHANGELOG` constant M3 reads, so the two can't drift.
- Workaround until it lands: the hubnode adds `CHANGELOG.md` to `common` once, on trunk.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
