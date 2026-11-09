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

# --- the marketplace (.claude-plugin/marketplace.json) serves ./plugin from main, so pushing
# main with the version bump is what reaches `claude plugin update`; the tag goes with it
git push --follow-tags

# --- the GitHub release carries the .plugin file for a direct install. release.sh refused
# before the build if the notes were missing, so they are here
notes="dist/notes-$version.md"
gh release create "v$version" "$@" --repo daveaseeman/jig --title "v$version" --notes-file "$notes"

# --- a release whose upload failed silently would leave nothing to install: check it is there
for f in "$@"; do
  gh release view "v$version" --repo daveaseeman/jig --json assets -q '.assets[].name' \
    | grep -qx "$(basename "$f")" || { echo "v$version is published without $f" >&2; exit 1; }
done
