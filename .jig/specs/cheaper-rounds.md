# Rounds after the first review cost only what changed

Source: maige-ecosystem hubnode session / 2026-11-13 / Dave (staged as feedback-maige-ecosystem-2026-11-13-job-flow-speed.md): "why are these taking so long?"
Source: adventure-studio hubnode session / 2026-11-13 / Dave (staged as feedback-adventure-studio-2026-11-13-job-speed-local-checks.md): "`cp` part 1 was built, reviewed and gated three times."

## Intent
After a job's first full review, each later touch costs what it changed. A peer pair found at
the gate is answered in the note, a clean sync needs no new review, a fix gets a recheck of its
delta at the review step's settings, and DEFERRED.md is judged by its net change. Rulings reach
the owner while the job builds, and the note's form is checked at commit, not at the gate.

## Done when
- [ ] `jig gate`'s pair refusal says to answer each pair in the note's fold-in and commit it,
      and to `jig sync` only when the merge itself needs a hand. Smoke: a job whose gate finds a
      new pair commits an answered note only (no sync, no new `jig reviewed`) and the next
      `jig gate` passes.
- [ ] `jig handoff` accepts a HEAD that `counts_reviewed` counts: a clean `jig sync` merge of a
      reviewed commit writes a note with no new `jig reviewed`. A hand-resolved sync is still
      refused, naming `jig reviewed --recheck`. Smoke, both cases.
- [ ] `changed_since` judges `.jig/ledgers/DEFERRED.md` by its net diff from the reviewed
      commit to the branch, not commit by commit. Smoke: a job that edits a row and restores it
      in a later commit, net append-only, merges with no new handoff. A net deleted line still
      counts.
- [ ] `jig workflow` prints a `recheck` step. With no override it has the review step's tier and
      effort, whatever those are (an override of review moves recheck with it); a `recheck`
      override in the config wins. Smoke: the default config, a review override, and a recheck
      override each print the expected line.
- [ ] `jig reviewed --recheck --tier N --effort N` records HEAD as a recheck. It is refused
      unless a full review of the job is on HEAD's first-parent chain. `jig handoff` accepts it,
      and the note carries a `Recheck:` line beside `Review:`. `jig gate` warns when the full
      review is below the spec's `review` line or the recheck below `recheck`, and is unchanged
      for a job with no full review. Smoke.
- [ ] The review skill: a recheck reviews `git diff <last recorded review>..HEAD` against the
      previous findings, and widens to a full review when the diff changes anything the findings
      didn't name. It never reruns a check the builder's report shows for the same commit.
- [ ] The commit hook, in a job's worktree, refuses a handoff note whose fold-in answer line has
      none of `agrees`, `narrows:` or `conflicts:`, naming the line. Smoke writes such a note
      and tries the commit.
- [ ] `jig gate` warns (never refuses) when the job's diff adds a `Proposed` decision entry,
      naming each. Smoke.
- [ ] The subnode skill, and the kickoff `jig open` prints, say: when you write or change a
      `Proposed` entry, or meet a question only the owner can answer, message the hubnode then,
      with the rule sentence and the alternative you rejected, and keep building. The hubnode
      skill says: batch those to the owner while the job builds, send each ruling back before
      the job's review, and mark no job ready while its own `Proposed` entry has no ruling,
      unless the owner said to gate it as proposed.
- [ ] `jig merge J` prints each open job that holds a later number of a counter J used, and says
      it syncs before its next handoff. Smoke.
- [ ] RULES.md § Workflow names `recheck`, the clean-sync allowance and the net DEFERRED rule.
- [ ] `bash tests/smoke.sh`, `claude plugin validate ./plugin`, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- A lighter first review: the fresh, full first review stays, as the job-flow report asks.
- `jig wait`, `jig merge` removing a clean worktree, fold-in lines generated for Up next items
  and changed entries, a machine-load note: listed in the job-flow report, not taken now.
- The duplicate check runs: the review half is here; the post-merge half is `checks-and-briefs`'.

## Touches
- `plugin/templates/jig/jig.py` (`cmd_gate`, `cmd_handoff`, `cmd_reviewed`, `changed_since`,
  `review_shortfall`, `cmd_merge`, `cmd_workflow`, `WORKFLOW_DEFAULTS`, the commit hook's note
  check, the kickoff text in `cmd_open`)
- `plugin/templates/jig/RULES.md` § Workflow, § Handoff
- `plugin/skills/review/SKILL.md`, `plugin/skills/subnode/SKILL.md`,
  `plugin/skills/hubnode/SKILL.md`
- `tests/smoke.sh` (a new `cheaper-rounds` section)

## Alternatives considered
- Recheck at a fixed tier 3, effort 3, as the report proposed — rejected by the owner: review's
  tier may change, and a hard-coded value would not follow it — [seen] in the owner's call.
- A sync before review, always — rejected because the job can't know which neighbour lands
  first; the clean-sync allowance gets the same saving without ordering — [assumed].
- The hubnode reading a fix diff in place of a recheck — rejected because the hubnode does no
  reviews (hubnode skill: "Do not re-review the diff") — [seen].
- Refusing at `mark ready` on an unruled `Proposed` entry — rejected because a job may be gated
  as proposed on the owner's word; the gate warns and the skill holds the rule — [seen] in
  adventure-studio's report.

## Decisions
- Calls the owner made on 2026-11-13: recheck follows review's configured settings, nothing
  hard-coded; the gate's pair message changes; DEFERRED net judging; the clean-sync allowance.
- Interpreted: a recheck is a `jig reviewed` record with a kind, in the same marker and log, so
  `counts_reviewed` and the metarepo's gate read it with no new file.
- Interpreted (hubnode accepted, 2026-11-13): the gate's Proposed warning covers entries the
  job adds or changes that are still Proposed, since the subnode rule covers changed ones too.
- Interpreted (hubnode accepted, 2026-11-13): a spec with no `recheck:` Workflow line is judged
  against its `review:` line, since recheck defaults to review's settings.
- Interpreted: a hand-resolved sync takes a recheck of the resolution, which is what this
  session did by hand three times (`--ran "(hubnode read of the conflict resolution only)"`).

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
