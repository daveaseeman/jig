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

# --- publish.sh posts these notes as the GitHub release, after the tag; refuse now, before
# anything is built or tagged, so a missing notes file can't leave a release half published
[ -s "dist/notes-$version.md" ] || { echo "write the release notes to dist/notes-$version.md first" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not signed in: publish.sh needs it" >&2; exit 1; }

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

# --- the file shipped must be this build: jig checks this run wrote it; this checks it says so
unzip -p "dist/jig-$version.plugin" .claude-plugin/plugin.json | grep -q "\"version\": \"$version\"" \
  || { echo "dist/jig-$version.plugin doesn't carry version $version" >&2; exit 1; }
