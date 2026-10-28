# Metarepo (2 of 2): pararepos cite the metarepo at a tag

## Intent
A pararepo (code, firmware, hardware) cites a released metarepo tag (`specs/meta.md`). A
pararepo that changes a shared contract proposes the metarepo change in the same piece of
work, on a branch of the metarepo, and bumps its pin after release. Drift is visible, never
silent. It writes the metarepo only by branch, via `para-propose`.

## Done when
- [ ] `tests/smoke.sh` gains a para section: a throwaway metarepo released at `v0.1` (using
      `specs/meta.md`'s commands) and one throwaway pararepo, every case PASS or the expected
      refusal:
  - [ ] `para-init` writes `jig/para.json`, generates the `AGENTS.md` header, fills
        `jig/meta-cache/` and adds it to `.gitignore`. Hand-editing the header → next commit
        refused.
  - [ ] Staging a change under a `contract_path` when no spec in the change carries a proposal
        id or `meta: none — <reason>` → refused. With either → accepted.
  - [ ] `git add -f` of anything under `jig/meta-cache/` → refused. Staging a path inside the
        metarepo checkout → refused.
  - [ ] `para-propose` creates a branch on the metarepo, writes the proposal id into the
        spec's Decisions, and never touches the metarepo's `main`.
  - [ ] `para-sync` after a metarepo release reports the diff in the pararepo's terms and
        proposes a bump; the pin is unchanged until the user commits `meta: <name> v0.1 → v0.2`.
  - [ ] `para-sync` offline (metarepo path unreachable) reads the cache and says so.
  - [ ] With `defer_until` in the future, `para-sync` prints nothing; on or after it, the full
        report.
- [ ] The generated `AGENTS.md` header is at most 6 lines, counted in the 40-line budget.
- [ ] `claude plugin validate ./plugin` passes. `jig.py` is still one stdlib-only file.
- [ ] `grep -rnE 'Maige|maige|"E-' plugin` returns nothing.

## Out of scope
- The metarepo side (`specs/meta.md`).
- Cross-pararepo dependencies (A cites B's code). Pararepos cite the metarepo only.

## Touches
- `plugin/templates/jig/jig.py`: `para-init`, `para-sync`, `para-propose`; a pararepo rule
  group in `check_rules`, gated on `jig/para.json` (absent → nothing changes).
- `plugin/templates/jig/`: `para.json`, the generated `AGENTS.md` header, a `PENDING.md`
  section for a deferring pararepo.
- Skills, one line each: `brief` asks whether the task touches a contract path; `review`
  gets a sixth question (contract change without a proposal?); `retro` asks whether a
  repeated cross-repo confusion is a glossary entry; `hubnode` runs `para-sync` at session
  start and refuses to open a lane whose spec cites an unreleased proposal.
- `plugin/templates/jig/RULES.md`: the pararepo gates, in `specs/meta.md`'s section.
- `tests/smoke.sh`, `marketing/FEATURES.md` (one row per command and for the rule group).

## Alternatives considered
- Let a pararepo commit directly to the metarepo when the author is the founder. Rejected: the
  gate doesn't know who you are, and a rule with an exception for its owner teaches every
  agent that it has exceptions — `[seen]`, stated.
- Warn instead of refuse on contract-path commits. Rejected by the owner: the gates are strict
  on purpose — `[seen]`, stated.
- A git submodule for the metarepo. Rejected: a submodule pins a commit, not a validated tag,
  and puts the metarepo's tree inside the pararepo's — exactly the contamination surface the
  gates forbid — `[seen]`.
- `defer_until` as a milestone label (`"demo-gate"`). Rejected: nothing can evaluate a label,
  so the deferral never ends on its own — `[seen]`.
- Read the proposal id from the commit message. Rejected: no `commit-msg` hook in a pararepo,
  and the spec is where Decisions already live — `[assumed]`.

## Decisions
- Config is `jig/para.json`: `{"meta": "<name>", "location": "<path or URL>", "pin": "v0.3",
  "defer_until": null, "contract_paths": ["..."]}`. `defer_until` is an ISO date or null.
- "The spec" for the contract-path check is any `jig/specs/*.md` staged in the same commit, or
  changed on the branch since trunk. Solo on trunk, stage the spec with the change.
- Pararepos pin minors; never `main`. A major bump makes `para-sync` list every term the
  pararepo uses that changed.
- A pin bump is its own commit, `meta: <name> v0.3 → v0.4`, body = `para-sync`'s report.
- The `AGENTS.md` header is generated from `para.json` between two marker comments; the gate
  regenerates and compares. The rest of `AGENTS.md` is the repo's.
- Our instance — metarepo `Maige-Ecosystem`; pararepos `maige-os` (contract paths
  `registry/**`, `docs/ARCHITECTURE.md`, `docs/REGISTRY_v0.md`, `crates/maige-core/src/**`),
  `maige-lite` (protocol header, hardware spec); later `familiar`, `towyr`; prefix `E-`; first
  tag `v0.1` — is configuration for those repos, not anything in `plugin/`. `maige-os` was
  `defer_until = "demo-gate"`; it needs a date.
