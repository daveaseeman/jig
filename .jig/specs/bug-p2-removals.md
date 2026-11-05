# Bug: P2 doesn't see a delete or a rename's old side

Source: bug-numbered-pointers investigation / 2026-11-05 / Dave Seeman (owner asked to spec it): P2's contract-path check doesn't see deletes or the old side of a rename; `git mv api/a.py lib/a.py` and `git rm api/a.py` on a contract path commit with no meta: question.

## Intent
Deleting a guarded path, or renaming it away, counts as changing it. That holds for every rule that
guards a path, not only P2. A pararepo's `jig update` lists the contract removals an older P2 let
through unanswered, and offers each one a buffer row.

## 1. Why
1. Why did `git rm api/a.py` commit with no question? P2 matches `contract_paths` against `changed_paths`, and that list has no deletes. [seen]
2. Why no deletes? `changed_paths` diffs with `--diff-filter=ACMRT` and rename detection on. It lists what the change writes, and a rename shows only under its new path. [seen]
3. Why is that wrong? One list serves two kinds of rule. R7, M1 and P3 judge what a change writes. R3–R5, P1, P2 and P4 guard paths, and those need the removed side. *(Root.)* [seen]

## 2. Givens
Reproduced Nov 5 with `plugin/templates/jig/jig.py` at 3b0ed48, which hasn't changed since v0.6.0. The throwaway repos were:
a metarepo `mm`, a pararepo `app` with `contract_paths: ["api/**"]`, and a plain repo with job A
owning `src/ui/**` and job B owning `src/core/**`.
- `[seen]` These commit with no refusal. The control edit of each path is refused.
  - P2: `git mv api/a.py lib/a.py` and `git rm api/a.py`. `git mv api/a.py api/c.py` is refused, because the new side matches.
  - P4: `git rm api/b.py` while a file for `mm` waits in `.jig/staging/`.
  - P1: `git rm AGENTS.md` and `git mv AGENTS.md DOCS.md`. `para_problems` reads trunk's AGENTS.md, so the next release refuses them [read].
  - R3, in A: `git rm other/o.py` and `git mv other/o.py src/ui/o.py`. R4: `git rm src/core/b.py` and `git mv src/core/b.py src/ui/b.py`. R5: `git rm .jig/config.json`.
  - M4, on `mm`'s trunk: `git rm docs/x.md` and `git mv docs/x.md .jig/x.md`. The next release refuses the rm, but not the move.
- `[seen]` These behave correctly today. Untracking a tracked `.jig/meta-cache/PIN` commits (P3), and a metarepo branch can remove a code file (M1). Both removals *are* the fix.
- `[seen]` R7 errs the other way. A plain `git mv` of a file that has a `WORKAROUND:` comment is refused: `git diff -U0 -- <new path>` can't pair the two paths, so every line reads as added.
- `[seen]` Fold-in and open. After A moved `src/ui/a.py` to `src/ui2/a.py`, `git diff --name-only main...A` lists only the new path, and `--no-renames` lists both. `foldin_lines` and `cmd_open` use the first form. `jig open C --owns src/ui/a.py` was accepted.
- `[seen]` Prototype in a scratch clone: R3–R5, P1, P2 and P4 read `git diff --name-only --no-renames`. Every case above is then refused, and all 523 smoke cases pass.
- `[seen]` What the bug leaves behind. Pararepo `po` was built from v0.6.0's templates.
  - Its own hook commits `git mv api/a.py lib/a.py` and `git rm api/b.py`.
  - `git log -M --name-status --diff-filter=DR` names both commits.
  - The plugin's `jig update` says "up to date".
- `[seen]` The real pararepos, read only.
  - In the reporting pararepo, three commits since para.json's adoption removed contract paths while nothing on their new side matched, so P2 never asked. One mass rename, one deleted module, one folder move.
  - Each of the three has a spec with `meta: none — …` in the same commit. One of those specs records this hole.
  - A prototype sweep that checks for an answer lists none of them, nothing in the other pararepo, and both of `po`'s removals.
  - All three predate the reporting pararepo's last two pin bumps.

## 3. One layer up
`changed_paths` callers: should a removal count, and does it?
- **R3, R4, R5** (`check_rules`): should, doesn't (Givens).
- **R7**: shouldn't, since a delete adds no comment. It doesn't. A rename over-counts (Out of scope).
- **M1, M2** (`meta_rules`): shouldn't, doesn't. Correct.
- **M4**: should, doesn't. `meta_problems` catches a delete at release and pre-push (Out of scope).
- **P1** (`para_rules`): should, doesn't. Release already refuses it, so the hook and the release disagree.
- **P2 contract, P4**: should, don't. This is the bug.
- **P2 answers** (specs, BUFFER rows): shouldn't. A deleted spec answers nothing, and a deleted ledger is read from the base. Correct.
- **P3**: shouldn't, doesn't. Correct.

Other places that judge what a change touches:
- **R6, M3, release's entry check, P2's pointer check**: `--no-renames`, so they count removals. Correct.
- **`meta_problems`**: no filter. A delete counts; a move into `.jig/` reads as `.jig/` only.
- **`foldin_lines`, `cmd_open`'s owns check**: no filter, renames on. A delete counts, a rename's old side doesn't. Should.
- **`changed_since`** (M5, merge): only checks whether the list is empty. A rename's new side keeps it non-empty. Counts.
- **`unreleased_proposals`; `--diff-filter=U`** in merge and sync: a spec's citations, and conflicted files. Correct.
- **update**: reads `ls-files` and file contents. Numbered-pointers adds `log --diff-filter=D` plus `show -M`, which sees both sides.

Existing pattern: the `--no-renames` diffs above ("a cited file deleted, or moved out of the entry set, is a change too").

## 4. Correction
- **Two views.** `changed_paths(trunk, staged, removed=True)` is `--no-renames` with no filter. That covers every path the change adds, edits or removes, and it is what P2's `diffed` is today. The default stays as it is.
- **Path guards read the removed view:** R3, R4, R5, P1's trigger, P2's contract test and P4. Content rules keep the default: R7, M1, M2, P3, and the spec and ledger answers.
  - In R3, a removed path existed on trunk, so it must be in owns, shares or common. A rename's new side is still new to the repo.
- **Fold-in** diffs with `--no-renames`, so the page covering a moved file's old path is asked too. UNOWNED lists only paths at HEAD.
- **Open's owns check** diffs with `--no-renames`.
- **RULES.md.**
  - Under The rules, one sentence: a delete changes its path, a rename changes both, and R3–R5, P1, P2 and P4 count each.
  - P2's row: "a contract-path change (an edit, a delete, or a rename from one)".
  - Fold-in: a moved file asks its old page too.
- **Cleanup, in a pararepo's `jig update`.** A "Contract removals" block, shown under the same conditions as "Metarepo pointers".
  - **Range.** Every non-merge commit on trunk whose parent has para.json (at `PARA` or its LAYOUT old name). Each is judged by that para.json's `contract_paths`, which is what P2 read then.
  - **Listed** when the commit's removals (deletes and renames' old sides, from `show -M --name-status`) match those globs, and every one of these holds:
    - nothing the commit writes matches them. Otherwise P2 asked, and its answer covers the commit;
    - no spec that the commit changed, or that the branch whose merge brought it changed, has a `PROPOSAL` line. Specs are read at `.jig/specs/` and at their LAYOUT old names;
    - the commit adds no Open row;
    - no row in trunk's `BUFFER.md`, Open or Closed, names the path;
    - no Metarepo pointers line already has the path.
  - **The line.** One per commit: `<hash> <subject>: api/a.py → lib/a.py; api/b.py deleted`. It offers one `BUFFER.md` row. Claim: the contract at the pin, for the old paths. Now: moved or deleted, plus the hash. A new path outside today's `contract_paths` adds: "add it to contract_paths if it still holds the contract".
  - **Writes nothing.** The row is added only on the owner's yes, through the update skill. `contract_paths` is the owner's.
- **Shared with numbered-pointers.** Its commit lookup becomes `removed_by(commit) -> [(old, new|None)]`, and both blocks call it. So do "a row already names it" and the row-offer wording. The blocks stay separate because their sources differ: one reads the cache, the other this repo's history and `contract_paths`. A contract file the metarepo never names still needs its row.
- **Other callers' leftovers.**
  - R3–R5 and open coordinate open jobs. Update refuses while jobs are open, and what those rules let through was later gated and merged. Nothing is left to name.
  - M4 and P1 are swept already, by release and pre-push. P4's misses are P2's commits.
  - Fold-in: see Out of scope.

## Done when
Section `removals` in `tests/smoke.sh`, listed in `UNITS`.
- [ ] Symptom gone. In pararepo `rp` (`contract_paths: ["api/**"]`):
  - `git mv api/a.py lib/a.py` is refused naming `P2 api/a.py`, and `git rm api/b.py` naming `P2 api/b.py`;
  - each commits with a spec carrying `meta: none — …`.
- [ ] More of `rp`:
  - `git rm api/b.py` while a file for the metarepo is staged is refused naming P4;
  - `git rm AGENTS.md` is refused naming P1;
  - untracking a tracked `.jig/meta-cache/PIN` commits.
- [ ] In a plain repo with jobs A (`src/ui/**`) and B (`src/core/**`), each of these, run in A, is refused naming its rule:
  - `git rm other/o.py` and `git mv other/o.py src/ui/o.py` (R3);
  - `git rm src/core/b.py` and `git mv src/core/b.py src/ui/b.py` (R4);
  - `git rm .jig/config.json` (R5).
  - `git rm src/ui/w.py` commits.
- [ ] A metarepo branch that removes a code file committed with `--no-verify` commits (M1).
- [ ] Fold-in and open:
  - after A moves `src/ui/a.py` to `lib/a.py` (in its shares), `jig handoff`'s note asks `docs/ui/ui.md` and `docs/lib/lib.md`;
  - a moved source file that no page covers is UNOWNED under its new path only;
  - `jig open C --owns src/ui/a.py` is refused, naming job A.
- [ ] The cleanup. Build `po` from v0.6.0's templates (`git -C "$JR" archive v0.6.0 plugin/templates`), with `contract_paths: ["api/**"]`.
  - Under its own hook these all commit, which is the bug, reproduced in the fixture: `git mv api/a.py lib/a.py`; `git rm api/b.py`; `git rm api/c.py` with a spec saying `meta: none — …`; `git rm api/d.py` with an Open row naming `api/d.py`.
  - Then `$UP` (a dry run) prints `Contract removals`, with a line for the move naming its short hash, `api/a.py → lib/a.py`, that `lib/a.py` isn't a contract path, and `BUFFER.md`.
  - A line names the drop's short hash, `api/b.py deleted` and `BUFFER.md`.
  - No line names `api/c.py` or `api/d.py`. Afterwards `git status --porcelain` is empty.
- [ ] After an Open row naming `api/b.py` is committed, `$UP` offers no row for it. `$UP --apply` leaves `BUFFER.md` as it was.
- [ ] A removed contract path that a cached pointer names (`` `po/api/a.py` ``) prints under Metarepo pointers, not under Contract removals.
- [ ] `grep` finds RULES.md's sentence on removals and P2's "a delete, or a rename from one".
- [ ] `bash tests/smoke.sh`, `claude plugin validate ./plugin` and `.jig/scripts/check.sh` pass, output shown.

## Out of scope
- **M4 and `meta_problems`.** Pre-push and release already refuse a delete on trunk [seen]. With the removed view, both would also refuse `jig update`'s own moves out of `jig/` on a metarepo's trunk. A fix there must first learn LAYOUT's old names, so it is a change of its own. The move into `.jig/` that they miss isn't an ordinary mistake.
- **R7 refusing a plain rename.** It errs toward asking, and the ledger row names the file, but the message ("adds a … comment") is wrong. Its own bug.
- **Deleting `para.json`.** That leaves the metarepo, which is a choice, not a mistake.
- **Fold-in leftovers.** A page that was never asked about may still describe a moved file. Only a reader can tell, so update doesn't sweep for it.
- **A removal answered outside a spec**, such as a proposal made in the metarepo by hand. History can't see it, so the owner declines the offered row.

## Touches
- `marketing/FEATURES.md` (gitignored), first. Rows: "R3 only owned/shared/new files", "R4 another lane's `owns` wins", "R5 board is the hubnode's", "Pararepo gates P1–P3", "`docmap` + fold-in", "`open`", and both "`update`" rows (the skill and the command).
- `plugin/templates/jig/jig.py`:
  - `changed_paths`;
  - `check_rules` (R3–R5);
  - `para_rules` (P1, P2, P4; `diffed` becomes the new call);
  - `foldin_lines`;
  - `cmd_open`;
  - `cmd_update`'s `report()`, plus `contract_removals` (new);
  - `removed_by`, from numbered-pointers' lookup.
- `plugin/templates/jig/RULES.md`: The rules, P2's row, Fold-in.
- `plugin/skills/update/SKILL.md`: one line beside numbered-pointers' paragraph. A Contract removals row is added only on a yes, and `contract_paths` too.
- `tests/smoke.sh`: `removals`, and `UNITS`.

**Coordination.** This is its own job, opened `--after` numbered-pointers.
- It reuses that job's history lookup and row offer, and it edits the same `diffed` line and P2 row. Built in parallel, the two would conflict on those.
- Merged into it, one job would span the resolver, every path-guard rule and two update blocks: too big for one review at tier 2.
- doc-homes also edits `report()`, in a separate block. slash-branch touches `cmd_handoff`, not `foldin_lines`.

## Alternatives considered
- **Add `D` to `--diff-filter` for every caller.** Rejected: M1 would then refuse removing code from a metarepo, and P3 untracking the cache, which are both the fix. Reason is [seen].
- **Fix P2 only**, with its own `--no-renames` diff. Rejected: R3–R5, P1 and P4 have the same hole. Reason is [seen].
- **Sweep with no answer check.** Rejected: all three of the reporting pararepo's slipped removals carry `meta: none`, so the sweep would offer three wrong rows. Reason is [seen].
- **Sweep only since the last pin bump.** Rejected: that misses all three, and a bump doesn't mean the metarepo saw them. Reason is [seen].
- **Sweep in `jig sync`.** Rejected: update brings the fix, as in numbered-pointers. Reason is [assumed].

## Decisions
- **One row per commit, not per path.** A deleted module is one change to the metarepo.
- **A Closed row suppresses too.** The metarepo released it.
- **No STAMP bump:** no LAYOUT row, default or STEP is added.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
