# Decisions and changes

This log follows Keep a Changelog (https://keepachangelog.com/en/1.1.0/) plus decision entries, and versions follow Semantic Versioning (https://semver.org/).
A breaking change is one that a reader taking the release must act on, and it is released as a major version.

## Open

## Unreleased

## v0.15.0 - 2026-11-19

### Added
- `jig queue -- <command>` runs a test or check holding one of the machine's slots (OS file locks in `.git/jig/queue/`, freed when a run dies), and waits when none is free; `jig queue` lists who holds and who waits. `queue.width` (the cores one run uses, or `"all"`), `queue.slots` and `queue.max_load` in `.jig/config.json` set it. The work, review and check roles run their tests and checks through it. A repo whose suite uses every core sets `queue.width: "all"`.
- `jig queue --full` is the complete check's: it also takes a single full lock, so two complete checks never run at once.
- `queue.overflow: {"to": "github", "reason": "<the owner's words>"}` is the owner's standing yes for the check role to push and delete `jig-check/*` branches, the one exception to "the owner's word before a push". With it, a complete check that finds the machine full exits 3 and prints the route to GitHub Actions; copy `plugin/templates/github/jig-check.yml` to `.github/workflows/` in the same commit. `jig checked --ci <run url>` records such a run only after `gh` shows it passed on HEAD.

### Fixed
- In a metarepo, a commit on a `propose/` branch passes R2 while jobs are open, as it does when none are: a proposal is on no job by design. A `propose/` branch in any other repo is refused as before, and R1 still keeps the trunk checkout off it.
- `jig roles --from TIER,EFFORT` takes the starting session's own settings and says under each role whether to start it with its settings or start it and then raise its model, its effort or both, compared one at a time as the tool clamps them; it also says when those settings rank below the hubnode floor. Settings rank by tier first, then effort. The hubnode runs it at the start of a session and follows it when starting a role.
- `tiers.json` names the tier-1 model in use today.
- A metarepo gets a generated block of its rules in its always-loaded agent instructions, as a pararepo gets its header: `jig init --meta` writes it, and `jig update` lists it when it is missing or older. A metarepo set up before this writes it in a job, with `jig init --meta` in the job's worktree, and removes the lines it wrote by hand for those rules, which update lists as the repo's procedure.

### Changed
- Pages describe the product only: how the repository is worked has its homes, by one test in `.jig/RULES.md` (Homes), and the rest of it goes to `.jig/process.md`, created on first use with a pointer line in the always-loaded rules file naming when to read which section (a repo already on jig adds that line itself; only jig's template has it). `jig survey` and `jig update` now list a page line naming a `.jig/` path other than the decision log, and an invariant whose holder names review: move each line to its home, and for what review covers give the invariant a named test or what is seen on screen, or move it to the body.

## v0.14.0 - 2026-11-16
