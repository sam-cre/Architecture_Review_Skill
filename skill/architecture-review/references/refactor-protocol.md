# Refactor Protocol - `refactor` Mode

_Load only when the user asks to act on a finished review. Hold `rules.md` and this file. Input: `.architecture-review/findings.json` from a prior run._

The review modes never modify the project (`rules.md` §1). This mode is the separate, scoped session that §1 hands off to: it applies **one finding at a time**, behavior-preserving, behind an approval gate, and proves the result with the same measurement that produced the finding. It exists because "feed this to a refactoring session" otherwise means an unguided session that has none of the review's discipline.

The v1 reason for keeping refactoring out of the review still holds: cross-boundary edits are fragile, and a broken build costs more trust than the findings earn. So this mode is narrow on purpose. If a step below cannot be met, stop and say which one.

---

## 1. Preconditions - check all before touching anything

1. **A review exists.** `.architecture-review/findings.json` parses and validates (the Phase 7 check). No review: run `standard` first. Never refactor from a finding you did not gate.
2. **One finding is chosen.** The user names its ID, or you propose the first item of the *Fix now* sequence from the plan and they confirm. Findings with status `Accepted as tradeoff` or `Requires human judgment`, or with confidence Low, are refused here: they need a human decision, not an edit.
3. **The finding is still true.** Re-open every location in `locations` and confirm the code still matches the evidence. Lines have moved or the problem is gone: say so and stop. A stale finding is not a work order.
4. **The tree is clean.** `git status` shows no uncommitted changes, or the user agrees to proceed on top of them. Work on a new branch unless they say otherwise. Never commit or push unless they ask.
5. **The baseline is green.** Run the project's build and tests and record the result. A red baseline: stop. You cannot tell your breakage from what was already broken.

---

## 2. Safety net

Decide whether the existing tests would catch a behavior change in the code you are about to move. Name the tests that cover each location, or say none do.

If coverage is missing, the first step of the plan is **characterization tests**: tests that pin down what the code does today, right or wrong, so the refactor can be shown to preserve it. They are written and pass against the unchanged code before any refactor step runs. This is the plan's "safety net first" rule (Phase 6 §2) made concrete.

---

## 3. Plan and approval gate

Write `.architecture-review/refactor-<finding-id>.md` with:

- the finding ID, title, and the recommendation being applied
- the steps, smallest and most reversible first, each one behavior-preserving (extract, move, inline, rename, introduce a seam, then remove the old path)
- every file each step touches. Only the finding's locations and their direct dependents are in scope
- the measurement from the finding's evidence ledger that should move, and in which direction
- what is explicitly **not** being changed

Show the plan, then stop and ask:

> Apply this refactor plan for <finding-id>? Reply YES to proceed, or say what to change.

Touch no project file before YES. A change to a published contract (an exported API, a schema, a wire format) needs its own explicit YES even inside an approved plan.

---

## 4. Apply in steps

For each step: make the change, then run the build and the tests.

- **Green:** continue. Record the step in the plan file.
- **Red:** undo that step (`git restore` the touched files, or `git stash`), record what failed, and stop to report. Do not stack a fix on a failing step, and do not edit a test to make it pass unless that test is a characterization test you wrote and the user agrees the old behavior was a bug.

No new features, no bug fixes, no style edits, and no drive-by cleanups, even small ones. Note anything you see in one line for later. A refactor that also changes behavior cannot be verified as a refactor.

---

## 5. Prove it moved

Re-run the exact Phase 1 tool and command that produced the finding's `[tool]` evidence, with the same settings, and put before and after side by side. For a `[git]`-only finding no single command can show the change; say so, and give the structural fact that changed instead (for example "the three call sites now go through one function").

If the measurement did not move, say so plainly. The refactor may still be worth keeping, but it did not fix the finding as stated. Never report improvement you did not measure (`rules.md` §8).

---

## 6. Record and hand back

- Set the finding's `status` in `findings.json` to `Resolved` only when step 5 showed the measurement moved and the tests are green; otherwise leave it `Open` and add what was learned to the plan file.
- Re-validate `findings.json` against the schema.
- Tell the user: the branch, the files changed, the test result, the before and after measurement, and anything noted for later. They review and commit.

One finding per run. For the next one, start again at §1: the previous refactor may have moved lines, changed dependents, or resolved other findings, and the evidence must be re-checked rather than assumed.
