# Decisions and changes

This log follows Keep a Changelog (https://keepachangelog.com/en/1.1.0/) plus decision entries, and versions follow Semantic Versioning (https://semver.org/).
A breaking change is one that a reader taking the release must act on, and it is released as a major version.

## Open

## Unreleased

### Added
- `jig queue -- <command>` runs a test or check holding one of the machine's slots (OS file locks in `.git/jig/queue/`, freed when a run dies), and waits when none is free; `jig queue` lists who holds and who waits. `queue.width` (the cores one run uses, or `"all"`), `queue.slots` and `queue.max_load` in `.jig/config.json` set it. The work, review and check roles run their tests and checks through it. A repo whose suite uses every core sets `queue.width: "all"`.
- `jig queue --full` is the complete check's: it also takes a single full lock, so two complete checks never run at once.
- `queue.overflow: {"to": "github", "reason": "<the owner's words>"}` is the owner's standing yes for the check role to push and delete `jig-check/*` branches, the one exception to "the owner's word before a push". With it, a complete check that finds the machine full exits 3 and prints the route to GitHub Actions; copy `plugin/templates/github/jig-check.yml` to `.github/workflows/` in the same commit. `jig checked --ci <run url>` records such a run only after `gh` shows it passed on HEAD.

### Fixed
- A metarepo gets a generated block of its rules in its always-loaded agent instructions, as a pararepo gets its header: `jig init --meta` writes it, and `jig update` lists it when it is missing or older. A metarepo set up before this writes it in a job, with `jig init --meta` in the job's worktree, and removes the lines it wrote by hand for those rules, which update lists as the repo's procedure.

## v0.14.0 - 2026-11-16
