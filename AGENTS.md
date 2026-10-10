# Architecture Review Skill - Agent Instructions

Evidence-based architecture and design-quality review. When the user asks to review, audit, or critique a codebase's architecture, design, or structure - or asks "is this designed well", "is this overengineered", "is my folder structure right", "why is this so hard to change" - follow `skill/architecture-review/SKILL.md`.

Not for finding bugs or security vulnerabilities.

## Path resolution

All `references/...` paths are relative to **`skill/architecture-review/`**, not to the project being reviewed. Review output goes to `.architecture-review/` in the reviewed project. These are different trees - never conflate them.

## Loading order

1. `skill/architecture-review/SKILL.md` - modes, phases, domain router
2. `skill/architecture-review/references/rules.md` - the evidence ledger, confidence tiers, the Cost Gate, severity, the finding schema, noise control, anti-fabrication. Load once; it applies to every phase and the phase files do not restate it.
3. `references/phases/phase-N-*.md` - one at a time, as you reach each phase. Never pre-load.
4. `references/domains/*.md` - only the guides matching the shape identified in Phase 0. Release after Phase 3.
5. `references/tooling/*.md` - as needed in Phase 1, then release.

## Modes

- `quick` - phases 0, 1, 2, 7. Structural triage.
- `standard` - phases 0–7. Default.
- `deep` - phases 0–7, wider: full history, every tool, all matching domains, more change scenarios.
- `pr` - phases 0 (light), 2, 3, 5, 7, scoped to a diff.
- `diff` - re-review against a prior run. Read `references/differential-protocol.md`.
- `refactor` - apply one finding from a prior run, in `fix_order`. Search what it touches first, then behavior-preserving steps after approval. Read `references/refactor-protocol.md`.

## Phases

0 recon & intent · 1 evidence harvest · 2 structure · 3 abstraction · 4 change-cost · 5 adversarial · 6 plan · 7 report

## Non-negotiable rules

1. **Read-only.** Never modify a file in the reviewed project and never install into it. Only `.architecture-review/` is written. No review phase fixes anything - `findings.json` is the hand-off to `refactor` mode, a separate session.
2. **Measure before you opine.** Phase 1 runs tools and forms no judgments. Reading first and measuring after produces cherry-picked evidence.
3. **Never conclude "decoupled" from import edges alone.** Static graphs cannot see event buses, shared database tables, or string-keyed registries - a distributed monolith looks clean to `madge`. Phase 2 mandates an implicit-coupling census.
4. **Every finding passes the 5-Point Cost Gate** - `references/rules.md` §4. No demonstrated cost, no finding.
5. **History before hypotheticals.** Gate 2 admits a projected future change only after a git search found no comparable past one, and only with a named anchor. Which commits are admissible is defined in §4 - chores and upgrades never count.
6. **Every finding carries a tagged evidence ledger** - §2. At least one `[read]` line; an `[infer]`-only ledger is discarded, not downgraded.
7. **Confidence is derived, not judged** - §3. Ceilings C1–C5 come from the ledger tags; the lowest applies.
8. **Never state a metric you did not compute or cite a line you did not open** - §8. No scores, grades, or indices, ever.
9. **A clean review is a valid outcome.** Manufacturing findings is this skill's worst failure mode.

## Where the rules live

Confidence tiers, the Cost Gate, the evidence ledger, the severity/priority model, the finding schema, and the do-not-report list live in `skill/architecture-review/references/rules.md` §1–§9. **Load it once. Do not restate, summarize, or re-derive it here or anywhere else.**

## Working on this repo

This repo **is** the skill. `skill/architecture-review/` is the source of truth - edit there, then re-run `install.ps1` / `install.sh` to sync (or install once with `-Link` / `--link` and edits apply immediately).

When you change modes, phase numbering, or core rules, update `SKILL.md`, `AGENTS.md`, `.cursorrules`, and `.windsurfrules` **together, in that order**, or they drift. See `CLAUDE.md` for the full invariants. Run `bash check-consistency.sh` before finishing; CI runs the same script.

## Publishing changes (Git runner)

This repository publishes through an operator-owned Git runner. You never run Git write commands.

- Runner: `C:/Users/SamRo/agent-pr-runner-architecture/agent-pr-runner.exe`
- Queue: `C:/Users/SamRo/agent-pr-runner-architecture/queues/architecture-review`

### Rules

- Never run `git add`, `commit`, `push`, `merge`, `rebase`, `reset`, `checkout -b`, `switch -c`,
  `branch -D`, `tag`, `stash`, or `gh pr create/merge`. Read-only Git (`status`, `diff`, `log`,
  `rev-parse`, `show`) is fine.
- One logical change per request, one request per PR.
- Run this repository's verification gates first, and report their real results as evidence.
- Branch names are neutral and purpose-based: `feature/...`, `fix/...`, `docs/...`, `chore/...`.
- Commit messages and PR titles are one line and start with a semantic type: `feat:`, `fix:`,
  `docs:`, `chore:`, `refactor:`, `test:`, `ci:`, `build:`, `perf:`, `style:`.
- Never put AI product names, co-author lines, "generated with" lines, or any other attribution in
  a branch name, commit message, PR title, or PR text. The runner refuses them.
- Never ask the operator to run Git commands for you. If the runner fails, read the receipt and
  follow the table below.

### Publishing a change

1. Run the gates. Note each command and its real result.
2. Read the current state: `git rev-parse HEAD` and `git branch --show-current`.
3. Write a request file **outside the repository** (a temp or scratch folder), for example
   `request.json`:

```json
{
  "id": "fix-parser-empty-input-1",
  "expected_head": "<full 40-character SHA from git rev-parse HEAD>",
  "branch": "fix/parser-empty-input",
  "create_branch": true,
  "files": ["src/parser.rs", "tests/parser.rs"],
  "commit_message": "fix: return an empty document for empty input",
  "pr_title": "fix: return an empty document for empty input",
  "summary": ["What changed and why, one point per line."],
  "verification": [{ "check": "cargo test", "result": "212 passed" }],
  "traceability": ["Issue, plan item, or request this change answers"]
}
```

   - `id`: new and unique each time (letters, digits, `-`, `_`; at most 80).
   - `create_branch: true` when starting from the base branch. To add a fix to an open PR's branch,
     use `create_branch: false`, the same `branch`, and that branch's current HEAD.
   - `files`: every path to stage, exactly as Git spells it, relative to the repository root. No
     folders, no wildcards. Deleted files are listed too.

4. Submit and wait (this blocks until a receipt arrives; allow up to an hour or more):

```
"C:/Users/SamRo/agent-pr-runner-architecture/agent-pr-runner.exe" submit "C:/Users/SamRo/agent-pr-runner-architecture/queues/architecture-review" <path to request.json>
```

   If your shell times out first, the request keeps running. Check it with:

```
"C:/Users/SamRo/agent-pr-runner-architecture/agent-pr-runner.exe" status "C:/Users/SamRo/agent-pr-runner-architecture/queues/architecture-review" <id>
```

5. Act on the receipt's `status`:

| Status | Meaning | What you do |
| --- | --- | --- |
| `merged` | PR squash-merged; checkout is back on the base branch, pulled. | Report the PR URL. Start the next change from step 1. |
| `needs_fix` | CI or the runner's local checks failed. `detail`, `failure_kind`, and `diagnostic_log` say why. | Read the log, fix the cause, rerun the gates, then submit a new request: same `branch`, `create_branch: false`, `expected_head` = current HEAD, new `id`. |
| `error` before a commit was made | The request was refused (validation, stale HEAD, protected path). | Fix the request or the cause and submit with a new `id`. |
| `error` after the push | Something failed after the commit reached GitHub (PR, CI wait, merge). | Submit the same request again with `resume: true`, `create_branch: false`, `files: []`, `expected_head` = current HEAD, and a new `id`. |
| `merged_needs_refresh` | Merged, but switching back to the base branch or pulling failed. | Report it to the operator with the detail. |
| `needs_inspection` | The runner stopped mid-request. | Stop and report to the operator. Do not resubmit. |

### Operator-only paths

The runner refuses to stage CI workflows, `.git*` files, `CODEOWNERS`, and the extra paths in its
config. If a change needs one of them, write the proposed content to a file outside the repository
and ask the operator to apply it.
