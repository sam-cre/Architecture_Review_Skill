# Domain - Library / SDK

**Primary failure mode: accidental public surface.**

Everything reachable by a consumer is API, whether you meant it or not. In a library the usual cost calculus inverts: internal messiness is cheap and fixable, while one leaked type is permanent. Weight findings accordingly - a small library can carry structural debt that would be serious in an application, and cannot carry a surface mistake that would be trivial there.

---

## 1. Map the actual public surface

Do this first; most other findings depend on it.

- What does the entry point export? Read `index.ts`, `__init__.py`, `lib.rs`, `mod.rs`, the `exports` map, `__all__`, `pub use`.
- **Wildcard re-exports** (`export * from './internal'`) publish everything downstream, including things added later by someone who didn't realize. This is the single most common cause of accidental surface.
- Does the package manifest restrict entry points (`exports`, `files`, `publishConfig`), or can consumers deep-import any internal path? Without restriction, **every file is public API** and every refactor is a breaking change.
- Are internal-only types reachable through a public signature's parameters or return values? Trace one public function's types outward - if a "private" type appears in a public signature, it is public.

Compare the intended surface against the reachable one. **The gap is the finding**, and its cost is concrete: those are the things you cannot change without a major version.

---

## 2. Change cost is versioning cost

Gate 2 evidence here has a form it doesn't have elsewhere. Check the history:

- How many **major** versions, and what forced each? A major bump caused by an internal refactor leaking through is direct evidence of surface leakage - the cost already happened.
- Have breaking changes shipped in **minor** versions? Check the tags against the diffs. If so, semver is decorative and consumers can't trust the range they pinned.
- Is there a deprecation path at all, or do things vanish? A library with no deprecation mechanism has only one migration strategy: break people.

```bash
git tag --sort=-v:refname | head -20
git diff v1.4.0..v1.5.0 -- src/index.ts     # did a minor change the surface?
```

---

## 3. The dependency footprint you impose

Every dependency is imposed on every consumer - version conflicts, bundle size, install time, transitive risk.

- **Heavy dependencies for narrow use.** A date library pulled in for one format call, an HTTP client for one request. Trace what actually uses it.
- **Dependencies that leak into the signature.** If a public function takes or returns a third-party type, consumers must depend on that library at that exact version. This is the worst dependency coupling available and it is invisible until someone hits a version conflict.
- **`dependencies` that should be `peerDependencies` or `optionalDependencies`** - frameworks, runtimes, or plugin hosts.
- **No tree-shaking path** - a single barrel entry with side effects means consumers get everything. Check for `sideEffects: false` and whether the entry actually has side effects.

---

## 4. Extension points

Libraries need seams that applications don't, because consumers cannot edit the code.

- Can consumers extend without forking? Options, hooks, middleware, injectable strategies - is there one deliberate mechanism, or several ad hoc ones?
- Conversely: an extension system with **no consumers using it** is `overengineering`. Check issues, tests, and the README for evidence anyone extends it. A plugin architecture with one built-in plugin and no external ones is speculative generality.
- Are errors part of the contract? Typed, catchable, documented error classes are API. Throwing bare strings or generic `Error` means consumers must string-match - and any message change breaks them silently.

---

## 5. Internal structure

Lower stakes than surface, but not zero. Weight against the tier from Phase 0.

- Cycles between internal modules still block partial imports and slow builds - file them, but at the severity the actual cost supports.
- A `utils/` module reachable through the public surface is `boundary-erosion` with a versioning cost attached.
- **Test-only code shipped in the package.** Check the built artifact, not the source tree.
- Deep internal hierarchies in a small library are usually `overengineering` at T1–T2.

---

## 6. Documentation as contract

Not a documentation review (`rules.md` §7.2). Only these, which are structural:

- Does the README document something the code no longer does? That is a contract mismatch with a real support cost.
- Are there **documented** internals? Documenting a thing publishes it, whatever the folder is called.
- Do examples use APIs marked internal? Then those APIs are public and consumers will depend on them.

---

## Reviewing this shape well

Read the package **as a consumer**: start from the entry point, follow only what is reachable, and stop where the surface ends. Then read the built artifact's type declarations if there are any - that file *is* the contract, and it frequently exposes more than the source suggests.

Then read the version history. In a library, the log tells you what the surface has already cost, which makes Gate 2(a) evidence unusually easy to obtain here.
