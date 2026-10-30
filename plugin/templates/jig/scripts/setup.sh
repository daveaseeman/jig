#!/usr/bin/env bash
# Makes this checkout runnable: dependencies, submodules, local config git doesn't carry.
# jig's git hooks run it in every new worktree and after every merge, so it must be safe to
# run twice and cheap when everything is already current. It takes no arguments; run it by
# hand after changing dependencies. A failure is reported and fails nothing.
set -eu
cd "$(dirname "$0")/../.."

# The main checkout, for the examples that copy or link from it.
main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")

# --- install: the default. Each checkout installs from the repo's own manifests, so the
# gate catches a package that is used but never declared.
# TODO: uncomment what this repo uses
# uv sync
# npm install --prefix ui
# git submodule update --init --recursive

# --- local config that git doesn't carry
# [ -e .env ] || cp "$main/.env" .env

# --- link instead of install: opt-in. Every job then shares the main checkout's
# environment, and the gate can't catch a package that is installed but not declared.
# Ignore the link as `.venv`, not `.venv/`: git doesn't treat a link as a folder.
# [ -e .venv ] || ln -s "$main/.venv" .venv

exit 0
