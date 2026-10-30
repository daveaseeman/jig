# Bug: the plugin's Stop and format hooks never run

Source: `/jig:feedback` from a repo on 0.3.0, Oct 30 (`jig-feedback-<repo>-2026-10-30.md`).

## 1. Why
- Why doesn't the Stop hook run `check.sh`? `hooks.json` executes `scripts/check.sh` directly,
  the file is mode 644, and the shell exits 126.
- Why 644? Git records it that way: `100644` for both hook scripts, and for the template's
  `check.sh` and `format.sh`. `setup.sh` and `release.sh` are `100755`.
- Why did nothing catch it? Smoke runs the scripts through `bash`, or after a `chmod +x`, and
  never execs them the way the hook does. Claude Code reports a 126 as a hook error, not a block.

## 2. Givens
- `[seen]` `git ls-files -s`: `plugin/scripts/check.sh`, `plugin/scripts/format.sh` and
  `templates/jig/scripts/{check,format}.sh` are `100644`.
- `[seen]` `plugin/hooks/hooks.json` runs `"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh"` and
  `.../format.sh` with no interpreter.
- `[seen]` The report's run: exec'd directly, exit 126. Run through `bash` in a repo with a
  type error, it blocks with exit 2. The logic works; only the mode is wrong.
- `[seen]` init and adopt `chmod +x .jig/scripts/*.sh`, which papers over the template's two.
- `[assumed]` Every install since the hooks shipped has had them silently off, this repo
  included.

## 3. One layer up
`run_setup` and `cmd_release` already run repo scripts as `bash <script>` when the file isn't
executable. The plugin's hooks are the one place that doesn't.

## 4. Correction
Both parts: record the four scripts `100755`, and have `hooks.json` run them through `bash`, so
a packaging step that drops modes can't turn the hooks off again.

## 5. Spec

### Done when
- [x] `git ls-files -s plugin/scripts plugin/templates/jig/scripts` shows `100755` for every `.sh`.
- [x] Both `hooks.json` commands start with `bash `.
- [x] Smoke: no `.sh` under `plugin/` is tracked as `100644`, and every `hooks.json` command
      starts with `bash `.
- [x] Smoke: the plugin's `scripts/check.sh`, run with `CLAUDE_PROJECT_DIR` set to an
      opted-in repo whose `.jig/scripts/check.sh` fails, exits 2.
- [x] `/jig:feedback` can be invoked by the model. Its flag is removed: it changes nothing in
      the repo, and RULES.md tells the agent to run it.
- [x] Smoke and the validator pass.

### Touches
`plugin/scripts/*.sh` and `plugin/templates/jig/scripts/{check,format}.sh` (mode only),
`plugin/hooks/hooks.json`, `plugin/skills/feedback/SKILL.md`, `tests/smoke.sh`.

### Alternatives considered
- Mode bits only. Rejected: a zip or upload step that drops modes turns the hooks off again,
  silently. `[seen]`: the template's scripts already needed init's `chmod`.
- `bash` only. Rejected as the sole fix: the template's scripts still land 644 in any repo set
  up by hand. `[seen]`: init and adopt carry a `chmod` for exactly that.
- Keep feedback user-only, and change RULES.md to "ask the user to run it". Rejected: the
  skill writes a temp file and edits nothing, so the model gains nothing risky by running it,
  and the agent hit the wall the rule put there. `[seen]`: the report.

### Decisions
- Build, Oct 30. Done as written. Smoke 263 PASS, two new; the validator passes. Also: the
  plugin's `check.sh` and `format.sh` run the repo's `.jig/scripts/` copy through `bash`, so a
  repo copy that lost its bit still runs. The older-layout fallbacks (`jig/scripts/`, root
  `scripts/`) still need the bit, because a root `scripts/check.sh` may be the repo's own.
