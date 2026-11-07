# Handoff: redocument

Commit: 15968cc7c66ccd73e2e987f05f6f8eaf0ddf0ec9
Date: 2026-11-07
Spec: .jig/specs/redocument.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown, fresh context (subagent; effort set to high, not readable by the subagent); four rounds, last at 3f9f692; its should-fix (pointer_cleanup pin check) and optionals fixed by 15968cc

## Built
`/jig:redocument` (`plugin/skills/redocument/SKILL.md`, user-only): migrates a jig repo's `docs/`
from Now/Rules/Checks pages to the descriptive page contract. The hubnode refuses on no old pages
or a busy board, resumes from `.jig/redocument.md`, seeds a remap from survey that the owner
approves, opens one job per surviving page with a spec of its own, writes docmap from each
handoff's conversion report, and cleans up in one change (old docs, docmap keys, references), with
survey clean after. The subnode traces, never invents, applies the four-fate rubric and writes a
clean/flagged conversion report in its note. In a pararepo the remap marks cited pages and
headings, and a `pointers` branch carries the pointer rewrites.

jig changes it needed (`jig.py`, `RULES.md`):
- P2 reads the job's own spec from trunk, including at the gate's scratch merge and at `jig merge`,
  for one job only.
- P2 has a fifth answer, `meta: <name> pointers <branch>` (`jig propose --pointers`). The gate checks
  the branch exists and doesn't wait for a release.
- Update's Contract removals and Metarepo pointers read the same answers.
- `jig sync` lists pointers branches.
- Survey's footer points at /jig:redocument.
- README, and the survey, review, spec and update skills, are updated to match.

## Done-when evidence
- SKILL.md carries the remap table, Sources, the four fates, never-invent, and the clean/flagged
  report: see `plugin/skills/redocument/SKILL.md`. `claude plugin validate ./plugin` → `✔ Validation passed`.
- Dry run → remap proposal from survey output, and both refusals and the resume: `bash
  tests/redocument-fixture.sh` → exit 0, output below.
- Survey footer: smoke `page contract: survey points a repo with old-contract pages at
  /jig:redocument` and `... an old-format page outside the docs tree points at /jig:redocument too` → PASS.
- P2's job-spec answer on the branch, at gate and at merge, one job only: smoke `para P2: …` cases
  (pj/pk/pl, the stacked and octopus cases) → PASS.
- `pointers`: smoke `propose --pointers …`, `para gate: …` (exists, missing, another metarepo,
  merged and unreleased, unreachable) and `update: …` (pending, pinned-and-missed, none-answered,
  covered removal) → PASS.
- `bash tests/smoke.sh` at 9d20fab → exit 0, 641 PASS, 0 FAIL. 15968cc changes only skill text.
  `.jig/scripts/check.sh` → exit 0. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → nothing.

Fixture output (`tests/redocument-fixture.sh`, from survey on):

```
-- before starting
start: old-format pages found, board quiet
-- remap seed (step 1), proposed to the owner as the step 2 table
| Old path(s) | New path | Verb | Notes | Cited |
|---|---|---|---|---|
| `docs/store/store.md` | `docs/store/store.md` | rewrite | old contract at home: in place, the job owns it |  |
| `docs/notes/sync.md` | `docs/sync/sync.md` | move | outside the docs tree; survey's destination — ask whether it nests as a subsystem |  |
| `docs/ideas.md` | — | drop | stray, 0 inbound — owner's call: drop, or fold into a page |  |

== refusal: no old-format pages
no old-format pages: nothing to redocument

== refusal: another job open
trunk: main
  feature              claimed   behind:1 clean  handoffs:0  after:-
jobs open: feature; redocument runs on a quiet board

== resume: the remap is on trunk and the run's own job is open
trunk: main
  store                claimed   behind:1 clean  handoffs:0  after:-
resume: .jig/redocument.md is on trunk; refusals skipped

== resume: every page rewritten in place, before cleanup
survey: no old-contract page left
resume: .jig/redocument.md is on trunk; refusals skipped

== pararepo: a metarepo decision cites the store page's Rules heading
-- the cache grep
.jig/meta-cache/DECISIONS.md:7:| D-001 | the store rule (`app/docs/store/store.md § Rules`) | accepted (owner) | 2026-11-01 |
-- remap seed, with Cited
| Old path(s) | New path | Verb | Notes | Cited |
|---|---|---|---|---|
| `docs/store/store.md` | `docs/store/store.md` | rewrite | old contract at home: in place, the job owns it | § Rules |
| `docs/notes/sync.md` | `docs/sync/sync.md` | move | outside the docs tree; survey's destination — ask whether it nests as a subsystem |  |
| `docs/ideas.md` | — | drop | stray, 0 inbound — owner's call: drop, or fold into a page |  |
-- at approval: the pointers spec and its pointers branch
made propose/app-redocument-pointers in hm and recorded it in .jig/specs/redocument-pointers.md.
-- the page rewrite alone: the job's spec on trunk answers P2
committed: P2 answered by meta: hm pointers propose/app-redocument-pointers
-- hand off, gate and merge store, the pointers branch unreleased
job store: gate 58c3a3a5737c from .jig/handoffs/store-2026-11-07.md on store
merged store; its entry is gone from .jig/jobs.json in the same commit. Sync the clean jobs.
```

## Review
Four rounds by the hubnode, fresh context, recorded at 15968cc (tier 2, effort 2). Everything
blocking and every should-fix is fixed.
- Round 1 (4599685), should-fix A–E:
  - cleanup removes docmap keys and repoints references, with an end check, after `/jig:update`;
  - a cleanup job route, required in a metarepo;
  - resume from the remap on trunk;
  - subnodes read the skill by its absolute path;
  - a spec per job, and the conversion report in the handoff note.
  Also: the fixture script as the Done-when evidence, the survey footer, the spec's Touches and
  Decisions, and the pararepo gap, which the owner then decided (cited pages marked, a metarepo
  branch opened at approval).
- Round 2 (286fd59):
  - Blocking B1: the job-spec answer failed at the gate and at `jig merge`. P2 now resolves the job
    from the side of the merge trunk lacks.
  - Blocking B2: a deadlock with the gate's unreleased-proposal rule. Owner's decision: Option A,
    below.
  - S1: decline update's moves of old-contract pages. S2: the footer for pages outside the tree.
    S3: the refusal text names the job's spec. S4: the cache grep uses every repo name. S5: resume
    before the branch opens.
- Round 3 (feae407), should-fix 1–5:
  - one job per merge (a stacked job or an octopus gets none);
  - `trunk_answers` shared by update's two blocks;
  - a merged, unreleased pointers branch passes;
  - the review and spec skills know `pointers`;
  - the spec brought in line with the code.
  Optionals: `jig sync` lists pointers, plus the unreachable-metarepo case and the FEATURES wording.
- Round 4 (3f9f692), should-fix: `pointer_cleanup` checks the pin. A pointer still dangling once the
  pin holds the branch gets the offer, naming the missed rewrite. Optionals: skip a foreign
  metarepo's answer, a none-answered case, the update skill's text, the spec's Touches.

Owner's decisions:
- P2 reads the job's spec from trunk ("strictly stronger: the answer comes from trunk").
- Option A: `meta: <name> pointers <branch>`, with a mandatory branch check at the gate, over B
  (a `none` naming the proposal in prose) and C (every job waits for the release).

Deferred, each with a row in `.jig/ledgers/DEFERRED.md`:
- a pointers branch only on a remote-tracking ref;
- `base()` judging a job's auto-committed merge of a sibling branch against trunk (should-fix,
  owner's wording, with the open question about stacked jobs);
- `trunk_answers` counting any `buffered` row;
- a hand merge deleting the entry later;
- `jig sync` not reading one-line specs;
- the three places a job's spec is read from;
- the generated AGENTS.md header.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — add to docmap, or no page needed because this repo has no `docs/` pages and an empty docmap; jig.py's behaviour is documented in `plugin/templates/jig/RULES.md`, updated in this change (P2's row, Pointers ahead of the metarepo, the gate sentence, `jig propose --pointers`)

## Shared files changed
- `README.md`: the skill in the list, a usage block, the user-only list.
- `tests/smoke.sh`: the user-only set, the survey footer, and the P2, gate, sync and update cases.
- `plugin/templates/jig/jig.py`, `plugin/templates/jig/RULES.md`: P2's job-spec and `pointers`
  answers, the gate check, update's readers, sync's listing, the survey footer.
- `plugin/skills/survey/SKILL.md`, `review/SKILL.md`, `spec/SKILL.md`, `update/SKILL.md`: point at
  /jig:redocument, and know the `pointers` form.
- `.jig/specs/redocument.md`: Touches, Alternatives and Decisions, as amended through the reviews.
- `.jig/ledgers/DEFERRED.md` (common): the deferred rows above.

## Test by hand
In a throwaway repo with old Now/Rules/Checks pages, type `/jig:redocument` as the hubnode.
Watch it refuse with another job open, propose the remap table, and write `.jig/redocument.md`
on approval. Then check that a subnode's kickoff carries the skill's absolute path.

## Left
Nothing for this job. Not run on any real repo (out of scope: the owner's call). The `base()`
stacked-job question waits on the owner, in DEFERRED.
