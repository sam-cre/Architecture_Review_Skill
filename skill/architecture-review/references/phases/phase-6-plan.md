# Phase 6 - Prioritized Plan

_Hold: `rules.md`, the surviving findings, the tier. Release: the Phase 5 file. Output: the plan section of `findings.md`._

Findings are now stable. This phase decides **what the user should actually do**, which is not the same as ranking by severity.

This skill changes nothing. The plan is advice and a hand-off artifact, not a work order you execute.

---

## 1. Assign severity and priority

Apply `rules.md` §5 to every finding. Both axes of severity need provenance tags - `(measured)` where a Phase 1 or Phase 4 number backs them, `(judged)` otherwise.

Then set priority from the Severity × Remediation Cost table. Do not shortcut this: **priority is not severity.** A Critical finding with a High remediation cost is *Plan it*, not *Fix now*, and saying so is more useful than urgency theater.

---

## 2. Sequence by leverage, not by severity

The order to fix things is rarely the order of their severity.

- **Unblocking first.** If fixing A makes B, C, and D cheap, A goes first even at lower severity. Say explicitly what it unblocks.
- **Reversibility first.** Prefer changes that are easy to undo before ones that aren't. Extract before you consolidate.
- **Safety net first.** If a fix needs test coverage that doesn't exist, "add characterization tests for X" is a real step in the sequence, not an assumption.
- **Migration ordering.** If two fixes touch the same files, sequence them and say so - otherwise the second is a rebase conflict.
- **Contract changes last**, and grouped, so consumers absorb one break instead of three.

Produce a short ordered list for the *Fix now* and *Plan it* groups only. The other groups do not need sequencing.

---

## 3. Group the output

| Group | Contents | What the user does |
|---|---|---|
| **Fix now** | High/Critical severity, Low/Medium cost | Sequenced, with the unblocking relationships stated |
| **Plan it** | High/Critical severity, High cost | Needs a decision and a staged approach; write what the decision *is* |
| **Fix when you next touch it** | Medium severity, Low/Medium cost | Opportunistic. Name the trigger - "when you next add a provider" |
| **Accept & document** | Medium/Low severity, High cost | Write the tradeoff down so the next person doesn't re-litigate it |
| **Note only** | Low / Informational | One line each, no elaboration |

**Accept & document is a real recommendation, not a way of avoiding one.** For each item in it, draft the two or three sentences the user should paste into an ADR or a comment: what the tradeoff is, why it was accepted, and what would change the answer. That text is the deliverable for that group.

---

## 4. Say what not to do

Explicitly list the things you considered recommending and decided against - the fixes that would cost more than the problem, the abstractions that would be premature, the restructurings the tier doesn't warrant.

This is not padding. It is the part of the review that protects the user from the *next* review, and it demonstrates the bar was applied. Two or three lines each:

> **Not recommended: extracting a repository layer.** The three call sites that touch the ORM directly are stable - no change in 14 months - and the layer would add a pass-through file per entity. Revisit if you add a second persistence target.

---

## 5. The do-nothing case

If the honest answer is that the design is sound for what this codebase is, **say so as the headline finding** and keep the report short. A three-paragraph review saying "this is fine, here are two things to watch" is a successful output.

Equally: if the codebase is one tier below where its growth is heading, the recommendation may be "nothing structural yet, but here is the boundary to draw first when you cross ~X" - an early-warning, not a work item.

---

## 6. Effort, honestly

For each *Fix now* and *Plan it* item, give effort as a **band with its basis**, never a number:

- **Contained** - one module, existing tests cover it
- **Moderate** - several modules or new tests required
- **Substantial** - crosses a published contract, needs a migration, or touches untested code

Say what makes it that band. Never estimate hours, days, or story points; you have no basis for it and a fabricated estimate is `rules.md` §8.6.

---

## Gate

Do not proceed until every surviving finding has a severity, a priority, and a group; the *Fix now* group is sequenced; and the "not recommended" list is written.
