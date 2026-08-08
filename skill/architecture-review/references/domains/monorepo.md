# Domain — Monorepo / Workspaces

**Primary failure mode: workspace boundary violations and the shared-package black hole.**

A monorepo's packages *look* like boundaries — separate folders, separate manifests, separate names. But unless something enforces them, they're folders with extra ceremony, and the graph underneath is a tangle. The two questions that matter: **do the declared boundaries match the real dependency graph**, and **is there a `shared`/`common` package that everything depends on?**

---

## 1. Declared graph vs. real graph

- Build the workspace dependency graph from the manifests, then build the *actual* import graph. **Where do they disagree?**
  - Imports not declared as dependencies — the package builds only because hoisting put the module in a shared `node_modules`. It will break the moment install order changes.
  - Declared dependencies never imported — noise, and slower builds.
  - **Deep imports across packages** (`@scope/pkg/src/internal/thing`) bypass the public entry entirely, so the package has no encapsulation regardless of what its manifest says.

```bash
# TS/JS: cross-package deep imports — should return nothing
grep -rn --include='*.ts' -E "from ['\"]@scope/[a-z-]+/(src|dist|lib)/" packages/

# what each package declares
cat packages/*/package.json | grep -E '"(name|dependencies)"' 
```

- **Cycles between packages.** Worse than file cycles: they break incremental build, cache invalidation, and independent versioning. Nx, Turbo, and pnpm will usually name them directly.
- **Is anything enforcing this?** Nx tags with `@nx/enforce-module-boundaries`, `dependency-cruiser` rules, ESLint `no-restricted-imports`, `import-linter` contracts, Bazel visibility. If rules exist, **check the exemption list** — a growing list of allowed violations is a boundary that already failed, and the list is dated evidence.

---

## 2. The shared-package black hole

The monorepo-scale version of `phase-2-structure.md` §2, and usually the highest-value finding in this shape.

`@scope/common`, `@scope/shared`, `@scope/utils`, `@scope/core`. Check:

- **Fan-in** — how many packages depend on it? If it's everything, every change to it invalidates every build and risks every app.
- **Internal cohesion** — do its own modules import each other, or is it a bag of unrelated exports?
- **Does it import back into feature packages?** An inverted dependency at package scale, and usually a cycle.
- **Growth** — additions with no removals, from many authors, for unrelated reasons:

```bash
git log --since=365.days --numstat -- packages/shared \
  | awk 'NF==3 {a+=$1; d+=$2} END {print "added:", a, "deleted:", d}'
git log --since=365.days --format='%an' -- packages/shared | sort -u | wc -l
```

- **What does it drag along?** If `shared` depends on the ORM, the HTTP client, and the date library, every consumer inherits all of it. Trace one heavy transitive dependency to its source.

The fix is rarely "clean up shared." It is usually "split it by the consumers it actually serves" — and the co-change data tells you where the split lines are.

---

## 3. Are the package boundaries the right ones?

- **Packages that always change together** are one package with a manifest between them. Run co-change (`git-history.md` §2) at the package level — this is decisive and cheap.
- **A package with exactly one consumer** is a folder that costs you a build step and a version. Justified only if it's independently published or independently deployed. Check whether it is.
- **Packages split by technical layer** rather than by change — `@scope/types`, `@scope/interfaces`, `@scope/constants` — mean every feature change touches several packages by construction. That is `change-amplification` and it is measurable in the log.
- Does the split match the tier from Phase 0? Twelve packages for a T2 codebase with two contributors is `overengineering`; say so.

---

## 4. Deployment boundaries — the pipeline overrides the code

**Read the pipeline files, not just the manifests.** Package boundaries in source mean nothing if the pipeline ships everything together: `.github/workflows/`, `.gitlab-ci.yml`, `turbo.json`, `nx.json`, `docker-compose.yml`, Dockerfiles, k8s manifests. Phase 0 Step 1b recorded the topology; check it against the package graph here.

The finding is not slow CI. **The finding is that the runtime boundary contradicts the source boundary** — and no dependency graph will ever show it:

- **Does any change trigger every build and deploy?** Then the ten packages are one deployable with extra ceremony, and every claim about their independence is false. Check the workflow's path filters — or their absence.
- **Are path filters consistent with the dependency graph?** A filter that rebuilds `web` when `api` changes, where no dependency exists, is a stale boundary nobody pruned. The reverse — a missing filter where a dependency *does* exist — is a correctness bug and a broken cache.
- **Do packages version and release independently in practice?** Check the tags and the release history, not the config's intent.
- **Are Docker build contexts scoped per package**, or does every image copy the whole repo? Whole-repo contexts mean every image invalidates on every change.

A monorepo whose packages cannot deploy independently is a modular monolith. That is a legitimate architecture — but say it plainly, and drop any finding that assumed independent deployability.

### Build graph

- Does changing one leaf package rebuild everything? Usually §2 — everything depends on `shared`, so nothing is ever cached.
- Is the task graph consistent with the dependency graph, or are there manual orderings and `dependsOn` hacks papering over a cycle?
- **Are TypeScript project references / path aliases consistent with the package graph?** Aliases that resolve across boundaries the manifests don't declare create a graph the build tool can't see.
- Long CI times are a symptom, not a finding. The finding is the coupling that causes them — CI duration over time is good corroborating evidence.

---

## 5. Versioning and release

- Fixed versioning (everything moves together) or independent? Fixed is fine and often right — but it means the packages are not independently consumable, so *do not* file findings premised on independent versioning.
- If packages are published, the surface rules in `library-sdk.md` apply to each published one.
- Internal-only packages marked `private: true`? If not, they can leak to a registry.

---

## Reviewing this shape well

Draw the package graph, then draw the co-change graph, and **overlay them**. Packages that co-change but don't depend on each other share a hidden concept. Packages that depend on each other but never co-change may be a boundary that is working correctly — note the good ones too; they tell you the team can draw boundaries when it tries.

Then take one recent feature commit and count the packages it touched. That number, against the total, is this shape's amplification metric and it belongs in the report.
