# Differential Protocol - `diff` Mode

_Load when `.architecture-review/` already exists from a prior run, or when the user asks whether the architecture has improved. Hold `rules.md`._

Answers one question: **did the design get better or worse since the last review?**

Do not re-run the full review. Re-running from scratch produces a differently-worded report that nobody can compare to the last one, which is the failure this mode exists to prevent.

---

## 1. Load the prior run

Read from `.architecture-review/`:
- `metrics-baseline.json` - the numbers to compare against
- `findings.json` - what was open, and at what priority
- `project-profile.md` - the prior tier and exclusions

If `metrics-baseline.json` is missing or predates the schema, say so and run `standard` instead. **Do not compare against numbers you cannot verify were measured the same way** - different tool versions and different history windows produce incomparable results.

Establish the comparison range:

```bash
git log --oneline <prior-commit>..HEAD | wc -l
git diff --stat <prior-commit>..HEAD
```

If the baseline recorded no commit, use its `generated` date as the boundary and say the range is approximate.

---

## 2. Re-measure, identically

Re-run Phase 1 with **the same tools, the same settings, and the same history window** as the baseline. `metrics-baseline.json.tools` records what to match.

If a tool version changed or is no longer available, say so and mark the affected rows **not comparable** rather than reporting a delta. A duplication percentage from jscpd 3.x against one from 4.x is not a trend.

Produce the delta table:

| Metric | Prior | Now | Δ |
|---|---|---|---|
| Cycles | 3 | 1 | **−2** |
| Max fan-in | 61 | 68 | +7 |
| Duplication | 4.2% | 4.4% | +0.2 (within noise) |
| Source LOC | 38,400 | 44,100 | +5,700 |

**Normalize by size.** A repo that grew 15% and gained 15% more duplicated lines has not gotten worse. Report absolute *and* per-KLOC where the metric supports it, and say which you are judging on. Growth is the most common source of false regression signals here.

---

## 3. Triage the prior findings

Each one gets exactly one verdict, and **each verdict needs evidence**:

| Verdict | Requires |
|---|---|
| **Resolved** | Re-read the location. Confirm the structure changed. `[read]` line required - a metric moving is not proof a specific finding was fixed. |
| **Partially addressed** | Some call sites fixed, some not. Name both. |
| **Unchanged** | Location still reads as before. Re-check severity - Change Frequency may have moved, which moves severity without anyone touching the code. |
| **Worsened** | Same defect, larger blast radius or higher churn. Quantify it. |
| **Moot** | The code was deleted or restructured such that the finding no longer applies. |
| **Not re-checked** | Out of the diff range and not worth re-reading. Say so; don't silently carry it forward. |

**Resolved requires a read, always.** Cycles dropping from 3 to 1 does not tell you *which* cycle was fixed.

---

## 4. Look for new findings - scoped

Run Phases 2–3 **scoped to what changed**: files in the diff range, plus their direct dependents.

```bash
git diff --name-only <prior-commit>..HEAD
```

Plus two full-repo checks that are cheap and catch regressions the diff scope would miss:
- **New cycles** - the graph is global; a new edge anywhere can create a cycle between untouched files.
- **New toll booths** - re-run the Phase 4 Step 1 file-frequency query over the new range. A file that has become a bottleneck since the last review is the most valuable thing this mode finds.

Everything else stays in the diff scope. A full re-review is `standard` mode, not this.

---

## 5. Direction of travel

The headline output. One paragraph, and it must be a judgment, not a metrics dump.

Weigh:
- **Were the prior *Fix now* items addressed?** This is the strongest signal, more than any metric.
- **Did new debt land in the same places**, or in new ones? Recurrence in the same module means the earlier fix treated a symptom.
- **Is amplification rising or falling?** Re-trace one recent feature (Phase 4 Step 1) and compare its incidental-file count to the prior traces. This is the truest measure available of whether the design improved.
- **Did growth outpace structure?** A codebase 40% larger with the same module count has modules 40% larger - and the tier may have moved. Re-check it.

Say plainly which of: **improved**, **held steady**, **drifted**, or **regressed** - and name the one thing most responsible.

---

## 6. Output

Overwrite `architecture-review.md` with the diff report; keep the same section order as the full template so the two are readable side by side, with the delta table and direction-of-travel paragraph inserted after **The answer**.

Update `findings.json`:
- Carry forward unresolved findings with their **original IDs**. Never renumber - stable IDs are the whole point of the machine artifact.
- Set `status` per §3 above.
- New findings continue the ID sequence.

Update `metrics-baseline.json` to the current run. Archive the prior one as `metrics-baseline.<prior-date>.json` so more than two runs can be trended.

---

## Honesty constraints

- **Do not report a delta on a metric measured differently.** Mark it not comparable.
- **Do not claim a finding was fixed** because a number moved. Read the code.
- **Small metric movements are noise.** A duplication change of a few tenths of a percent is not a trend; say nothing rather than narrate it.
- **"No meaningful change" is a complete answer** and takes one paragraph. If the codebase has barely moved, the report should be short.
