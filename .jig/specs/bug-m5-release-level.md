# Bug: smoke's M5 release case expects the old metarepo default level

Source: the batch check of trunk 786e212, 2026-11-19 (check role, `.git/jig/gate-check-main-786e212.out`): one FAIL, "M5: review, then a note, then a sync of trunk: jig merge is accepted, and so is the release"; smoke.sh exit 2 after 802s.

## Intent
The smoke suite passes on trunk again. The M5 case in `sec_r6_ints` expects the release level the
versioning change made the default.

## Why
1. Why did it fail? The case runs `jig release` with no level in a metarepo (`init --meta`, smoke.sh
   ~1850) and expects tag `v0.2.0`. rig-and-versioning (merged db1f18b) made `--patch` the default
   in every repo kind, so the tag is now `v0.1.1`. [seen] (smoke.sh ~1897; the merged spec's Part A)
2. Why wasn't it caught? rig-and-versioning moved its other metarepo release cases to `--feature`
   (helper `mf`), but `sec_r6_ints` wasn't among the sections its evidence ran. [seen]

## Correction
In that one case, release with `--feature` and keep expecting `v0.2.0`: the case tests M5's merge
and that a release is accepted, not the default level. Don't change `jig.py`.

## Done when
- [ ] `bash tests/smoke.sh r6_ints` passes, the M5 case among the PASS lines.
- [ ] `grep -n "release >/dev/null 2>&1 && git tag | grep -qx v0.2.0" tests/smoke.sh` finds no
      metarepo case left without a level.
- [ ] `.jig/scripts/check.sh` exits 0. The full suite runs once, at the batch check.

## Out of scope
- `jig.py`'s release default, which is right as rig-and-versioning built it.

## Touches
- `tests/smoke.sh`

## Alternatives considered
- Expect `v0.1.1` instead — rejected, because the case is about M5 and a release being accepted, and
  `--feature` keeps its expectation stable whatever the default — [assumed].

## Roles
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
