# Architecture Review Skill

Finds the design problems AI-built codebases and cleans them up.

Made for vibecoded codebases: one concept stored in two places, a webhook nothing registers, folders that promise a structure the code dropped. The import graph can't see these. This skill looks for them directly.

Not a bug hunter, linter, or security scanner.

## Setup: let your agent do it

Open a chat in the project you want reviewed and paste this:

```
Set up the architecture-review skill from https://github.com/sam-cre/Architecture_Review_Skill by following its SETUP-FOR-AGENTS.md, then run a full standard architecture review of this repository.
```

The agent installs the skill, runs the review, and reports back. It never commits, installs software into your project, or edits it. If an install already exists, it asks before replacing it. Restart Claude Code afterwards to load the skill everywhere.

## Manual install

```powershell
cd "C:\path\to\Architecture_Review_Skill"
.\install.ps1
```

macOS or Linux: `cd path/to/Architecture_Review_Skill && ./install.sh`. Add `-Link` or `--link` to symlink instead of copy, so edits to the repo apply immediately.

## Usage

From any project:

```
/architecture-review              full review
/architecture-review quick        structure only: graph, cycles, hotspots
/architecture-review deep         wider sweep, more change scenarios
/architecture-review pr           review a diff
/architecture-review diff         re-review: did the debt move?
/architecture-review refactor     apply one finding, after you approve
```

Output goes to `.architecture-review/` in your project. Nothing else is modified.

## Cleaning up

1. **Review.** Read `architecture-review.md`. `findings.json` is the machine-readable copy.
2. **Refactor.** Runs one finding per session, in `fix_order`. It searches what the finding touches, plans the change, waits for your YES, applies behavior-preserving steps, undoes any step that turns the tests red, and re-measures.
3. **You commit.** It never commits or pushes unless you ask.

Refactor needs a working build and tests. Without them it stops at the baseline step, because it cannot prove anything changed safely.

## Limits

- Review is read-only. Refactor edits only after you approve a plan.
- No scores or grades. Every finding carries its evidence, and a clean review is a valid result.
- Vibecoded code often has no tests. Expect the first refactor to add characterization tests, shown in the plan for your approval.

## Development

```bash
cd path/to/Architecture_Review_Skill
bash check-consistency.sh
```

Edit `skill/architecture-review/`, the source of truth. CI runs the same check on every pull request. Layout and invariants are in `CLAUDE.md`.
