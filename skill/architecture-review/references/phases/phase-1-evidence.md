# Phase 1 - Evidence Harvest

_Hold: `rules.md`, the tier and exclusions from `project-profile.md`. Release: the rest of Phase 0. Output: `.architecture-review/evidence/*`, `metrics-baseline.json`._

**Run tools. Record output. Form no opinions.**

You will notice things while running these. Write them nowhere - not in a scratch note, not in a "preliminary observations" file. The whole point of measuring before reading is that it stops you from cherry-picking evidence to support a conclusion you already reached. Phases 2–4 are where judgment happens.

---

## Context discipline - read this before running anything

**Raw tool output goes to files, never into context.** A `madge` dump on a 500-file repo or a full `jscpd` report will eat the budget you need for Phase 3.

```bash
mkdir -p .architecture-review/evidence
<tool> ... > .architecture-review/evidence/<name>.txt 2>&1
```

Then read back only what you need: a head, a count, a grep for the specific module. Cite the file path in the ledger and quote the excerpt you actually read.

---

## What to gather

Eight measurements. Commands per stack, and the fallback for each, are in the tooling files - load them as you need them and release them after.

| # | Measurement | Tooling file | Feeds |
|---|---|---|---|
| 1 | Module inventory & size distribution | `references/tooling/code-metrics.md` | Blast radius basis, tier check |
| 2 | Dependency graph + cycles + fan-in/fan-out | `references/tooling/dependency-graph.md` | Phase 2 entirely |
| 3 | Git churn, co-change coupling, change amplification | `references/tooling/git-history.md` | Change Frequency axis, Gate 2(a) |
| 4 | Duplication | `references/tooling/code-metrics.md` | Phase 3 duplication triage |
| 5 | Complexity / hotspots | `references/tooling/code-metrics.md` | Prioritization, cohesion signals |
| 6 | Reachability sweep (dead code) | `references/tooling/code-metrics.md` | **Measurement hygiene** - see below |
| 7 | **Writer/reader ledger** - every writer and reader of each store, event, contract | `references/tooling/data-flow.md` | Phase 2 §6, `data-flow-gap` findings |
| 8 | **Integration inventory** - env vars, SDK inits, inbound/outbound external seams | `references/tooling/data-flow.md` | Phase 2 §6b, `integration-gap` findings |

### The evidence hierarchy is inverted for the codebases this skill actually reviews

The classic advice was "git history is the highest-value measurement" - it is the only source of *demonstrated* cost. That holds for a mature repo with a clean, intentional commit history. **It does not hold for the codebase this skill is built to review: assembled feature-by-feature by prompts, one author, bundled commits, no ADRs, glued to external services.** There, history usually fails its own survivor sample (`tooling/git-history.md` §2) and Gate 2(a) is unavailable - so leaning on it produces either nothing or confident noise.

So the primary evidence, in order:

1. **The writer/reader ledger and the integration inventory (7, 8).** These catch the two failures that most often break these systems - a second source of truth (`data-flow-gap`) and an unwired external contract (`integration-gap`) - and neither is visible to any other measurement. **On a vibecoded review, do these first and do them exhaustively.**
2. **The dependency graph (2).** Stack-dependent but mechanical and history-free.
3. **Git history (3) - attempted always, ranked by its survivor sample.** When the sample passes, history is still the strongest *demonstrated-cost* evidence there is and Gate 2(a) is back on the table - use it as primary. When it fails, treat it as not run and say so. Do not force it.

**Classification never gates *which* measurements run - only how they rank.** Always attempt all measurements present in the repo; the demotion of history is driven by the **mechanical survivor-sample result** (`tooling/git-history.md` §2), never by the "vibecoded" label. A repo misjudged as vibecoded whose history is actually clean will pass the survivor sample and history stays primary; the label was never the gate. This is deliberate: a misclassification should cost you *ranking*, not *evidence*. Record the resulting posture - `history-usable` or `history-unusable (survivor sample: N/N bundles)` - in `tool-availability.md` so Phase 7 can state it and a human can override.

In `deep` mode: all eight, full history window, every available tool.

**In `quick` mode: 1, 2, 3, 6, and a bounded 7–8.** `quick` answers *"is my structure sane"* and its budget is the point, so spend it where the cost/answer ratio is best:

- **1, 2, 3, 6 in full.** The graph, cycles, churn and the reachability sweep are each one command and each feeds the structural verdict directly. Measurement 6 is *not* optional here despite being a "hygiene" step - it is one command and it corrects the LOC the tier was graded on.
- **4 and 5 skipped.** Duplication and complexity feed Phase 3, which `quick` does not run.
- **7 and 8 time-boxed, not dropped.** Do the *inventory* - name the stores, events and seams and count writers and readers per name - and stop there. Skip the per-key reading and the totality analysis that `data-flow-gap` findings need, since `quick` files none. An orphaned writer or an unwired payment webhook surfacing in ten minutes is worth more than everything else on this list, but the exhaustive census is a `standard`-mode cost. **State in coverage that 7–8 were inventory-only**, so nobody reads the absence of gaps as their absence.

---

## Every measurement is stack-specific - a wrong-stack empty is a coverage gap, not a clean result

**This skill reviews any language.** Phase 0 profiled the stack; **every measurement below uses the tooling row for that stack** (the `tooling/*.md` files carry per-language tools and patterns). This is not optional polish - it is a correctness rule, because the failure mode is silent:

> A `madge` run, a `process.env` grep, a `collection('x')` census, an `npx knip` sweep all **succeed and return empty** on a Rust, Go, or Python repo. An agent that reads that empty as "clean" reports a false *no findings* - the single easiest way for this skill to be confidently wrong on an unfamiliar stack.

So for the graph, data-flow, integration, duplication, complexity, and reachability alike:

- **Use the tool and patterns for the language Phase 0 identified**; if several languages are present, run each and say which you covered. The tooling files are keyed by stack for exactly this.
- **An empty result from a wrong-stack or absent tool is a coverage gap, not a finding.** Record it in `tool-availability.md` as `no <measurement> tool for <stack>`, take the C1/C2 ceiling (`rules.md` §3), state it in the Phase 7 coverage section - and **never** let it read as "clean." Confirm the tool ran and fit the stack before trusting silence (positive-control it - run against a token you know exists).
- The **stack-appropriateness rule** on the data-flow census (`tooling/data-flow.md` §7 coverage verdict - an empty wrong-stack pattern is `non-enumerable`) is the specific case of this general law; apply the same logic to every measurement.

If the stack is one the tooling files do not cover and you cannot construct an equivalent, that is an honest, first-class limit: say so in coverage rather than reviewing it as if the JS tools had found nothing wrong.

---

## Measurement hygiene - do this before recording any number

**Dead code corrupts this review's own evidence.** Unreachable files inflate LOC (which sets the tier in Phase 0), inflate duplication percentages, and add phantom edges and fan-in to the dependency graph. A metric computed over a corpus that includes abandoned code is measuring the wrong system.

So the reachability sweep is not a search for findings - it is a correction to the denominator:

1. Run the sweep (`code-metrics.md` §4) - orphan modules, unreferenced files, unused exports.
2. **Check dynamic reachability before believing any of it** - the defeaters are listed once in `rules.md` §7 "Dead code - inventory, not findings". Apply that list; do not re-derive it.
3. **Exclude confirmed-dead code from the metrics** and re-record them. State both numbers where the difference is material - "38,400 LOC, or 34,100 excluding 12 unreferenced files."
4. Write `evidence/reachability.md`: what looked dead, what survived the dynamic check, and the false-positive risk of the method used.

Per `rules.md` §7, dead code is **inventory, not findings** - it fails Gate 2 by construction. It becomes a finding only as evidence of a structural problem (an abandoned abstraction is `overengineering`; a module orphaned by a moved boundary is `module-organization`). Do not file one entry per unused symbol.

---

## Tool availability table - mandatory

Before you finish this phase, write `evidence/tool-availability.md`:

| Measurement | Tool | Ran? | Fallback used | Ledger tag findings get |
|---|---|---|---|---|
| Dependency graph | `madge` | yes | - | `[tool]` |
| Duplication | `jscpd` | no - not installed, no network | grep-based repeated-block scan | `[proxy]` → ceiling C2 |
| Complexity | - | no | none | findings capped by C1 |

This table is copied into the Phase 7 coverage statement verbatim. It is what makes the review's limits legible instead of hidden.

**Never leave a row blank because a tool failed.** "Did not run" is a result. Silently substituting reasoning for measurement is the violation named in `rules.md` §8.9.

---

## Write the baseline

`metrics-baseline.json` - the input to `diff` mode on the next run. Only include numbers you actually measured; omit keys you could not fill rather than writing nulls or guesses.

```json
{
  "generated": "<ISO date>",
  "window_days": 180,
  "source_files": 412,
  "source_loc": 38400,
  "modules": 14,
  "cycles": 3,
  "max_fan_in": 61,
  "duplication_pct": 4.2,
  "hotspots": ["src/services/order.ts", "src/api/routes.ts"],
  "tools": { "dependency_graph": "madge@6.1.0", "duplication": "not_run" }
}
```

---

## Gate

Do not proceed until: `evidence/` holds the raw output files, `tool-availability.md` is written with a row per measurement, `metrics-baseline.json` exists, **the writer/reader ledger (`evidence/data-flow.md`) and integration inventory (`evidence/integrations.md`) are written**, and **the co-change survivor sample has been run and recorded**. Zero findings have been created.

**The writer/reader ledger and integration inventory are gate items, not optional colour.** They are the primary evidence for this skill's target codebases (see the hierarchy above) and the only source for `data-flow-gap` and `integration-gap` findings. A review that skips them on a service-glued, single-author repo has skipped the two checks most likely to find what actually breaks it. Build both per `tooling/data-flow.md`; where a channel cannot be enumerated (a dynamic key, a binary protocol), record the coverage gap rather than omitting it.

**The co-change matrix is not admissible evidence until its survivor sample passes** (`tooling/git-history.md` §2). Sample and classify random *surviving* commits - the fanout cap is deaf to small multi-concern bundles, so the exclusion percentage cannot stand in for this check (`rules.md` §3, C5 on corpus verdicts).

If the sample fails, record `co-change: unusable - <N of N sampled commits are bundles>` in `tool-availability.md`, and treat co-change as a measurement that did not run. Phases 2 and 4 then work from the import graph and the §6 implicit-coupling census instead. This is a normal outcome on single-author and squash-merged repositories, not a failure of the review - but proceeding to quote pair counts anyway would be.
