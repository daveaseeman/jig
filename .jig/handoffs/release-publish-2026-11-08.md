# Handoff: release-publish

Commit: b5db934862731ecd1140a402388297ea467b837f
Date: 2026-11-08
Spec: .jig/specs/release-publish.md
Review: tier 2, effort 2
Ran: fresh Opus subagent, effort high: diff main...release-publish, spec, AGENTS.md; 0 blocking, 2 should-fix (duplicate artifacts to publish.sh; rerun line without exec bit), 5 optional (rerun cwd, update/init skill lines, stale smoke text, stdout order) — all fixed in b5db934

## Built
`jig release` now runs `.jig/scripts/publish.sh <version> <artifact>…` after the tag, from the
repo root, with the files this run built (each once, as repo-root paths). While the script holds
`# TODO: publish steps.` it is skipped and `Push it: git push --follow-tags` prints as before. A
failure after the tag leaves the tag, prints `released vX.Y.Z at <commit>, but … exited N` and a
rerun line that works from anywhere (`cd <root> && [bash ].jig/scripts/publish.sh X.Y.Z …`),
and exits 1. New template `plugin/templates/jig/scripts/publish.sh`; `jig update` adds it (a
`STEPS` row). RULES.md `## Release` and Commands, and the release, init and update skills say so.

## Done-when evidence
- Smoke `release` (TODO skipped + Push it; steps run after tag with `2.0.3 dist/app-2.0.3.zip`; exit 3 leaves the tag, prints the rerun line, exits 1; refused release never runs it; plus overlapping globs once, and the no-exec-bit rerun line run from `/`): `bash tests/smoke.sh release` → all PASS.
- Smoke `update`: "publish.sh is added from the template, TODO line included, and staged" PASS for all five old layouts; exact `.jig/` lists (init, update ×2) name `publish.sh`.
- RULES.md `## Release` paragraph on publish.sh (when it runs, the TODO line, failure after the tag); Commands reads "…release protocol, then tag, then publish". Read in the diff.
- `/jig:release` skill: "Before it runs" asks what a release publishes while defining the protocol or while the TODO is there; "After" drops the ask-first; the test-clone exemption is kept. Read in the diff.
- `bash tests/smoke.sh` → exit 0, 652 PASS, 0 FAIL (output: side-session-notes/…/release-publish-smoke-2.out); `claude plugin validate ./plugin` → ✔ Validation passed; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → nothing (exit 1); `.jig/scripts/check.sh` → exit 0.

## Review
Hubnode's fresh reviewer, tier 2 effort 2, on aa6aaf3: 0 blocking, 2 should-fix, 5 optional — all fixed in b5db934.
- Should-fix: overlapping artifact globs passed one file twice → deduped in order (`dict.fromkeys`), used for the printed list and the rerun line; smoke check added.
- Should-fix: rerun line used the bare path when publish.sh lacks the exec bit → prefixed with `bash`; smoke check runs the printed line.
- Optional: rerun from a subfolder → the line starts `cd <quoted root> &&`.
- Optional: update skill → leave publish.sh's TODO; /jig:release asks next release.
- Optional: init skill → same.
- Optional: stale smoke text ("four scripts", update message) → five scripts, names publish.sh.
- Optional: stdout order when piped → flush before each script; smoke checks jig's line comes first.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (`## Release`, Commands), updated here, plus the release skill.

## Shared files changed
- `plugin/templates/jig/jig.py`: `cmd_release` runs publish.sh; `PUBLISH`/`PUBLISH_TODO`, `publish_script`, `add_publish`, a `STEPS` row.
- `plugin/templates/jig/RULES.md`: `## Release` paragraph (appended) and the Commands line.
- `tests/smoke.sh`: `sec_release` checks appended, the update check, and the exact `.jig/` file lists.
- `plugin/skills/update/SKILL.md`, `plugin/skills/init/SKILL.md` (added to shares in aa7367a): one line each on publish.sh's TODO.

## Test by hand
In a scratch repo with a filled release protocol: put `echo published "$@"` under publish.sh's steps, delete its TODO line, and run `jig release`; watch the echo after `released vX.Y.Z`. Then add `exit 3` and check that the printed rerun line works when pasted.

## Left
Nothing on this job. After merge and a release: this repo's own publish.sh (push, `gh release create … dist/jig-X.Y.Z.plugin`, `gh release view`) via `/jig:update`, out of scope per the spec. A metarepo keeps publish.sh's TODO line (init --meta strips only release.sh's); that's not in the spec, so I left it.
