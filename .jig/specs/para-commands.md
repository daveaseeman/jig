# A pararepo's commands become standard ones, and its header is rewritten once

Source: owner, Oct 29–30 ("as few meta- and para-specific commands as possible"); `release.md`
left `para-sync` and `para-propose` for this spec.

## Intent
jig knows a repo's kind from `.jig/meta.json` / `.jig/para.json`, so a pararepo needs no
commands of its own. `para-sync` becomes what `jig sync` does in a pararepo. `para-propose` is
truly pararepo-only: it keeps its job under the plain name `jig propose`. The generated
`AGENTS.md` header stops naming `para-init`, `para-sync` and `para-propose`, through an update
path that trunk's older P1 accepts. The other meta/para items are already built: each gets a
smoke case where it has none, or is closed here.

## Done when
Smoke, in the pararepo section unless it says otherwise:
- [ ] **`jig sync` brings in this checkout's upstream.** On a lane, the upstream is trunk, as
      now. On trunk in a pararepo, it is the metarepo. The three `para-sync` cases pass with
      `jig sync` run on trunk: the report after a release, offline, and `defer_until`, which runs
      with `.jig/para.json` modified and uncommitted.
- [ ] On a pararepo lane, after trunk bumps the pin, `jig sync` merges trunk. The lane's
      `.jig/meta-cache/PIN` then names the new pin, even with the metarepo unreachable.
- [ ] `jig sync` on trunk in a plain repo or a metarepo is still refused ("not on a lane
      branch"). There is nothing upstream to sync.
- [ ] **`jig propose <spec> <slug>`** passes today's `para-propose` cases. In a plain repo or a
      metarepo it refuses and names `jig init --para`.
- [ ] **Header migration.** The fixture is a pararepo whose committed `.jig/jig.py` is today's,
      from `git -C "$R" show bb1eb98:plugin/templates/jig/jig.py`. Smoke already reads older
      files this way. Its header names `jig para-init`.
  - `update --apply` and a commit: the hook accepts it.
  - `jig sync` on trunk prints `the AGENTS.md header is out of date`, naming `jig init --para`.
  - `jig init --para` and a commit of only what it changed (`AGENTS.md`, and `para.json` if it
    rewrote it): also accepted.
  - Afterwards `grep -cE 'para-(init|sync|propose)' AGENTS.md` is 0, there is one `jig:meta —`
    block, and `jig sync` no longer prints the note.
- [ ] **Header offline.** With the metarepo removed from `repos.json`, `jig init --para` in an
      existing pararepo still regenerates the header, says the cache wasn't refreshed, and
      exits 0.
- [ ] **Two-part pins.** A pararepo pinned at a hand-made `v0.1` release, with a metarepo that then
      releases `v0.2.0`: `jig sync` reports `v0.2.0 is out` and `meta: docs v0.1 → v0.2.0`, and
      the cache fills at `v0.1`.
- [ ] **`repos add` offers init.** `jig repos add meta` in a repo without `.jig/meta.json` prints
      `jig init --meta`. `add para` without `.jig/para.json` prints `jig init --para`.
- [ ] **Metarepo release default via update.** In a metarepo with no `release.sh`, `update
      --apply` adds one with no `# TODO: release protocol` line, and `jig release` runs with no
      `/jig:release` refusal.
- [ ] `grep -rnE 'para-(init|sync|propose)' plugin README.md` finds only the comment
      by `with_header`'s marker match that explains the old marker, plus the aliases if the owner
      keeps them (Q1).
- [ ] Smoke passes, `claude plugin validate ./plugin` passes, and
      `grep -rnE 'Maige|maige|"E-' plugin` finds nothing.

## Out of scope
- `jig open` refusing a spec that cites an unreleased proposal itself, instead of the hubnode
  skill doing it (Q3). That needs the job record's `spec` path from `names.md`.
- A pararepo release step. `release.md` decided a pararepo releases like a plain repo.
- The decision `open` status and lifecycle. Built and smoke-tested in `decision-open.md`.
  Nothing here changes it.
- P4 and forwarding staged files to the metarepo. `forward()` and P4 already branch on the
  repo's kind inside standard commands, which is the shape this spec wants. Only the hint
  `forward()` prints changes its command name.

## Touches
- `marketing/FEATURES.md` (main checkout only, gitignored): the `init --para / para-sync /
  para-propose` row rewritten before the code.
- `plugin/templates/jig/jig.py`:
  - `cmd_sync`:
    - on trunk in a pararepo, it runs `cmd_para_sync`'s body and adds the stale-header note.
    - the dirty-tree refusal moves inside the lane path.
  - `run_setup` copies the main checkout's cache when the lane's `PIN` differs from its pin, not
    only when it has none.
  - `cmd_para_init`, run again in an existing pararepo, writes the header before it looks for
    the metarepo. An unreachable metarepo is a warning, not a stop.
  - `cmd_para_propose` → `cmd_propose`.
  - `para_header` and `HEADER_BEGIN` get the new wording.
  - `with_header` also finds the old begin marker.
  - the P2 message, the `forward()` hint, the parser.
  - No `update` step and no `STAMP` bump (see Decisions).
- `plugin/templates/jig/RULES.md`:
  - rule 1 names `jig propose`.
  - the bump-commit sentence names `jig sync`'s report and says older `vX.Y` pins keep working.
  - the Commands block.
- Skills:
  - `hubnode`: step 5, and "Opening a lane".
  - `brief`, which `names.md` renames to `spec`.
  - `retro`
  - `update`: in a pararepo, after the commit, run `jig init --para` and commit only what it
    changed.
- `tests/smoke.sh`, `README.md` (line 39).
- **Collides with the `names` lane.** The `cmd_sync` messages say "lane". The hubnode, brief→spec
  and retro skills, the RULES Commands block and `smoke.sh` are all files `names` rewrites. Build
  this after `names` merges.

## Alternatives considered
- Fold `para-sync` into `jig status`. Rejected: status is a local, read-only report, and
  `para-sync` fetches the metarepo's tags and rewrites the cache — `[seen]`, `cmd_para_sync`.
- Keep `para-sync`. Rejected: it is sync one level up: bring what this repo depends on up to
  date, then say what moved. The kind is known from `para.json` — `[seen]`.
- Have `sync` bump the pin itself. Rejected: RULES makes the bump a deliberate commit of its
  own, with the report as its body — `[seen]`.
- Fold `para-propose` into `staging resolve`, which already forwards a staged file to the
  metarepo. Rejected: forward moves an untracked chat file into the metarepo's staging, while
  propose makes a branch there and edits a committed spec. A contract change starts from a
  spec, not a chat file — `[seen]`, `forward()` and `cmd_para_propose`.
- Fold it into `jig open`, since a proposal is a branch. Rejected: `open` writes the board on
  trunk, and in the metarepo that is a write to its main, against rule 1 — `[seen]`.
- Drop the command and have the skill run `git branch`. Rejected: review already caught the
  branch named after a lane's folder, and the command exists to get that right — `[seen]`, `para.md`.
- Retire the header by having P1 accept both forms for one release. Rejected: it works only if
  every pararepo updates through that release, and `update` takes a repo from any generation in
  one pass — `[seen]`, `names.md` intent.
- Rewrite the header in the update commit with `--no-verify`, as the update skill allows for R7.
  Rejected: `--no-verify` skips every rule for that commit, and a two-commit path needs no
  bypass — `[seen]`, update skill step 3.

## Decisions
- **The header changes over two commits on trunk.** The hook runs trunk's committed checker. So
  commit 1, the update, leaves `AGENTS.md` alone, and P1 doesn't run because neither
  `AGENTS.md` nor `para.json` changed. Commit 2 is `jig init --para` regenerating the header,
  and the new checker now on trunk judges it. Until commit 2, a commit that touches `AGENTS.md`
  is refused by P1, whose message already says to run `jig init --para`. `update` refuses while
  lanes are open, so only a lane opened between the two commits can get that refusal, and it
  clears once the lane `jig sync`s. `[seen]`: the hook template, `base()`, P1's trigger, and
  `cmd_update`'s open-lane refusal.
- **Commit 2 needs no metarepo.** The header is generated from `para.json` alone, so a re-run
  of `init --para` writes it before it looks for the checkout. Offline, or on a machine whose
  `repos.json` doesn't list the metarepo, the header can still be fixed.
- **The reminder for commit 2 comes from `jig sync` on trunk, not from `update`.** The hubnode
  runs `jig sync` every session. Right after commit 1, `update` says "up to date", and the
  update skill stops there.
- **A lane's cache follows its pin through `run_setup`.** `run_setup` already runs after every
  merge and copies the main checkout's cache. Widening it to copy whenever the pins differ
  needs no metarepo access. A second path through `fill_cache` would need it. The main
  checkout's cache is at the new pin, because the bump commit is made after `jig init --para`
  refills it.
- **The dirty-tree refusal is lane-only.** It protects the merge. On trunk, the metarepo step
  writes only the untracked cache.
- **`with_header` matches `<!-- jig:meta — ` up to the end marker, not the exact begin line.**
  Otherwise the new code can't find the old block and adds a second one.
- **The new header, still at most 6 lines.** The begin line says `by \`jig init --para\``.
  `jig sync` refreshes the cache and reports releases. Contract changes need `jig propose` or
  `meta: none — <reason>`. The metarepo is written only by branch, via `jig propose`.
- **No `update` step and no `STAMP` bump.** The header is regenerated by an existing command,
  and the board doesn't change.
- **`propose` stays kind-specific, with a reason.** It is the one command that writes a branch
  into another repo, and no standard verb does that. Dropping the prefix doesn't reduce the
  number of commands. It makes the kind show up in the command's refusal, not in its name, and
  it costs nothing extra because the header is rewritten anyway.
- Release defaults, two-part pins, and `repos add` offering init are already built
  (`release.md`, `release_script`, `version_key`, `cmd_repos`). This spec adds only the smoke
  cases they lack.

## Open questions for the owner
1. Keep `para-sync` / `para-propose` as hidden aliases for one release? They would print the new
   name and run it. Until commit 2, an existing pararepo's header still names them.
   Recommended: yes, then remove them.
2. `jig propose`, or keep `para-propose`? Both are pararepo-only. The rename buys a Commands
   list with no `para-` entries.
3. Should `jig open` in a pararepo refuse a spec that cites an unreleased proposal itself, once
   `names` gives the job record a spec path? Enforcement belongs in `jig.py`, and today it is
   one line of hubnode prose.
4. Should `jig sync` on trunk in a metarepo report anything, such as pararepos whose pins lag
   the latest release? It could find them through `meta.json`'s `pararepos` and `repos.json`.
   Recommended: not now. Nothing has needed it.
5. The header migration leaves every existing pararepo with a manual second commit, and with
   `AGENTS.md` edits refused until that commit is made. Is that trade acceptable, or should the
   header keep its current wording and only the commands change? In that case the header would
   name the aliases for good.
