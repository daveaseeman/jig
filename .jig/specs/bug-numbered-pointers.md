# Bug: a numbered `§` pointer never resolves, so P2 stops guarding it

Source: Claude Code session (maige-ecosystem hubnode) / 2026-11-04 / Dave Seeman + Claude (staged as feedback-maige-ecosystem-2026-11-04-section-number-pointers.md): "Every numbered pointer reads as dangling." and "P2 lets a rename through", although a cached metarepo pointer names the renamed file.

## Intent
A pointer's `§2` or `§2.1` names the heading with that number, as RULES.md's Documentation rule
cites rules. P2 counts the loss of a pointer's file even when its heading was already missing.
A pararepo's `jig update` lists what the old P2 let through, each with its fix.

## 1. Why
1. Why did the rename commit without a `meta:` question? P2 only counts a pointer that resolved at the base. A `§N` pointer never resolves, so losing its file isn't new.
2. Why doesn't `§2` resolve to `## 2. Motes`? A section matches heading words: the whole text of a code span, or in prose a heading the text starts with. "2" is neither.
3. Why are pointers numbers? The Documentation rule makes the number the heading and the citation. The pointer rule matches words only. RULES.md contradicts itself. *(Root.)*

## 2. Givens
Reproduced Nov 5 with `plugin/templates/jig/jig.py` (e6ac7f5, which is 0.6.0), in a throwaway
metarepo `mm` and pararepo `app` built the way `sync_buffer` builds them. `app/docs/x.md` has
`## 2. Motes`, `### 2.1 Identity` and `## 10. Open questions`.
- `[seen]` `jig sync` reports `§ 2.1`, `§ 2` and `§ 3` against x.md, all three "has no heading for". Only `§ 3` really dangles.
- `[seen]` The display is wrong in two ways:
  - a prose `§1.2 (cited by path …` prints `§ 1`;
  - a prose `§1 (cited by path until app has release tags, which …` prints `§ 1 (cited by path until app has release tags`.
  - The cause is `shown = re.split(r"[.,;:)|]", want)[0]`: it cuts at `.` and never at `(`.
- `[seen]` P2 results:
  - committed with no question: `git mv docs/x.md docs/y.md` (only numbered pointers name it), and deleting `### 2.1 Identity`;
  - refused: renaming `docs/r.md`, which a whole-heading pointer `` `app/docs/r.md § Rules` `` names, and renaming that heading;
  - committed: `git rm docs/g.md`, whose one pointer `` `§ Gone` `` was already missing. P2 tests `not pointer_gap(…, body_at(base(trunk), path))` first.
- `[seen]` What the bug leaves behind, after the x.md rename went through:
  - `jig sync` printed "points to docs/x.md, which this repo doesn't have" three times, one line per pointer.
  - `git log -1 --diff-filter=D -- docs/x.md` gives the commit, and `git show -M --name-status <it>` gives `R100 docs/x.md docs/y.md`.
  - `git log -1 -G '^ {0,3}#{1,6}[ \t]+4([. \t]|$)' -- docs/w.md` gives the commit that removed `## 4. Keys`, and `## 40 Other` doesn't match.
  - The plugin's `jig update` said "up to date" and listed nothing.
- `[seen]` `cmd_update` replaces `.jig/jig.py` whenever its bytes differ from the plugin's, so the first update to a fixed copy always prints its report. Today the report reads nothing of the metarepo.
- `[seen]` RULES.md has the two rules that conflict:
  - Documentation: "Number every rule; the number is the heading (`### 31.1 …`), so a citation resolves by search".
  - What the metarepo holds: in a code span, "the section is the span's text, matched whole; in prose it is any heading the text after `§` begins with".
- `[seen]` I read the real repos without writing to them. A probe ran the plugin's resolver over the metarepo's v1.1.0 entry files.
  - Six cached `` `maige-os/docs/ARCHITECTURE.md §N` `` lines (`§2` ×2, `§3`, `§4`, `§6`, `§10`) fail today and resolve under a number match.
  - Four `maige-lite/docs/systems/ui.md §1` pointers fail either way. That page has `## Rules` and `### 1.1`–`### 1.8`, and no heading numbered 1.
- `[seen]` Nothing in the real repos was left behind by the bug:
  - Since Maige Lite took 0.6.0 (d7a4e76), no commit there has deleted or renamed a file the metarepo names.
  - The metarepo has no whole-heading rewrites of pararepo pointers.
  - Maige OS is on layout 8, which predates the pointer checks.
- `[seen]` Maige Lite's other dangling pointer, `specs/walyt-alpha-demo.md`, names a path that repo never had: the spec was added at `.jig/specs/`. Some pointers are simply wrong in the metarepo, and no P2 let them through.
- `[seen]` Sibling hole: with `contract_paths: ["api/**"]`, both `git mv api/a.py lib/a.py` and `git rm api/a.py` commit with no question. `changed_paths` uses `--diff-filter=ACMRT`.
- `[assumed]` Any pararepo that follows the Documentation rule gets cited by number. The reporting metarepo's AGENTS.md says to link `<repo>/<path> §n`. The fix doesn't depend on this.

## 3. One layer up
- **Sibling (same P2):** the pointer check diffs with `--no-renames`, so deletes and renames count for it. The contract-path check uses `changed_paths`, which drops both. That is the same hole with a different cause (Out of scope).
- **Sibling readers:** `jig sync` and `jig release` report through `stale_pointers`, while update reads nothing of the metarepo. The cleanup reuses the same resolver.
- **Existing pattern:** `changes_report` matches decision ids as whole words (`git grep -w`), so `D-1` isn't `D-12`. Matching a section number as a whole token works the same way: `2` isn't `2.1` or `20`.

## 4. Correction
Fix the resolver so the two RULES.md rules agree. A workaround in each repo would mean rewriting
every numbered pointer, against the Documentation rule.
- **Resolve numbers.** A section that starts with a number, `N` or `N.M`, names the heading whose leading number is exactly that token.
  - `§2` is `## 2. Motes`. It is not `### 2.1 …` and not `## 20 …`.
  - Any words after the number aren't compared.
  - Any other section is matched as it is today.
- **P2 compares levels.** The levels are: resolves, heading missing, file missing. A pointer is newly broken when its level is worse now than at the base.
  - Losing the file counts even when the heading was already missing.
  - An edit that leaves a missing heading missing doesn't count.
- **Display.**
  - A number prints whole: `§ 1.2`.
  - Words are cut at `(`, `,`, `;`, `:`, `)` or `|`, or at a `.` that ends a sentence. A `.` inside a token never cuts.
  - Each dangling line prints once.
- **Cleanup, in `jig update` in a pararepo.** Update's report gets a "Metarepo pointers" block, built from the cache as the last `jig sync` left it. Update changes none of the pointers. There is one line for each pointer that dangles under the fixed resolver:
  - **This repo removed it.** The history names the commit that deleted or renamed the file (with the new path), or the commit that removed the heading. The fix offered is a row for `.jig/ledgers/BUFFER.md`: the claim is the cache file's pointer, and "this repo now" is the new path and the commit. The next `jig release` proposes the row to the metarepo. If an Open row already names the path, the line names that row and offers none.
  - **This repo never had it.** The metarepo's pointer is what's wrong, and update can only report it: the fix is made there, by `jig propose`. The `ui.md §1` family is one case.
  - **No cache.** One line: run `jig sync`, then update again.
- **What update can't do.** It can't write the row (the repo's file, added only on the owner's yes) or the metarepo (written only by branch). It can't tell whether a removal was answered when it was committed (`meta: none`, a proposal). In that case the owner declines the offered row.

## Done when
In a new section `pointers` in `tests/smoke.sh`, listed in `UNITS`, with a metarepo `pm` and a
pararepo `pp`. `pp/docs/x.md` has `## 2. Motes`, `### 2.1 Identity` and `## 10. Open questions`.
`docs/r.md` has `## Rules` and `### 1.1 …`. `docs/g.md` has `## Other`.
- [ ] `jig sync` prints no line for `` `pp/docs/x.md §2.1` `` or `` `pp/docs/x.md §2` ``. It prints `… points to docs/x.md § 3, which docs/x.md has no heading for`, and the same for `§1`, which `## 10.` doesn't satisfy.
- [ ] `` `pp/docs/r.md §1` `` is reported dangling: `### 1.1` is not heading 1.
- [ ] The prose `pp/docs/x.md §1.2 (cited by path, for now)` prints exactly `… points to docs/x.md § 1.2, which docs/x.md has no heading for`. Two pointers into a file this repo lacks print one line.
- [ ] The fix fires. Each of these is refused, and the refusal names the pointer:
  - `git mv docs/x.md docs/y.md`;
  - deleting `### 2.1 Identity` (`docs/x.md § 2.1`);
  - `git mv docs/r.md docs/s.md`, whose one pointer `§1` already dangled. This is the report's rename;
  - `git rm docs/g.md`, whose one pointer `` `§ Gone` `` already dangled.
- [ ] An edit to `docs/g.md` that leaves `§ Gone` missing commits. The x.md rename commits with `meta: buffered <id>`.
- [ ] The cleanup. Build pararepo `po` from v0.6.0's templates (`git -C "$JR" archive v0.6.0 plugin/templates`). Under its own hook, `git mv docs/x.md docs/y.md` and deleting `## 4. Keys` from `docs/w.md` both commit: that is the bug, reproduced in the fixture. Then `$UP`, as a dry run:
  - it prints `Metarepo pointers` with the x.md line naming the rename's short hash, `docs/y.md` and `BUFFER.md`;
  - it prints a `docs/w.md § 4` line naming its commit and `BUFFER.md`;
  - it prints a `docs/r.md § 1` line saying this repo never had it and naming `jig propose`, with no row offered;
  - afterwards `git status --porcelain` is empty.
- [ ] After an Open row naming `docs/x.md` is committed, the next `$UP` offers no row for it. `$UP --apply` doesn't touch `BUFFER.md`.
- [ ] Every existing pointer case in `sync_buffer` passes, `§ Colors` included.
- [ ] `grep` finds the number rule in RULES.md's What the metarepo holds (`§ 2` is `## 2. Motes`, not `### 2.1`). It also finds, in P2's row, that a lost file counts even when its heading was already missing.
- [ ] `bash tests/smoke.sh`, `claude plugin validate ./plugin` and `.jig/scripts/check.sh` pass, with their output shown.

## Out of scope
- **The report's bare-`§N` family rule** (`§1` over `1.x` headings). The owner dropped it as overfit. As a result, the reporting metarepo's four `ui.md §1` pointers keep reporting, correctly.
  - Update names them as the metarepo's to fix: point at `§ Rules` or at a `§ 1.N`.
  - The rename half of the symptom is fixed for them anyway (Done when, the `docs/r.md` rename).
- **P2's contract-path check misses deletes and the old side of a rename** (`changed_paths`). It was reproduced (Givens). It gets its own /jig:bug, because what it left behind, contract files lost without a question, needs a sweep of its own.
- **A renumbered heading whose number another heading now holds.** The pointer resolves to the wrong section. The fixed P2 doesn't catch it either, so it isn't this bug's leftover, and history can't tell a renumber from a rewording.
- **Workaround rewrites in a metarepo** (`§1` → `§ Rules`). They still resolve, and jig can't tell a workaround from a choice. The reporting metarepo has none (Givens).
- **A metarepo's update.** Nothing applies there: a metarepo holds no pararepo files, so it can't resolve a pointer.

## Touches
- `marketing/FEATURES.md` (gitignored), edited first. Rows:
  - "Pararepo gates P1–P3": number pointers, and P2's file level;
  - "RULES: What the metarepo holds": the number rule;
  - both "`update`" rows (the command and the skill): the Metarepo pointers block, and a row added only on a yes.
- `plugin/templates/jig/jig.py`: `pointer_gap`, `stale_pointers`, `para_rules` (P2) and `cmd_update`'s report.
- `plugin/templates/jig/RULES.md`: the pointer wording in What the metarepo holds, and P2's row.
- `plugin/skills/update/SKILL.md`: one paragraph. Show each Metarepo pointers line. Add a BUFFER.md row only on a yes. Never edit the metarepo.
- `tests/smoke.sh`: the `pointers` section, and `UNITS`.

## Alternatives considered
- **(b), RULES.md says a number alone isn't a pointer.** Rejected: the owner chose (a), and (b) contradicts the Documentation rule and rewrites ten pointers in the reporting metarepo's entry files. Reason is [seen].
- **P2 with no base comparison** (refuse any change to a file a dangling pointer names). Rejected because it would refuse every edit to a page that has an old dangling pointer. The reporting pararepo's `ui.md` has four such pointers and has been edited five times since 0.6.0. Reason is [seen].
- **The lookup in `jig sync` instead of update.** Rejected: sync already lists each dangling pointer on every pull. Catching up on what an older P2 let through belongs to the update that brings the fix. Reason is [assumed].
- **Update writes the BUFFER.md rows or edits the metarepo.** Rejected: update never applies the repo's own files without a yes, and a pararepo writes the metarepo only by branch (RULES.md, Metarepo and pararepos, rule 1). Reason is [seen].

## Decisions
- **Words after a number aren't compared.** The number is the rule's identity, so `§ 2 Motes` survives `2. Motes` being reworded.
- **The pointer wording names the gap the family rule leaves.** RULES.md's own example puts `### 31.1` under `## Rules`, so a page in that shape never has a heading `31`. The wording says to cite a rule by its whole number (`§ 31.1`), or the section by its heading (`§ Rules`).
- **"Not at `.`" means not inside a token.** A sentence-ending `.` still cuts, so `§ Colors.` prints `§ Colors` (a `sync_buffer` case). Read literally, the owner's rule would print `§ Colors.`.
- **No STAMP bump:** no LAYOUT row, default or STEP is added.
- **Where the block shows.** It shows whenever update prints its report, which is every run that brings a new `jig.py`. It needs `.jig/para.json` and the board at `.jig/config.json`.
- **The BUFFER row's text.** Claim: `<cache file>: the pointer to <path>[ § <section>]`. Now: `<new path or "deleted">, <hash>`. Decided: the owner, on the yes.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
