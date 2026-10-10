# Architecture Review Skill

An evidence-based architecture review and refactoring skill for Claude Code (and, through the mirror files, Codex, Cursor, and Windsurf).

It answers two questions:

1. **Is this codebase actually designed well?** Review mode grounds every finding in measurements, git history, and a written evidence trail. It refuses to answer with opinion.
2. **How do I clean it up safely?** Refactor mode applies **one reviewed finding at a time**, searches what that finding touches before it changes anything, and proves the result with the same measurement that found the problem.

Not a bug hunter, not a linter, not a security scanner. For security, use a security audit skill.

## Who this is for

The main idea: **a codebase assembled feature by feature with AI prompts ("vibecoded") accumulates problems no one holds in their head.** Each feature works on its own. The breakages sit between features:

- the same concept stored in two places, and one screen reads only one of them
- a webhook the code depends on that nothing in the repo registers
- the same rule written three ways because it was prompted three times
- folders that claim a structure the code no longer follows

The import graph cannot see these. This skill looks for them specifically (the `data-flow-gap` and `integration-gap` categories), then gives you a safe, one-step-at-a-time way to fix them.

### Best-fit codebases

- **Prompt-built apps** that grew past what one person can hold in their head, roughly 5k to 100k lines.
- **Solo or small-team products** where a number keeps disagreeing with another number ("why does the revenue total not match the orders page?").
- **Projects about to be handed off** to a new developer or agent. The review is the map.
- **Projects with tests and a working build.** Refactor mode needs them to prove nothing broke.

### Poor fit

- **Tiny scripts.** The skill grades findings against a ceremony budget. A 300-line script should get a short "this is fine" report.
- **Codebases with no build or test command at all.** Review still works. Refactor will stop at the baseline step, because it cannot prove anything without one.
- **Bug hunts and security reviews.** Use a dedicated skill.
- **Very large monorepos** without splitting. The skill supports parallel review, but the work scales with the number of modules.

## Install

**Windows**
```powershell
.\install.ps1
```

**macOS / Linux**
```bash
./install.sh
```

Add `-Link` (Windows) or `--link` (Mac/Linux) to symlink instead of copy, so edits to this repo apply immediately.

Installs to `~/.claude/skills/architecture-review/`. Available in every project after. Restart Claude after installing.

### Or let an agent do it

Open a chat in the project you want reviewed and paste this:

```
Set up the architecture-review skill from https://github.com/sam-cre/Architecture_Review_Skill by following its SETUP-FOR-AGENTS.md, then run a full standard architecture review of this repository.
```

The agent clones the skill outside your project, installs it, runs the review, and reports back. It does not commit, install software into your project, or change anything in it. If an install already exists, it asks before replacing it. The steps are in [SETUP-FOR-AGENTS.md](SETUP-FOR-AGENTS.md).

## Usage

From any project directory:

```
/architecture-review              full review (standard)
/architecture-review quick        structural triage: graph, cycles, hotspots
/architecture-review deep         wider evidence sweep, more change scenarios
/architecture-review pr           review the design of a diff
/architecture-review diff         re-review; did the debt move?
/architecture-review refactor     apply one finding: search, plan, approve, then change
```

It also triggers on plain requests like: *"is this overengineered?"*, *"why is this so hard to change?"*, *"review my architecture"*, *"do I have circular dependencies?"*

## The cleanup workflow

1. **Review.** Run `/architecture-review`. You get `architecture-review.md` (read this) and `findings.json` (the hand-off) in `.architecture-review/` in your project. Nothing in your project is modified.
2. **Decide.** Read the *Fix now* and *Plan it* groups. Items marked *Accept & document* come with a paragraph you can paste into an ADR.
3. **Refactor one finding.** Run `/architecture-review refactor`. It takes the first open item in `fix_order`, then:
   - runs the finding's **search directive**: the searches that find every reader, writer, or caller the fix touches
   - checks the finding is still true
   - finds the project's build and test commands and records a green baseline
   - writes a plan and **stops for your YES**
   - applies the steps one at a time, undoing any step that turns the tests red
   - re-runs the original measurement and reports before and after
4. **Commit yourself.** The skill never commits or pushes unless you ask.
5. **Repeat, then re-review.** One finding per run. Run `diff` now and then to see whether the debt actually moved.

If the project has no tests, the first refactor is often writing characterization tests (tests that pin current behavior). The plan shows them, and they wait for your YES like everything else.

## How it works

| Phase | |
|---|---|
| 0 | Recon & intent: profile, and set the **ceremony budget** (T1–T4) that every finding is graded against |
| 1 | Evidence harvest: run the tools, record raw output, form **no** judgments |
| 2 | Structure: module organization, boundaries, dependency direction, cycles, and the implicit-coupling census |
| 3 | Abstraction: SOLID lens, missing/incorrect abstraction, duplication, overengineering |
| 4 | Change-cost simulation: what past changes actually cost; anchored projections only after |
| 5 | Adversarial self-review: defend every finding, then audit the ledger |
| 6 | Prioritized plan: sequence by leverage, write `fix_order`; "accept & document" and "change nothing" are valid |
| 7 | Report: with a mandatory coverage statement, plus `findings.json` |

Measurement comes before reading, deliberately: reading first and measuring afterward produces cherry-picked evidence.

### Refactor mode in one table

| Step | What happens | Stops when |
|---|---|---|
| Preconditions | Valid review, one finding chosen, clean tree, green baseline | Any check fails |
| Discovery | Runs the finding's `search_directive`, compares with `expect` | Results are narrower, empty, or hit dynamic references |
| Safety net | Names covering tests; plans characterization tests if none | Characterization tests fail on unchanged code |
| Plan | Writes `.architecture-review/refactor/<id>.md` | Waits for YES |
| Apply | One behavior-preserving step at a time, tests after each | A step turns the tests red (it is undone) |
| Prove | Re-runs the original measurement and the directive | Reports whether the measurement moved |

## Honesty guarantees

- No architecture score, grade, or health index. Severity is ordinal: Blast Radius × Change Frequency, with `(measured)` or `(judged)` marked on every axis.
- No metric it did not compute; no file or line it did not open.
- If a tool is missing, it says so, uses a documented fallback, and caps the resulting confidence.
- Every report states what was **measured**, what was **reasoned**, and what was **not reached**.
- A clean review is a valid outcome. If your design is sound for what it is, the report says so and stays short.
- Refactor mode never reports an improvement it did not measure.

## Development

Edit `skill/architecture-review/`. That is the source of truth. Then run:

```bash
bash check-consistency.sh
```

It checks the router, phase table, mirrors, rule anchors, ceiling ranges, both JSON schemas, and that the findings schema accepts `tests/fixtures/findings-valid.json` and rejects `tests/fixtures/findings-missing-search-directive.json`. CI runs the same script on every pull request (`.github/workflows/ci.yml`).

Layout and invariants are in `CLAUDE.md`. Agent-specific pointers are in `AGENTS.md`, `.cursorrules`, and `.windsurfrules`.
