# Project Profile - <name>

<!-- .architecture-review/project-profile.md - written in Phase 0, read by every later phase. -->

**Reviewed:** <date> · **Mode:** <quick|standard|deep|pr|diff>

---

## The question

<!--
The user's actual question, verbatim if they asked one. Phase 7 must answer THIS
in its first paragraph. "is this overengineered" / "why is this so hard to change"
/ "should I split this up". If they asked nothing specific, write "general review".
-->

---

## Profile

| Dimension | Value |
|---|---|
| Type | |
| Languages | <each, with share of source files> |
| Frameworks | <with versions from manifests> |
| Source files | <excluding generated/vendored> |
| Source LOC | |
| Modules / top-level dirs | |
| Entry points | |
| Deployable units | |
| Tests | <present? roughly what proportion? do they run?> |
| Build / CI | <tool; does CI enforce anything structural?> |
| Repo age | |
| Contributors (all time / in window) | |

---

## Non-code architecture

<!-- Phase 0 Step 1b. Neither of these appears in any dependency graph. -->

### Schema

**Authoritative definition:** <`prisma/schema.prisma` | `migrations/` | entity classes | none - no persistence>

**Table inventory** - the corpus for the Phase 2 §6 database census. Without this the census is pattern-guessing and its findings cap at Medium.

| Table / collection | Owning module (if evident) |
|---|---|
| | |

### Deployment topology

**Pipeline files read:** <`.github/workflows/deploy.yml`, `docker-compose.yml`, …>

| Unit | Deploys independently? | Triggered by |
|---|---|---|
| | | |

<!--
Clean module boundaries + a pipeline that ships everything on any change =
coupled at runtime regardless of the graph. Record it here even though it looks
like a CI concern; monorepo.md §4 and distributed-services.md §1 treat it as a
boundary, not as build performance.
-->

---

## Intended architecture

**Signal strength:** <asserted-and-enforced | asserted-in-docs | implied-by-folders | none>

<!--
What the project claims to be, and where that claim comes from:
  1. ARCHITECTURE.md, ADRs, README section
  2. Folder names asserting a pattern (domain/, adapters/, usecases/)
  3. Enforcement config - dependency-cruiser, import-linter, ArchUnit, Nx tags,
     eslint no-restricted-imports  ← strongest signal
  4. The dominant convention in the code

If (3) exists, note any rules that are disabled, warn-level, or carry exemptions -
an exemption list is a boundary that already failed, and it is dated.

If nothing asserts a pattern, write "none asserted" - the codebase then has no
architectural contract to violate, and findings must stand on cost alone.
-->

---

## Ceremony budget

**Tier: <T1 | T2 | T3 | T4>**

<!--
T1 Script/tool      ~<2k LOC · 1 module          → functions and files; layers are overhead
T2 Small app        ~2k–15k LOC · 2–5 modules    → module folders + ONE boundary that matters
T3 Growing product  ~15k–100k LOC · 6–20 modules → real boundaries, explicit direction, seams at volatile points
T4 Large system     ~>100k LOC · 20+ modules     → enforced boundaries, contracts, CI dependency rules

LOC is the weakest signal here. Boundary counts win when they disagree.
-->

**Modules:** <N> - counted by rung <1 deployment artifact | 2 package manifest | 3 public entry point | 4 boundary rule | none matched → 1 module>

<!--
Mechanical definition, phase-0-recon.md Step 3. A folder whose files are imported
individually is a NAMESPACE, not a module - utils/ with 50 functions counts as 1.
A framework routing directory is not a set of modules; count the deployable.
If no rung matches, the codebase has exactly one module - at T3+ that is itself
a first-class finding.
-->

**Graded on:** <structural count | LOC | both agree> - <modules, deployables, packages, exported surface, dependency count>

**Reasoning:** <the numbers that put it here>

**Density adjustment:** <e.g. "shifted up - 9k LOC of Rust is more system than the band assumes", or "none">

**Trajectory adjustment:** <e.g. "T2 by size but reviewed as early T3 - 3 commits/day and 4 new contributors this quarter", or "none">

> Every finding is graded against this tier. A recommendation that only makes
> sense one tier up fails Gate 5 and is discarded.

---

## Exclusions

**In-flight migrations** - <both sides named; the deprecated side is never a finding>

**Accepted tradeoffs** - <what the user already knows about and has accepted>

**Out of scope** - <directories the user excluded; generated/vendored/build are excluded by default>

**Known deadline artifacts** - <code the user identified as knowingly rushed>

---

## Domain routing

| Matched guide | Triggering signal |
|---|---|
| `domains/backend-service.md` | `src/api/` handlers + Prisma models + `jobs/` |
| `domains/monorepo.md` | `pnpm-workspace.yaml`, 7 packages |

<!-- Loaded in Phase 2, not Phase 0. Released after Phase 3. -->

---

## Assumptions

<!--
Anything you had to decide without confirmation, stated plainly so the user can
correct it. If intent was unclear and one question would resolve it, ask it in
Phase 0 - then record the answer here.
-->
