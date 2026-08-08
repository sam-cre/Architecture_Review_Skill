---
name: architecture-review
description: >-
  Evidence-based architecture and design-quality review for any codebase — module
  organization, coupling and cohesion, dependency direction and cycles, SOLID
  violations, real duplication, missing and incorrect abstractions, overengineering,
  scalability bottlenecks, testability, and future change cost. Grounds every finding
  in dependency-graph output, git co-change history, and duplication/complexity
  metrics rather than style opinion. Use when the user asks to review, audit, or
  critique a project's architecture, design, or structure; asks "is this designed
  well", "is this overengineered", "is my folder structure right", "SOLID review",
  "is this maintainable", "where is my technical debt", "why is this so hard to
  change", "are my modules too coupled", "should I split this up", "do I have
  circular dependencies", "review the design of this PR"; wants to make sense of a
  vibecoded or AI-generated codebase that got out of hand, "why doesn't this
  feature's data show up", "is my data consistent across the app", "audit my
  webhook/integration wiring", "what does my app actually depend on", find second
  sources of truth or unwired external contracts; or wants a structural refactor
  plan. Not for finding bugs or security vulnerabilities.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash, Task, TodoWrite
---

# Architecture Review

Evidence-based design-quality review. The question is *"is this actually designed well?"* — not "does it have bugs" and not "does it match a style guide."

Adapt to what the project actually **is**. Do not assume a stack, a size, or an intended pattern until Phase 0 confirms it.

**Default posture: assume the codebase was assembled feature-by-feature, likely with an LLM.** That is the common case now, and it changes the evidence order. Such repos have no usable git history (bundled, single-author — it fails its own survivor sample) and no asserted architecture, so the highest-value evidence is the **writer/reader ledger** and the **integration inventory** (Phase 1 measurements 7–8), not history. The posture changes the **ranking** of evidence, never which measurements run: history is always attempted, and its own *mechanical survivor sample* — not the "vibecoded" label — decides whether it leads or is set aside (`phases/phase-1-evidence.md`). A misclassified repo therefore loses ranking, not evidence. The two failures that most often break these systems — a second source of truth (`data-flow-gap`) and an unwired external contract (`integration-gap`) — are invisible to the import graph, and finding them is the point. On a mature repo with history and asserted intent, the older order still applies; Phase 0 tells you which you are in.

## Path Resolution — read this first

Every `references/...` path below is **relative to this skill's own directory** (the folder containing this SKILL.md), *not* the project being reviewed. If a Read fails, locate this SKILL.md and resolve from there. Never guess at the contents of a file you could not load — say the load failed.

Review artifacts are written to **`.architecture-review/`** in the *reviewed project's* root. These two trees are different things; never conflate them.

## Non-Negotiable Guardrails

1. **Read-only.** This skill never modifies a file in the reviewed project. Nothing is installed into it. The only writes go to `.architecture-review/`.
2. **Measure before you opine.** Phase 1 gathers evidence with no judgments. Reading first and measuring afterward produces cherry-picked measurement.
3. **Every finding passes the 5-Point Cost Gate** and carries a tagged evidence ledger. No demonstrated cost → not a finding.
4. **No invented numbers.** No scores, grades, indices, or metrics you did not compute.
5. **A clean review is a valid outcome.** Manufacturing findings to justify the review is this skill's worst failure mode.

**Read `references/rules.md` now.** It is the single source of truth for the evidence ledger, confidence tiers and ceilings, the 5-Point Cost Gate, the severity/priority model, the finding schema, noise control, and anti-fabrication. It loads once and applies to every phase — later files cite it by section number and never restate it.

## Modes

Determine the mode before Phase 0. Default is `standard`.

| Mode | Phases | Use for |
|---|---|---|
| `quick` | 0, 1, 2, 7 | Structural triage — graph, cycles, hotspots, module organization. Answers "is my folder structure sane". No abstraction judgment. |
| `standard` | 0–7 | Full design review. Default. |
| `deep` | 0–7 | Same phases, wider: full history window, every available tool, all matching domain guides, 5–8 change scenarios instead of 3. |
| `pr` | 0 (light), 2, 3, 5, 7 | Scoped to a diff. Does *this change* move the architecture in a good direction? Scope Phases 2–3 to changed files plus their direct dependents. |
| `diff` | — | Re-review against a prior run. Read `references/differential-protocol.md`. |

There is no fix or refactor mode. The Phase 7 JSON is the hand-off artifact for a separate, scoped refactoring session.

## Phases

Work in order. Findings are queued and gated, never filed on sight.

| # | Phase | File | Gate |
|---|---|---|---|
| 0 | Recon & intent: profile, ceremony budget, domain routing | `references/phases/phase-0-recon.md` | Ceremony budget set |
| 1 | Evidence harvest: run the tools, record raw output, no judgments | `references/phases/phase-1-evidence.md` | Tool availability table written |
| 2 | Structure: module organization, boundaries, dependency direction, cycles | `references/phases/phase-2-structure.md` | Graph reconciled with folders |
| 3 | Abstraction: SOLID lens, missing/incorrect abstraction, duplication, overengineering | `references/phases/phase-3-abstraction.md` | Every candidate gated |
| 4 | Change-cost simulation: what past changes cost, what named future ones would | `references/phases/phase-4-change-cost.md` | History searched before hypotheticals |
| 5 | Adversarial self-review: defend each finding, hunt gaps, audit the ledger | `references/phases/phase-5-adversarial.md` | Every finding survived or dropped |
| 6 | Prioritized plan: sequence by leverage; "accept & document" is a valid output | `references/phases/phase-6-plan.md` | Every finding has a priority |
| 7 | Report: human markdown + JSON baseline + honest coverage statement | `references/phases/phase-7-report.md` | Coverage stated |

**Load ONLY the current phase file.** Do not pre-load future phases. Release the previous phase file when you advance.

## Domain Router

In Phase 0, identify the project shape and load **only** the matching guides, for use in Phases 2–3. Most projects match one or two. Each guide is anchored to that shape's *primary failure mode* — read it for that, not as a checklist.

| Signal in the project | Load | Primary failure mode |
|---|---|---|
| HTTP handlers/controllers, service + repository layers, ORM models, migrations, background jobs | `references/domains/backend-service.md` | Domain logic bleeding into transport and persistence |
| Component tree, client router, state store (Redux/Zustand/Context/signals), co-located styles | `references/domains/frontend-app.md` | State topology — prop drilling, global-store sprawl, data-fetch placement |
| Published package manifest, explicit `exports`/`__all__`/`pub` surface, semver tags, consumer docs | `references/domains/library-sdk.md` | Accidental public surface and unversioned breaking change |
| ≥2 deployable units, service-to-service HTTP/gRPC/queue, per-service manifests, multi-image compose/k8s | `references/domains/distributed-services.md` | Distributed monolith and shared-database coupling |
| Workspace config — pnpm/yarn/npm workspaces, nx, turbo, lerna, cargo workspace, go.work, Gradle multi-project | `references/domains/monorepo.md` | Workspace boundary violations and the shared-package black hole |
| Android/iOS/React Native/Flutter, native bridge, platform lifecycle | `references/domains/mobile-app.md` | Platform boundary leakage and offline/sync state ownership |
| An argv/flag parser, a `[[bin]]`/`main`/console entry point, terminal or stdout output, no server and no published library surface — including TUIs, REPLs, game loops, and hosts that parse their own DSL | `references/domains/cli-tool.md` | The decide/emit boundary — logic entangled with output, then reimplemented per front-end |
| Single/two-author bundled history, no ADRs, folders that assert a pattern the code drops, heavy external-service glue (Firebase/Supabase/Stripe/Clerk/webhooks) | `references/domains/vibecoded-app.md` | Second source of truth (a store one consumer never learned about) and unwired external contracts |

**No workspace config → single-package is the default**; do not load `monorepo.md`. `mobile-app.md` and `vibecoded-app.md` are delta guides — load each *with* the stack guide it modifies (`frontend-app.md`, `backend-service.md`, …), not instead of it.

**If nothing matches, say so and proceed — do not force a fit.** Load no guide, record `domains: none matched` in `project-profile.md`, and carry Phases 2–3 on `rules.md` and the phase files alone; they are complete without a domain guide, which only adds a failure-mode lens. Forcing the nearest guide is worse than none, because its checklist will pull the review toward failure modes this project cannot have.

**A partial match is worth taking, if you say what you took.** Load the guide for the lens that applies and ignore the rest — `frontend-app.md`'s state-topology section is useful to anything with two views over one state, whatever the stack. Record which sections you used and which you disregarded, and note the unmatched aspects in the coverage statement so a reader knows that part was reasoned without a guide.

## Context Discipline

Each phase file opens with what to **hold** and what to **release**. Follow it. `SKILL.md` and `rules.md` are the only always-resident files.

Phase 1 raw tool output goes to files in `.architecture-review/evidence/`, never into context — read back only the summary lines you need. A full `madge` or `jscpd` dump will consume the budget you need for Phase 3.

Release domain guides after Phase 3. Release Phase 1–4 detail before Phase 7; the report is written from the findings file, not from memory.

For codebases over ~300 source files or 3+ languages, read `references/parallel-review.md` and split Phases 2–3 by module.

## Output Workspace

Create `.architecture-review/` in the reviewed project root. Phase 0 lists the files; create subdirectories lazily, only when something is about to be written into them. Mention that they may want to gitignore it — but `.gitignore` is a project file, so edit it only if they explicitly ask (`references/rules.md` §1).

If it already exists from a prior run, use `references/differential-protocol.md` instead of starting over.
