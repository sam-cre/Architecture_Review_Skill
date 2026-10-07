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
- `refactor` - apply one finding from a prior run, behavior-preserving, after approval. Read `references/refactor-protocol.md`.

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

When you change modes, phase numbering, or core rules, update `SKILL.md`, `AGENTS.md`, `.cursorrules`, and `.windsurfrules` **together, in that order**, or they drift. See `CLAUDE.md` for the full invariants.
