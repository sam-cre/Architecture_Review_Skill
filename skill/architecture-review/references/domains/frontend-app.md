# Domain — Frontend Application

**Primary failure mode: state topology.** Where state lives, who can reach it, and what has to change when it moves.

Prop drilling, global-store sprawl, and misplaced data fetching are all the same underlying problem — no one decided which layer owns which state, so it accumulated wherever it was first convenient. Component structure follows from that; it is rarely the root.

---

## 1. State topology — map it before anything else

For three or four real pieces of state (the current user, a form's draft, a fetched list, a modal's open flag), answer: **where does it live, who reads it, who writes it?**

Then look for these, in order of cost:

- **Global store holding component-local state.** A store slice with exactly one reader and one writer is a local `useState` with extra ceremony and a serialization boundary. Count them.
- **Prop drilling past three or more levels.** Every intermediate component takes a prop it does not use. The cost is measurable: check whether adding a field to that prop required editing all the intermediates — that is Gate 2(a) evidence sitting in the log.
- **The same state in two places.** Server data cached in a global store *and* in a query cache. Which is authoritative when they disagree? If nobody knows, that is the finding, and there is usually a bug report proving it.
- **Context providers as a dependency-injection container.** Nine nested providers at the app root means nine implicit global dependencies, and any component may quietly depend on all of them.
- **State that outlives its screen with no one owning cleanup.** Look for stale-data bugs in history; they are this problem's symptom.

The finding is never "you should use Zustand instead of Redux" (`rules.md` §7.3). It is "this state is owned in the wrong place and here is what that cost."

---

## 2. Data fetching placement

- **Fetching inside deep leaf components.** Makes the component untestable without a network mock, unreusable in another context, and puts request waterfalls where nobody can see them. This is `testability` with a specific import to point at.
- **Fetching in too few places.** A page-level fetch passing everything down produces the prop drilling in §1. The two failures trade off; say which side this codebase is on.
- **Duplicate fetches of the same resource** from unrelated components with no shared cache — the same endpoint called from three places with three different response shapes.
- **Server-state managed as client state.** Manual loading/error/refetch flags reimplemented per component is `missing-abstraction` — count the sites before recommending anything.

---

## 3. Component boundaries

- **Components that mix concerns**: layout, data fetching, business rules, and formatting in one file. A component that can't render in a story or a test without a store, a router, and a network is coupled to all three — quote its test setup.
- **Presentational components importing from the store or the router.** They can never be reused or previewed.
- **Prop explosion.** Fifteen props, most optional, several boolean mode switches. Boolean props that change behavior wholesale are `incorrect-abstraction` (`phase-3-abstraction.md` §2) — the component is two components wearing one name.
- **Copy-pasted component variants** — `UserCard`, `UserCardCompact`, `UserCardWithActions` — diverging over time. Check whether they still share a reason to change before calling it duplication.

---

## 4. Folder organization: type vs. feature

`components/`, `hooks/`, `utils/`, `types/` groups by what things *are*. Changes arrive by what things are *about*.

Only a finding with co-change evidence: does a typical feature change touch four directories? Measure it with `git-history.md` §3 rather than asserting it. Absent that evidence this is layout preference and belongs nowhere in the report (`rules.md` §7.7).

Watch for the `components/common/` variant of the shared-package black hole (`phase-2-structure.md` §2) — highest fan-in, zero internal cohesion, monotonic growth.

---

## 5. Routing and code splitting

- Route definitions duplicated between a router config, a nav component, and a permissions map — three lists that must agree, with nothing enforcing it. Grep a route string; count where it appears.
- Route params parsed and validated independently at each destination.
- Everything in one bundle because the boundaries don't align with the routes. Architectural when the *structure* prevents splitting; not this skill's problem when it's just a missing config flag.

---

## 6. The design-system boundary

- Does app code import from a component library *and* reimplement its primitives? Count the one-off buttons.
- Do design tokens have one home, or are colors and spacing hardcoded alongside a token system? A token system with widespread hardcoded bypasses is a boundary that has already failed — and the bypass count is the evidence.
- Does the shared component library import from feature code? That is an inverted dependency and usually a cycle.

---

## Reviewing this shape well

Pick the **most complex screen** and trace every piece of state it renders back to its owner, reading each file. Then pick a **recent feature commit** and list what it touched. The two together tell you whether the state topology matches how the app actually changes — and give you `[read]` and `[git]` lines for everything you file.

Ignore rendering performance unless the *structure* is what prevents fixing it. A missing memo is not an architecture finding; a state shape that forces a whole-tree re-render is.
