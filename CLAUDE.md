# Architecture Review Skill

This repo **is** a skill. `skill/architecture-review/` is the portable unit; `install.ps1` / `install.sh` copy or symlink it to `~/.claude/skills/architecture-review/` so it works in every project.

## Working on this repo

- The source of truth is `skill/architecture-review/`. Edit there.
- After editing, re-run the installer to sync - or install once with `-Link` / `--link` and edits apply immediately.

## Structure

```
skill/architecture-review/
├── SKILL.md                     always loaded - keep it lean
└── references/
    ├── rules.md                 single source of truth: ledger, confidence,
    │                            gate, severity, schema, noise, anti-fabrication
    ├── phases/                  8 files, phase-0-recon .. phase-7-report
    ├── domains/                 loaded by project shape; the router in
    │                            SKILL.md is the checked source of truth
    │                            (no count here - it drifts)
    ├── tooling/                 per-measurement commands + fallbacks
    ├── templates/               report, profile, traces, 2 JSON schemas
    ├── differential-protocol.md diff mode
    └── parallel-review.md       large codebases
```

## Invariants - do not break these

**Paths.** Every `references/...` path is relative to the skill directory. This works only because it is installed as a *skill*, not as a `.claude/commands/` slash command - commands resolve relative to the CWD, which silently breaks every reference and leaves the model improvising a review that looks correct. Do not add a command file.

**No duplication.** The evidence ledger, confidence tiers and ceilings, the 5-Point Cost Gate, the severity/priority model, the finding schema, noise control, and the anti-fabrication rules live in `references/rules.md` **only**. Phase files, domain guides, and the agent mirrors cite sections by number; they must never restate the content. Duplication caused real drift in the sibling skill - copies diverge and the model follows whichever it read last.

**Section numbers in `rules.md` are stable citation anchors.** Everything cites them. Add sections; never renumber.

**Read-only.** The skill never modifies a file in the reviewed project and never installs into it. There is no fix or refactor phase - `findings.json` is the hand-off to a separate, scoped session. This was a deliberate v1 decision: cross-boundary refactoring is fragile at current context lengths, and a broken build destroys the trust a rigorous assessment earns. Do not add a fix phase without revisiting that reasoning.

**Output directory.** Artifacts go to `.architecture-review/` in the reviewed project - never `references/` or `Templates/`, which collide case-insensitively with the skill's own tree on Windows and macOS.

**Context discipline.** `SKILL.md` and `rules.md` are the only always-resident files. Every phase file states what to hold and what to release. Phase 1 raw tool output goes to files, never into context. Content added to `SKILL.md` costs tokens on every invocation - put it in a phase or domain file instead.

**No fabricated numbers.** There is no architecture score, grade, health index, or maturity level, and there never will be - the severity model is deliberately ordinal (Blast Radius × Change Frequency, then Priority against Remediation Cost) with `(measured)`/`(judged)` provenance on every axis. Do not introduce invented decimals; that is the failure the sibling skill's CVSS handling exists to avoid.

**Confidence is mechanical.** Ceilings C1–C5 derive from evidence-ledger tags, not judgment. If you change the tag set in §2, update the ceilings in §3 and the JSON schema's `evidence` and `ceiling_applied` fields together.

## Known soft heuristics - deliberately not invariants

**The T1–T4 ceremony-budget bands in `phases/phase-0-recon.md` Step 3.** Everything in the review is graded against the tier, and the tier's LOC component is the least evidence-backed number in the design - LOC is language-dependent, and 10k lines of Java is a fraction of the system 10k lines of Rust or Haskell is.

Step 3 therefore ranks **boundary counts above LOC** (modules, deployables, packages, exported surface) and instructs the reviewer to state which signal it graded on, to shift for language density, and to pick the lower tier when two are defensible. Treat the bands as loosely held defaults and recalibrate them against real codebases you know well.

If you tighten these, the natural next step is weighting the structural counts explicitly rather than leaving the tie-break to judgment.

## Adding a domain guide

1. Write `references/domains/<name>.md` in the existing shape: a stated **primary failure mode** at the top, numbered sections of concrete signals, then a short "Reviewing this shape well" section on review strategy.
2. Anchor it to that failure mode. A guide that becomes a generic checklist is worse than no guide - the value is judgment, not pattern-matching.
3. Add a row to the domain router in `SKILL.md`, keyed on the **detection signal** - what in the project indicates the guide applies - plus its primary failure mode.
4. Re-run the installer.
5. Verify the router matches disk:
   ```bash
   diff <(grep -oE 'references/domains/[a-z-]+\.md' SKILL.md | sort -u) <(ls references/domains | sed 's|^|references/domains/|' | sort)
   ```

## Adding a phase

Phases are numbered and sequential. Adding one means renumbering the files after it, updating the phase table in `SKILL.md`, the mode-to-phase mapping, all four mirrors, and the `mode` enum in `templates/findings-schema.json`. Consider a section inside an existing phase first.

## Other assistants

`AGENTS.md` (Codex), `.cursorrules` (Cursor), and `.windsurfrules` (Windsurf) mirror the load order, modes, phase list, and rule *pointers* using repo-relative paths - those tools run with the repo as CWD, not an installed copy.

They deliberately contain **no** rules content: no gate criteria, no confidence tiers, no severity tables, no schema, no do-not-report list. Each one ends by pointing at `references/rules.md` §1–§9 and instructing the reader not to re-derive it.

**When you change modes, phase numbering, or core rules, update `SKILL.md` → `AGENTS.md` → `.cursorrules` → `.windsurfrules`, in that order, or they drift.**

Then run the check - a hand-maintained mirror of a spec that changes is a boundary that has already failed unless something verifies it:

```bash
./check-consistency.sh
```

It verifies the router and phase table against disk, that every `references/...` path resolves, that the mirrors agree with `SKILL.md` on modes and phase range, that no mirror restates rules content, that `rules.md` still has its 9 stable anchors, and that both schemas parse.
