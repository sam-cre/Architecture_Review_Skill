# Domain — Backend Service / API

**Primary failure mode: domain logic bleeding into transport and persistence.**

Business rules end up in HTTP handlers, in ORM models, in SQL, and in middleware — so the rule cannot be tested without a request, cannot be reused by a job or a CLI, and gets reimplemented slightly differently in the second place it's needed.

Read this for that failure mode. It is not a checklist.

---

## 1. Where do the business rules live?

Pick two or three real rules — a pricing calculation, a permission check, a state transition, a validation with a domain reason — and find every place each is expressed.

Signals worth costing:
- **Rules inside HTTP handlers.** The controller computes discounts, checks entitlements, or decides a state transition. Test: could a scheduled job apply this same rule? If it would have to duplicate the code or fake a request, the rule is trapped in the transport layer.
- **Rules inside ORM models or DB triggers**, so half the logic is in the schema and half in the app. Ask which is authoritative when they disagree. Nobody usually knows — that answer *is* the finding.
- **Rules in middleware.** Authorization scattered across route decorators with no single place that answers "who can do what."
- **The same rule in two layers** — validation in the request schema *and* in the service, drifting apart. Check history: has one been updated without the other?

The cost is almost always demonstrable via Gate 2(a): find the commit where a rule changed and count how many layers had to be edited.

---

## 2. Transport types as domain types

The most common structural mistake in this shape, and the most expensive to reverse later.

- **ORM entities returned directly from handlers.** Every column becomes public API. Adding a field to the DB silently changes the response; renaming one breaks clients. Check whether a migration has ever forced an unrelated API change — that's the evidence.
- **Request DTOs passed deep into the domain**, so business functions take an HTTP-shaped object and cannot be called from anywhere else.
- **Serialization annotations on domain objects** — `@JsonProperty`, `response_model`, `serializer_class` on a class that is supposed to be transport-agnostic.

At **T1–T2** this is fine and often correct — say so and move on. It becomes a real finding at T3+ *or* when the API has external consumers, because then the coupling has a versioning cost you can name.

---

## 3. Service layer: real or ceremonial?

Both failures appear, and they need opposite fixes.

**Ceremonial** (`overengineering`): service methods that only forward to the repository method of the same name. Count them — if most of the layer is pass-through, it is ceremony. Recommend deleting it, not populating it.

**Overloaded** (`cohesion`): one service class handling everything for an aggregate, growing with every feature. Check for distinct co-change clusters inside it before filing — a large cohesive service is fine.

**Missing** (`missing-abstraction`): logic split between fat controllers and fat models with nothing in between. Only a finding at T3+ with demonstrated cost — usually a rule that had to be duplicated between a handler and a job.

---

## 4. Persistence coupling

- **Repository that leaks its query language.** A "repository" returning ORM query builders for callers to chain hasn't abstracted anything — swapping the store means rewriting every caller. Either it's a real seam or it isn't; decide and say which.
- **N+1 as a design problem.** One query in a loop is a bug. A *data model* where the natural access pattern is always N+1 is `scalability-bottleneck` — trace the growth dimension per `phase-4-change-cost.md` §3.
- **Transaction boundaries.** Where does one begin and end? If a business operation spans two service calls with two transactions, partial-failure states are reachable by design. Find one and describe it.
- **Migrations as coupling.** Multiple modules reading and writing the same table with independent assumptions about its shape. Grep the table name across modules.
- **Schema is a contract.** If external consumers or other services read the DB directly, the schema is a published API without a version. See `distributed-services.md`.

---

## 5. Background work and scheduling

Jobs and queues are where duplication concentrates, because they were added after the HTTP path existed.

- Does a job reimplement a rule the API already has? Grep for the rule's distinctive constant or error string.
- Can a job call the same service function as the handler, or must it duplicate the flow? If it must, the logic lives in the wrong layer — that is §1 with a concrete cost attached.
- Is the job's failure/retry behavior part of a coherent strategy, or ad hoc per job? See `cross-cutting-placement`.

---

## 6. Configuration and environment

- A config module with the highest fan-in in the repo is a `boundary-erosion` candidate (`phase-2-structure.md` §2) — check whether it pulls heavy dependencies with it.
- Environment checks (`if (env === 'production')`) inside business logic mean the code paths tested and the code paths shipped differ. Count the sites.
- Config for things that have never varied is `overengineering` — check the value's history across environments.

---

## Reviewing this shape well

Trace **one request end to end** and **one background job end to end**, reading every file the path touches. Then compare: where do the two paths converge, and where do they duplicate each other? The gap between them is where this shape's design problems live, and the trace gives you `[read]` lines for all of it.

Then check the schema against the modules that touch it. The tables with the most independent writers are the real coupling centers, and they never appear in an import graph.
