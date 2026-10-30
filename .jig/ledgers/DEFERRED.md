# DEFERRED

Every should-fix or optional review finding not taken at handoff has a row here. Retro reads this.

| Date | Lane / handoff | Finding | Reviewer's rank | Disposition | Reason [seen/assumed] |
|---|---|---|---|---|---|
| 2026-10-30 | release.md | A metarepo with a hand-set two-part tag_pattern (not the old default, which update widens) recomputes the same tag; git tag fails after update-ref has moved trunk | optional | deferred | Only the old default pattern exists in any metarepo; init and update write it. [assumed] |
| 2026-10-30 | names | No `jig close`: an abandoned job, or one merged outside `jig merge`, leaves jobs.json only by hand-deleting its entry on trunk | should-fix | deferred | `jig merge` of a branch already in trunk deletes the entry; an abandoned job is rare in a one-user repo, and the update refusal and skill now say how to close one by hand. A command is a new feature with its own FEATURES row. [assumed] |
| 2026-10-30 | gate-order | A later note dated earlier (clock or timezone moved, two machines' local dates) sorts first, so gate and merge take the older note | optional | deferred | Notes are written by `date.today()` on one user's one machine; the name orders them as `jig handoff` wrote them. [assumed] |
| 2026-10-30 | gate-order | Smoke mixes `$(date +%F)` with jig's `date.today()`; a run crossing midnight between handoff and check fails | optional | deferred | A smoke run takes minutes; a flake at midnight is rerun. [assumed] |
| 2026-10-30 | gate-order | Solo mode on a branch with `/` (`claude/x`): `jig handoff` writes `handoffs/claude/x-<date>.md` without its folder, and `handoff_notes` matches the base name, so it never finds that note | optional | deferred | Pre-existing and outside this spec; a job's name is used instead of the branch when one is open. Its own fix. [seen] jig.py `cmd_handoff` |
| 2026-10-30 | gate-order | A note with no `Commit:` line passes merge's moved-branch check silently (it falls back to the branch itself) | optional | deferred | Pre-existing; `jig handoff` always writes the line, and gate shows the commit it took. [seen] jig.py `cmd_merge` |
