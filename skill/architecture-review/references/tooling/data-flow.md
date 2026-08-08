# Tooling - Writer/Reader Ledger & Integration Inventory

**The two measurements the import graph cannot produce, and the highest-value pair on the codebases this skill actually reviews** (`phase-1-evidence.md`, the inverted hierarchy). Measurement 7 is the writer/reader ledger; measurement 8 is the integration inventory. Both are **censuses** (`rules.md` §2 *Search as measurement*) - done properly they are `[tool]` evidence and can reach High; done as a casual grep they are pointers worth nothing. So do them properly: name the corpus, record the full result set to `evidence/`, and open at least one hit per channel to confirm the pattern means what you think.

Raw output to `.architecture-review/evidence/`; read back only the matrix rows you need.

---

## 7. Writer/reader ledger - where the data actually flows

A dependency graph shows imports. It does **not** show that two modules with no edge between them read and write the same table, topic, or cache key - which is the most durable coupling in the system and the one that silently breaks when a feature is bolted on as a parallel copy. The ledger makes it visible.

### The corpus

Three channels. The corpus for each is named in Phase 0 or enumerable here:

| Channel | Corpus | From |
|---|---|---|
| **Persistence** | every table / collection name | Phase 0 Step 1b schema inventory |
| **Events / messages** | every topic / event-type / queue name | census of publish + subscribe sites |
| **Shared contract** | every route string, cache-key prefix, storage path, string registry key | census of the literals |

If Phase 0 recorded no schema, build the persistence corpus here from the migration/model files. Without a named corpus this degrades to grepping for things that *look* like table names - which fails the census criteria and caps findings at Medium.

### Enumerate every writer and every reader, per name

For **each** name in the corpus, find write sites and read sites separately. Patterns are stack-specific; state the ones you used.

```bash
# Firestore / Mongo-style: writes vs reads of a collection
rg -n --glob '!node_modules' -e "collection\(['\"]orders['\"]\)|\.collection\(['\"]orders['\"]\)" src/ api/ \
  > .architecture-review/evidence/df-orders.txt
rg -n -e "\.(set|add|update|delete|create|insert)\b" .architecture-review/evidence/df-orders.txt   # writers
rg -n -e "\.(get|where|find|doc|query|snapshot|read)\b" .architecture-review/evidence/df-orders.txt  # readers

# SQL / ORM: which modules name each table (writers vs readers by verb)
rg -no --glob '!migrations' -e '\b(insert into|update|delete from)\s+([a-z_]+)' -r '$2' src/ | sort | uniq -c   # writers
rg -no --glob '!migrations' -e '\b(from|join)\s+([a-z_]+)' -r '$2' src/ | sort | uniq -c                        # readers

# Prisma / TypeORM style: model.create/update vs model.find
rg -n -e "prisma\.[a-zA-Z]+\.(create|update|upsert|delete)" src/   # writers
rg -n -e "prisma\.[a-zA-Z]+\.(find|findMany|findUnique|count)" src/ # readers

# Events: publishers vs subscribers of each topic
rg -n -e "(emit|publish|dispatch|send)\(['\"][a-z0-9._-]+['\"]" src/  > .architecture-review/evidence/df-emit.txt
rg -n -e "(on|subscribe|addListener|handle)\(['\"][a-z0-9._-]+['\"]" src/ > .architecture-review/evidence/df-sub.txt
```

### The patterns above are JS/TS - match the census to the Phase 0 stack

**The commands above find nothing on a Rust, Python, or Go codebase, and an empty result there is not a clean data-flow - it is a census that never ran for this stack** (see the coverage verdict below). And "store" is broader than "database table": it is *any place one unit puts data and another takes it* - a table, a **cache file**, a global/`static`, a channel, a struct threaded through calls. Identify the actual exchange mechanism from Phase 0, then pick the row:

| Stack | Store writers | Store readers | Env / config read |
|---|---|---|---|
| **JS/TS - Firestore/Mongo** | `collection('x')…(set\|add\|update)` | `…(get\|where\|query\|doc)` | `process.env.X`, `import.meta.env.X` |
| **JS/TS - SQL/Prisma** | `prisma.x.(create\|update)`, `insert into x` | `prisma.x.(find\|count)`, `from x` | ″ |
| **Rust** | `fs::write`, `save_*`/`store_*`, `sqlx::query!(…INSERT…)`, `static mut`, channel `.send(` | `fs::read`, `load_*`/`get_*`, `sqlx::query_as`, `.recv(` | `std::env::var("X")`, `env::var(` |
| **Python** | `session.add`/`commit`, `cursor.execute("INSERT…")`, `open(p,'w')`, `.to_parquet/.to_csv` | `.query(`, `SELECT`, `open(p)`, `read_csv` | `os.environ[`, `os.getenv(` |
| **Go** | `db.Exec("INSERT…")`, `os.WriteFile`, `ch <- v` | `db.Query`, `os.ReadFile`, `<-ch` | `os.Getenv(`, `os.LookupEnv(` |
| **Any** | file paths written, cache-key prefixes, event topic names | same keys read elsewhere | secrets/URLs from any config source |

Other stacks' **env read** (the rest is analogous - find the language's persistence and event idioms the same way): Java `System.getenv("X")` · C# `Environment.GetEnvironmentVariable("X")` / `Configuration["X"]` · Ruby `ENV["X"]` · PHP `getenv("X")` / `$_ENV["X"]` · Swift `ProcessInfo.processInfo.environment["X"]`.

Run the row's patterns with `grep -rnE` where `rg` is absent. If the project's stack has **no row here and you cannot construct equivalent patterns**, the census is `non-enumerable` for that channel - say so; do not report a clean data-flow you never measured (`phase-1-evidence.md`, "every measurement is stack-specific").

### Coverage verdict - run this BEFORE trusting any gap, and it caps confidence

A grep census that matched `collection('orders')` has enumerated readers *that match that pattern* - not every reader. The one it missed is exactly the dynamic reader whose absence would otherwise "prove" a gap:

```ts
const table = user.isGuest ? 'guest_orders' : 'orders';   // interpolated - invisible to a literal census
db(table).where({ paid: true });
await prisma[model].findMany();                            // dynamic model - invisible
repository.forEntity(entity).find(...);                    // wrapper indirection - invisible
```

So before reading the matrix for gaps, run a **pre-flight scan for dynamic access** and assign each channel a coverage verdict:

```bash
# dynamic / interpolated access that a literal census cannot see
rg -n --glob '!node_modules' -e "collection\(\s*[a-zA-Z_]|\.collection\(\s*[a-zA-Z_]|prisma\[|\bdb\(\s*[a-zA-Z_]|forEntity\(|from\(\s*\`|table\(\s*[a-zA-Z_]" src/ api/ \
  > .architecture-review/evidence/df-dynamic.txt
# rg not on PATH? use grep so the scan actually RUNS - see the guard below:
#   grep -rnE "collection\(\s*[a-zA-Z_]|\.collection\(\s*[a-zA-Z_]|prisma\[|\bdb\(\s*[a-zA-Z_]" src api
```

**Two ways an empty result lies, and both look identical to a clean scan.**

1. **The search did not run.** A missing `rg`, a wrong path, or a silent shell error produces empty output. Guard it: run a positive control (grep a token you *know* exists), fall back to `grep -rnE` where `rg` is absent; if no search tool ran, coverage is **unknown**, never `enumerable`. *(Real case: a Firestore admin dashboard read its stores via `collection(db, coll)` - dynamic - while a silently-failed `rg` reported "no dynamic access." Trusting it would have fired a confident false-positive gap. The store was read; the search never ran.)*
2. **The pattern does not match the stack.** This is the subtler one. `process.env.X` and `collection('x')` **run fine on a Rust or Python repo and return empty** - not because there is no config or no store, but because Rust reads `std::env::var` and caches to a file. An empty result from a **wrong-stack pattern** is the census-incompleteness failure at the stack level, and it is invisible: the command succeeded, the output is empty, and it reads as clean. Guard it: the census is only `enumerable` when its patterns are the ones for the language Phase 0 profiled (the table above). *(Real case: on a Rust TUI the JS `process.env` grep returned empty; the app in fact consumed three API keys via `std::env::var` and cached to `.cache`. An empty JS grep is not evidence of a clean data-flow - it is evidence you censused the wrong stack.)*

Per channel, record the verdict in `evidence/data-flow.md`:
- **`enumerable`** - the patterns are **stack-appropriate for the language Phase 0 profiled**, every access mechanism found during stack profiling is statically matchable, the scan is **confirmed to have run**, and it is empty for this channel. Findings may reach High.
- **`partial`** - at least one dynamic/indirect access site exists. The census is an **unvalidated aggregate**; per `rules.md` §3 every finding on this channel **caps at Medium**, and the ledger line must state the coverage and tag `[proxy]`. A dynamic site is often *resolvable by reading* - open `collection(db, coll)`'s callers, find the literals passed in, record which stores it touches; that read turns a false gap into a correct "no gap."
- **`non-enumerable`** - access is predominantly dynamic and not resolvable by reading (`collection(db, req.params.type)`), **or the stack has no pattern row you can census with**. Do not emit gaps for this channel; report "coverage gap prevents census - <stack> not enumerable" and move the concern to the reasoned section.

`enumerable` is a claim you must be able to defend: *stack-appropriate patterns, exhaustive over the mechanisms this stack uses, confirmed to have run* - not *exhaustive over one regex from the wrong language*. When in doubt, it is `partial`.

### Build the matrix and read it

Write `evidence/data-flow.md` as one table per channel, **each row carrying its coverage verdict**:

| Store | Written by (`path:line`) | Read by (`path:line`) | Verdict |
|---|---|---|---|
| `orders` | api/checkout writer, webhook | admin, orders page, **api/checkout** | ok |
| `guest_orders` | api/guest-checkout, webhook | orders page (guest) | **partial reader - admin reads `orders`, not this** |
| `analytics_events` | client tracker | admin dashboard | ok |
| `audit_log` | 4 modules | - | **orphaned writer - nothing reads it** |

Three findings fall out. **Their definitions, evidence bars and confidence rules are in `rules.md` §6 (`data-flow-gap`) and are not restated here** - read them there before filing. What belongs on this page is only how each one *looks in the matrix you just built*:

| Shape | In the matrix | Before you file it |
|---|---|---|
| **partial reader** | one concept, two or more source rows; a consumer appears against some rows and not others | The subset read is not the finding by itself - `rules.md` §6 requires a mechanical **totality signal**. Find it or file at Low. |
| **orphaned writer** | a row with writers and an empty reader column | Read the writers before judging: dead path, missing consumer, or a reader outside the repo (then it is an integration seam, measurement 8 - not an orphan). |
| **shape drift** | one row, two writers, and the fields they write differ | Open both write sites *and* the reader. The divergence is the finding, not the two writers. |

A row's **coverage verdict caps every finding on it** - a `partial` or `non-enumerable` channel means the reader you did not match may be the one that closes the gap (`rules.md` §3, C5).

### Fallback & coverage

No stack-specific access pattern you can enumerate (a dynamic table name, an ORM that hides the string)? Say so - that channel is a coverage gap, not an absence of coupling. Cross-reference every pair the ledger flags against co-change **only if** history passed its survivor sample; on most target repos it will not, and the ledger stands alone. State the ledger's coverage in `evidence/data-flow.md`: which channels were enumerable, which were not.

---

## 8. Integration inventory - the contracts to the outside world

Everything the code assumes is true *outside* the repository: environment configuration, third-party SDKs, and the inbound and outbound seams to external services. The most catastrophic failures in a service-glued app live here and are invisible to every code-only measurement - a payment webhook handler that works perfectly and is never called because nothing registered the endpoint.

### Inventory four things

```bash
# (a) config the code CONSUMES - every env var / settings key read.
#     PICK THE LINE FOR THE PHASE 0 STACK - the JS pattern returns empty on Rust/Python/Go
#     and that empty is a wrong-stack census, not "no config" (see §7 coverage verdict).
rg -no --glob '!node_modules' -e "process\.env\.([A-Z0-9_]+)|import\.meta\.env\.([A-Z0-9_]+)" -r '$1$2' src/ api/ \
  | sort -u > .architecture-review/evidence/env-consumed.txt          # JS/TS
# rust:   rg -no -e "env::var\(\"([A-Z0-9_]+)\"" -r '$1' src/
# python: rg -no -e "os\.(environ\[|getenv\()['\"]([A-Z0-9_]+)" -r '$2' .
# go:     rg -no -e "os\.(Getenv|LookupEnv)\(\"([A-Z0-9_]+)\"" -r '$2' .

# (b) external SDKs INITIALISED - the services this app is glued to
rg -n -e "new (Stripe|S3|Storage)\(|initializeApp\(|createClient\(|new Resend\(|Twilio\(|OpenAI\(" src/ api/

# (c) INBOUND seams - handlers something external must call
rg -n -e "/(webhook|callback|oauth|cron|task|hook)s?\b" src/ api/           # route paths
rg -n -e "\b(webhook|onRequest|onSchedule|onMessagePublished|scheduled|consumer)\b" src/ api/

# (d) OUTBOUND calls - external hosts this app depends on at runtime
rg -no -e "https?://([a-z0-9.-]+)" src/ api/ | sort | uniq -c | sort -rn | head -30
```

### The falsifiable question, per seam: is there evidence it is wired?

For each item, check the repo for the thing that would prove it configured - and record the answer:

| Seam | Evidence it is wired | If absent |
|---|---|---|
| **Env var consumed** | appears in `.env.example`, CI secrets, deploy config, or IaC | `config-gap` - code reads it, nothing here supplies it |
| **Inbound handler** (webhook/callback/cron) | a registration call, IaC (`aws_*`, k8s CronJob), a setup script, or a documented dashboard step | `integration-gap` - handler exists, nothing here proves the provider calls it |
| **Secret with two homes** | one source of truth | drift risk - e.g. a signing secret set both in code config and a provider dashboard |
| **Outbound host** | an SDK/client with ret/timeout config, or a documented dependency | note as an undocumented runtime dependency |

```bash
# cross-check: consumed env vars that appear in NO config source
comm -23 \
  <(sort -u .architecture-review/evidence/env-consumed.txt) \
  <(cat .env.example .github/workflows/*.yml docker-compose.yml 2>/dev/null \
    | rg -no -e "([A-Z0-9_]{4,})" -r '$1' | sort -u) \
  > .architecture-review/evidence/env-unwired.txt
```

### These findings rest on absence of evidence - cap and frame them accordingly

A provider's dashboard is not in the repository, so you usually **cannot prove** an inbound seam is unwired - only that nothing here proves it *is*. Per Gate 4 (`rules.md` §4), phrase it as *"nothing in the repo wires this - verify X in the provider console"*, cap at **Low**, and collect these into the **external-assumptions-to-verify checklist** (`phase-7-report.md`), not the findings list.

**Rank the checklist, or it becomes noise you will be ignored for.** An unfiltered list of 40 env vars and SDKs buries the one webhook that blocks all payments - the report a reader skims is a report that failed (Gate 5). Two rules (`rules.md` §6, `integration-gap`):
- **Drop routine config.** Standard framework env vars (`PORT`, `NODE_ENV`, `LOG_LEVEL`, `TZ`) and analytics/logging/monitoring seams stay in `evidence/integrations.md` but do **not** reach the checklist.
- **Order what remains by blast radius, and tie each item to the flow it threatens.** Cross-reference every seam against the writer/reader ledger: a seam on a money/auth/durable-write path goes to the top - *"`STRIPE_WEBHOOK_SECRET` is the only thing that marks orders paid; nothing here wires it - if unset, no order is ever fulfilled."* An analytics key nobody's core flow depends on does not belong on the list at all. This keeps the audit subordinate to data-flow - it explains why a *traced flow* may silently not execute, not "is your deployment configured right" in the abstract.

Write `evidence/integrations.md`: the four inventories, the wired/unwired verdict per seam, the blast-radius rank, and the coverage (which seams you could and could not evaluate from the repo alone).

---

## Ledger form

```
[tool]  rg -n "collection\(['\"](orders|guest_orders)['\"]\)" src/ api/   (writer/reader census)
        → orders: written 2 sites, read 4 sites (admin, orders, checkout, webhook)
        → guest_orders: written 2 sites, read 1 site (orders page only)
[read]  src/admin.js:39 - query(collection(db,'orders'), where('paymentStatus','==','paid'))
        reads `orders` only; no query against `guest_orders`
[infer] admin's paid-orders view is a partial reader - guest orders are stored but never shown

[tool]  rg -no "process\.env\.([A-Z0-9_]+)" api/ | sort -u  vs  .env.example
        → STRIPE_WEBHOOK_SECRET consumed at api/server.js:314, absent from .env.example and CI
[read]  api/server.js:312-322 - webhook handler; verifies signature with STRIPE_WEBHOOK_SECRET
```

Always name the corpus and record the full result set. A census whose corpus you cannot state is `[proxy]` at best (`rules.md` §2).
