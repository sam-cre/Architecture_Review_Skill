# Phase 4 — Change-Cost Simulation

_Hold: `rules.md`, the tier, the findings list so far. Release: the Phase 3 file. Output: `.architecture-review/change-cost-traces.md`, plus Gate 2 evidence attached to existing findings and possibly new ones._

This is the falsifiability phase — the architectural analogue of writing a proof-of-concept for a security finding. It converts "this design is bad" into "here are the eleven files the last comparable change had to touch."

**History first. Hypotheticals only after history comes up empty, and only when anchored.** This ordering is `rules.md` §4 Gate 2 and it is not optional: falsifiable history beats speculation about the future, always.

---

## Step 1 — Measure what changes have already cost

Find the last 3–5 substantive changes in the log.

**Which commits are admissible is defined in `rules.md` §4 "Which history counts" — read it before selecting, and record your rejections.** The selection is the most manipulable part of this phase: a formatting commit "proves" the architecture is perfectly isolated, a framework upgrade "proves" it is hopelessly coupled, and neither tells you anything. In short: a business feature or domain-rule change qualifies; chores, bumps, renames, and test/docs/config-only commits never do.

If you cannot find three admissible changes, say so and do not substitute chores to reach the count.

```bash
# candidate commits: substantive, multi-file, not merges
git log --no-merges --since=180.days --format='%h %ad %s' --date=short \
  --shortstat | head -80

# what one change actually touched
git show --stat --format='%h %s' <sha>

# a squashed feature branch, or a range
git diff --stat <base>..<head>
```

For each, record in `change-cost-traces.md`:

| Field | Content |
|---|---|
| Change | What it did, in one line, from the commit message and diff |
| Files touched | The count, and the list grouped by module |
| Modules crossed | How many, and which |
| Incidental files | Files touched **only** because of coupling — not because the feature lived there |
| Amplification | Incidental ÷ essential. This is the number that matters. |

**The incidental column is the finding.** If adding a payment provider required editing a route file, a DI registration, an enum, a validation schema, a UI dropdown, and a test fixture — none of which contain payment logic — that is six units of change amplification, dated, attributable, and impossible to argue with.

Then look for the pattern across changes: **which files appear in every trace regardless of what the change was?** Those files are the architecture's toll booths. They are almost always the highest-value findings in the review, and they are frequently the ones nobody suspected.

```bash
# files that appear in the most recent N feature commits
git log --no-merges --since=180.days --name-only --format='---%h' \
  > .architecture-review/evidence/change-files.txt
```

Attach these traces to existing findings as Gate 2(a) evidence. **Findings that survived Phases 2–3 on (b) or (c) should be re-checked here — many can be upgraded to (a), and some will turn out to have never cost anything.** Those get dropped.

---

## Step 2 — Anchored hypotheticals

Only after Step 1. Record the history command you ran and state that no comparable change was found before writing a single hypothetical.

A hypothetical needs an **anchor** — something in the repository or from the user, not your imagination:

| Valid anchor | Not an anchor |
|---|---|
| A `TODO`/`FIXME`/`HACK` naming the change | "Codebases usually need to scale" |
| An issue, roadmap, or milestone the user pointed at | "You might want to swap databases someday" |
| An existing near-duplicate proving the shape recurs (one payment provider → a second) | "What if you had 100× the traffic" |
| Something the user stated in Phase 0 | A pattern you have seen elsewhere |
| A commented-out or half-built alternative in the code | Best-practice reasoning |

For each anchored scenario, trace it **concretely**: open the files, follow the imports, and produce the actual list of what would have to change. Not an estimate — a list.

```
Scenario: add a second payment provider (anchor: TODO at src/billing/stripe.ts:12
          "make this pluggable when we add Adyen")
Files that must change:
  src/billing/stripe.ts:1-240      the logic itself — essential
  src/billing/types.ts:8           StripeCharge is the shared shape — incidental
  src/api/checkout.ts:56-71        constructs Stripe directly — incidental
  src/config/index.ts:22           STRIPE_KEY hardcoded in the schema — incidental
  src/webhooks/router.ts:14-40     provider-specific parsing inline — incidental
  prisma/schema.prisma:88          `stripeChargeId` column — incidental, needs migration
  src/ui/Checkout.tsx:102          hardcoded provider name — incidental
Essential: 1   Incidental: 6   Amplification: 6×
```

**Three scenarios in `standard`, five to eight in `deep`, none in `quick`.**

If you cannot produce an anchor, you do not write the scenario. An unanchored hypothetical fails Gate 2 and is not evidence.

---

## Step 3 — Scalability, traced not asserted

"This won't scale" is the least falsifiable sentence in software. Make it falsifiable or don't say it.

A scalability finding needs a **traced growth path**: name the dimension that grows, the specific code that degrades, and why.

- **Which dimension?** Rows, users, requests/sec, concurrent connections, file size, tenants, services, team members. Name one.
- **What breaks first?** Point at the code: a query with no index and no pagination at `file:line`; an in-memory collection that holds the full result set; a synchronous fan-out that is O(n) in network calls; a lock held across an I/O boundary; a per-request full-table scan.
- **At roughly what magnitude?** Order of magnitude only — "somewhere past a few thousand rows per tenant," not "at 4,200 rows." Precision here is fabrication (`rules.md` §8.1).
- **Is it currently near that?** Check the data if you can see a schema, seed data, or fixtures. A bottleneck three orders of magnitude away in a T2 codebase is Informational.

**Architectural scalability, not performance.** A slow function is not this skill's concern. A design where the only way to make it faster is to restructure — that is `scalability-bottleneck`. The distinguishing question: *would fixing this require changing the shape of the code, or just the contents of one function?*

Team scalability counts too, and is often the more real constraint: a file every feature must touch is a merge-conflict funnel and a review bottleneck. Step 1's toll-booth files are exactly this, already measured.

---

## Step 4 — Reconcile

- Upgrade findings whose cost you just demonstrated. Move (c) evidence to (a) where Step 1 supplied it, and update the confidence ceiling accordingly.
- **Drop findings that Step 1 shows never cost anything.** A structural violation in code that has not changed in two years and was not touched by any traced change is Cold — and Cold + Contained is Informational per `rules.md` §5. Be willing to delete your own work here.
- File new findings for toll-booth files and amplification patterns Step 1 revealed. Category: `change-amplification`.

---

## Gate

Do not proceed until: at least one historical change has been traced (or the repo genuinely has no substantive history, stated explicitly), every hypothetical carries a named anchor, and every scalability claim names a dimension, a location, and a magnitude.
