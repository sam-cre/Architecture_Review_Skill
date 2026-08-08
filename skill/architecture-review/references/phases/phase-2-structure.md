# Phase 2 - Structure & Dependencies

_Hold: `rules.md`, the tier, the Phase 1 summary numbers, matched domain guides. Release: the Phase 1 file and all raw tool output. Output: gated findings appended to `.architecture-review/findings.md`._

Now read code - with the graph in hand. This phase is graph-driven and produces the most mechanically verifiable findings in the review.

In `pr` mode: scope to the changed files plus their direct dependents.
For repos over ~300 source files: read `references/parallel-review.md` first.

---

## 1. Does the folder structure match the dependency structure?

The single most revealing check available, and it is nearly free once you have the graph.

Folders declare an intended grouping. The dependency graph and the co-change data reveal the actual one. Where they disagree, the folders are lying, and every new contributor pays for it.

- Cluster the graph by actual dependency density. Compare to the top-level folders.
- Cross-reference with git co-change (Phase 1 measurement 3): which files change together, regardless of where they live?
- A module whose files co-change more with *another* module's files than with each other is not a module.

**Organization by type vs. by feature** is only a finding when the graph shows it costs something - a feature whose implementation is scattered across `controllers/`, `services/`, `models/`, and `utils/` such that every change to it touches four directories. That is `change-amplification`, measurable from history. Absent that evidence, folder-layout preference is `rules.md` §7.7 noise.

---

## 2. Boundary erosion - the shared-package black hole

Nearly every codebase has one: `utils/`, `common/`, `shared/`, `helpers/`, `core/`, `lib/`. It starts as a convenience and becomes a dependency magnet that couples everything to everything.

Signals, in order of strength:
- **Highest fan-in in the repo** - measured from the graph. Everything imports it.
- **Zero internal cohesion** - its own files don't import each other; it's a bag, not a module.
- **It imports back into domain modules.** A shared module that depends on a feature module is a cycle waiting to happen and an inverted dependency already.
- **It grows monotonically.** Check its git history: additions with no removals, from many different authors, for unrelated reasons.

The finding is not "you have a utils folder." The finding is a specific, traced cost: this function in `utils/` pulls in the ORM, so every consumer of `utils/` transitively depends on the database layer. Category: `boundary-erosion`.

---

## 3. Dependency direction

Determine the intended direction from Phase 0 (asserted pattern, folder names, or the dominant convention). Then check the graph against it.

- **Upward leaks** - a lower-level module importing from a higher-level one. Infrastructure importing domain, a data layer importing a controller, a shared module importing a feature.
- **Framework leakage into the core** - the domain layer importing HTTP, ORM, or serialization types. Only a finding at T3+ or where the codebase asserted a boundary; at T1–T2 this is normal and correct.
- **Concrete-to-concrete where a seam was claimed** - an interface exists but callers construct the implementation directly. The abstraction is decorative; either it's `overengineering` (delete it) or `dependency-direction` (use it). Phase 3 decides which.

If the project has dependency rules configured in CI (`dependency-cruiser`, `import-linter`, ArchUnit, Nx tags), **check for rules that are declared but disabled, warn-level, or carry exemptions**. A boundary with a growing exemption list is a boundary that has already failed, and the exemption list is dated evidence.

---

## 4. Cycles

Phase 1 found them. Here you explain each one and cost it.

For every cycle:
1. Print the full edge list - module A imports B at `file:line`, B imports C at `file:line`, C imports A at `file:line`. Every edge needs a `[read]` line; a cycle you cannot walk edge by edge is not one you can report (`rules.md` §8.3).
2. Identify the **inverted edge** - the one that doesn't belong. There is usually exactly one, and it is usually the newest. Check its git blame.
3. **Ask what the language actually charges for it**, then cost it via Gate 2. Do not skip this step - the usual list of cycle harms is language-specific, and asserting harms the toolchain does not impose is how a review manufactures a finding out of a tool's output.

### First: does this language penalise this cycle at all?

| Where the cycle sits | Penalty | Read as |
|---|---|---|
| Python modules, JS/TS modules | Real - import-time `ImportError`/`undefined`, order-dependent | Almost always a finding |
| **Go packages** | **Hard compile error** - it cannot exist | If you found one, you mis-measured |
| **Rust modules inside one crate** | **None.** Legal, idiomatic; the crate resolves as one unit | Usually *not* a finding |
| **C# types inside one assembly · Java classes inside one package** | **None** | Usually *not* a finding |
| Rust *crates* · Go *modules* · separate assemblies/JARs | Hard error or a build-order problem | Real finding |

So on Rust, C#, and Java, an intra-unit cycle costs nothing on **load order** and nothing on **co-deployment** - those two harms simply do not apply, and Gate 2 must not claim them. What can still apply is **independent testing** and **comprehension**, and both must be *shown*: if the test suite already constructs the two types together and passes, testing is not blocked and you have no Gate 2 evidence. Check before you file.

Then run Gate 3: extracting a shared type into its own module costs a file and a handful of import edits. At T1–T2 that usually buys nothing measurable, and a cycle finding that fails Gate 3 belongs in *considered and dropped*, not the findings list.

A cycle between two files in the same module is usually noise. A cycle across module boundaries **in a language that penalises it** is almost always a real finding. A cycle across *deployable* boundaries is a Phase 4 blast-radius problem - flag it for `distributed-services.md`.

---

## 5. Cohesion

Cohesion is what the co-change data measures directly, which makes it one of the few genuinely quantifiable design properties here - **when the matrix passed its Phase 1 survivor sample.** If it did not, skip the co-change reasoning in this section entirely and say so; do not quietly downgrade it to a hedged claim.

Note the asymmetry when history is bundled: **churn degrades gracefully, co-change degrades catastrophically.** A bundled commit adds one to each touched file's churn, but adds an edge between *every pair* of them - the distortion is linear in one and quadratic in the other. So a repo whose co-change matrix is unusable may still have usable churn for the Change Frequency axis. State which you are relying on.

**Fallback when co-change is unusable:** cohesion is then judged from the import graph (do a module's files import each other?) and by reading, and the findings carry ceiling C1. That is a real loss of rigor - record it in coverage rather than papering over it.

- **Within a module:** do its files change together? High internal co-change = cohesive. Files that never change together are unrelated things sharing a folder.
- **Within a file:** does the whole file change at once, or do different regions change in different commits for different reasons? Separate co-change clusters inside one file are the *only* admissible evidence for a size finding (`rules.md` §7.1) - line count alone is never it.
- **Across modules:** two modules that always change together are one module with a folder between them, or they share a hidden concept that should be extracted. Say which.

---

## 6. Implicit coupling - mandatory census

**Do not skip this step, and do not treat it as optional colour on the graph work.**

A dependency graph measures *static import edges only*. Modern systems couple through channels it cannot see: an event bus, a shared table, a string-keyed registry, a matching constant. Two services that communicate entirely over Kafka have **zero** edges between them. A distributed monolith and a well-factored system are indistinguishable to `madge`.

Relying on the graph alone therefore produces a specific, confident, catastrophic error: **grading a distributed monolith as highly decoupled.** The graph's silence is not evidence of independence.

Run a **census** for each channel below - an exhaustive, recorded search over a stated corpus. Done properly this is `[tool]` evidence per `rules.md` §2 *Search as measurement*, and it can reach High confidence. Done as a casual grep it is a pointer and worth nothing, so do it properly: name the corpus, record the full result set to `evidence/`, and open at least one hit to confirm the pattern means what you think.

| Channel | Census for | Coupling it reveals |
|---|---|---|
| **Events / messages** | Topic and event-type names, payload keys, queue names | Publisher ↔ consumer pairs with no import edge |
| **Database** | Table and collection names, raw SQL, model class names | Modules sharing a schema with independent assumptions |
| **Routes / URLs** | Path literals, endpoint constants, deep-link patterns | The same route asserted in three places that must agree |
| **String-keyed registries** | Registration and lookup keys, feature-flag names, DI tokens, plugin ids | Wiring the compiler never checks |
| **Shared constants** | Magic numbers, status/enum string values, error codes | A domain concept duplicated instead of shared |
| **Config keys** | Env var names, settings paths | Modules coupled through the environment |
| **Filesystem / cache** | Path literals, cache-key prefixes, bucket names | Modules coordinating through storage |

```bash
# events - every publish and subscribe site, corpus stated, full result recorded
rg -n --glob '!node_modules' -e "(emit|publish|dispatch|subscribe|on)\(['\"][a-z0-9._-]+['\"]" src/ \
  > .architecture-review/evidence/event-census.txt

# shared tables - which modules name each table
rg -no --glob '!migrations' -e '\b(from|join|into|update)\s+([a-z_]+)' -r '$2' src/ \
  | sort | uniq -c | sort -rn > .architecture-review/evidence/table-census.txt

# a specific suspected literal, across the whole tree
rg -n --stats -F 'order.created' .
```

### Shared tables - census against the schema, not against a guess

Use the **table inventory from Phase 0 Step 1b** as the corpus. For each known table, find every module that reads it and every module that writes it. That is exhaustive. Grepping for strings that look like table names is not, and it misses precisely the ORM-mediated access that matters most.

| Table | Read by | Written by | Verdict |
|---|---|---|---|
| `orders` | orders, reporting | orders | fine - single writer |
| `inventory_items` | orders, inventory | **orders, inventory** | two writers, no API boundary |

**Two modules writing the same table without going through one another's interface is a High-confidence structural finding** when backed by a schema census plus a `[read]` of both write sites. Nothing in the type system, the import graph, or either module's tests will catch the day one of them changes an assumption.

Grade the two cases separately - they need different fixes:
- **Shared writes** - a boundary failure. Neither module owns the concept. Category `coupling`, or `dependency-direction` where one clearly should own it.
- **Shared reads** - a versioning problem. The schema is now an unversioned published contract.

When the modules are separately deployed, this is the defining anti-pattern of that shape - see `domains/distributed-services.md` §2.

### Coverage gaps - the writer/reader ledger, read for holes (`data-flow-gap`)

Shared writes are one failure the ledger surfaces. The other two - **partial reader** and **orphaned writer**, plus **shape drift** - are the ones that most often break an assembled-by-prompts codebase, and they come straight off the **writer/reader ledger built in Phase 1 measurement 7**. Read that matrix for holes, not just for shared cells.

**Definitions, evidence bars and confidence caps: `rules.md` §6 (`data-flow-gap`). How each looks in the matrix: `tooling/data-flow.md`.** Neither is restated here.

Two things this phase adds, because they are structural judgments rather than census mechanics:

- **A hole here is the finding that survives where co-change cannot.** It needs no history at all, which makes it the highest-value check on exactly the repos whose history fails its survivor sample. On such a repo, work this section before §5.
- **Do not fire on a bare subset read.** Intentional scoping - a "Guest Orders" tab, a `RetailDashboard` reading `retail_orders` - is working as designed, and flagging it is a confident false positive. `rules.md` §6 defines the mechanical totality signal that separates the two; without it, the honest output is a Low `scope-mismatch candidate` that names both stores and asks which was intended.

File these as `data-flow-gap`. The Gate 2 evidence is (b) blocked capability - *this consumer cannot answer its own question correctly given the current stores* - demonstrable without a single commit.

**Reading it.** A key that appears in exactly one place is fine. A key appearing in **two or more modules that have no import edge between them** is an implicit dependency, and it is worse than an explicit one: nothing type-checks it, nothing warns when one side changes, and it will not appear in any refactoring tool's rename. Cross-reference against co-change - if the two sides have been edited in the same commits, the coupling is already costing something and that is Gate 2(a).

Also check, by reading rather than census:

- **Shared mutable state** - globals, singletons, module-level caches, ambient config objects.
- **Temporal coupling** - A must run before B, enforced nowhere. Look for init ordering, `setup()`/`teardown()` pairs, comments saying "call this first."
- **Type-only coupling** - usually *not* real coupling and routinely over-reported by graph tools. Check whether the edge vanishes at compile time before costing it.

**Write the implicit-coupling map into `evidence/`, and state its coverage.** If you could not census a channel - a binary protocol, a dynamic key you cannot enumerate - say so. This is where the graph's blind spot becomes the review's blind spot, and it must be visible in Phase 7 rather than absorbed silently.

---

## 6b. Integration wiring - the contracts to the outside world (`integration-gap`)

The seams to external services are where a service-glued codebase actually fails, and they are invisible to every code-only measurement: a payment webhook handler that is perfectly correct and never fires because nothing registered the endpoint; an env var the code reads that no config source supplies; a secret set in two places that silently drift apart. Work from the **integration inventory built in Phase 1 measurement 8** (`tooling/data-flow.md`).

For each seam, the question is falsifiable: **is there evidence in the repo that it is wired?**

- **Inbound handler with no registration** - a webhook/OAuth-callback/cron/queue handler exists, but nothing in the repo (registration call, IaC, setup script, documented dashboard step) proves the provider is configured to call it. `integration-gap`.
- **Consumed config with no source** - `process.env.X` is read, but `X` is in no `.env.example`, CI secret, or deploy config. `integration-gap` (the `config-gap` shape).
- **A secret with two homes** - set in code config *and* a provider dashboard, free to drift. Flag the drift risk.

**These rest on absence of evidence and cap at Low** (`rules.md` §6 category note, and Gate 4): a provider's dashboard is not in the repository, so you can only say *"nothing here wires this - verify X in the console,"* never *"this is unwired."* Do not force them to High by over-reading the code. Collect them into the **external-assumptions-to-verify checklist** for Phase 7, not the findings list.

**Rank the checklist and drop the routine, or it is noise** (`rules.md` §6, `integration-gap`; Gate 5). Standard framework config (`PORT`, `LOG_LEVEL`) and analytics/logging seams stay in `evidence/` but never reach the checklist. Order what remains by blast radius against the writer/reader ledger - a seam on a money/auth/durable-write path first - and tie each item to the flow it threatens. An unranked forty-item dump buries the one webhook that matters. This keeps the audit subordinate to data-flow: it explains why a *traced* flow may silently not run, not whether the deployment is configured right in the abstract.

The one time an integration gap reaches a real finding: when the missing wiring is **demonstrably load-bearing for a flow the code treats as complete** - an order pipeline whose only fulfilment path is a webhook that nothing registers. Then it is a `data-flow-gap` or `integration-gap` at Medium with the broken flow traced, not a checklist item.

---

## Filing

Every candidate runs the 5-Point Cost Gate (`rules.md` §4) before it becomes a finding. Confidence derives from the ledger per §3; record the ceiling applied. Use the schema in §6. Categories available here: `module-organization`, `boundary-erosion`, `coupling`, `cohesion`, `dependency-direction`, `dependency-cycle`, `change-amplification`, `data-flow-gap`, `integration-gap`.

Gate 2 evidence for this phase is usually available and cheap - the graph gives you (b) blocked capability, and co-change gives you (a) historical cost. **A structural finding with no Gate 2 evidence in a repo where you have both tools is a finding you did not look hard enough at.**

---

## Gate

Do not proceed until every cycle from Phase 1 is either explained and filed or explicitly dismissed with a reason, and the folder-vs-graph comparison has been made.
