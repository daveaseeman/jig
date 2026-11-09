#!/usr/bin/env bash
# This repo's publish step: what a release sends out once it is tagged. `jig release` runs it
# after the release commit and the v<version> tag, as `publish.sh <version> <artifact>...`:
# the version is X.Y.Z (no "v"), the artifacts are the files this run built that matched
# `release.artifacts`, as paths from the repo root.
# While the TODO line below is here, jig skips this script and prints the push command instead.
# A repo that publishes nothing deletes the line and leaves no steps.
# A non-zero exit leaves the tag in place: jig prints the command to run this again.
set -eu
cd "$(dirname "$0")/../.."
version="$1"
shift

# TODO: publish steps. /jig:release fills this in with you, then deletes this line.

# --- push the release commit and its tag, for example:
# git push --follow-tags

# --- publish the artifacts, for example:
# gh release create "v$version" "$@"
