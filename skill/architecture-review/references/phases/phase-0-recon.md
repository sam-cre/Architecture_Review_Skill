# Phase 0 - Recon & Intent

_Hold: `rules.md`. Release: nothing yet. Output: `.architecture-review/project-profile.md`._

Everything downstream is graded against what you establish here. The ceremony budget in Step 3 is what makes Gate 5 (`rules.md` §4) enforceable - without it, every "this should be layered" opinion is unfalsifiable.

---

## Create the Workspace

`.architecture-review/` in the **reviewed project's** root:

```
project-profile.md        findings.md              architecture-review.md
evidence/                 findings.json            metrics-baseline.json
change-cost-traces.md
```

Create subdirectories **lazily** - `evidence/` when Phase 1 is about to write its first file, not now. Empty folders read as unfinished work.

Mention that they may want to gitignore `.architecture-review/` - it is working state, not a deliverable. **Do not edit `.gitignore` unless they explicitly ask** (`rules.md` §1); it is a project file, and this skill does not modify those.

---

## Step 1 - Profile the project

Walk the tree and read the manifests. Do not assume.

| Dimension | Determine |
|---|---|
| **Type** | Backend service, SPA, CLI, library, mobile app, monorepo, distributed system, notebook collection, or a mix. Be specific. |
| **Languages** | Every one present, with the share of source files each holds |
| **Frameworks** | From manifests, with versions |
| **Size** | Source files, source LOC (excluding generated/vendored), module or top-level-directory count |
| **Entry points** | `main`, server bootstrap, CLI commands, exported package surface, app root |
| **Deployables** | How many independently shippable units |
| **Tests** | Present or not, roughly what proportion, and whether they run. This drives Remediation Cost in `rules.md` §5. |
| **Build/CI** | Build tool, whether CI enforces anything structural (dependency rules, lint boundaries) |

Useful starting counts (adapt to the stack, exclude vendored and generated paths):

```bash
git ls-files | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
git ls-files | wc -l
git log -1 --format=%cd; git log --reverse -1 --format=%cd   # repo age
git shortlog -sn --all | wc -l                                # contributors
```

---

## Step 1b - Inventory the non-code architecture

Two artifacts outside the source tree constrain the design more than most of the code, and **neither appears in any dependency graph.** Locate both now; Phases 2–3 depend on them.

### The schema

Find the authoritative definition: `schema.prisma`, `migrations/`, `*.sql`, `models.py`, entity classes, `schema.rb`, Liquibase/Flyway changesets, a Terraform/CDK table definition. Write the **table inventory** - every table or collection name - into `project-profile.md`.

Code architecture is downstream of data architecture. Two modules with no import edge between them that write the same table are coupled through the most durable thing in the system: the schema outlives the code that reads it, neither module can refactor it alone, and neither module's tests notice when the other's assumptions change.

The table list is the **corpus** for the Phase 2 §6 database census. With it, that census is exhaustive; without it, you are grepping for things that look like table names, which fails the census criteria in `rules.md` §2 and caps the resulting findings at Medium.

If there is no schema - no persistence, or a schemaless store - say so. It removes an entire class of finding, and that is worth stating.

### The deployment topology

Read the pipeline and container definitions: `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `azure-pipelines.yml`, `docker-compose.yml`, Dockerfiles, k8s manifests, `turbo.json`, `nx.json`, `Procfile`, serverless config.

Record: **what units deploy, whether they deploy independently or together, and what triggers each.**

A codebase with clean module boundaries and a pipeline that rebuilds and ships everything on any change is **coupled at runtime regardless of the graph** - and the graph will never show it. Note this here even if it seems like a CI concern; Phases 2 and the `monorepo`/`distributed-services` guides treat it as a boundary, not as build performance.

### The external-integration surface

List the third-party services the code is glued to: payment (Stripe, Paddle), auth (Firebase Auth, Clerk, Auth0), data (Firebase, Supabase, a hosted DB), email/SMS (Resend, Twilio, SendGrid), storage, queues, LLM APIs. Read the manifest dependencies and the SDK inits. Record which providers, and for each **whether the app depends on it inbound** (a webhook/callback the provider must call) or only outbound.

This surface is the corpus for the Phase 1 integration inventory (measurement 8) and a first-class tier signal (Step 3). A 3k-line app wired to six external services has far more that can silently break than its line count suggests - and the breakages are all in the wiring, not the code.

---

## Step 2 - Establish intended architecture

You cannot judge a deviation without knowing what it deviates from.

Look for, in this order:
1. `ARCHITECTURE.md`, `docs/`, ADRs (`docs/adr/`, `decisions/`), a README section describing structure
2. Folder names that assert a pattern - `domain/`, `adapters/`, `ports/`, `usecases/`, `features/`, `layers/`
3. Config that enforces structure - `dependency-cruiser` rules, ESLint `no-restricted-imports`, `import-linter`, ArchUnit tests, Nx boundary tags
4. The dominant convention in the code itself

Record what you found and how strong the signal is. **If a project asserts a pattern (3) and violates it, that is a first-class finding - the codebase's own stated rule is the strongest possible Gate 4 rebuttal.** If nothing asserts a pattern, the codebase has no architectural contract to violate, and findings must be justified purely on cost.

If intent is genuinely unclear and it changes the review, ask the user **one** question - no more. Then proceed on the most likely reading and say which you assumed.

**On a prompt-assembled codebase, "nothing asserted" is the normal case, not a red flag** - and folder names that assert a pattern the code does not keep (an empty `domain/`, a `services/` of pass-throughs) are noise, not intent. Do not manufacture an intended architecture to measure against, and do not treat the absence of one as itself a finding. The design target is the *dominant actual convention*, inconsistent as it may be; findings rest purely on demonstrated cost. If the tells in `domains/vibecoded-app.md` §1 hold, load that guide.

---

## Step 3 - Set the ceremony budget

**The most important output of this phase.** Grade the project into a tier, and record the reasoning.

| Tier | Rough shape | Architecture that is warranted |
|---|---|---|
| **T1 - Script / tool** | ~<2k LOC · 1 module · 1–2 contributors · one entry point | Functions and files. Layers, interfaces, DI containers, and repository patterns are all pure overhead here. |
| **T2 - Small app** | ~2k–15k LOC · 2–5 modules · small team · one deployable | Clear module folders. **One** boundary that actually matters - usually domain logic vs. I/O. Nothing more. |
| **T3 - Growing product** | ~15k–100k LOC · 6–20 modules · several contributors · active feature work | Real module boundaries, an explicit dependency direction, and seams at the points that demonstrably change. |
| **T4 - Large system** | ~>100k LOC · 20+ modules · many contributors · multiple deployables | Enforced boundaries, explicit contracts between units, dependency rules checked in CI. |

### What counts as a module - mechanical definition

Do not eyeball this; the tier depends on it and "top-level directory" is not a definition. A **module** is a unit with an explicit boundary. Apply this ladder in order and use the first that matches:

1. **A separate deployment artifact** - its own container image, lambda, binary, or published package.
2. **A package manifest** - `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `*.csproj`, `build.gradle`, `pom.xml`, `composer.json`.
3. **An enforced module interface**, in either of two shapes:
   - **(a) A language-level visibility boundary** - items not marked public are *inaccessible* from outside the module, and the compiler says so. Rust `mod` + `pub`/`pub(crate)`, Java and Kotlin packages, C# `internal`, Go's lowercase identifiers, Swift `internal`/`fileprivate`, OCaml/F# signatures.
   - **(b) An explicit public entry point that other code imports *through*** - `index.ts`, `__init__.py` with `__all__`, `mod.rs` with `pub use`, a barrel file - where consumers import the entry, not the internals.
4. **A directory named by a boundary rule** - an Nx tag, a `dependency-cruiser` or `import-linter` scope, an ArchUnit package rule, a Bazel visibility group.

**Do not miss 3(a) because you were looking for a barrel file.** It is the *stronger* form - enforced by the compiler rather than by convention - but it has no index file to point at, so a JS-shaped reading of this ladder skips straight past it and lands on "one module," which under-grades the tier and then silently loosens Gate 5 for the whole review.

**3(a) is a claim you can measure, so measure it: the ratio of public to total top-level items, per module.** A module exposing 2 of 78 items has a real interface. One exposing 28 of 32 is a namespace wearing the keyword, and it does not count as a module however many `pub`s it carries. State the ratio for the modules you counted.

**A folder whose files other code imports individually is not a module - it is a namespace.** `utils/` with fifty independently-imported functions counts as **one** namespace, not fifty modules. A framework routing directory (Next.js `app/`, Rails `controllers/`) is not a set of modules; count the deployable instead.

**If nothing above matches, the codebase has exactly one module.** Record that - at T3+ it is itself a first-class finding, because a codebase that large with no enforced internal boundary has no architecture to review, only a structure to describe.

Count modules by this definition, write the count and which rung of the ladder you used into `project-profile.md`, and grade the tier on it.

### The LOC bands are loosely held defaults

They are calibrated on mainstream imperative languages and they are the **weakest** signal in the table. Do not grade on LOC alone.

**Count boundaries, not lines.** These say more about how much architecture a codebase needs, because they measure how many things must be kept coherent:

- Top-level modules or source directories that hold real code
- Independently deployable units
- Published packages or workspace members
- Size of the exported/public surface
- Direct dependency count
- **External-integration surface** - third-party providers the app is glued to, especially those with inbound seams (webhooks/callbacks). A small app wired to six services has a large surface that can break, all of it in the wiring; grade it up even when the LOC says T1–T2.

**When the structural count and the LOC band disagree, the structural count wins.** Say which you graded on. Forty thousand lines in one flat module is a T2 problem with a T3 line count; five thousand lines across nine deployables is the reverse.

**Language density shifts the bands.** The same LOC represents materially more system in a dense language than a verbose one - 10k lines of Java is a small service, 10k lines of Rust, Haskell, Scala, Clojure, or heavily-typed TypeScript is considerably more. Shift the band in that direction and state that you did.

**Trajectory shifts them too.** A T2 codebase with three commits a day and four new contributors this quarter is reviewed as an early T3.

Record the tier, the signal you graded on, and any adjustment - one line each. If two tiers are genuinely defensible, **choose the lower one**: under-prescribing architecture costs the user far less than a review that recommends ceremony the codebase never needed.

**Write the tier into `project-profile.md` and grade every later finding against it.** A recommendation that only makes sense one tier up fails Gate 5 and is discarded.

---

## Step 4 - Record exclusions

These prevent noise later (`rules.md` §7 items 8 and 14). Ask the user briefly if any are non-obvious.

- **In-flight migrations.** Two patterns coexisting on purpose - a strangler-fig rewrite, a framework upgrade, a partial extraction. Record both sides. The deprecated side is never a finding.
- **Deliberate tradeoffs.** Anything the user already knows about and has accepted.
- **Out of scope.** Directories the user does not want reviewed. Generated, vendored, and build output are excluded by default.
- **Known deadline artifacts.** Code the user identifies as knowingly rushed.

---

## Step 5 - Route domains

Match against the domain router in `SKILL.md`. Load the matching guides in Phase 2, not now - they are Phase 2–3 input and would sit in context uselessly through Phase 1.

Record which guides matched and which signals triggered them - and, where a guide matched only partly, which of its sections you intend to use and which you are disregarding.

**"None matched" is a valid outcome and must be recorded as one.** The phase files are complete without a domain guide; a guide only adds a failure-mode lens. Write `domains: none matched` rather than reaching for the nearest guide, whose checklist would pull the review toward failure modes this project cannot have.

---

## Step 6 - Confirm the mode and the question

State back in two lines: the project as you understand it, its tier, and the mode you are running.

**Capture the user's actual question if they asked one** - "is this overengineered", "why is this so hard to change", "should I split this up". Phase 7 must answer that question directly in its first paragraph, before any findings list.

---

## Gate

Do not proceed until `project-profile.md` contains: type, size numbers, **module count with the ladder rung used**, tier with reasoning and the signal it was graded on, **the table inventory (or "no schema")**, **the deployment topology**, intended architecture (or "none asserted"), exclusions, and matched domains.

The table inventory and the deployment topology are gate items because Phase 2 cannot do its job without them - the database census degrades to pattern-guessing, and a runtime boundary that contradicts the code boundary goes unseen.
