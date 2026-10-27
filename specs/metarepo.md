# Metarepo and pararepos

## Intent
jig manages a *set* of repos: one **metarepo** — docs only: definitions, decisions,
conventions — and one or more **pararepos** (code, firmware, hardware) that cite it at a
tag. The metarepo points; it never copies. A pararepo that changes a shared contract proposes
the metarepo change in the same piece of work, on a branch of the metarepo, and bumps its
pin after release. Drift is visible, never silent. Contamination in either direction is a
gate failure — the gates are strict on purpose.

Three rules do the work: a pararepo writes the metarepo only by branch, via `para-propose`;
the metarepo holds no code and no copied pararepo content; only `meta-release` tags, so a
pin can never point at something that didn't pass validation.

## Done when
- [ ] `tests/smoke.sh` gains a meta/para section, every case below as PASS or the expected
      refusal, in a throwaway metarepo + one throwaway pararepo:
  - [ ] `meta-init` then `meta-release` tags `v0.1`; a second `meta-release` with no entry-file
        change refuses ("nothing to release").
  - [ ] metarepo: staging a `.py` → refused. A decision row without status + date → refused.
        Entry file changed without `CHANGELOG.md` staged → refused. Commit to `main` that is
        not a merge of a reviewed branch → refused.
  - [ ] `git tag v0.2` by hand → next validator run fails naming the tag.
  - [ ] pararepo: `para-init` writes `jig/para.json`, generates the `AGENTS.md` header, fills
        `jig/meta-cache/`. Hand-editing the header → next commit refused.
  - [ ] pararepo: staging a change under a `contract_path` with no proposal id in the spec and
        no `meta: none — <reason>` → refused. With either → accepted.
  - [ ] pararepo: staging anything under `jig/meta-cache/` → refused. Staging a path inside
        the metarepo checkout → refused.
  - [ ] `para-propose` creates a branch on the metarepo, writes the proposal id into the spec's
        Decisions, and never touches the metarepo's `main`.
  - [ ] `para-sync` after a metarepo release reports the diff in the pararepo's terms and
        proposes a bump; the pin is unchanged until the user commits `meta: <name> v0.1 → v0.2`.
  - [ ] `para-sync` offline (metarepo path unreachable) reads the cache and says so.
  - [ ] with `defer_until` set, session start prints nothing.
- [ ] `claude plugin validate ./plugin` passes. `jig.py` is still one stdlib-only file.
- [ ] No name from our instance (Maige, maige-os, `E-`) appears in `plugin/`.

## Out of scope
- Rendering or hosting the metarepo. It is markdown in git.
- Cross-pararepo dependencies (A cites B's code). Pararepos cite the metarepo only.
- Multi-metarepo. One per pararepo.
- Migrating an existing docs repo into a metarepo (that is `adopt`'s job later).

## Touches
- `plugin/templates/jig/jig.py`: five commands — `meta-init`, `meta-release`, `para-init`,
  `para-sync`, `para-propose`; two new rule groups in `check_rules`, gated on which file is
  present (`jig/meta.json` → metarepo rules, `jig/para.json` → pararepo rules; neither →
  nothing changes). Validator as a function `meta-release` and the Stop hook share.
- `plugin/templates/jig/`: `meta.json`, `para.json`, `CHANGELOG.md`, decision-row template,
  the generated `AGENTS.md` header, a `PENDING.md` section for a deferring pararepo.
- Skills: `brief` asks whether the task touches a contract path; `review` gets a sixth
  question (contract change without a proposal?); `retro` asks whether a repeated cross-repo
  confusion is a glossary entry; `hubnode` reads `para-sync`'s report at session start and
  refuses to open a lane whose spec cites an unreleased proposal. One line each.
- `plugin/templates/jig/RULES.md`: a "Metarepo and pararepos" section — the three rules and
  the gates, one page.
- `tests/smoke.sh`, `marketing/FEATURES.md` (one row per command and per rule group).

## Alternatives considered
- Copy shared docs into each pararepo and diff them. Rejected: copies drift silently, which is
  the failure this exists to make visible — `[seen]`, the forwarding-address bloat in Daisy
  was the same mechanism.
- Let a pararepo commit directly to the metarepo when the author is the founder. Rejected: the
  gate doesn't know who you are, and a rule with an exception for its owner teaches every
  agent that it has exceptions — `[seen]`, stated.
- Warn instead of refuse on contract-path commits. Rejected by the owner: the gates are strict
  on purpose — `[seen]`, stated.
- TOML for `meta`/`para` config. Changed to JSON: the board is JSON, `jig.py` already parses
  it, and `tomllib` is read-only and 3.11+. One format, one parser — `[seen]`.
- A git submodule for the metarepo. Rejected: a submodule pins a commit, not a validated tag,
  and puts the metarepo's tree inside the pararepo's — exactly the contamination surface the
  gates forbid — `[seen]`.

## Decisions
- Config is `jig/meta.json` and `jig/para.json` (not `.jig/`, not TOML). Paths follow
  `specs/jig-folder.md`; do that spec first.
- `para.json`: `{"meta": "<name>", "location": "<path or URL>", "pin": "v0.3",
  "defer_until": null, "contract_paths": ["..."]}`.
- `meta.json`: `{"name": ..., "entry_files": [...], "tag_pattern": "^v\\d+\\.\\d+$",
  "decision_prefix": "E-", "pararepos": ["..."]}`.
- Tags `v<major>.<minor>`: minor for additions and clarifications, major for a rename or a
  reversed decision. A major bump makes `para-sync` list every term the pararepo uses that
  changed. Pararepos pin minors; never `main`.
- Metarepo commit subjects start with the ids touched (`E-022: …`, `GLOSSARY: mote`) so
  `git log` is the decision index. The gate checks the prefix.
- A pin bump is its own commit, `meta: <name> v0.3 → v0.4`, body = `para-sync`'s report.
- "Copied pararepo content deeper than a pointer" is a warning, not a refusal: the reviewer
  decides. Everything else in §3 of the outline refuses (exit 2).
- The `AGENTS.md` header is generated from `para.json` between two marker comments; the gate
  regenerates and compares. The rest of `AGENTS.md` is the repo's.
- Our instance — metarepo `Maige-Ecosystem`; pararepos `maige-os` (`defer_until =
  "demo-gate"`, contract paths `registry/**`, `docs/ARCHITECTURE.md`, `docs/REGISTRY_v0.md`,
  `crates/maige-core/src/**`), `maige-lite` (protocol header, hardware spec); later
  `familiar`, `towyr`; prefix `E-`; first tag `v0.1` — is configuration for those repos, not
  anything in `plugin/`.
