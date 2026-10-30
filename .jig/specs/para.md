# Metarepo (2 of 2): pararepos cite the metarepo at a tag

## Intent
A pararepo (code, firmware, hardware) cites a released metarepo tag (`jig/specs/meta.md`). A
pararepo that changes a shared contract proposes the metarepo change in the same piece of
work, on a branch of the metarepo, and bumps its pin after release. Drift is visible, never
silent. It writes the metarepo only by branch, via `para-propose`.

## Done when
- [x] `tests/smoke.sh` gains a para section: a throwaway metarepo released at `v0.1` (using
      `jig/specs/meta.md`'s commands) and one throwaway pararepo, every case PASS or the expected
      refusal:
  - [x] `para-init` writes `jig/para.json`, generates the `AGENTS.md` header, fills
        `jig/meta-cache/` and adds it to `.gitignore`. Hand-editing the header → next commit
        refused.
  - [x] Staging a change under a `contract_path` when no spec in the change carries a proposal
        id or `meta: none — <reason>` → refused. With either → accepted.
  - [x] `git add -f` of anything under `jig/meta-cache/` → refused. Staging a path inside the
        metarepo checkout → refused.
  - [x] `para-propose` creates a branch on the metarepo, writes the proposal id into the
        spec's Decisions, and never touches the metarepo's `main`.
  - [x] `para-sync` after a metarepo release reports the diff in the pararepo's terms and
        proposes a bump; the pin is unchanged until the user commits `meta: <name> v0.1 → v0.2`.
  - [x] `para-sync` offline (metarepo path unreachable) reads the cache and says so.
  - [x] With `defer_until` in the future, `para-sync` prints nothing; on or after it, the full
        report.
- [x] The generated `AGENTS.md` header is at most 6 lines, counted in the 40-line budget.
- [x] `claude plugin validate ./plugin` passes. `jig.py` is still one stdlib-only file.
- [x] `grep -rnE 'Maige|maige|"E-' plugin` returns nothing.

## Out of scope
- The metarepo side (`jig/specs/meta.md`).
- Cross-pararepo dependencies (A cites B's code). Pararepos cite the metarepo only.

## Touches
- `plugin/templates/jig/jig.py`: `para-init`, `para-sync`, `para-propose`; a pararepo rule
  group in `check_rules`, gated on `jig/para.json` (absent → nothing changes).
- `plugin/templates/jig/`: `para.json` and the generated `AGENTS.md` header.
- Skills, one line each: `brief` asks whether the task touches a contract path; `review`
  gets a sixth question (contract change without a proposal?); `retro` asks whether a
  repeated cross-repo confusion is a glossary entry; `hubnode` runs `para-sync` at session
  start and refuses to open a lane whose spec cites an unreleased proposal.
- `plugin/templates/jig/RULES.md`: the pararepo gates, in `jig/specs/meta.md`'s section.
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

- Build, Oct 29. Smoke covers every case above, and smoke and the validator pass.
  - **`location` must be a local clone.** `para-sync` fetches its tags. A URL has no way to
    read a tag's files with stdlib git alone, so the cache stands in. `[assumed]`
  - **A proposal id is the metarepo branch `propose/<pararepo>-<slug>`.** It is written into
    the spec's Decisions as `meta: <name> proposal <branch>`. `para-sync` reports whether
    each one has reached a release, and the hubnode refuses a lane that cites an unreleased
    one.
  - **`para-init` gitignores `jig/meta-cache/`**, and also the clone when it sits inside the
    repo.
  - **Not built: the `PENDING.md` section** for a deferring pararepo. `defer_until` alone
    silences `para-sync` until its date, and nothing else needed the section yet.
- Amended Oct 29, with the owner: **`para.json` names its metarepo and no longer holds a
  path.** A committed path only works on the machine that wrote it, and repos needn't share
  a folder.
  - `para-init`, `para-sync` and `para-propose` find the checkout by that name in the user's
    `repos.json` (`jig repos`, from `jig/specs/staging.md`). None of the three is a gate, so
    reading user config there is allowed. `para-init --location` records the path there.
  - P3 stays stateless. It refuses a staged gitlink whose checkout's `jig/meta.json` names
    this metarepo, and `para-init` gitignores a checkout that sits inside the repo.
  - The config line in Decisions above is now
    `{"meta", "pin", "defer_until", "contract_paths"}`. An older `para.json`'s `location` is
    dropped on the next `para-init`.
  - Smoke passes 119/119.
- Review, Oct 29 (fresh context), all taken and smoke-tested:
  - A new worktree had no `jig/meta-cache/`. `run_setup` now copies the main checkout's cache into it.
  - `para-propose` named its branch after a lane's folder. It now uses the repo's own name.
  - `jig repos` failed outside a git repo. It now works anywhere.
  - A mistyped pin wiped the cache. `fill_cache` now checks the tag first.
  - Malformed JSON raised a traceback in the hook. It is now a refusal.
