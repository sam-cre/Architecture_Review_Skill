# Refactor Protocol - `refactor` Mode

_Load only when the user asks to act on a finished review. Hold `rules.md` §6 and this file. Input: `.architecture-review/findings.json` (schema 1.1) from a prior run. Also load `tooling/test-baseline.md` at §1 step 4._

The review modes never modify the project (`rules.md` §1). This mode is the separate, scoped session that §1 hands off to. It applies **one finding at a time**, behavior-preserving, behind an approval gate, and proves the result with the same measurement that produced the finding.

The reason for keeping it narrow still holds: cross-boundary edits are fragile, and a broken build costs more trust than the findings earn. If a step below cannot be met, stop and say which one.

Scope is finding-driven only. The user does not ask for a refactor in their own words; they pick a finding from the review. Requests like "extract the billing logic" are answered by saying which finding covers it, or that none does and a review run would have to produce one.

---

## 1. Preconditions - check all before touching anything

1. **A review exists and is valid.** `.architecture-review/findings.json` parses and validates against schema 1.1. A 1.0 file has no `search_directive`: run `standard` again first. Never refactor from a finding you did not gate.
2. **One finding is chosen.** Propose the first `Open` ID in `fix_order` whose priority is *Fix now* or *Plan it*, or the ID the user names. The user confirms. Refuse these, because they need a human decision rather than an edit: status `Accepted as tradeoff`, `Requires human judgment`, or `Resolved`; confidence `Low`.
3. **The tree is clean.** `git status` shows no uncommitted changes, or the user agrees to proceed on top of them. Work on a new branch unless they say otherwise. Never commit or push unless the user asks. (In a repo with an operator-owned git runner, commits go through the runner, not through this session.)
4. **The baseline is green.** Find the build and test commands with `tooling/test-baseline.md`, run them, and record the result. A red baseline or no baseline: stop. You cannot tell your breakage from what was already broken.

---

## 2. Discovery - run the search directive

The finding's `search_directive` says what to search for. Run it before planning, because the review saw the code as it was when it ran, and the code may have changed since.

1. Run every command in `search_directive.commands` from the project root. Each command is read-only; if one is not, stop and report it.
2. Transcribe the verbatim output into `.architecture-review/refactor/<finding-id>/discovery.txt` at the moment you have it (`rules.md` §9).
3. Compare the result with `search_directive.expect`:
   - **Matches:** the sites the review saw, same count. Proceed.
   - **Wider:** new sites exist. Add each to the plan, and say so in the plan. If a new site sits outside the finding's module tree, stop and ask before widening the scope.
   - **Narrower or empty:** the finding may be stale. Re-open each `locations` entry. If the problem is gone, say so and stop. A stale finding is not a work order.
   - **Dynamic-reference hits** (strings built at runtime, reflection, framework registration): stop and ask. Search cannot prove the list is complete, and the user must decide whether those sites are in scope.
4. The result is the **list of every site the fix touches**. That list is the plan's file list in §4.

---

## 3. Safety net

For each touched site from §2, name the tests that exercise it. Say "none" where none do.

If coverage is missing, the first step of the plan is **characterization tests**: tests that pin what the code does today, right or wrong, so the refactor can be shown to preserve it. They are written as part of the approved plan (§4), not before it. They must pass against the unchanged code before any refactor step runs. A characterization test that fails on unchanged code means the test is wrong or the baseline is wrong: stop.

This is the plan's "safety net first" rule (`phase-6-plan.md` §2) made concrete.

---

## 4. Plan and approval gate

Write `.architecture-review/refactor/<finding-id>.md` with:

- the finding ID, title, and the recommendation being applied
- the discovery summary: the site count and list from §2, and how it compared with `expect`
- the baseline commands, their sources, and the recorded result
- the steps, each one behavior-preserving (extract, move, inline, rename, introduce a seam, then remove the old path). If §3 needs characterization tests, they are step 0.
- every file each step touches, **including every new file**, because undo depends on this list
- the measurement from the finding's evidence ledger that should move, and in which direction
- what is explicitly **not** being changed

Show the plan, then stop and ask:

> Apply this refactor plan for <finding-id>? Reply YES to proceed, or say what to change.

**Touch no project file before YES.** That includes characterization tests: they are part of the plan, so they wait for the same YES. A change to a published contract (an exported API, a schema, a wire format) needs its own explicit YES even inside an approved plan.

---

## 5. Apply in steps

For each step: make the change, then run the baseline commands from §1.

- **Green:** continue. Record the step as done in the plan file.
- **Red:** undo that step, record what failed, and stop to report.
  - Restore tracked files the step touched: `git restore -- <paths>`.
  - Delete new files the step created, only the ones the plan lists for that step, by explicit path.
  - Do not stack a fix on a failing step. Do not edit a test to make it pass, unless it is a characterization test you wrote and the user agrees the old behavior was a bug.

No new features, no bug fixes, no style edits, and no drive-by cleanups, even small ones. Note anything you see in one line for later. A refactor that also changes behavior cannot be verified as a refactor.

---

## 6. Prove it moved

Re-run the exact Phase 1 tool and command that produced the finding's `[tool]` evidence, with the same settings, and put the before and after side by side. Re-run the `search_directive` commands too, and compare with `expect`: the structure the finding named should now be visible in the search. Example: "the three call sites now go through one function," shown by the search returning one caller of the old path.

For a `[git]`-only finding no single command can show the change. Say so, and give the structural fact that changed instead.

If the measurement did not move, say so plainly. The refactor may still be worth keeping, but it did not fix the finding as stated. Never report an improvement you did not measure (`rules.md` §8).

---

## 7. Record and hand back

- Set the finding's `status` in `findings.json` to `Resolved` only when §6 showed the measurement moved and the baseline is green. Otherwise leave it `Open` and add what was learned to the plan file.
- Re-validate `findings.json` against schema 1.1.
- Tell the user: the branch, the files changed (including new ones), the test result, the before and after measurement, and anything noted for later. They review and commit.

One finding per run. For the next one, start again at §1. The previous refactor may have moved lines, changed dependents, or resolved other findings, so the next finding's directive must be re-run in §2 rather than trusted from the review.
