# One release command, a release protocol per repo, and lighter staging

Source: owner, Oct 29, in review of `names.md`.

## Intent
Every repo releases with `jig release`. What a release builds and ships is the repo's own
protocol, kept in one standard place. jig adds the steps a metarepo needs because it can see
it is one, and it refuses a release while files are staged unless forced. Commits and pushes
stay free of staging. A staged document gets no ceremony: dropping one deletes it.

## Done when
Smoke:
- [x] `jig release` in a plain repo, on trunk with a clean tree:
  - runs `.jig/scripts/check.sh`, then `.jig/scripts/release.sh <version>`
  - commits whatever the script changed as `release v<version>`
  - checks every `release.artifacts` glob on the board matches a file
  - tags `v<version>`
  - prints the artifacts
- [x] The version is the last `v*` tag bumped by `--major`, `--minor` or `--patch` (the default),
      or `--version X.Y.Z` when there is no tag yet.
- [x] Refused, with nothing tagged:
  - with a file in `.jig/staging/`, unless `--force`. The refusal lists the staged files. A
    forced release names them in its commit message.
  - off trunk, or with a dirty tree.
  - when `check.sh` or `release.sh` fails, or an artifact glob matches nothing.
- [x] In a metarepo, `jig release` does what `meta-release` does today: it validates history,
      turns `## Unreleased` into the version heading, tags `vX.Y.Z` (see Decisions), and says
      "nothing to release" when no entry file changed. `--major` means a rename or a reversed
      decision, as now. `meta-release` is gone.
- [x] `jig init` and `jig update` add `.jig/scripts/release.sh` from a template, with TODOs, and
      an empty `release.artifacts`. In a metarepo the template has no build steps, because jig
      runs the meta steps itself.
- [x] A protocol that isn't defined yet refuses before anything runs. That means a
      `release.sh` still holding the template's TODO marker, or an empty `release.artifacts`
      outside a metarepo. The refusal says "the release protocol isn't defined: run
      /jig:release", and `/jig:release` asks the user what the repo builds and ships, fills
      both in, and commits them before releasing.
- [x] The repo kind is read from trunk: `.jig/meta.json` makes it a metarepo and `.jig/para.json`
      a pararepo, the same files the hooks already read. `jig release` prints the kind it found.
- [x] `gate` and trunk's pre-push no longer look at staging: a lane merges and trunk pushes with
      files staged.
- [x] `jig staging drop <file>` deletes the file and records nothing. `resolve --drop` is gone.
- [x] Staging writes no `CHANGELOG.md` line. Resolving decisions into a metarepo appends the
      rows only, and M3 still refuses that commit until it has a changelog line. The stage
      skill tells the agent to add the line.
- [x] `jig init --meta` and `jig init --para <meta> --contract <globs>` replace `meta-init` and
      `para-init`. `/jig:repos add meta|para` offers them.
- [ ] This repo's own `.jig/scripts/release.sh`:
  - writes the version into `plugin/.claude-plugin/plugin.json` and
    `.claude-plugin/marketplace.json`
  - runs the validator and smoke
  - builds `dist/jig-<version>.plugin` with `git archive` of the plugin folder
  - its board has `release.artifacts: ["dist/jig-*.plugin"]`

  (`.jig/` changes only by update, so this file is filled after the release that adds it.)
- [x] Smoke passes, and the validator passes.

## Out of scope
- Publishing: uploading artifacts to GitHub or a store. A repo's `release.sh` may do it. jig
  doesn't.
- `para-sync` and `para-propose`. They are the next candidates to fold into standard commands
  (`sync`, `propose`), in their own spec.
- Signing or notarizing builds.

## Touches
- `marketing/FEATURES.md`: rows for `jig release`, the release protocol, and `staging drop`.
  The meta-release row is rewritten.
- `plugin/templates/jig/jig.py`:
  - `cmd_release`, which absorbs `cmd_meta_release`
  - `release` on the board, with `BOARD_DEFAULTS`
  - an `update` `STEPS` row for `release.sh`
  - `init --meta/--para`, which absorbs `meta-init` and `para-init`
  - `gate` and pre-push stop reading staging
  - `staging drop`
  - the `changelog_line` calls leave staging
- `plugin/templates/jig/scripts/release.sh`: new.
- `plugin/templates/jig/RULES.md`: the Staging, Metarepo and Commands sections.
- Skills:
  - `stage`
  - `repos`
  - `init`
  - `update`
  - `hubnode`, if it names meta-release
  - a new user-invoked `/jig:release`. It runs the command. On first use it fills `release.sh`
    with the user, the way init fills `check.sh`.
- `tests/smoke.sh`, `README.md`.

## Alternatives considered
- Warn about staged files and ask "continue anyway?". Rejected by the owner: a release has to
  know there's work left, and committing and pushing stay free. `[seen]`, Oct 29.
- Keep `meta-release` beside a plain `release`. Rejected by the owner: jig knows a metarepo
  from `.jig/meta.json`, so one command is enough. `[seen]`, Oct 29.
- Record the protocol as prose in `AGENTS.md` or a doc. Rejected: a release has to run, and
  prose gets skipped. `check.sh` and `setup.sh` already live in `.jig/scripts/`. `[seen]`.
- A drop that records its reason in git. Rejected by the owner: the dropped file was never
  committed, so the record points at nothing. `[seen]`, Oct 29.

## Decisions
- `release.sh` is the protocol, and `release.artifacts` is what the release ships. The globs
  let jig check the script's result without knowing how the build works.
- Version bumps live in `release.sh`, because only the repo knows where its version is written
  (`plugin.json`, `package.json`, `Cargo.toml`). jig passes the number in and commits the result.
- Owner, Oct 29: **`vX.Y.Z` in every repo**, metarepos included. `--minor` is the metarepo
  default, since its changes are additions, and `--major` is a rename or reversal, as now.
  Existing `vX.Y` tags still count: after `v0.3`, the next minor is `v0.4.0`. `tag_pattern`
  accepts both, and `update` widens a metarepo's stored `^v\d+\.\d+$` to
  `^v\d+\.\d+(\.\d+)?$`. Pararepo pins on `vX.Y` tags keep working.
- A pararepo releases like a plain repo. Its P rules already run at every commit, so there is
  nothing extra to check at release time.
- Owner, Oct 29: accepts both reversals, `staging drop`, and the changelog staying meta-only.
- This reverses two decisions in `staging.md`: release-refusal moves off `gate` and pre-push,
  and drop loses its reason. `staging.md` is shipped and closed; this spec records the change.
- Build, Oct 29. Done as written, except this repo's own `release.sh`, which waits for the
  release that ships it, as the item says. Smoke 207 PASS: 11 new release cases (protocol
  undefined, artifacts, first version, bumps, staged and forced, a failing script, an
  unmatched glob, off trunk), the meta and para cases moved to `init --meta/--para` and
  `release`, and the staging cases flipped (drop, gate, push). The validator passes. Also:
  - `STAMP` 7, with three `update` steps: add `release.sh`, widen a metarepo's two-part
    `tag_pattern`. (A third, rewriting the pararepo header line that names `jig para-init`,
    was cut in review: see below.)
  - init copies the template's `release.sh` before `init --meta` runs, so `--meta` strips the
    TODO from the copy that's already there.
  - Pre-push no longer reads the pushed refs: staging was the only thing it used them for.
- Review, Oct 30 (fresh context). Blocking, taken: the header-rewrite step couldn't be
  committed, because trunk's older checker judges the update commit and P1 refuses any change
  to the header. The step is gone and the header keeps its `jig para-init` wording, with a
  comment saying why. Should-fix, taken:
  - an artifact counts only if this run wrote it (by mtime), so last release's `dist/` can't
    pass for this one
  - `release` runs from the repo root, so a refusal from a subfolder puts every file back and
    `add -u` takes every change
  - smoke cases for a dirty tree, a failing `check.sh`, the metarepo and pararepo kinds,
    decisions resolved into a metarepo and M3 refusing without the line

  Optional, taken: the FEATURES para row, `CHANGELOG.md` staged by name, `init --no-hooks
  --meta`, and the old `## Unreleased` regex that ate the newline. A release now also leaves an
  empty `## Unreleased` above its heading. Deferred: a custom two-part tag pattern (see
  `.jig/ledgers/DEFERRED.md`).
