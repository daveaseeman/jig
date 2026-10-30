#!/usr/bin/env bash
# Runs after every Edit/Write. Formatting is a hook, not a rule, so it always happens.
# TODO: uncomment the formatter for this repo. Must be idempotent and fast.
# clang-format -i $(git diff --name-only -- '*.c' '*.h' '*.cpp') 2>/dev/null
# npx prettier --write $(git diff --name-only -- '*.ts' '*.tsx' '*.js' '*.json') 2>/dev/null
# cargo fmt 2>/dev/null
# ruff format . 2>/dev/null
exit 0
