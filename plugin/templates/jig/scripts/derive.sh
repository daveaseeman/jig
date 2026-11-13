#!/usr/bin/env bash
# Writes the files this repo derives from the whole tree (a generated reference, an index),
# in the checkout it runs in. It takes no arguments and must be safe to run twice.
# Write every output on every run, even when its content is unchanged: jig stages what this
# touched, so an output skipped as already current stays out of the merge commit.
# `jig merge` runs it on trunk, after setup.sh, and commits what it wrote in the merge commit.
# Branches don't commit these files: in a job's checkout its sources are ahead of trunk's, and
# two jobs' copies merge into a wrong file. If a branch does commit one, the merge rewrites
# it, and a conflict in one can be settled by taking either side.
# check.sh doesn't compare them with their sources: in the gate's checkout they are trunk's.
# Solo work on trunk runs this by hand and commits what it wrote.
# A non-zero exit stops the merge before its commit; jig prints how to finish.
# jig commits every file this writes that git doesn't ignore: write the outputs and nothing
# else (a Python generator's __pycache__ needs an ignore line). A generator that setup.sh runs
# moves here: setup.sh must leave tracked files alone.
set -eu
cd "$(dirname "$0")/../.."

# --- regenerate a reference from the sources, for example:
# python3 tools/gen_reference.py > docs/reference/index.md

# --- an index of a folder, for example:
# { echo "count: $(ls src | wc -l | tr -d ' ')"; ls src; } > INDEX.md

exit 0
