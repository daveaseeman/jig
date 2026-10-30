# DEFERRED

Every should-fix or optional review finding not taken at handoff has a row here. Retro reads this.

| Date | Lane / handoff | Finding | Reviewer's rank | Disposition | Reason [seen/assumed] |
|---|---|---|---|---|---|
| 2026-10-30 | release.md | A metarepo with a hand-set two-part tag_pattern (not the old default, which update widens) recomputes the same tag; git tag fails after update-ref has moved trunk | optional | deferred | Only the old default pattern exists in any metarepo; init and update write it. [assumed] |
