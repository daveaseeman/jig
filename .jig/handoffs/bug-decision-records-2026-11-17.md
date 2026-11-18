# Handoff: bug-decision-records

Commit: a7ec65b4578d4270a5e70c16602dfc00cacc3b36
Date: 2026-11-17
Spec: .jig/specs/bug-decision-records.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
A folder of decision records (the ADR layout adr-tools and MADR write) is a decision register:
`jig init` writes no seed log beside it, `jig update` lists it, survey counts its files at home
and maps it to the log, and `jig update --merge-log` turns each record into a log entry with the
next id, into an empty log or one already in use (Issue 2). Citations of records in Markdown
files are rewritten to the new ids in the same change; history and non-Markdown files are left
and listed. The hook lets converted entries in without `Touches:` when the same change removes
their records. RULES.md (Homes, Before the log, Commands), the update skill and the adopt skill's
ADRs row say so. Smoke `merge_log` has 23 new checks.

## Done-when evidence
- Fixture R init/update: smoke "init writes no log beside a folder of decision records, and names the folder", "update lists the folder to review" PASS.
- Survey: "survey lists none of the folder's five files as homeless, and maps the folder to the log", "a plain repo's DECISIONS.md with rows is no stray either" PASS.
- `--apply --merge-log` on R: "D-001 to D-003 in number order …", "the log reads three entries, each with its Context paragraph …", "the records and the index are gone, the template kept and listed", "the page cites D-001 and D-002; the handoff still says record 0001", "the run's output commits unedited through the hooks" PASS.
- adr-tools and MADR: "… list as record folders; numbered guide chapters don't", "both convert: Superceded read from adr-tools' link, MADR's who from decision-makers …", "their output commits unedited" PASS.
- Issue 2: "a log in use: the dry run … appends D-003 to D-005", "D-003 to D-005 come after D-002, which with D-001 stays byte for byte", "the output commits unedited, and a second run has nothing to merge" PASS.
- Refusals: "ended, a missing superseder and a numbered file with no status are refused, naming each, writing nothing", "a record naming a spec is listed as a line the hook would refuse" PASS.
- Daisy snapshot (git archive of its trunk in a scratch repo, this jig.py): survey lists nothing under docs/decisions/ as homeless; `jig update` lists `docs/decisions/: a folder of decision records, 82 records`; the `--merge-log` dry run prints `appends D-072 to D-152` (log's highest D-071), `reserve.record: files ['docs/decisions/README.md'] → [.jig/decisions.md]`, lists `daisy/tests/test_comments.py:214: not a document, change by hand`, and refuses `docs/decisions/0025-lanes-skill-unchanged.md: status \`ended\``. Output: bug-decision-records-daisy-dry-2.out in the hubnode's notes folder.
- `.jig/scripts/check.sh` rc 0; `claude plugin validate ./plugin` Validation passed; `grep -rnE 'Daisy|daisy' plugin` 0 lines; `bash tests/smoke.sh merge_log decisions homes update` rc 0, 291 PASS, 0 FAIL (bug-decision-records-smoke-2.out).

## Review
Review-work of 6eb5fe1: 2 blocking, all fixed in 66d472f.
- BLOCKING: any status word made a numbered folder a record folder (migrations `applied`, book chapters `draft`). Fixed with the rule recorded in the spec's Decisions (work's reading, accepted by the hubnode): two numbered files with a status jig reads, one of them decided. Smoke covers both false folders.
- BLOCKING: the board wasn't rewritten for a kept index, or after a merge on a branch. Fixed: the index goes to `board_rewrite` kept or not; `stale_board_names` treats a gone record, or an index with no record links in a folder that lost records, as stale. Smoke covers both.
- should-fix: `records_converted` admitted any deleted numbered file. Fixed: it must have been a record in a record folder at `since_trunk`, claimed once. Smoke: a guide chapter's entry without Touches is refused.
- should-fix: relations (`amended by 0033`, `Amends 0001 and 0002`) inside converted entries. Fixed: mapped to ids, unmapped ones listed.
- should-fix: citations rewritten in code files. Fixed: Markdown only, others listed; the hubnode's reading is in the spec's Decisions.
- optional: refusal ordering taken (stdout flushed first); link to the new entry not taken (no anchor form in RULES.md), DEFERRED row.
Review-change of 66d472f: 0 blocking. Its two should-fix findings (`stale_board_names` doesn't check the log holds a converted entry; `RECORD_RELATE` maps prose numbers silently) and its optional findings are DEFERRED rows: the should-fix round is used, by the owner's rule.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Documentation § Homes; Decision log, Before the log: the folder of decision records passage; Commands).

## Shared files changed
- `plugin/templates/jig/jig.py`: the reader and merge live beside `log_sources` and `cmd_merge_log`; `doc_homes`, `COORDINATION`, `stale_board_names` and the hook's `touches_problems` needed one change each.
- `plugin/templates/jig/RULES.md`: Homes gains a bullet, Before the log gains a passage after its last paragraph, Commands one line.
- `tests/smoke.sh`: new checks appended at the end of `sec_merge_log`.
- `plugin/skills/update/SKILL.md`: a paragraph after the merge paragraph. `plugin/skills/adopt/SKILL.md`: the ADRs row.

## Test by hand
In a copy of a repo with `docs/decisions/` (or Daisy's snapshot): `jig update --merge-log` and read the ids it appends, the citations it rewrites and leaves, and the hook lines; fix any refused status with the owner; `--apply --merge-log`, edit the listed lines, commit.

## Left
Nothing on this spec. The DEFERRED rows dated 2026-11-17 for bug-decision-records are the follow-ups: `stale_board_names`' log check, and the stricter number match in relations.
