# Architecture Review — <project name>

<!--
Template for .architecture-review/architecture-review.md (Phase 7).
Section order is fixed. Delete any section that has no content — do not pad it.
Length is proportionate to findings. A short review is a valid outcome.
-->

**Reviewed:** <date> · **Mode:** <quick|standard|deep|pr|diff> · **Tier:** <T1–T4>
**Nothing in this project was modified.**

---

## The answer

<!--
Answer the user's Phase 0 question directly, in one paragraph, with the evidence.
If they asked nothing specific, give the one-line verdict plus the single most
consequential finding. Do not hedge into a list. This paragraph is the report.
-->

---

## What this project is

- **Type:** <backend service / SPA / library / monorepo / …>
- **Size:** <N source files, ~N LOC, N modules>
- **Tier:** <T1–T4> — <one line of reasoning; adjust for trajectory if relevant>
- **Asserted architecture:** <the pattern the project claims, or "none asserted">
- **Excluded:** <in-flight migrations, accepted tradeoffs, scoped-out paths>

---

## Coverage

<!-- Mandatory, and it goes here — not at the end. rules.md §8.10 -->

**History window:** <N days> · **Repo age:** <…> · **Contributors in window:** <N>
**Execution model:** <single session — Phase 5 was a filter, not an independent audit | cold phases, each a separate invocation reading findings.md fresh> (`rules.md` §9)

### Aggregate validity

<!--
Ceiling C5. Co-change is the most confounded signal here — bundled commits make
every file in them co-change with every other. State whether the aggregates were
validated, or the numbers below cannot support High confidence.
-->

- **Co-change fanout cap:** <12> — **commits excluded:** <N of M>
- **Survivor sample:** <N sampled> → <N focused / N bundles / N unclassifiable> → **verdict: <usable | usable with mandatory per-pair spot-check | UNUSABLE>**

<!--
The exclusion percentage above is NOT the verdict — it is deaf to small
multi-concern commits that pass the cap. The sample is the verdict.
rules.md §3 (C5 on corpus verdicts) · tooling/git-history.md §2.
If UNUSABLE: quote no pair counts anywhere in this report, and say here that
cohesion was judged from the import graph and by reading, at ceiling C1.
-->

- **Sampled commits:** <sha — classification, one line each>
- **Validated pairs:** <which specific pairs were re-derived against filtered history, or how many contributing commits were spot-checked>
- **Unvalidated aggregates:** <listed — these carry C5 and cap at Medium>

### Measured

| Measurement | Tool | Ran | Fallback | Effect on findings |
|---|---|---|---|---|
| Dependency graph | madge 6.1.0 | yes | — | `[tool]` |
| Duplication | jscpd | no — unavailable offline | grep repeated-block scan | `[proxy]` → capped Medium |
| Complexity | — | no | none | capped by C1 |

### Reasoned

<!-- What was read and judged without tool backing, and why. These cap at Medium. -->

### Implicit-coupling census

<!--
Phase 2 §6. Static graphs cannot see event buses, shared tables, or string-keyed
registries — a distributed monolith looks decoupled to madge. State which channels
were censused and which could not be.
-->

| Channel | Censused | Corpus | Cross-module hits |
|---|---|---|---|
| Events / messages | yes | `src/`, ts+tsx | 4 keys shared across 2 modules with no import edge |
| Database tables | yes | `src/`, excl. `migrations/` | 1 table written by 2 modules |
| Routes | yes | `src/` | none |
| Binary protocol | **no** — cannot enumerate | — | unknown |

### Dead code inventory

<!--
rules.md §7 — inventory, not findings. A count and the largest items, never one
entry per unused symbol. State the false-positive risk of the detection method.
Escalates to a finding only as evidence of a structural problem.
-->

- **Detected:** <N unreferenced files, N unused exports> via `<tool>`
- **Survived dynamic-reachability check:** <N> — <what was ruled out: DI registration, route auto-discovery, public package export…>
- **Excluded from metrics:** <N files / N LOC> — LOC reported above is <corrected | uncorrected>
- **False-positive risk:** <what this method misses>

### Machine artifact verification

- `findings.json` — <parsed OK, schema-validated (ajv) | parsed OK, schema not validated (no validator available)>

### Not reached

<!--
Directories skipped, languages not analyzable, runtime behavior not observable,
generated code not verified, implicit-coupling channels that could not be
censused. Be specific. "I could not assess the Python service — 40% of the code —
because no dependency tool was available" is worth more than any
Medium-confidence finding.
-->

---

## Findings

<!-- Grouped by priority, not severity. Omit empty groups entirely. -->

### Fix now

<!-- Sequenced. State what each one unblocks. -->

### [ARCH-001] <short imperative title>

- **Location:** `path/to/file.ext:88-142`
- **Category:** <closed-list value> · **Severity:** <…> · **Priority:** Fix now
- **Confidence:** <High|Medium|Low> — ceiling applied: <none|C1|C2|C3|C4>
- **Blast radius:** Wide *(measured: 61 of 94 modules import it)*
- **Change frequency:** Hot *(measured: 41 commits/180d, top decile)*
- **Remediation cost:** Medium *(judged: 4 files, needs new tests, no contract change)*

**Evidence**

```
[tool] <command>
       <verbatim excerpt>
[git]  <command>
       <actual numbers>
[read] path:88-142 — <what is actually there>
[infer] <the reasoning connecting them>
```

**Cost demonstrated:** <historical | blocked capability | forced — history searched: `<cmd>`, none found; anchored to: `<anchor>`>

**What's wrong.** <Structurally, what the code does.>

**Why it costs.** <The concrete consequence, tied to the evidence above.>

**Considered defense.** <The strongest case for the current design, and why it does not hold.>

**Recommendation.** <The specific change. Name files. Prefer the smaller fix.>

**Cost of the fix.** <Contained | Moderate | Substantial — and what makes it that.>

**If you do nothing.** <What this looks like in six months.>

---

### Plan it

<!-- High severity, high cost. State what the decision actually is. -->

### Fix when you next touch it

<!-- Name the trigger: "when you next add a provider". -->

### Accept & document

<!--
For each: the two or three sentences to paste into an ADR or a comment —
what the tradeoff is, why it was accepted, what would change the answer.
That text is the deliverable here.
-->

### Note only

<!-- One line each. No elaboration. -->

---

## What I am not recommending

<!--
Fixes considered and deliberately rejected. Two or three lines each.
This protects the user from the next review and shows the bar was applied.

**Not recommended: extracting a repository layer.** The three call sites that
touch the ORM directly have not changed in 14 months, and the layer would add a
pass-through file per entity. Revisit if you add a second persistence target.
-->

---

## Considered and dropped

<!-- One line each, with the gate that failed. -->

| Candidate | Failed | Why |
|---|---|---|
| `src/legacy/` uses an older pattern | G-excl | In-flight migration, recorded in Phase 0 |
| `OrderService` is 900 lines | G2 | Single co-change cluster — cohesive, not overloaded |
| No repository abstraction | G3/G5 | Fix costs more than the coupling does at T2 |

---

## Informational

<!-- Gate-failed items still worth a mention. Not findings. -->

---

## Baseline

<!-- For comparison on the next run. Only measured numbers; omit what you could not fill. -->

| Metric | Value |
|---|---|
| Source files | |
| Source LOC | |
| Modules | |
| Dependency cycles | |
| Max fan-in | |
| Duplication | |
| Hotspots (complex × hot) | |

Re-run in `diff` mode against `.architecture-review/metrics-baseline.json` to see whether this moved.

---

## Files produced

- `architecture-review.md` — this report
- `findings.json` — hand-off for a scoped refactoring session, one finding at a time
- `metrics-baseline.json` — input to the next `diff` run
- `change-cost-traces.md` — what past and projected changes cost
- `evidence/` — raw tool output

*No project file was modified.*
