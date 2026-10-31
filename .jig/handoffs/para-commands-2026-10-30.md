# Handoff: para-commands

Commit: cf8d068df36f627f0caea34f99a91781ab816615
Date: 2026-10-30
Spec: .jig/specs/para-commands.md

## Built
- `jig sync` on a pararepo's trunk does what `para-sync` did: refreshes the cache and reports releases. It also notes an out-of-date `AGENTS.md` header. The dirty-tree refusal applies to jobs only. On a job, the cache follows the pin, with no metarepo needed. On trunk in a plain repo or a metarepo, sync is still refused.
- `para-propose` is now `jig propose`. Outside a pararepo it refuses and names `jig init --para`. No aliases.
- Re-running `jig init --para` (no name needed) writes `para.json` and the header first. A missing metarepo or pin tag is a warning, and the cache waits. The old `para-init` header block is replaced, not duplicated.
- `jig gate` refuses a job whose specs cite a proposal that isn't in trunk's pinned release. Its specs are the board's, the note's, and the ones it changed. It also refuses a different metarepo, and an unreachable metarepo when a proposal is cited. The sync report uses the same `proposal_in` test. That test also finds a deleted branch through git's `Merge branch '…'` subject or `jig merge`'s `merge <job>`. A just-made, empty proposal counts as not released.
- Updated: RULES.md, the hubnode, spec, retro and update skills, and README.

## Done-when evidence
- `bash tests/smoke.sh` at cf8d068: 366 PASS, 0 FAIL, exit 0. All cases below are in the section "pararepo commands are the standard ones" unless noted.
- sync brings in the upstream: the three pararepo sync cases pass with `$J sync` on trunk ("sync on a pararepo trunk: …"). The defer_until case leaves `para.json` modified and uncommitted.
- job sync after a pin bump: "sync on a pararepo job: … the job's cache follows, metarepo unreachable" — PASS.
- sync refused on trunk in a plain repo or a metarepo: two PASS cases.
- `jig propose`: the old propose cases PASS under the new name. "propose: in a plain repo or a metarepo it refuses, naming jig init --para" — PASS.
- header migration (the fixture is v0.3.1's `jig.py`):
  - update commit accepted;
  - sync names `jig init --para`;
  - the init commit is accepted;
  - afterwards 0 `para-` hits, one block, sync quiet.

  Five PASS cases.
- header offline: "with the metarepo gone from repos.json, init --para rewrites the header…, exits 0" — PASS. Also a clone missing the pinned tag — PASS.
- two-part pins: "a pararepo pinned at a hand-made v0.1 sees v0.2.0, proposes the bump, and caches v0.1" — PASS.
- gate cases, all PASS:
  - unreleased → refused;
  - released after the pin → refused, "bump the pin";
  - in the pin → passes;
  - branch deleted → passes;
  - wrong metarepo → refused;
  - unreachable → refused;
  - `meta: none` → passes with the metarepo away;
  - a spec on trunk only → refused;
  - landed by `jig merge` with its branch deleted → passes.
- sync report: "a proposal whose branch was deleted after its release reads released by" — PASS.
- repos add offers init: PASS. Metarepo release.sh via update: PASS.
- `grep -rnE 'para-(init|sync|propose)' plugin README.md`: only `jig.py:1904`, `with_header`'s comment.
- `claude plugin validate ./plugin`: "✔ Validation passed". `grep -rnE 'Maige|maige|"E-' plugin`: nothing. `.jig/scripts/check.sh`: exit 0.

## Review
Round 1, fresh context (Opus, xhigh). Eight findings, all taken, in cf8d068:
1. BLOCKING — the gate read only specs in the job's diff, so a spec proposed on trunk before `jig open` slipped past. Taken: it now also reads the board's spec and the note's `Spec:`. The repro is a smoke case and is refused. The spec's Done-when is amended to match.
2. should-fix — the deleted-branch fallback missed `jig merge`'s `merge <job>`. Taken: matched through the job's entry just before the merge, with a smoke case.
3. should-fix — `init --para` died in `fill_cache` before writing the header when the pin tag was missing. Taken: one path, header first, cache optional. Smoke case added.
4. optional — `run_setup` copied the main checkout's cache at any pin. Taken: only when it is at the job's pin.
5. optional — sync's report checked proposals on other metarepos. Taken: skipped, matching the gate.
6. optional — the fixture used bb1eb98. Taken: v0.3.1.
7. optional — FEATURES.md:116 said `para-sync`. Taken (main checkout, gitignored).
8. The spec's Decision contradicted update-skill step 4. Taken: the Decision now says what was built.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because this repo's docmap is empty and has no docs/ tree. RULES.md (updated: rule 1, the bump-commit paragraph, Commands) and the hubnode, update, spec and retro skills (updated) document these commands.

## Shared files changed
- `plugin/templates/jig/jig.py`: edits stay inside the functions the spec names: `cmd_sync`, `run_setup`, `cmd_para_init`, `cmd_propose`, `para_header`/`HEADER_BEGIN`/`PROPOSAL`, `with_header`, `cmd_gate`, P2, `forward()` hint, the parser. New helpers sit beside `sync_meta`: `proposal_in` and `unreleased_proposals`. Two more lines are in `cmd_init` (`--para` with no value).
- `plugin/templates/jig/RULES.md`: rule 1, the bump paragraph, and the Commands block (`jig sync`, `jig propose`).
- `tests/smoke.sh`: the pararepo section's `para-sync`/`para-propose` calls are renamed in place, because the commands are gone. Everything new is a section of its own at the end.
- `README.md` line 39. `plugin/skills/hubnode/SKILL.md`: step 5, Opening a job step 1, Gating step 1. `plugin/skills/update/SKILL.md`: a new step 4 after the commit, nothing else.

## Test by hand
In a pararepo:
- On trunk, run `jig sync`: it should report the metarepo and not refuse.
- Make a proposal with `jig propose` and gate a job citing it before it is released: refused.
- Release it, bump the pin, and gate again: passes.

## Left
Nothing on this job.
