# Handoff: bug-strikes-and-gates

Commit: eb35ee56f04c6029537c0a6051e31e7b1a71081c
Date: 2026-11-19
Spec: .jig/specs/bug-strikes-and-gates.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
- One reader of `Bug-for:`: `bug_for(text)` (a line of its own, outside fenced code via the shared `unfenced()`, a name with no `<`, `>` or spaces) and `bug_specs_at(rev, job)`. `waiting_specs`, `finished_specs` (rig, `--close`, merge's close), `cmd_open` and `bug_spec_for` all go through them. Smoke `next` fails on any other reader of the line in jig.py.
- A bug spec lifts the strike limit for the part it was written in only (`this_part`, `bug_spec_for(job, chain)`). It counts if a first-parent, non-merge commit of the part added or changed it, it names the job at the part's tip, and it didn't name the job at the part's base (a `git mv` is read under its old path). An earlier part's spec, edited or moved, lifts nothing, and the refusal asks for a new path.
- `jig next` never names merge for a gated job whose branch moved past its note. It names the ungated step, with "gated at <commit>, changed since: mark it back; review-change, handoff, gate again". `jig merge` is unchanged.
- RULES.md: the waiting-spec sentence, the strike contract, and the reason `jig open` gives for refusing a leftover bug spec.

## Done-when evidence
Spec bug-strikes-and-gates:
- [x] Quoted / `x y` / `<job>` Bug-for lines are waiting specs; a line of its own is not: smoke `rig` "a spec carrying Bug-for: is no waiting spec…" and "a spec quoting Bug-for: in fenced code, or naming no one job, is a waiting spec, in jig rig and jig consolidate" PASS. The second FAILed at v0.14.0. (They sit in `rig`, beside its rspec helpers, not in `next`.)
- [x] Strikes per part: smoke `next` k7: "part 2's third blocking review says Bug runs next, though part 1 committed a bug spec", "a bug spec from an earlier part lifts nothing: part 2's third strike is bug", "part 2's fourth review is refused, naming Bug-for", "part 1's bug spec edited in part 2 lifts nothing, and the refusal asks for a new path", "part 1's bug spec moved in part 2 lifts nothing", "part 2's own bug spec, at a new path, lifts part 2's limit". k9: draft with no line is bug; line added later lifts; line removed counts for nothing. All PASS. The k7 cases FAILed at v0.14.0 (part 2 got "review-change … strike 3"), and the edited/moved cases at 8549a87.
- [x] Gated and moved: smoke `next` k8: "a gated job with nothing since its note is still the merge" and "a gated job changed since its note is the review-change, not the merge" PASS. The second FAILed at v0.14.0 (got "merge").
- [x] RULES.md's waiting-spec sentence and strike contract say a bug spec counts for the part it was written in, by a line of its own, outside fenced code, at a new path for a later part.
- [x] `.jig/scripts/check.sh` exit 0; `bash tests/smoke.sh next workflow rig consolidate` exit 0 at 2b42b3b (125 PASS); `claude plugin validate ./plugin` ✔ Validation passed (each fix).
Spec bug-sag-one-reader:
- [x] Smoke `rig` "a spec quoting Bug-for: X in fenced code, or Bug-for: <job>, isn't finished for a job X off the board, and --close leaves both" PASS; FAILed at 2b42b3b.
- [x] Smoke `close` "merging FQ closes its own Bug-for spec and leaves a spec quoting the line in a fence" PASS; FAILed at 2b42b3b.
- [x] Smoke `close` "jig open refuses a name whose earlier job's Bug-for spec is still on trunk…" with a later trunk commit above it PASS; FAILed at 2b42b3b.
- [x] Smoke `next` "jig.py reads the Bug-for: line only in bug_for and bug_specs_at" PASS. It FAILed with main's `finished_specs` line (2b42b3b's jig.py) and with a `startswith` reader spliced in. The awk alone also exits 1 on `"Bug-for:" in text` and on `re.search(r"Bug-for:\s*(\S+)")`.
- [x] `.jig/scripts/check.sh` exit 0; `bash tests/smoke.sh next rig close consolidate` exit 0 at 8deb11f (122 PASS, 0 FAIL); `bash tests/smoke.sh next` exit 0 at eb35ee5 (43 PASS, 0 FAIL); `claude plugin validate ./plugin` ✔. `jig queue` isn't in the installed jig, so these ran directly. Outputs: the session notes folder, bug-strikes-and-gates-smoke{,-2,-3,-4,-5}.out.

## Review
- Review-work of 92214e5, 1 blocking. B: a part-2 rewrite of part 1's bug spec never counted (`--diff-filter=A` only): taken (added or changed, read at the tip). S: a draft given its line later must count, and a removed line must not: taken (k9). S: a moved gated job named a handoff that `jig handoff` refuses: taken (falls through to the ordinary steps). O: `bug_for`'s own fence parser: taken (`unfenced()`). O: a bug spec through a merge no longer counts; the skills say "is committed": deferred (DEFERRED rows).
- Review-change of 8549a87, 1 blocking. B1: editing or `git mv`-ing an earlier part's spec lifted the current part's limit: taken (the spec must not name the job at the part's base; renames mapped; the refusal asks for a new path). S1: a moved gated job could lead to merging an unchecked commit: taken (the reason says mark it back). S2: the spec no longer described the code: taken (Corrections 2-3 and Done-when amended). O2: quotePath: taken. O1: `next` and `reviewed` disagree in a part of clean syncs only: deferred (DEFERRED row).
- Review-change of 2b42b3b, 1 blocking (strike 3, Bug; spec bug-sag-one-reader). B1: `finished_specs`, brought in by the sync 5716007, had its own regex, so `--close` and merge deleted a spec quoting the line: taken (`bug_for`). S1: `cmd_open` called `bug_spec_for` with main's old signature: taken (`bug_specs_at`, RULES reason reworded). Three optional findings (rename threshold, the moved gated job's reason vs step, the `git mv` message assertion) plus the count alternative: deferred (DEFERRED rows).
- Review-change of 8deb11f, 1 blocking (strike 4, under the bug spec). B: the one-pattern guard missed `startswith`, `in` and loose regex readers: taken (the backtick one-reader check, scoped per top-level statement).
- Review-change of eb35ee5, clean. O: a reader line that also carries a backticked `Bug-for` passes the check: deferred (DEFERRED row, this commit).

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (The board: the waiting-spec sentence; Workflow: the strike contract; the `jig open` refusal's reason).

## Shared files changed
- `.jig/ledgers/DEFERRED.md`: rows for the untaken findings of each review, as the work role requires.
- `.jig/specs/bug-strikes-and-gates.md`: Corrections 2-3 and Done-when amended to match the code (review S2). `.jig/specs/bug-sag-one-reader.md`: written by the bug role, and Correction 3 and Done-when amended to the one-reader check.

## Test by hand
- In a throwaway repo, take a job to three blocking reviews, commit `Bug-for: <job>`, hand off `--partial`, and take part 2 to three strikes: `jig reviewed` refuses until a new bug spec at a new path is committed.
- Mark a job gated, commit on its branch: `jig next <job>` names review-change with "gated at …, changed since: mark it back".

## Left
- Nothing on either spec. The full suite is the check role's at the gate.
