#!/usr/bin/env bash
# Writes the files this repo derives from the whole tree (a generated reference, an index),
# in the checkout it runs in. It takes no arguments and must be safe to run twice.
# List every file this writes in `derived_files` in .jig/config.json (globs): jig commits
# exactly what they match, as it is after this runs, and nothing else this writes.
# `jig merge` runs it on trunk, after setup.sh, and commits what `derived_files` matches in the
# merge commit.
# Branches don't commit these files: in a job's checkout its sources are ahead of trunk's, and
# two jobs' copies merge into a wrong file. If a branch does commit one, the merge rewrites
# it, and a conflict in one can be settled by taking either side.
# check.sh doesn't compare them with their sources: in the gate's checkout they are trunk's.
# Solo work on trunk runs this by hand and commits what it wrote.
# A non-zero exit stops the merge before its commit; jig prints how to finish.
# A tracked file left changed and not in `derived_files` is named on stderr and not committed.
# A generator that setup.sh runs moves here: setup.sh must leave tracked files alone.
set -eu
cd "$(dirname "$0")/../.."

# --- regenerate a reference from the sources, for example:
# python3 tools/gen_reference.py > docs/reference/index.md

# --- an index of a folder, for example:
# { echo "count: $(ls src | wc -l | tr -d ' ')"; ls src; } > INDEX.md

exit 0
