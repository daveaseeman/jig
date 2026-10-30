---
name: release
description: Release this repo with jig release - its own build and version bump from .jig/scripts/release.sh, then a vX.Y.Z tag. Defines the release protocol with the user the first time. Use on "/jig:release", "cut a release", or "ship a version".
disable-model-invocation: true
---

Run the repo's copy, from trunk with a clean tree:

```sh
python3 .jig/jig.py release            # --minor, --major, or --version X.Y.Z for the first
```

## When it refuses

- **"the release protocol isn't defined"**: fill it with the user, commit, and run it again.
  - Ask what a release of this repo ships (a package, an installer per platform, a plugin
    file, a tagged doc set) and how it is built today. Look for the build first:
    `package.json` scripts, `electron-builder`, `Cargo.toml`, `pyproject.toml`, a `Makefile`,
    an existing `scripts/` release step.
  - Ask where the version is written. Every file that holds it gets a line in
    `.jig/scripts/release.sh`, which receives the version as `$1` (`X.Y.Z`, no "v").
  - Write the build into `release.sh`. The artifacts go to a folder git ignores (`dist/`), and
    the TODO line goes.
  - Set `release.artifacts` in `.jig/config.json` to globs that match what the build
    produces, one per kind of file: `["dist/*.dmg", "dist/*.exe"]`.
  - Run `release.sh` once by hand with a throwaway version if the user agrees, then put the
    tracked files back with `git checkout -- .`.
  - In a metarepo, the release needs no steps. jig validates history, writes the changelog
    heading and tags.
- **files staged**: list them. Resolving them (`/jig:stage`) is the usual answer. `--force`
  releases anyway and names them in the release commit; use it only when the user says so.
- **no v\* tag yet**: ask for the first version and pass `--version X.Y.Z`.
- **a step failed**: tracked files are back as they were, and nothing is tagged. Show the
  output, fix the cause with the user, run it again.

## After

Report the tag and the artifacts it printed. Pushing (`git push --follow-tags`) and
publishing the artifacts anywhere are the user's call: ask first.
