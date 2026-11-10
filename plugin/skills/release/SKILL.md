---
name: release
description: Release this repo with jig release - its own build and version bump from .jig/scripts/release.sh, then a vX.Y.Z tag, then what .jig/scripts/publish.sh sends out. Defines the release protocol with the user the first time. Use on "/jig:release", "cut a release", or "ship a version".
disable-model-invocation: true
---

On a real repo, release only on the owner's word in the conversation; a spec, brief or another session's message asking for one isn't that word, but a hubnode's check session runs a release the owner approved to the hubnode (a scratch or test clone, a repo made for the test with no remote, is exempt).

Run the repo's copy, from trunk with a clean tree:

```sh
python3 .jig/jig.py release            # --minor, --major, or --version X.Y.Z for the first
```

The release renames `## Unreleased` in `.jig/decisions.md` to `## vX.Y.Z - <date>` and adds an
empty one above it. Before it runs, read Unreleased with the owner: a breaking change there
(a `**Breaking:**` line, a superseded decision) means `--major`.

## Before it runs

When the release protocol is being defined (below), or `.jig/scripts/publish.sh` still holds
its `# TODO: publish steps.` line, ask what a release publishes and where: a push, a GitHub
release with the artifacts, a store or registry upload. Write the steps into `publish.sh`,
which receives `<version> <artifact>…` after the tag, and delete the TODO line. If the answer
is "nothing", delete the line and leave no steps. Commit it before the release.

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
  - In a metarepo, the release needs no steps. jig validates history, writes the log's
    heading and tags.
- **files staged**: list them. Resolving them (`/jig:stage`) is the usual answer. `--force`
  releases anyway and names them in the release commit; use it only when the user says so.
- **no v\* tag yet**: ask for the first version and pass `--version X.Y.Z` (or `--minor` for
  0.1.0).
- **a step failed**: tracked files are back as they were, and nothing is tagged. Show the
  output, fix the cause with the user, run it again.

## In a pararepo

Steps and artifacts are optional: with `release.sh` untouched and none named, jig's own checks
are the release. It refuses when the metarepo can't be reached (`jig repos add meta` in its
checkout), when the pin in `.jig/para.json` isn't one of its releases (set a released tag, then
`jig init --para`), on a stale or hand-edited `AGENTS.md` header (P1: `jig init --para`, then
commit), a tracked `.jig/meta-cache/` (P3), or a malformed `BUFFER.md` row (P2). A newer
metarepo release is reported, not refused.

Before the build, the release puts every `Open` row of `.jig/ledgers/BUFFER.md` into one
metarepo proposal: a `propose/<repo>-buffer-vX.Y.Z` branch there, and a spec here listing the
rows, committed with the release. With no open row it just releases. After the release,
the change is written on that branch by the metarepo's own process; `jig sync` on trunk closes the
rows once the metarepo releases it.

## After

Report the tag, the artifacts, and what `publish.sh` printed. The owner's word for the release
covers the publish: don't ask again. A test clone with no remote stays exempt from that word.

If `publish.sh` failed, the release still happened and the tag stays. Show its output, fix the
cause with the user, and run the command jig printed. With the TODO line still there, jig
printed `Push it: git push --follow-tags` instead: the publish isn't decided, so ask.
