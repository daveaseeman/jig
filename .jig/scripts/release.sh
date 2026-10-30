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

# --- the version lives in the plugin manifest and the marketplace entry
for f in plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  sed -i.bak "s/\"version\": \"[^\"]*\"/\"version\": \"$version\"/" "$f" && rm "$f.bak"
done

# --- the plugin must validate and every rule must pass end to end before it ships
claude plugin validate ./plugin
bash tests/smoke.sh

# --- the release is the plugin folder zipped as a .plugin, from the working tree: the version
# bump above isn't committed yet, so `git archive HEAD` would ship the old version
mkdir -p dist && rm -f "dist/jig-$version.plugin"
(cd plugin && git ls-files -z | xargs -0 zip -q "../dist/jig-$version.plugin")
