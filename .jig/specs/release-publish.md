# release-publish

Source: owner, Nov 8, after the 0.7.0 release was pushed and published by hand: "release should
do both - plugin in dist & released on gh for propogation", and "if you're asking me to release
… then it is my call, so why can't it be part of jig's per-repo configuration? … it should be
configurable, then you ask, then you do it all".

## Intent
A repo's release protocol says what a release publishes, as well as what it builds. The owner's
word for `jig release` covers both: no second ask before pushing or uploading.

## Design
- **`.jig/scripts/publish.sh`**: a per-repo template beside `release.sh`, holding the line
  `# TODO: publish steps.` and commented examples (`git push --follow-tags`; `gh release create
  "v$version" "$@"`). `jig release` runs it after the tag as `publish.sh <version> <artifact>…`.
  The artifacts are the files this run built, matched by `release.artifacts`, as paths from the
  repo root. It runs from the repo root, with the same environment as `release.sh`.
- **The TODO line means "not decided yet".** jig skips the script while the line is there and
  prints `Push it: git push --follow-tags` as it does today. Publishing is optional in every kind
  of repo, so the TODO never blocks a release. A repo that publishes nothing deletes the line and
  leaves the script with no steps.
- **A failed publish leaves the tag.** By then the tag is made and may already be pushed, so jig
  does not undo it. It prints `released vX.Y.Z at <commit>, but publish.sh exited N`, followed by
  the exact command to run again (`.jig/scripts/publish.sh X.Y.Z <artifacts>`), and exits 1.
- **`jig update`** adds `publish.sh` from the template, TODO line included, to a repo that
  doesn't have it, the same way it adds `release.sh`. `jig init` copies it along with the rest of
  `templates/jig/`.
- **`/jig:release`**:
  - When the release protocol is being defined, or `publish.sh` still holds its TODO line, the
    skill asks what a release publishes and where before it runs the release. It then fills the
    script, or deletes the TODO line if the answer is "nothing".
  - The "After" section loses its "ask first". The owner's word for the release covers
    `publish.sh`, and the skill reports what the script printed.
  - A test clone with no remote stays exempt from that word, as it is now.

## Done when
- [ ] Smoke `release`:
  - with `publish.sh` untouched, a release tags, does not run the script, and prints the
    `Push it` line;
  - with steps, the script runs after the tag (it sees `vX.Y.Z` in `git tag`) and receives
    `X.Y.Z dist/app-X.Y.Z.zip`;
  - a script that exits 3 leaves the tag, prints the rerun command, and `jig release` exits 1;
  - a refused release (a `release.sh` that fails) never runs `publish.sh`.
- [ ] Smoke `update`: a repo without `publish.sh` gets it from the template, TODO line included,
  staged. The smoke checks that list `.jig/` files exactly (init, update, and the board files)
  name it.
- [ ] RULES.md `## Release` describes `publish.sh`: when it runs, the TODO line, and a failure
  after the tag. The Commands line reads "…release protocol, then tag, then publish".
- [ ] The `/jig:release` skill text matches the Design section above.
- [ ] `bash tests/smoke.sh` passes; `claude plugin validate ./plugin` passes;
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- This repo's own `publish.sh` and its AGENTS.md release line. This repo gets the hook only
  through a release and `/jig:update`, so 0.7.1 still publishes by hand. Filling the script
  (push, `gh release create … --notes-file`, then `gh release view`) is a trunk change after
  that update.
- Release notes. Writing them stays with the owner and the repo's own script.
- A `--publish-only` flag. The printed rerun command is enough.
- Survey's "jig pieces present" list: `release.sh` isn't on it either.

## Touches
- `plugin/templates/jig/scripts/publish.sh` (new)
- `plugin/templates/jig/jig.py`: `cmd_release` (run it after the tag, failure message), a
  `STEPS` row and its add function, and the `PUBLISH` / `PUBLISH_TODO` constants
- `plugin/templates/jig/RULES.md` (`## Release`, Commands)
- `plugin/skills/release/SKILL.md`
- `tests/smoke.sh` (`sec_release`, the update section, and the exact `.jig/` file lists at about
  lines 254, 449 and 647)
- `marketing/FEATURES.md` (main checkout only: a new row, and row "`jig release` and
  `.jig/scripts/release.sh`" loses "A publisher" from what it is not)

## Alternatives considered
- Publish from `release.sh`: rejected because it runs before the release commit and the tag, so
  a GitHub release would point at the previous commit, and a later failure would roll back files
  that had already been published [seen: `cmd_release`, `jig.py:2239`–`2279`].
- A wrapper script outside jig (`scripts/ship.sh`): rejected by the owner because publishing
  should be per-repo configuration in jig, under the release's one approval [seen: owner, Nov 8].
- A `release.publish` command list in `config.json`: rejected because the build is already a
  script in `.jig/scripts/`, and a shell step such as `gh … --notes-file` reads better as a
  script than as JSON strings [assumed].

## Decisions
- Pushing goes in `publish.sh` and isn't built into jig: some repos have no remote, or push
  somewhere other than `origin`.
- Exit 1, not 2, after a failed publish: the release itself happened. 2 means refused, with
  nothing tagged.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
