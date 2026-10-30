#!/usr/bin/env bash
# This repo's release protocol: build what it ships, and write the version where the repo
# keeps it. `jig release` runs it on trunk with a clean tree, after check.sh, as
# `release.sh <version>` (X.Y.Z, no "v"). jig then commits the tracked files it changed,
# checks the board's `release.artifacts` globs each matched a file, and tags v<version>.
# A non-zero exit refuses the release and puts the tracked files back.
# Leave artifacts untracked (dist/ in .gitignore): the tag names the source, not the build.
set -eu
cd "$(dirname "$0")/../.."
version="$1"

# TODO: release protocol. /jig:release fills this in with you, then deletes this line.

# --- write the version where the repo keeps it, for example:
# npm version "$version" --no-git-tag-version
# sed -i.bak "s/\"version\": \"[^\"]*\"/\"version\": \"$version\"/" app/manifest.json && rm app/manifest.json.bak

# --- build what the release ships, into a folder git ignores, for example:
# npm run dist                      # an app's installers
# zip -r "dist/app-$version.zip" build/
