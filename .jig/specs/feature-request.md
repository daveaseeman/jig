# feature-request

Source: owner, Nov 9: "I also want another way to stage that isn't a user-story. This would
be more like a feature-request. It wouldn't take the form of a user story, but it would be
similar in that it's not a fully defined spec - this task would read it and interpret it into
a spec. It's format would be less like a user story and more descriptive like, I want it to do
xyz."

## Intent
A chat can stage a feature request: a plain description of what the owner wants the product to
do, in their own words. The hubnode interprets it into a spec, shows what it had to interpret,
and resolves the request once the spec carries it.

## Design
- **The kind.** `kind: feature-request` joins staging's kinds. The header is the usual one;
  the body is free prose ("I want it to do xyz"), with no required shape: no "As a … I want …
  so that …", no Done-when. `change: new` is a new feature; `update` changes one a spec
  already describes, and its `destination` names that spec if known.
- **Resolving it** works like a story: `jig staging resolve` refuses until a spec under
  `.jig/specs/` carries the file's mark, then lands it. The refusal says "a request resolves
  into a spec".
- **Interpreting it** (the stage and hubnode skills). Run `/jig:spec` with the request as
  input. Because a request leaves things undefined, the spec:
  - quotes the request in its `Source:` line in the owner's words, as `/jig:fix` does a
    report's symptom, with `(staged as <file name>)`;
  - restates it as the spec's Intent; if that can't be done in a sentence, asks the owner one
    question before writing anything;
  - lists under Decisions each thing it filled in that the request didn't say, starting
    `Interpreted:`, so the owner can correct the reading before the work starts.
  Then the hubnode shows the spec, and resolves once the owner accepts it.
- **Story or request.** A user story names who wants what and why; a request describes what
  the thing should do. Both resolve into a spec; only the stage skill's wording tells them
  apart, so a chat picks whichever fits what was said.

## Done when
- [ ] Smoke `staging`: a staged `feature-request` file is listed by `jig staging`; `resolve`
  refuses with "a request resolves into a spec" before a spec carries its mark, and resolves
  after.
- [ ] Smoke: a header with `kind: feature-request` passes the header check; a misspelt kind
  (`feature`) is still refused, naming the kinds.
- [ ] RULES.md (Staging) and the stage skill name the kind, its free-prose body, and the
  `Interpreted:` decisions; the stage skill's description names feature requests.
- [ ] `bash tests/smoke.sh` passes, `claude plugin validate ./plugin` passes, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- A template or form for requests: the point is that they have none.
- Turning a request into a roadmap change. A request that needs a new scope gets one through
  a `kind: roadmap` staged file (spec `roadmap`), separately.
- A check that a spec lists its interpretations: that's the review's job.

## Touches
- `plugin/templates/jig/jig.py`: `KINDS`, and `resolve`'s story branch (`~3903`)
- `plugin/templates/jig/RULES.md` (Staging)
- `plugin/skills/stage/SKILL.md`, `plugin/skills/hubnode/SKILL.md` (where it resolves staging)
- `tests/smoke.sh` (`sec_staging`)
- `marketing/FEATURES.md` (main checkout only)

## Alternatives considered
- Stage requests as `user-story` with looser wording — rejected because the owner asked for a
  kind that isn't a story, and the kind is what tells the hubnode to expect interpretation —
  reason is [seen: owner, Nov 9]
- Stage them as `kind: spec` — rejected because a staged spec lands as written on `resolve`,
  with no interpretation step; a request is "not a fully defined spec" — reason is [seen:
  jig.py `resolve`, a new spec is written as staged; owner, Nov 9]

## Decisions
- `Interpreted:` decisions make the gap between request and spec visible in the spec itself,
  where the owner reads it before approving.
- This runs after `roadmap`: both add a staging kind in the same lines of jig.py, RULES.md and
  the stage skill.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
