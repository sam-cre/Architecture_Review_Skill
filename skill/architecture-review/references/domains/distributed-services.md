# Domain - Distributed / Microservices

**Primary failure mode: the distributed monolith.**

Services that must be deployed together, released together, and understood together - but now with network calls, partial failure, and no compiler checking the seams between them. The distributed monolith is strictly worse than the monolith it replaced, which is why detecting it matters more than any other check in this guide.

---

## 1. Distributed monolith detection - run this first

If the answer to these is yes, it is the review's headline finding and most other observations are downstream of it.

- **Must services be deployed together?** **Read the pipeline, do not infer it from the code.** `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `docker-compose.yml`, k8s manifests, Helm charts - Phase 0 Step 1b recorded the topology. A single job that builds and ships every service on any change means you have one deployable wearing N names, whatever the repository layout says. Corroborate with release history: do the service versions or image tags move in lockstep? `git log` on the deploy manifests is direct, dated evidence.
- **Does one change routinely touch multiple services?** This is `git-history.md` §2 co-change applied across service directories, and it is the strongest possible evidence here.
- **Do services share a database or schema?** See §2.
- **Is there a synchronous call chain three or more services deep** on a user-facing path? Any one of them being down takes the whole path down, so availability multiplies downward.
- **Do they share a library containing business logic** - not just utilities? Then a rule change requires a coordinated release of every consumer.

The cost is easy to demonstrate: find a recent feature and count the services it required, plus the deploy ordering it implied.

---

## 2. Shared database

The defining anti-pattern of this shape. Two services reading and writing the same tables have **no boundary at all** - they share their most important internal representation, and neither can migrate it alone.

Check for:
- Two services' migration directories touching the same tables. Grep table names across service directories.
- A shared ORM model package imported by multiple services.
- One service reading another's tables directly instead of calling it.
- A "reporting" or "analytics" service reading everyone's schema - the most common way this starts, and the hardest to unwind later.

**Grade the sharing.** Shared write access is a hard boundary failure. Shared read access is a versioning problem - the schema is now a published contract that nobody versions. Read replicas of an *owned* schema are fine. Say which one you found; they need different fixes.

---

## 3. Service boundaries

- **Do boundaries follow change, or the org chart, or technology?** A service per team is often right. A service per technical layer (an "API service", a "database service", a "logic service") is a distributed monolith by construction.
- **Chatty services.** One user action producing many cross-service calls means the boundary cuts through a cohesive operation. Count the calls on one real path.
- **Anemic services.** A service that only forwards to another is a network hop with a deployment cost. Same test as a ceremonial service layer - is most of it pass-through?
- **Entity services.** A "User service" that everything must call for every operation becomes the fan-in center of the whole system. Measure it: how many services depend on it, and what fraction of requests touch it?

---

## 4. Contracts and their ownership

- **Where does the contract live and who owns it?** Copy-pasted request/response types in every consumer means there is no contract, only convention.
- Is there schema versioning, and can producer and consumer deploy independently? If not, every change is a coordinated release. Find one in the log and count the steps.
- **Are there contract tests**, or does integration only break in staging? This is `testability` at the service level, and it is usually demonstrable - look for the incident or the revert.
- Shared client libraries: do they contain business rules, or only transport? Rules in a shared client is §1's lockstep-release problem wearing a helpful name.

---

## 5. Data consistency by design

- Which operations span services, and what happens on partial failure? Find one multi-service write and trace the failure path. If there isn't one, the design assumes success - say so plainly.
- Are compensating actions explicit, or is inconsistency handled by hope and manual repair? Look for the runbook or the cleanup script; either is evidence.
- Is the same data duplicated across services with no defined authority? Then divergence is guaranteed and there is probably already a ticket for it.
- Is eventual consistency **chosen and documented**, or accidental? A system that quietly assumes strong consistency across a network boundary has a design defect, not a bug.

---

## 6. Cross-cutting infrastructure

- Auth, logging, tracing, retries, timeouts: implemented once, or per service? Per service means N different behaviors and no way to reason about the whole.
- Is there request tracing across boundaries? Without it, nobody can answer where a request spent its time - architectural, because it constrains every future investigation.
- **Are retries layered?** Retries at three levels multiply into a load amplifier under failure. Count the layers on one path; this is a `scalability-bottleneck` with a traceable growth dimension.
- Are timeouts consistent down a call chain? An outer timeout shorter than an inner one means work continues after the caller gave up.

---

## Reviewing this shape well

Trace **one user-facing operation across every service it touches**, reading the actual call sites. Then check the deploy history for whether those services ever ship independently.

If they don't, you have found the review's answer and everything else is a detail. Say it in the first paragraph of the report.
