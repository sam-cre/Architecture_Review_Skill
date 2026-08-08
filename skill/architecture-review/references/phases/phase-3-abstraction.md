# Phase 3 - Abstraction & Design

_Hold: `rules.md`, the tier, matched domain guides, Phase 2 findings list (titles only). Release: the Phase 2 file, graph detail you're done with. Output: gated findings appended to `.architecture-review/findings.md`._

The judgment-heaviest phase, and therefore the one where the gate does the most work. Most opinions people call "architecture review" live here, and most of them fail Gate 2.

In `pr` mode: scope to the changed files and the abstractions the change introduces or touches.

---

## SOLID is a lens, not a category

Use the principles to *notice* things. Then file the finding under what actually fails, per `rules.md` §6:

| Principle noticed | Files as | Only if you can show |
|---|---|---|
| Single Responsibility | `cohesion` | Distinct co-change clusters, or a change that had to touch it for an unrelated reason |
| Open/Closed | `missing-abstraction` | A class that grew a branch every time a variant was added - count them in git |
| Liskov | `incorrect-abstraction` | A subtype that no-ops, throws, or narrows a precondition, and a caller that has to know |
| Interface Segregation | `incorrect-abstraction` | An implementer forced to stub methods it has no meaning for |
| Dependency Inversion | `dependency-direction` | The concrete edge in the graph, plus what it blocks (usually testing) |

**"Violates SRP" is never a finding title.** The cost it causes is.

---

## 1. Missing abstraction

The same *decision* is made in several places, and adding a new variant means finding all of them.

Signals:
- A `switch`/`if-else` chain over the same discriminator appearing in 3+ locations. Grep the discriminator; count the sites.
- A new-variant commit in history that touched N files, where N-1 of them were only touched to add one more case. **This is Gate 2(a) evidence and it is decisive** - find it in the log rather than arguing from the shape.
- Parallel type hierarchies that must be extended in lockstep.
- A constant list duplicated between code and schema and validation and UI.

The bar: **three real occurrences and a demonstrated cost of adding the fourth.** Two occurrences is not a pattern; it's two things. Recommending an abstraction at two occurrences is itself the `overengineering` finding.

### The exception: N parallel implementations of one role

The three-occurrence bar is calibrated on the *scattered-branch* shape - a `switch` over the same discriminator turning up in more decision sites over time. It is the wrong instrument for a different, common shape: **two complete implementations of the same role, expected to stay in lockstep.** Two front-ends over one engine. A web and a mobile client of one flow. Two adapters for one protocol.

There, N=2 is not "two things that happen to look alike" - it is a **parallel-maintenance contract**, and one is not a smaller version of the problem than three: every change to the shared behaviour costs 2×, forever, and the failure when someone updates one and not the other is *silent divergence* rather than a visible duplicate.

So for this shape the bar is different, and stricter in a different place. All three must hold:

1. **The implementations share a role, not just a shape** - they answer the same question for different presentations, platforms, or transports. Name the role.
2. **You can enumerate the shared *decisions***, not the shared lines. Walk both and list them in order; if they make the same decisions in the same sequence and differ only in output, that is the finding. A census of one of those decisions across both copies is `[tool]` evidence (`rules.md` §2).
3. **Gate 2 is met on the parallel maintenance itself** - a commit that had to touch both (that is (a), and it is decisive at N=2), or a demonstrated blocked capability.

**Then separate what must stay split from what must not.** The reason two implementations exist is usually real and load-bearing - different rendering, different platform APIs - and a recommendation that collapses *that* is an `overengineering` finding wearing a fix. Extract the **decision**; leave the **rendering**. If you cannot articulate which half is which, you do not yet understand the duplication well enough to file it.

---

## 2. Incorrect abstraction

An abstraction exists, but it models the wrong thing. **Worse than a missing one** - a missing abstraction costs you duplication you can see; a wrong one costs you every future change fighting a shape that doesn't fit, and it looks like good design while doing it.

Signals, strongest first:
- **Boolean/enum parameters that switch behavior wholesale.** `process(order, isRefund)` where the two branches share almost nothing. The abstraction captured a superficial similarity.
- **Subclasses that override to no-op, throw, or ignore the parent's contract.** The base class asserts something untrue about its children.
- **An options bag that keeps growing.** Every new caller adds a flag; no caller uses more than a third of them. The parameter object is standing in for several distinct operations.
- **The interface changes every time an implementation is added.** A correct abstraction is stable under new implementers. Check git: if the interface file's churn tracks the implementations' churn, it isn't abstracting anything.
- **Callers must know which implementation they hold.** Type checks, downcasts, or capability probes at call sites mean the polymorphism is fake.
- **The name is a lie.** `UserManager` that also sends email; `Repository` that contains business rules. Name-vs-behavior mismatch is weak evidence alone but corroborates the rest.

Cost this via Gate 2 like anything else. The usual evidence is (a): a feature whose commit had to modify the abstraction itself, not just implement against it.

---

## 3. Overengineering

The reverse failure, and the one this skill must be most careful about - because the recommendation for every *other* finding risks creating one.

Signals:
- **An interface or abstract base with exactly one implementation**, and no second one visible in the code, the roadmap, or the history. Check whether a second ever existed and was deleted.
- **Layers that only forward.** A service method whose entire body calls the repository method of the same name. Count how many such pass-throughs exist; if most of the layer is pass-through, the layer is ceremony.
- **Configuration for things that never vary.** A setting with one value across every environment, for its whole history.
- **A plugin/strategy/factory system with one plugin.**
- **Generic parameters instantiated at exactly one type.**
- **Indirection that adds a hop without adding a seam** - a wrapper that neither changes the interface nor isolates anything.

Grade against the tier from Phase 0. At T1–T2, most of this list is a finding. At T4, a single-implementation interface at a genuine deployment or team boundary is often correct - say why you think it isn't before filing.

**Gate 3 runs in reverse here:** the fix is deletion, which is usually cheap, so overengineering findings pass Gate 3 easily. That makes them the highest-value findings in a typical review. Look for them properly rather than treating them as an afterthought.

---

## 4. Duplication triage

Phase 1 gave you a duplication report. Most of it is not a finding.

**The test: do the copies share a reason to change?**

- Same shape, same reason → real duplication. `duplication`.
- Same shape, different reasons → coincidental. Leave it alone; merging it creates an `incorrect-abstraction`. This is `rules.md` §7.6 and it is the single most common false positive a duplication detector produces.
- Different shape, same reason → *this* is the important one, and no tool finds it. Two implementations of the same business rule that look nothing alike will silently diverge. Look for it deliberately: the same constant, the same validation, the same tax/permission/status rule expressed twice.

Check history for corroboration: if the copies have been edited in the same commit before, they share a reason to change and someone has already paid the cost - that is Gate 2(a).

Boilerplate a framework requires, generated code, and test setup are not duplication findings.

---

## 5. Cross-cutting concern placement

Logging, error handling, authorization, validation, caching, transactions, configuration, telemetry.

The question is not "is there a pattern" but **"is there exactly one pattern, and does it have one home?"** Three different error-handling strategies in one codebase is a real cost - every contributor must learn all three and guess which applies.

- Where does each concern live? Middleware, decorators, base class, scattered inline, or all of the above?
- Is it applied consistently, or does each module do it its own way?
- Can a new module opt in without copying code? If every new handler must remember to add the same four lines, the concern has no home. That is `cross-cutting-placement`, and the evidence is easy: find a commit where someone forgot.

---

## 6. Testability as a design signal

Tests are the cheapest available probe of coupling, and the evidence is unusually strong because it's Gate 2(c) - a blocked capability you can demonstrate rather than argue.

- **What requires a database, network, or filesystem to test that shouldn't?** Trace the import that forces it. That import *is* the finding.
- **What is untested because it's hard to test**, rather than because it's unimportant? Cross-reference coverage (if available) against complexity: untested + complex + hard to instantiate is a coupling finding wearing a testing costume.
- **How much setup does a typical unit test need?** A test that constructs nine collaborators to exercise one method is telling you the fan-out is too high. Quote the setup block.
- **Are there tests that assert on implementation detail** because there's no seam to assert behavior at?

File these as `testability` with the specific import or constructor that blocks the test.

---

## Filing

Every candidate runs the 5-Point Cost Gate (`rules.md` §4). This phase's findings lean on `[read]` and `[git]` evidence more than `[tool]`, so ceiling C1 will apply often - **that is correct, not a shortcoming.** A well-evidenced Medium is worth more than an inflated High.

Categories available here: `duplication`, `missing-abstraction`, `incorrect-abstraction`, `overengineering`, `testability`, `cross-cutting-placement`, `cohesion`.

---

## Gate

Do not proceed until every candidate from this phase has run the gate, and the domain guides have been released.
