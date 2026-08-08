# Phase 5 - Adversarial Self-Review

_Hold: `rules.md`, the full findings list, the tier. Release: the Phase 4 file. Output: revised `findings.md`, plus a "considered and dropped" list._

Everything up to here was constructive. This phase is destructive on purpose: **your job is to break your own findings.** Whatever survives is worth reporting.

Expect to drop findings here. A review that enters this phase with fourteen findings and leaves with six is working correctly.

---

## Pass A - Steelman the current design

For **every** finding, argue the opposite case as if the codebase's author were defending it. Write the defense down; do not just consider it.

Ask in order:
1. **What would this design be right for?** Every structure is optimal for some set of constraints. Name that set. Then check Phase 0 - does this project have those constraints? If yes, you are wrong and the finding dies here.
2. **Is the "problem" actually load-bearing?** Duplication that lets two teams move independently. A god object that is genuinely one cohesive concept the domain treats as one thing. Coupling to a framework the project will never leave.
3. **Would the fix break something I can see?** A public API, a serialization format, a deployment assumption, a migration path.
4. **Am I reviewing a snapshot of something mid-flight?** Cross-check Phase 0 Step 4 exclusions.
5. **Is my alternative actually better, or just different?** If you cannot articulate the specific cost the current shape imposes and the specific cost your alternative removes, there is no finding - only preference.

Kill anything that doesn't survive. Record it in the dropped list with the reason.

---

## Pass B - The overengineering check on your own recommendations

**The self-referential test, and the one this skill most needs.** A design review that recommends overengineered fixes has failed at its own subject matter.

Take each recommendation and review it as though it were code someone submitted. Run it through Phase 3's overengineering signals:

- Does it introduce an interface with one implementation?
- Does it add a layer that only forwards?
- Does it add configuration for something that has never varied?
- Does it add indirection without a seam?
- **Would this recommendation be a finding if I found it already in the codebase?** If yes, the recommendation is wrong. Rewrite it or drop the finding.

Then check it against the tier: does the fix push the codebase past what Phase 0's ceremony budget warrants? A T2 codebase does not get a T4 remedy.

**Prefer the smaller fix.** Deleting the wrong abstraction beats adding a right one. Moving a file beats introducing a layer. Extracting one function beats a plugin system. If two fixes address the same finding, recommend the cheaper one and say the larger one exists.

---

## Pass C - Hunt what no metric surfaced

Tools find cycles, duplication, and churn. They cannot find the things below, so look for them deliberately. This is the false-negative pass.

- **The abstraction that is fine today and wrong for the stated roadmap.** Cross-reference Phase 4's anchors.
- **The concept that has no name.** A rule expressed identically in four places with no shared vocabulary - different shape, same reason to change (Phase 3 §4). No detector finds this.
- **Boundaries drawn around technology rather than change.** `services/`, `models/`, `hooks/` group by what things *are*; changes arrive by what things are *about*. Confirm against co-change.
- **What the tests are shaped like.** Test structure mirrors the seams the code actually has. Where they're awkward, a seam is missing.
- **What is conspicuously absent.** No error type hierarchy in a system with many failure modes. No transaction boundary in something that clearly needs one. No versioning on a contract that has consumers.
- **Modules with high fan-in and no interface** - every change is a breaking change.
- **The thing you keep having to re-read to understand.** If you needed three passes to follow a control flow, that is a cohesion signal. Verify it before filing, but do not ignore it.
- **What you did not look at at all.** Directories you skipped, languages you can't analyze, generated code that might not be generated anymore. This feeds the Phase 7 coverage statement.

---

## Pass D - Ledger audit

**Work from the file, not from memory.** Re-read `findings.md` from disk and audit what is written there.

Know what this pass can and cannot do (`rules.md` §9): in a single continuous session the file you read is already in context, so this is a **filter, not an audit** - it catches lines you know you cannot reproduce, not lines you wrongly believe you can. Do not report it as verification. If the review needs real verification, run the phases cold as separate invocations and say so in the coverage section.

Mechanical. Go finding by finding through `rules.md` §2 and §3.

1. **Every `[tool]` and `[git]` line: can you name the command and quote real output?** If not, retag `[infer]` and re-run the gate. A retagged line usually changes the ceiling.
2. **Every `[read]` line: did you actually open that file at that range?** Not grep - open. If not, open it now or drop the line.
3. **Every finding has at least one `[read]` line.** No exceptions.
4. **No finding is `[infer]`-only.** Those are discarded outright, not downgraded (§2.3).
5. **Recompute the ceiling** (C1–C5, lowest wins) and correct any confidence that drifted upward while you were writing.
6. **Every number in every finding traces to a command.** Any bare figure you cannot source gets deleted from the text, not softened.
7. **No location is cited without a line range.**

---

## Pass E - Sanity-check the whole

Step back from the individual findings.

- **Do the findings contradict each other?** Recommending both consolidation and separation of the same code means you have not decided what the boundary should be. Decide.
- **Is there one root cause under several findings?** Merge them. Five symptoms of one inverted dependency is one finding with five consequences, and it reports far better.
- **Is the report proportionate?** Twenty findings on a T2 codebase means the bar was too low - re-run Gate 5 across the set.
- **If every recommendation were applied, would the result be better?** Picture it concretely. If the answer is "more ceremony, marginally cleaner," the review has drifted into style. Cut back to the findings with real Gate 2 cost.
- **Does the top finding answer the user's Phase 0 question?** If they asked "why is this so hard to change" and the top finding is a naming inconsistency, re-rank.

---

## Gate

Do not proceed until every finding has a written steelman, every recommendation has passed Pass B, and the ledger audit is complete. Record the dropped list - Phase 7 reports it as "considered and dropped."
