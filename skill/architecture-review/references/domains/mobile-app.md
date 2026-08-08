# Domain — Mobile Application

**Load `frontend-app.md` with this guide.** State topology, component boundaries, and data-fetch placement are shared and are covered there — they are not repeated here.

**Primary failure mode (the delta): platform boundary leakage and unowned offline/sync state.**

Platform APIs and lifecycle events reach into business logic, so the logic cannot be tested off-device or shared across platforms; and cached data has no single owner, so the app has two versions of the truth with no rule for reconciling them.

---

## 1. The platform boundary

- **Platform APIs called from business logic** — camera, geolocation, notifications, biometrics, keychain, filesystem — rather than behind an interface. Every one is a place the logic can only run on a device. This is `testability` with a precise import to point at.
- **Platform conditionals inside domain code.** `if (Platform.OS === 'ios')` scattered through business rules rather than isolated at the edge. Count the sites; the count is the finding.
- **Native bridge / plugin surface** (React Native native modules, Flutter platform channels, Capacitor plugins): is it one deliberate boundary, or does each feature open its own channel? Ad hoc channels mean the native contract is undocumented and untyped.
- **Duplicated logic across platform-specific files.** `.ios.tsx` / `.android.tsx` pairs that share a reason to change — check whether they've been edited in the same commits.

The test to apply: **could this business rule run in a plain unit test with no simulator?** Where the answer is no, trace the import that prevents it.

---

## 2. Lifecycle coupling

Mobile's structural hazard with no web equivalent — the OS suspends, resumes, and kills your process, and code that assumes continuity breaks in ways that only appear on real devices.

- State machines driven by lifecycle callbacks (`onResume`, `applicationDidBecomeActive`, `AppState` listeners) scattered across components rather than owned in one place. Each is an implicit global.
- Work started in a lifecycle hook with no defined cancellation. Look for the leak reports in the issue tracker; they are this problem's symptom.
- **Does the app survive process death and restore?** If restoration logic is spread across screens instead of owned by a navigation or state layer, it will be inconsistent — and the inconsistency is usually already in the bug log.
- Background-task registration scattered per feature rather than coordinated.

---

## 3. Offline and sync — who owns the truth?

The place where mobile architecture most often has no answer.

- **Is there a single source of truth**, or do a local database, an in-memory store, and the server each hold a version? Trace one entity through all three.
- **What is the conflict rule** when local and remote disagree — last-write-wins, server-wins, merge, prompt? If there is no rule, conflicts are resolved by accident. Say that plainly; it is a design defect, not a bug.
- Is the sync queue durable across restarts, or does pending work vanish when the process dies?
- Do individual screens implement their own caching? That is `missing-abstraction` — count the implementations.
- Is optimistic UI applied consistently or per-screen? Inconsistency here is user-visible and is a `cross-cutting-placement` finding.

---

## 4. Navigation

- Is navigation declarative and centralized, or do screens push each other imperatively from anywhere? The latter makes the flow graph unknowable and deep-linking retrofits expensive.
- Is deep-link handling a coherent layer or per-screen parsing? Grep for the route strings.
- Are screens reachable only through one path? That is a hidden coupling that blocks reuse and testing.
- Does navigation state live with app state or separately, and can they disagree?

---

## 5. Modularization and app size

- Are features modules with boundaries, or a flat screen list? At T3+ this matters for build time and team parallelism — and for dynamic delivery / app thinning if the platform supports it.
- Does the module structure permit feature-level builds, or does everything depend on one `app` module?
- App size is architectural when the *structure* prevents splitting — a shared module pulling every dependency into the base bundle. It is not architectural when a large asset needs compressing.

---

## Reviewing this shape well

Take one feature that **works offline** and trace its data from the UI through the cache to the network and back, reading every file. That single trace exposes the source-of-truth question, the sync policy, and the platform boundary all at once, and it yields `[read]` lines for all three.

Then check the crash and bug history for state-restoration and stale-data reports. In mobile, the bug tracker is unusually good Gate 2(a) evidence — these design gaps produce a recognizable class of recurring defect.
