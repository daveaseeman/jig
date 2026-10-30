# Staging: chat-born files land in a repo through one door

Source: user story "staging chat-born documents into repos", cowork session 2026-10-28
(Dave + Claude), amended with the owner Oct 29. Written by hand: this repo doesn't run jig on
itself yet.

## Intent
Chat sessions produce specs, decisions, doc edits and user stories faster than a repo's
workflow absorbs them. Every jig repo — plain, metarepo or pararepo alike — gets one folder,
`jig/staging/`, where such a file can be dropped with a header saying where it belongs.
Nothing in it counts until `jig staging resolve` lands it in its target repo, or drops it with
a reason. Until then jig reports it at session start, and refuses to release the repo unless
the user forces it.

## The staged file
A Markdown file in `jig/staging/` (untracked: never committed), with a header:

```yaml
---
staged: true
target: <repo name from repos.json, or "this">
kind: spec | doc | decisions | user-story
change: new | update
destination: <inside the target, relative to its root: a path if known, else a filename, else a one-line description>
source: <session / date / author, free text>
status: staged
---
```

Every file says whether it adds something new or updates something that exists. The skill
that writes it fills `destination` as precisely as it can — a path relative to the target's
root, a filename, or a description — never an absolute path, which is one machine's layout.

## Done when
- [x] Plain repo (smoke):
  - `init` creates `jig/staging/` holding only a `.gitignore`, and `update` creates it in
    older repos. A dropped file shows in no `git status`.
  - `jig staging` lists each file with its kind, target and destination. It names every
    header with a field missing or out of range, and exits 1.
  - `jig staging resolve <file>` does what the kind needs, then removes the staged file:
    - `spec`, `change: new`: written to `destination` under `jig/specs/`, with the header
      replaced by a `Source:` line. Refused if that path already exists.
    - `spec`, `change: update`: refused until the spec at `destination` contains the
      `source`, so the skill merges it with the user first.
    - `doc`, `change: new`: written to `destination` with a `Source:` footer.
    - `doc`, `change: update`: refused until the page contains the `source`. The skill finds
      the page from the path, filename or description, edits it with the user, and resolves.
    - `decisions`: `new` adds rows; `update` changes rows that exist (a status moving to
      superseded) and is refused until the register shows them, so the skill edits with the
      user. Either way each row keeps its status and date. Body lines that aren't rows are printed as "left for you", and
      the file stays until they're handled.
    - `user-story`: `new` is refused until a new spec written by `/jig:brief` from the story
      carries its `source`; `update`, until the existing spec it amends does.
  - `resolve <file> --drop "<why>"` removes it and records the reason (see Decisions).
    Without a reason it refuses.
  - Release is refused while anything is staged, naming each file, unless forced:
    - `jig gate` (the merge to trunk) refuses; `jig gate --force` proceeds and logs it.
    - The pre-push hook refuses a push of trunk; `git push --no-verify` is the force.
  - Session start (`hubnode`) prints one line: the count and kinds. (Amended at build: a
    subnode's worktree never holds staged files.)
- [x] Metarepo (smoke): `meta-release` refuses while anything is staged; `--force` proceeds
      and adds a `CHANGELOG.md` line saying what was left staged.
- [x] Cross-repo (smoke): a file is always resolved in its target. `resolve` run elsewhere
      forwards it:
  - It looks up the target's path in `repos.json` and moves the file into that repo's
    `jig/staging/`, which is the only place it writes in another repo.
  - From a pararepo to its metarepo, it also checks both sides: the target is `para.json`'s
    `meta`, and the metarepo's `meta.json` lists this pararepo. When the file touches a
    contract, it prints the `para-propose` line to run for the spec that depends on it (amended
    at build: only the user knows which spec).
  - From a metarepo to a pararepo, it checks that `meta.json` lists the pararepo and that the
    pararepo's `para.json` names this metarepo.
  - A target with no `repos.json` entry is refused, with the `jig repos add` line to run.
- [x] Pararepo (smoke): P4 refuses a contract-path commit while the main checkout's
      `jig/staging/` holds a file targeting the metarepo.
- [x] `jig repos add <name> <path>` writes `~/.config/jig/repos.json` (or
      `$XDG_CONFIG_HOME/jig/`, or `$JIG_CONFIG`); `jig repos` lists entries and flags paths
      that no longer exist. Only `jig repos` and cross-repo `resolve` read it; no hook or gate
      does. Smoke sets `JIG_CONFIG` to a temp file.
- [x] `/jig:stage` skill: lists staged files and resolves or drops each with the user.
- [x] `init` offers `jig repos add` for the repo it set up, and the board gets a `name` key
      (the folder name; an `update` step adds it to older boards; `STAMP` 5).
- [ ] By hand: the owner runs real files through `/jig:stage`; what happens goes under
      Decisions.
- [x] `claude plugin validate ./plugin` passes; `grep -rnE 'Maige|maige|"E-' plugin` is empty.

## Out of scope
- A command to drop a file into staging. A chat writes the file itself.
- Promoting or resolving automatically. Only `resolve`, run deliberately.
- Writing another repo's content from here. A forward moves the staged file to the target's
  staging; the target's own session resolves it.
- An index of staged files. The header is the whole schema.
- A chat client's permission model. RULES says what to grant; jig can't enforce it.

## Touches
- `marketing/FEATURES.md`: rows for `jig/staging/`, `jig staging resolve`, the release
  refusal, `jig repos` and P4, before any code.
- `plugin/templates/jig/staging/.gitignore` (new): `*` and `!.gitignore`.
- `plugin/templates/jig/jig.py`: header parsing (the stdlib `key: value` subset, not YAML);
  `cmd_staging` with `resolve` and `--drop`; `cmd_repos`; the board's `name` and its update
  step, `STAMP` 5; the release refusal in `gate`, pre-push and `meta-release`; P4; survey
  treats `jig/staging/` as a home.
- `plugin/templates/jig/RULES.md`: a Staging section — the header, what `resolve` does per
  kind, nothing staged is authoritative, the release refusal and its force, the `repos.json`
  path a chat is granted.
- Skills: new `/jig:stage`; `hubnode`/`subnode` session-start line; `brief`, `review`,
  `hubnode` read staged files for context only, never as decided; `init` offers `jig repos add`.
- `tests/smoke.sh`.

## Alternatives considered
- Commit staged files. Rejected by the owner: untracked, they can't reach a contract except
  through `resolve`. `[seen]`, Oct 29.
- Separate `promote`, `resolve`, `drop`, `take` commands. Rejected by the owner: one command,
  `resolve`, does what the kind needs. `[seen]`, Oct 29.
- `target` as a path. Rejected: a path is one machine's layout, and repos needn't share a
  folder. A name resolved through `repos.json` works wherever each repo lives. `[assumed]`.
- Refuse a release with no way through. Rejected by the owner: the user can force it. `[seen]`.
- A Stop-hook warning in plain repos. Dropped: the release refusal and the session-start line
  cover it, and a warning at the end of every turn is noise. `[assumed]`.
- Hooks reading `repos.json`. Rejected: a commit's result must not depend on whose machine
  ran it. `[seen]`, AGENTS.md ("Enforcement lives there and in git hooks").

## Decisions
- One command. jig.py does the mechanical part of `resolve` (writing a new spec or doc,
  appending decision rows, forwarding) and checks the result where the work needs judgment
  (an update, a story's spec). The skill does the judgment with the user, then calls it.
- Provenance: a spec's `Source:` line, a doc's footer, a decision's `CHANGELOG.md` line (in a
  metarepo) or board log line (elsewhere). `resolve` checks the `source` text is present.
- Where a decisions file lands: a metarepo's register (`DECISIONS.md`, an entry file); in any
  other repo, the `destination` the header names. jig has no decisions register outside a
  metarepo — see the logs note below.
- A drop's reason goes to the board log, and in a metarepo also to `CHANGELOG.md`.
- The release refusal reads the main checkout's `jig/staging/`, since staged files are never
  on trunk. It only refuses more, so a branch can't weaken it.
- What jig keeps that reads like a log, for the record: the board log (lane events and
  merges), `jig/ledgers/WORKAROUNDS.md` (patches in the code), `jig/ledgers/DEFERRED.md`
  (review findings not taken), `jig/handoffs/` (one note per handoff), each spec's Decisions,
  and in a metarepo `CHANGELOG.md` and the `DECISIONS.md` register. Staging adds none.
- Build, Oct 29. Smoke passes 142/142 and the validator passes. The by-hand run is the
  owner's, through `/jig:stage`.
  - **Not built: the session-start line in `subnode`.** A subnode works in a lane worktree,
    and staged files live only in the main checkout, so the line belongs to `hubnode`.
  - **A decision row is any table row whose first cell is `<PREFIX>-<n>`.** In a metarepo
    the prefix comes from `meta.json`. A plain repo has no register, so the header's
    `destination` names one, and the board log records where the rows went.
  - **Forwarding doesn't run `para-propose` itself.** Proposing needs the spec here that
    depends on the change, and only the user knows which one. It prints the command instead.
  - **The board gains `name`** (`STAMP` 5). Init fills it from the folder name, and update
    adds it the same way. The update step also creates `jig/staging/.gitignore`.
- Review, Oct 29 (fresh context). All findings were taken, and each has a smoke case.
  - **A forward to a path that isn't a jig repo** crashed, or made a stray `jig/staging/`.
    Now it's refused.
  - **A destination outside the repo** (absolute, or `..`) is now refused.
  - **Provenance is now a per-file mark**, `Source: <source> (staged as <file>)`. Before, a
    source substring let two files from the same session stand in for each other.
  - **Only `.md` files count as staged**, so a `.DS_Store` no longer blocks a release.
  - **CRLF headers parse.**
  - **A spec destination always lands under `jig/specs/`.**
  - **A duplicate decision id** is refused as `new`.
  - **`resolve` reads the main checkout's staging**, so it works from a lane.
  - **pre-push refuses by the ref being pushed to trunk**, so `feat:main` is caught too.
  - **`resolve` with no file is a clean refusal.**

