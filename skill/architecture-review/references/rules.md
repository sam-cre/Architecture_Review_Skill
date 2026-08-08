# Core Rules — Loaded Once, Applies to Every Phase

_This is the single source of truth for evidence, confidence, the triage gate, severity, the finding schema, noise control, and anti-fabrication. Phase files, domain guides, and agent mirrors **cite these sections by number and never restate them**. If a phase file seems to contradict this file, this file wins._

_Section numbers are stable citation anchors. Add sections; do not renumber them._

---

## 1. Scope & Operating Constraints

**What this skill assesses:** design quality — how the code is organized, how its parts depend on each other, which abstractions exist and whether they model the right thing, and what all of that costs to change.

**What it does not do.** Not bug hunting. Not security review (that is `security-audit`). Not performance profiling. Not linting, formatting, naming, or style. If you notice a bug or a vulnerability, note it in one line at the end of the report and move on — do not investigate it here.

**Read-only, absolutely.** This skill never modifies a file in the reviewed project. There is no fix phase and no refactor phase in v1. The only writes are to `.architecture-review/` in the reviewed project root.

**`.gitignore` is the one exception, and only on explicit request.** Telling the user they may want to ignore `.architecture-review/` is fine; editing `.gitignore` yourself because it seemed helpful is not — it is a project file, and a review that silently modifies the repository it reviewed has broken its own guarantee. If they say yes, add that one line and nothing else. If the file already has uncommitted changes, say so and let them decide rather than mixing your edit into their work.

If the user asks you to apply a refactor mid-review, finish the review first and hand off the Phase 7 JSON as the input to a separate, scoped session — a broken build costs more trust than the findings earn.

**Never install into the reviewed project.** Do not add to its manifest, lockfile, or `node_modules`. Analysis tools run ephemerally (`npx -y`, `uvx`, `go run`, a global install, a temp dir) or they don't run at all. If a tool can only be obtained by modifying the project, ask the user; until they say yes, take the degraded path in §2 and accept the confidence ceiling.

**Bound expensive commands.** On large repos, cap history scans with `--since` or `-n` and **state the window you used** in the report. An unstated window makes every frequency number unreadable.

---

## 2. The Evidence Ledger

Every finding carries an `Evidence:` block. Every line in it is tagged. Untagged claims are not evidence and do not count toward anything.

| Tag | Means | Must contain |
|---|---|---|
| `[tool]` | Output from an analysis program you executed **this session** | The literal command, and a **verbatim excerpt** of its real output |
| `[proxy]` | A substitute measurement, used because the real tool was unavailable | The command/method used, **and** the tool it replaces, **and** its limitation |
| `[git]` | Output from a version-control command you executed this session | The literal command and its actual numbers |
| `[read]` | A file and line range you opened with Read and can quote | `path:start-end` and what is actually there |
| `[infer]` | Your reasoning connecting the lines above | Nothing external — this is the unbacked tag |

### Ledger rules

1. **Verbatim or it isn't `[tool]`.** If you cannot quote the output, you do not have it. Paraphrased or remembered tool output is `[infer]`, retag it.
2. **Every finding needs at least one `[read]` line.** You may not report on code you did not open. A grep hit is a pointer, not a read — open the surrounding unit first.
3. **The `[infer]` auto-fail.** A finding whose ledger contains **only** `[infer]` lines is **discarded, not downgraded**. Reasoning about code you did not open is not a low-confidence finding; it is not a finding.
4. **Load-bearing means load-bearing.** If removing a line would collapse the claim, that line is load-bearing and its tag sets the ceiling in §3.
5. **Retag on doubt.** If you cannot reproduce the command behind a `[tool]` or `[git]` line, retag it `[infer]` and re-run §4.

### Search as measurement — when grep counts as `[tool]`

A `grep`/`rg` search is normally a **pointer**: it locates code and contributes nothing to the ledger (rule 2 above). It becomes `[tool]` evidence only when it is a **census** — an exhaustive count over a stated corpus. All four must hold:

1. **The corpus is named** — which paths, which extensions, what was excluded.
2. **The pattern is exhaustive for the thing being counted**, not a sample. State the pattern.
3. **The complete result set is recorded** — every distinct location, or the full count plus the file list, written to `evidence/`.
4. **You opened at least one hit** and confirmed the pattern means what you think it means.

This rule exists because the most important coupling in a modern system is invisible to import graphs — shared event names, shared table names, duplicated route strings, matching magic constants, string-keyed registries. Those are only measurable by census. Without this rule they would be capped at Medium by ceiling C2 while the weakest import-graph finding reached High, **inverting their real reliability**.

A census failing any of the four is `[proxy]` at best.

### Example

```
Evidence:
  [tool]  npx -y madge --circular --extensions ts src/
          ✖ Found 1 circular dependency:
          1) auth/session.ts > user/profile.ts > auth/session.ts
  [git]   git log --since=180.days --format=%H --name-only -- src/billing src/users
          → 41 commits touch src/billing; 27 of those also touch src/users
  [read]  src/billing/invoice.ts:88-142 — constructs UserProfile directly and
          reads profile.taxRegion to branch invoice logic
  [infer] the tax-region branch is why the two modules co-change; the rule lives
          in billing but the data it keys on lives in users
```

---

## 3. Confidence Tiers

Every finding carries a confidence. It is **derived from the ledger**, not judged.

| Tier | Requires |
|---|---|
| **High** | At least one `[tool]` **or** `[git]` line, **and** at least one `[read]` line, **and** a consequence traced to named files |
| **Medium** | `[read]` plus `[proxy]`, or `[read]` alone where the structure was hand-traced and the consequence is concrete and specific |
| **Low** | Consequence is projected rather than traced; or the claim depends on runtime behavior, roadmap, or team facts not visible in the repository |

### Hard ceilings

Mechanical. Apply every ceiling that matches; **the lowest wins**. Record which you applied.

- **C1** — No `[tool]` and no `[git]` line anywhere in the ledger → **cannot exceed Medium.** Reasoning alone never reaches High.
- **C2** — Any load-bearing `[proxy]` line → **cannot exceed Medium.** This is the tooling-fallback cap; a grep-based import count is not madge.
- **C3** — The consequence is projected rather than traced to specific files → **cannot exceed Low.**
- **C4** — Any load-bearing fact is `[infer]` → **cannot exceed Low.**
- **C5** — A load-bearing `[tool]` or `[git]` line is an **unvalidated aggregate** → **cannot exceed Medium.**

### C5 — measured is not the same as measured the right thing

C1–C4 check what *kind* of evidence you have. C5 checks whether it supports the claim, and it exists because the rest of this section cannot tell the difference.

An **aggregate** is a statistic computed over a corpus you did not filter: a co-change pair count, a churn rank, a duplication percentage, a fan-in number. A tag proves the command ran. It does not prove the corpus was clean.

Co-change is the worst offender and the most heavily used signal in this skill. In a repository of bundled commits — *"add 404 page; rename hero CTA; drop stray dead CSS"* — every file in that commit now co-changes with every other, for no design reason. The matrix measures **what got bundled into a pull request**, not what is coupled. Without C5 that lands at High: it has a `[git]` line, a `[read]` line, and a traced consequence, and no other ceiling fires.

**Lifting C5** requires validating the specific claim, not the whole corpus. Do one:

- **Re-derive it against filtered history** — re-run the query excluding inadmissible commits (§4) and high-fanout ones, and quote the filtered number alongside the raw one.
- **Spot-check the contributors** — open some of the commits behind the number and confirm they are admissible changes rather than bundles. State how many you checked and what you found.

An aggregate you validated is `[tool]`/`[git]` at full strength. An aggregate you merely ran is capped.

**C5 governs corpus verdicts, not just findings.** A statistic that decides whether a body of evidence is usable — *"the fanout cap excluded 32% of commits, so the history is fine"* — is itself an unvalidated aggregate. Trusting it is the same error C5 exists to prevent, committed one level up: a derived percentage standing in for an inspection nobody performed. The exclusion rate is a *proxy for a proxy*, and it is systematically blind to small multi-concern commits that pass the cap untouched.

Validate the specific question — *is this history too coarse?* — by **sampling the surviving commits and classifying them**, never by trusting a derived fraction. The protocol is in `tooling/git-history.md` §2 and it is a Phase 1 gate item: the co-change matrix is not admissible evidence until its survivor sample passes. Where a corpus fails that check, the correct output is not a lower confidence tier but **silence on that evidence type**, with the reason stated in coverage.

**A grep census is an unvalidated aggregate whenever its corpus cannot be proven complete.** A writer/reader census (`tooling/data-flow.md`) that matched literal `collection('orders')` calls has *not* enumerated readers — it has enumerated readers *that match its patterns*. Dynamic access (`db.collection(name)`, `prisma[model]`, a repository wrapper, an interpolated table name) is invisible to it, and it is exactly the reader whose absence would otherwise "prove" a `partial-reader` or `orphaned-writer` gap. So: every census carries a **per-channel coverage verdict** — `enumerable` (every access mechanism found during stack profiling is itself statically enumerable), `partial` (at least one dynamic/indirect mechanism exists), or `non-enumerable`. **A finding resting on a census whose channel is `partial` or `non-enumerable` is capped at Medium** — the census is an unvalidated aggregate, C5 applies. High requires `enumerable` coverage stated in the ledger. This is what stops a leaky regex from wearing a `[tool]` High.

Escalate only when you add a new evidence line. Downgrade freely and without justification.

**"I can't determine this" is a complete finding.** File it at Low with the specific unknown named and what would resolve it. That is always better than a confident guess, and it is not a failure of the review.

---

## 4. The 5-Point Cost Gate

Run every candidate finding through all five, in order. **Gates 1 and 2 are hard-fail — discard.** Gates 3–5 downgrade to Informational or discard.

### Gate 1 — Coordinates

Name the files and line ranges you opened. "The service layer is over-coupled" is not a finding; `src/services/order.ts:1-340` and `src/services/billing.ts:12-96` is. A finding without coordinates is discarded. No exceptions, no "throughout the codebase."

### Gate 2 — Demonstrated Cost

**The falsifiability gate.** You must produce one of the following. **Search them in this order** — history first, hypotheticals last.

**(a) Historical cost.** Version-control evidence that this already hurt. Files that co-change but have no declared relationship; one file repeatedly churned for unrelated reasons; a past feature addition or bug fix whose commit touched modules that should not have been involved. Look at what adding the *last* comparable feature actually cost.

**(b) Blocked capability.** Something currently impossible or disproportionately expensive, **shown rather than asserted**. This module cannot be unit-tested without a live database because of the import at line 4. This component cannot be reused because it reads global state directly. This service cannot deploy without that one.

**(c) Forced cost (hypothetical).** A named future change, traced to the exact file list it would require.

> **(c) is only admissible after (a) has been attempted and failed.** You must record the history command you ran and state that no comparable change was found. The hypothetical must also be **anchored** — to a TODO in the code, a roadmap or issue the user pointed at, an existing near-duplicate that proves the shape recurs, or something the user stated in Phase 0. An unanchored hypothetical ("what if you need to support ten times the traffic") is not evidence and fails this gate.

**(d) Prospective cost — young code only.** (a), (b), and (c) are all retrospective or require an in-repo anchor, which makes them structurally blind to code too new to have a history. That is precisely where a design fix is cheapest — the cost has not been paid yet — so a narrow lane exists. It is fenced deliberately; do not widen it.

Admissible only when **every** condition holds:
- **The code did not exist for most of the history window.** Verify with `git log --diff-filter=A -- <path>`. This lane exists because history is *unavailable*, not because it is inconvenient — old code with no demonstrated cost does not qualify and never will.
- **You name the specific future change and why this shape resists it**, at the concreteness Phase 4 demands of a traced scenario. "This will be hard to extend" is not that.
- **The finding is capped at Low**, marked `prospective`, and never rises above *Fix when you next touch it*.
- **Gate 3 applies hard.** On new code the cheap fix is usually to change it now, before anything depends on it. If your recommendation is expensive, you have the wrong recommendation — drop it.

Falsifiable history beats speculation about the future. If you produce none of (a), (b), (c), or (d), **it is not a finding** — this is what turns "this violates SRP" into either a real finding or silence.

#### Which history counts

Gate 2(a) and all of Phase 4 depend on *which commits you examine*, and that choice is manipulable in both directions: a formatting commit "proves" perfect isolation, a framework upgrade "proves" total coupling. Neither tells you anything about the design. Constrain the selection.

**Admissible** — the change adds or alters behaviour the business cares about:
- A new feature, or a new variant of an existing concept (a second provider, a third report type)
- A domain rule change — pricing, permissions, validation, state transitions, workflow
- A new entity, field, or relationship that flows through the system
- A bug fix whose root cause was a domain rule rather than a typo

**Inadmissible** — never usable as change-cost evidence:
- Formatting, linting, renames, import reordering
- Dependency bumps, framework or language version upgrades
- Test-only, docs-only, config-only, or CI-only commits
- Generated-file regeneration, lockfile churn, vendored updates
- Initial scaffolding and bulk file moves
- Merge commits and reverts
- **Bundled / kitchen-sink commits** — several unrelated changes in one commit. These are the most damaging of all, because they do not merely fail to inform: they actively inflate every pairwise co-change count in the repository. See ceiling C5 in §3.

**Record the selection, including rejections.** List the commits you examined *and the ones you rejected, with the reason*. A trace built from an unstated selection is not falsifiable — a reader cannot tell whether the sample was chosen or found. Selection transparency is what makes this gate resistant to being gamed, including by yourself.

**If you cannot find three admissible changes, say so.** Do not substitute chores to reach a count. A repository with no substantive feature history is a real limit on what this review can determine, and it belongs in the coverage statement, not papered over.

### Gate 3 — The fix must cost less than the problem

Estimate remediation concretely: files touched, tests required, whether a data migration or a published-contract break is involved. Compare it against the Gate 2 cost. **If the fix is larger than the pain, the finding caps at Informational.** A design review that recommends overengineered fixes is failing at its own subject matter — this gate is mandatory, not advisory.

### Gate 4 — Chesterton's fence

Look for why it is this way: commit messages, comments, ADRs, a framework constraint, a visible deadline artifact, a platform limitation. If a plausible rationale exists and you cannot rebut it, downgrade.

Report the two outcomes differently — they are not the same claim:
- *"The rationale existed and no longer applies"* — cite it and say what changed. Strong.
- *"I found no evident rationale"* — say exactly that. Weaker, and must be phrased as absence of evidence, not evidence of absence.

### Gate 5 — Ceremony budget

Is the criticism proportionate to what this codebase actually is, per the ceremony budget set in Phase 0 (size, team, expected lifespan, change rate)? A 400-line CLI does not need ports and adapters. **If the finding only makes sense for a codebase an order of magnitude larger or a team several times bigger, discard it.**

### Discarded findings

Discarded means discarded. The one exception: if a reader would reasonably expect a given issue to be flagged and it was not, add one line to the report's **Considered and dropped** appendix saying what you looked at and which gate it failed. That is a short list, not a second findings section.

---

## 5. Severity and Priority

**No numeric scores.** Never emit a decimal, a score out of ten, a "debt index", a "coupling coefficient", or an overall architecture grade. If a tool computed a number, cite the tool and the number is the tool's. Otherwise there is no number. A count of findings is not a quality measure and must not be presented as one.

Three ordinal axes. Each carries a provenance tag: **`(measured)`** — from a `[tool]` or `[git]` line — or **`(judged)`**.

### Blast Radius

| Value | Criteria |
|---|---|
| **Wide** | A foundational or cross-cutting module; or roughly a fifth or more of modules have a transitive dependency on it; or the Gate 2 trace crossed three or more modules |
| **Moderate** | Several modules, bounded; the trace stayed inside two or three modules |
| **Contained** | One module; the trace stayed inside it |

State the basis you used (proportion of modules, transitive-dependent count, or trace width). Proportion beats raw file counts — eight files is wide in a 40-file repo and contained in a 4,000-file one.

### Change Frequency

Over a stated window (default 180 days, or full history if the repo is younger).

| Value | Criteria |
|---|---|
| **Hot** | Top decile of commit counts in the repo, or changed roughly weekly or more |
| **Warm** | Changed within the window, below the top decile |
| **New** | The file did not exist for most of the window — confirm with `git log --diff-filter=A` |
| **Cold** | Present for the whole window, no commits in it |

This axis requires a `[git]` line. Without one it is `(judged)` and caps at Warm — you may not call code Hot on intuition. A bad design in code nobody touches is not urgent, and this is the axis that encodes that.

**New is not Cold.** Cold means nobody touches it; New means you cannot tell yet. Collapsing the two would file every young-code finding as Informational and re-create the retrospective blindness Gate 2(d) exists to fix. Check file age before assigning Cold.

### Remediation Cost

| Value | Criteria |
|---|---|
| **Low** | Mechanical and contained; existing tests cover the affected behavior |
| **Medium** | Semantic change within one boundary; needs new tests; no external contract changes |
| **High** | Crosses a published contract or API; requires a data migration; or touches code with no test coverage to make the change safe |

### Severity = Blast Radius × Change Frequency

| | Hot | Warm | New | Cold |
|---|---|---|---|---|
| **Wide** | Critical | High | High | Medium |
| **Moderate** | High | Medium | Medium | Low |
| **Contained** | Medium | Low | Low | Informational |

### Priority = Severity × Remediation Cost

Priority is a separate output on purpose. It is what makes *"real, but not worth fixing"* an honest, first-class answer instead of something the model has to smuggle past a fix queue.

| | Low / Medium cost | High cost |
|---|---|---|
| **Critical / High** | **Fix now** | **Plan it** — staged, needs a written decision |
| **Medium** | **Fix when you next touch it** | **Accept & document** — record as a known tradeoff |
| **Low / Informational** | Note only | Note only |

**Accept & document** is a success condition, not a cop-out. So is a review whose top recommendation is to change nothing.

### Priority override — externally-visible failure modes

The severity axes measure **structural** impact: how much of the codebase, how often it changes. They deliberately say nothing about what happens *outside* the codebase when the design fails. Two findings with identical blast radius and churn can differ enormously in consequence — one wastes a developer's afternoon, the other advertises one price and charges another.

You may raise priority **one step** above the matrix when **both** hold:

- **The failure mode is externally visible** — money, data loss or corruption, security, legal or compliance exposure, or a customer-facing correctness claim. Developer friction, build times, and code aesthetics never qualify.
- **Remediation Cost is Low.** If the fix is expensive the matrix answer stands: use *Plan it* and say why it matters.

Record it as `priority_override` with the failure mode named. The override never lowers priority, never moves more than one step, and never substitutes for Gate 2 — the finding must already have passed on its own evidence.

**Do not inflate severity to reach the priority you want.** Severity stays what the axes produced. The override is a separate, visible, bounded adjustment, and keeping it separate is what stops it becoming a general-purpose escape hatch.

---

## 6. Finding Schema

Every finding goes in both `.architecture-review/findings.md` (human) and `.architecture-review/findings.json` (machine — schema at `references/templates/findings-schema.json`). The JSON is the hand-off artifact for a separate refactoring session and for CI trending across runs.

```markdown
### [ARCH-XXX] Short imperative title

- **Location:** path/to/file.ext:88-142 (+ any other coordinates)
- **Category:** <one value from the enum below>
- **Blast Radius:** Wide | Moderate | Contained — (measured: <basis>) | (judged: <why>)
- **Change Frequency:** Hot | Warm | Cold — (measured: <command + number>) | (judged: <why>)
- **Remediation Cost:** Low | Medium | High — (judged: <files, tests, migration, contract>)
- **Severity:** Critical | High | Medium | Low | Informational
- **Priority:** Fix now | Plan it | Fix when you next touch it | Accept & document | Note only
- **Confidence:** High | Medium | Low
- **Ceiling applied:** none | C1 | C2 | C3 | C4 | C5
- **Evidence:**
    [tool] / [proxy] / [git] / [read] / [infer] lines per §2
- **Cost demonstrated:** (a) historical | (b) blocked capability | (c) forced — history searched: <command>, none found; anchored to: <anchor>
- **Gate:**
    G1 coordinates: <pass>
    G2 cost: <which of a/b/c, one line>
    G3 fix < problem: <the comparison>
    G4 rationale: <found and rebutted | none evident>
    G5 proportionate: <against the Phase 0 ceremony budget>
- **What's wrong:** Plain language. What the code does, structurally.
- **Why it costs:** The concrete consequence, tied to the Gate 2 evidence.
- **Recommendation:** The specific change. Name files.
- **Cost of the fix:** What it takes, honestly.
- **If you do nothing:** What this looks like in six months.
- **Status:** Open | Accepted as tradeoff | Resolved (diff mode) | Requires human judgment
```

### Category enum — closed list

`module-organization` · `boundary-erosion` · `coupling` · `cohesion` · `dependency-direction` · `dependency-cycle` · `duplication` · `missing-abstraction` · `incorrect-abstraction` · `overengineering` · `testability` · `change-amplification` · `scalability-bottleneck` · `cross-cutting-placement` · `contract-stability` · `data-flow-gap` · `integration-gap`

Do not invent categories. If a finding fits none of these, it is probably not an architecture finding.

**SOLID is a lens, not a category.** Use the principles to *find* problems, then file the finding under what actually fails — a Single Responsibility problem is `cohesion`, a Dependency Inversion problem is `dependency-direction`, an Interface Segregation problem is `incorrect-abstraction`. "Violates ISP" is never a finding title; the cost it causes is.

### `data-flow-gap` and `integration-gap` — the two that catch what the graph cannot

These two exist because the import graph, cycles, and co-change — the signals the rest of this skill is built on — are all **blind to the failures that most often break an assembled-by-prompts codebase**: a second source of truth that a consumer never learned about, and an external contract the code assumes but nothing wires. They are measured by the writer/reader ledger and the integration inventory (`phase-1-evidence.md` measurements 7–8; reasoned in `phase-2-structure.md` §6 and §6b).

**`data-flow-gap`** — writers and readers of a persistence store, event channel, or shared contract do not line up. Three shapes, each a distinct finding:
- **partial reader** — a concept is written to N sources but a consumer that **claims to cover the whole concept** reads only M < N of them. The claim is what makes it a bug rather than a design choice, and it must be **mechanically evidenced**, not assumed: a name asserting totality (`getAllOrders`, `totalRevenue`, `allCustomers`), user-facing copy ("All Orders"), or — strongest — a **sibling consumer of the same concept that reads all N sources** while this one reads a subset. A bare subset read with no totality claim is **not** a partial-reader finding: `guest_orders` beside `orders` is the bug only if something purports to show *all* orders and misses one store; `retail_orders` read by a view named `RetailDashboard` is working as designed. Without a mechanical totality signal, file it at **Low** as a *scope-mismatch candidate* that names the two stores and asks which is intended — never as a High bug.
- **orphaned writer** — something is written that nothing reads. Either a dead path or a missing consumer; decide which by reading, do not assume dead (`§7` dead-code rules). A store read only by a system outside the repo is not orphaned — reclassify as an integration seam.
- **shape drift** — two writers put different shapes into the same store and a reader assumes one of them.

A `data-flow-gap` reaches **High** only when **all three** hold: the writer/reader census carries an `enumerable` coverage verdict (§3 — a `partial`/`non-enumerable` channel caps it at Medium, because the reader you didn't match may be the one that closes the gap); a `[read]` of the mismatched sites; and, for partial-reader, the mechanical totality signal above. When they hold, it is worth High precisely because nothing in the type system, the graph, or the tests catches it. When they do not, it is a real candidate at Medium or Low — still valuable, still honest.

**`integration-gap`** — the code depends on an external contract that nothing in the repo proves is wired: an inbound handler (webhook, OAuth callback, cron/queue consumer) with no registration or setup artifact; a config value or secret the code reads that no `.env.example`, CI, or deploy config supplies; or two config sources for one secret that can silently drift. These rest on **absence of evidence** — a provider's dashboard is not in the repository — so per Gate 4 they are phrased as *"nothing here proves X is wired,"* **cap at Low**, and render as the *external-assumptions-to-verify* checklist (`phase-7-report.md`), not as confident defects.

Two rules keep this from degrading into ops-linting noise (Gate 5, proportionality):
- **Subordinate to data-flow, not a standalone ops audit.** An integration-gap earns a place on the checklist only when it sits on a path the data-flow ledger shows the code treats as load-bearing — a webhook that is the *only* writer of `orders.paid`, an auth callback the signup flow depends on. Tie each surfaced item to the flow it threatens. This is not "is your deployment correct"; it is "here is the outside-world assumption that, if wrong, silently breaks *this* flow."
- **Rank by blast radius; drop routine config.** Standard framework env vars (`PORT`, `NODE_ENV`, `LOG_LEVEL`) and analytics/logging seams are inventoried in `evidence/` but do **not** go on the checklist. Order what remains by the core capability it blocks — payment/auth/durable-write seams first. An unranked 40-item dump buries the one webhook that matters, and a report the reader skims is a report that failed.

So framed, Low confidence does not mean low value: a ranked, flow-tied list of the load-bearing outside-world assumptions a codebase in disarray silently depends on is often the single most useful page in the report.

---

## 7. Noise Control — Do Not Report

These waste the reader's attention and erode trust in the findings that matter.

1. **File or function length on its own.** A 1,000-line file that is highly cohesive is fine. To report it you must **prove low cohesion** — distinct responsibilities that change for different reasons, or separate co-change clusters inside the same file. Line count is never the finding.
2. **Missing comments, docstrings, or README content.** Documentation tooling's job, not this skill's.
3. **Framework or library preference** with no cost attached to the current choice.
4. **"This isn't hexagonal / clean / onion / DDD"** when nothing in the codebase demands that ceremony. Fails Gate 5 by construction.
5. **Premature-abstraction suggestions** whose fix would itself be an overengineering finding. Fails Gate 3.
6. **Coincidental similarity reported as duplication.** Same shape is not the same thing. Real duplication shares a *reason to change*; if the two copies would evolve differently, leave them alone.
7. **Naming, formatting, and file-placement aesthetics.** Linter territory.
8. **The deprecated side of a migration** that Phase 0 recorded as already in flight.
9. **Test-code internal structure** — unless the production coupling is precisely what makes the tests expensive, in which case the finding is about the production code.
10. **Generated code, vendored dependencies, lockfiles, build output.**
11. **Generic advice with no specific finding behind it** — "add a service layer", "consider dependency injection", "you should have more interfaces".
12. **Language or type-system arguments.** Out of scope.
13. **"This should be microservices" / "this should be a monolith"** without demonstrated cost. Architecture-style migration is the most expensive recommendation available; it requires the strongest evidence in the report or it does not appear.
14. **Anything the user explicitly scoped out** in Phase 0.
15. **Anything that fails Gate 1 or Gate 2.**

Items worth a mention that failed Gates 3–5 go in a short **Informational** appendix at the end — never in the findings list.

### Dead code — inventory, not findings

Unused exports, unreferenced files, orphan modules, and **stranded assets** (an image replaced by a WebP, a font from a deleted section) are **not** design findings on their own. They fail Gate 2 by construction: a file nothing references has never cost a change, so there is no demonstrated cost to point at. Filing forty "unused export" or "unused image" entries is exactly the linter behaviour this list exists to prevent. Asset reachability is measured the same way as code and defeated by the same dynamic reference (`tooling/code-metrics.md` §4 — globs, string-built paths); it belongs in the same bounded inventory.

Handle it in two places instead:

1. **Measurement hygiene (Phase 1).** Dead code corrupts this review's own evidence — it inflates LOC (which sets the tier), inflates duplication percentages, and adds phantom edges and fan-in to the dependency graph. Detect it, exclude it from the metrics, and state the exclusion.
2. **A bounded inventory section** in the report — a count, the largest items, and the detection method's false-positive risk. One section, not one entry per symbol.

It escalates to a real finding **only when it is evidence of a structural problem**: an abandoned abstraction whose implementations nothing calls is `overengineering`; a module left unreachable when a boundary moved is `module-organization`. There, the structure is the finding and the dead code is the evidence.

**Never claim code is dead without checking dynamic reachability.** Reflection, string-keyed registries, dependency-injection containers, framework auto-discovery (routes, migrations, event handlers, CLI commands, test collectors), build-time codegen, and conditional imports all defeat static reachability analysis. In a library, an unused export is public API, not dead code (`domains/library-sdk.md`). State the false-positive risk of whatever method you used.

---

## 8. Anti-Fabrication Rules

1. **Never state a metric you did not compute.** Coupling counts, cyclomatic complexity, duplication percentages, churn numbers, dependency depth — either cite the command that produced it or say the tool was not run.
2. **Never cite a file or line you did not open.** Grep results locate code; they do not license claims about it.
3. **Never claim a dependency cycle** without graph tool output, or a hand-trace you print in full, edge by edge.
4. **Never claim two things "change together"** without the git command and its actual numbers.
5. **Never present paraphrased tool output as verbatim.** If you cannot quote it, you do not have it — retag it `[infer]` per §2.
6. **Never invent an aggregate.** No architecture score, no grade, no health index, no maturity level.
7. **Never describe runtime behavior you did not observe.** *"I can't tell without seeing how this is used at runtime"* is a valid, complete finding — file it at Low, name the specific unknown, and say what would resolve it.
8. **Never attribute intent.** Say what the code does and what it costs. Not what its author was thinking, was trying to do, or failed to understand.
9. **Never silently substitute reasoning for measurement.** If a tool is missing or failed, say so in the coverage section, take the `[proxy]` path, and accept ceiling C2.
10. **Report coverage honestly.** Every report states what was measured, what was reasoned, and what was not reached at all. A review that overstates its coverage is worse than a short one.

---

## 9. Cross-Cutting Rules

### Evidence is transcribed at the moment of observation

**Never hold evidence in context for later transcription.** The moment you have a `[tool]`, `[git]`, or `[read]` line, write it into `findings.md` in full — the literal command, the verbatim excerpt, the exact `path:start-end`.

This is a fabrication control, not a filing convention. Over a long run the *precise* things decay from working memory first — line numbers, commit hashes, fan-in counts — while the **impression they created persists**. An agent that recalls "there was a cycle through the auth module" and reconstructs a line number for it has produced an `[infer]` line wearing a `[read]` tag.

- `findings.md` is **append-only through Phases 2–4.** A candidate goes in as it is formed, with its complete ledger, before you move to the next file. Do not accumulate several and write them together.
- A ledger line you cannot copy from disk must be **re-derived** — re-run the command, re-open the file. Reconstructing it from memory is prohibited.
- **Phases 5 and 7 work from what is written**, not from recollection. They filter, merge, rank, and format.
- If Phase 5 encounters a claim it cannot trace to a written line, that claim is **deleted, not softened**.

### What this control does and does not do

State this accurately. Overclaiming here would tell the reader the review is auditable in a way it is not — which is the same failure this skill exists to prevent, committed by the skill itself.

- **Transcription at observation works.** Writing the ledger line the instant you have it front-loads the honest record before precision decays. That is real, and it is why the rule exists.
- **Reading it back later is not independent verification.** When Phases 2–7 run in one continuous session, the file you read is already in context. An agent that reconstructed a line number in Phase 2 will "confirm" it in Phase 5 from the same faulty recollection that produced it.
- Therefore **Phase 5 Pass D is a filter, not an audit.** It catches lines you know you cannot reproduce. It does not catch lines you wrongly believe you can.

**To make verification real, run the phases cold** — as separate agent invocations, each starting without the previous phase's context and loading `findings.md` from disk. `references/parallel-review.md` already uses that shape for module workers. This is a deliberate fork: take it when the review is large enough that drift matters, and **state in the coverage section which model you ran.**

Likewise, the **Hold / Release** headers on each phase file are budget guidance, not a memory operation. Within one session, context is append-only and nothing is truly released. Read "release" as *stop consulting this, it is stale* — and, in a cold-phase run, as literal.

The corollary stands regardless: a phase that ends with important evidence only in context has failed, whatever it concluded.

- **Write `.architecture-review/` artifacts at every phase transition.** They are working state, not a final deliverable — a crashed session must be resumable.
- **Mention gitignoring `.architecture-review/`** at the start — but do not edit `.gitignore` unless asked (§1). It is a working directory, not a commitment.
- **Evidence is gathered before opinions are formed** (Phase 1 before Phases 2–3). Reading the code first and running the tools afterward produces cherry-picked measurement, which is worse than no measurement.
- **Anything that looks structurally wrong but matches no category in §6** → one line in the Informational appendix rather than a forced fit or a dropped observation.
- **If the user asks a direct question** — "is this overengineered?", "is my folder structure right?" — answer it in a sentence, with the evidence, before the findings list. Do not hedge into an enumeration.
- **A clean review is a valid outcome.** If the design is sound for what this codebase is, say so plainly. Manufacturing findings to justify the review's existence is the worst failure mode available to this skill.
