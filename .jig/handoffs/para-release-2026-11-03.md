# Handoff: para-release

Commit: 5696244f911cd98055fe66868657af363cc7a32e
Date: 2026-11-03
Spec: .jig/specs/para-default-release.md
Review: tier 2, effort 1
Ran: claude-opus-5-5 at xhigh, fresh context (subagent)

## Built
A pararepo now has a default release, as a metarepo does. Steps and artifacts are optional:
the template's TODO, an empty `release.artifacts` and a missing `release.sh` no longer refuse.
Any steps and globs that are given still run and must match. Before the tag, the new
`para_problems` checks the repo against its metarepo. It refuses an unreachable metarepo, a pin
that isn't one of its releases, a stale or hand-edited header (P1), a tracked cache (P3) and a
malformed or duplicate buffer row (P2). It prints `jig sync`'s lines for a newer release or an
uncovered cited path, unless `defer_until` hasn't passed yet. The buffer still settles in the
release. `newer_release` is the "is out" report, factored out of `sync_meta` so both print it.

## Done-when evidence
- No refusal for the TODO or empty artifacts: smoke `PASS  para release: release.sh untouched from the template and no artifacts: tags v0.1.0`
- Refusals print `refused: …` and tag nothing: smoke `PASS  para release: pin set to main is refused, naming the pin, and tags nothing`, `… a hand-edited header committed with --no-verify is refused, naming P1`, `… a metarepo that isn't registered is refused, naming jig repos add meta`, `… a tracked cache and a malformed buffer row are refused, naming P3 and P2`, `… a second row with an id already taken is refused, naming P2`, `… a pin on a tag made by hand in the metarepo is refused, naming the pin`, `… a P3 refusal leaves the tree clean, so the next release names P3 again`
- Warns and goes on: smoke `PASS  buffer: the release warns, as jig sync does, of a path a metarepo decision cites that contract_paths doesn't cover`, `PASS  buffer: a release after a newer metarepo release, pin not bumped, warns as jig sync does and tags`
- Buffer still settles: smoke `PASS  para release: with two Open rows it also makes the one proposal branch`, plus every existing `buffer:` case
- Own steps and a glob: smoke `PASS  buffer: a pararepo release with its own steps and a glob that matches nothing tags nothing`, `PASS  buffer: a pararepo release with no buffer runs its steps, checks the glob, and opens no proposal branch`
- Plain repo with the TODO still refuses: smoke `PASS  release: an undefined protocol refuses and points to /jig:release, naming the kind`
- RULES.md *Release*, the release skill's *In a pararepo* and the init skill are updated. The FEATURES row was edited by the hubnode.
- `bash tests/smoke.sh`: rc 0, 490 PASS, 0 FAIL; tail:
  ```
  PASS  feedback: release refuses while a report for this repo waits in the fallback, naming it and not another repo's
  PASS  feedback: once it's dropped, the release goes through beside the other repo's report
  PASS  feedback: jig repos prints where tool reports wait
  PASS  isolation: the user's real jig config folder is unchanged by the run
  ```
- `claude plugin validate ./plugin`: `✔ Validation passed`
- Changed in an existing case: "a release whose Open rows a proposal already carries unchanged opens no branch" no longer moves the metarepo away. The spec now refuses an unreachable metarepo.

## Review
Round 1: a fresh claude-opus-5-5 subagent, set to xhigh by the hubnode; it reported its effort as
unknown. It found nothing blocking. It raised four should-fix and seven optional findings.
- Should-fix 1 (a P3 refusal still ran `fill_cache`, which ran `rmtree` on the tracked cache): fixed. `para_problems` returns before the cache step, and a smoke case covers it.
- Should-fix 2 (`defer_until` ignored): fixed. The warnings wait for it, as `sync_meta`'s do.
- Should-fix 3 (RULES.md said "(below)" for sections above): fixed.
- Should-fix 4 (no smoke case for the warnings): fixed with two cases.
- Optional 1 (no pre-push or hand-made-tag check for a pararepo): deferred, with a row in DEFERRED.md.
- Optional 2 (the unreachable `die` in the buffer step, and a duplicate skill sentence): fixed. The step reuses `para_problems`' checkout.
- Optional 3 (smoke for a twin row and a hand-made tag pin): fixed.
- Optional 4 (a pararepo with no `release.sh` still refused): fixed.
- Optional 5 (the init skill's sentence about the first release): fixed, now plain repos only.
- Optional 6 (the release skill's P1 wording): fixed.
- Optional 7: taken and fixed in 5696244 (the hubnode's list).

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because this repo's docmap is empty and has no docs/ tree. RULES.md *Release* and the release and init skills (all updated) document the pararepo release.

## Shared files changed
- `plugin/templates/jig/jig.py`, `plugin/templates/jig/RULES.md`, `tests/smoke.sh`, `plugin/skills/release/SKILL.md`: the board lists these as shared with the other jobs. The smoke cases sit inside the pararepo and sync-buffer sections, not at the end of the file.
- `plugin/skills/init/SKILL.md`: added to the board after review, for its release sentence.
- `.jig/ledgers/DEFERRED.md`: one appended row.

## Test by hand
In a scratch metarepo and pararepo, with `release.sh` left as the template, run `jig release
--version 0.1.0` in the pararepo: it tags. Set the pin to `main` and commit: it refuses, naming
the pin. With a newer metarepo release out, it prints "<meta> vX is out" and still tags.

## Left
Nothing on this job. Follow-up (DEFERRED): pararepo checks at pre-push and commit time.
