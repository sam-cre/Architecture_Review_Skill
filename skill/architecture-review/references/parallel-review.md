# Parallel Review - Large Codebases

_Load before Phase 2 when the project exceeds ~300 source files or spans 3+ languages. Hold `rules.md`._

Phases 2–3 read a lot of code. Past a few hundred files this stops fitting in one context, and quality degrades in a specific way: findings from files read early get compressed into vague summaries, so they lose the `[read]` lines the ledger requires and quietly fail the gate.

Split the reading. Keep the judgment central.

---

## What splits and what does not

| Phase | Split? | Why |
|---|---|---|
| 0 Recon | **No** | The tier and exclusions must be one decision. Splitting produces sub-reviews with different bars. |
| 1 Evidence | **No** | Tools run repo-wide once. Cheap. Splitting produces incomparable numbers. |
| 2 Structure | **Partly** | Cross-module analysis is global; within-module reading splits cleanly. |
| 3 Abstraction | **Yes** | Reading-bound and naturally per-module. |
| 4 Change-cost | **No** | Traces cross modules by definition - that is the point of the phase. |
| 5 Adversarial | **No** | Must see all findings at once to merge duplicates and catch contradictions. |
| 6–7 Plan, report | **No** | One voice, one bar. |

**Global work stays central**: the dependency graph, cycles, fan-in, folder-vs-graph reconciliation, and cross-module co-change. Those are Phase 1 outputs and Phase 2 §1–§4, and none of them can be seen from inside a single module.

---

## How to split

Split by the **module boundaries the graph shows**, not by directory listing. Phase 1's clustering already tells you where the seams are; using folders instead assumes the organization is correct, which is one of the things under review.

Aim for 5–10 files' worth of judgment per worker, roughly 30–80 source files each. Fewer, larger units beat many small ones - each worker pays a fixed cost to load `rules.md` and the tier.

**Give every worker:**
- `rules.md` - non-negotiable, and it must not be summarized
- The tier and exclusions from `project-profile.md`
- Its file list, and the relevant matched domain guide
- The **graph facts about its module**: what depends on it, what it depends on, its fan-in, its churn ranking
- The instruction to file candidates in the §6 schema with full evidence ledgers

**Do not give a worker:** other modules' findings, or authority to set final severity. Severity needs the whole-repo picture - a Wide blast radius is only visible centrally.

---

## What comes back

Workers return **candidates**, not findings. Each must carry:
- Coordinates with line ranges (Gate 1)
- A full evidence ledger with tags (§2)
- Their Gate 2 attempt - and it is fine for a worker to return "cost not demonstrated, needs cross-module context." Phase 4 often supplies it.

**Do not accept a summary.** A worker that returns "this module has high coupling" without ledger lines has produced nothing usable - the whole reason for splitting is to preserve `[read]` lines that would otherwise be compressed away. Send it back or read the module yourself.

---

## Merging

Do this centrally, before Phase 4:

1. **Deduplicate.** Two workers reporting the two ends of one cross-module dependency is one finding. Merge and keep both sets of coordinates.
2. **Find the root cause.** Five modules each reporting "imports from `shared/`" is one `boundary-erosion` finding with five consequences - and it reports far better as one.
3. **Set severity centrally.** Only you can see the true blast radius.
4. **Re-check the bar.** Independent workers calibrate differently, and the usual drift is toward more findings. Re-run Gate 5 across the merged set against the tier; if the count is disproportionate for the tier, the bar slipped.
5. **Note what nobody covered.** Files in no worker's list go in the Phase 7 "not reached" coverage section.

---

## When not to split

- **Under ~300 files** - the merge overhead and calibration drift cost more than they save.
- **When the codebase is one tangle.** If everything imports everything, there are no module boundaries to split on, and that fact *is* the review's headline finding. Report it and read centrally.
- **In `pr` mode** - the diff is already the scope.
- **When you cannot give workers the graph facts.** Without them, workers report local observations with no blast radius, and you get volume instead of judgment.

---

## Cheaper alternative

Before splitting, try scoping instead. Use Phase 1's data to rank modules by **churn × fan-in** and review the top 30–40% thoroughly rather than everything shallowly.

This is usually the better trade. Cold, contained modules produce Informational findings at best (`rules.md` §5), so reading them exhaustively buys little. Whichever you choose, **the Phase 7 coverage statement must say which** - "reviewed the 12 highest-churn modules of 31" is honest and useful; implying full coverage is not.
