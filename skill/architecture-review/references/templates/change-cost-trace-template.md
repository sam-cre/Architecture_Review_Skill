# Change-Cost Traces - <project name>

<!--
.architecture-review/change-cost-traces.md - Phase 4.
Section 1 (history) is mandatory. Section 2 (hypotheticals) is admissible only
after section 1 has been attempted and come up empty, and every scenario needs
a named anchor. rules.md §4 Gate 2.
-->

**History window:** <N days> · **Commits examined:** <N>

---

## 0. Commit selection - audit trail

<!--
rules.md §4 "Which history counts". Recording rejections is what makes the
selection falsifiable - otherwise a reader cannot tell whether the sample was
chosen or found.

Admissible: new feature or variant · domain rule change · new entity/field
            flowing through the system · bug fix rooted in a domain rule
Inadmissible: formatting · renames · dep bumps · framework upgrades ·
            test/docs/config/CI-only · generated files · scaffolding ·
            bulk moves · merges · reverts
-->

**Candidates examined:** <N> · **Admissible:** <N> · **Rejected:** <N>

| Commit | Subject | Verdict | Why |
|---|---|---|---|
| `a3f9c21` | add Adyen provider | **admissible** | new variant of an existing concept |
| `77b201e` | bump react 17→18 | rejected | framework upgrade - touches everything by nature |
| `c40de8a` | prettier across src | rejected | formatting - touches everything, means nothing |
| `9f1a3d2` | fix tax rounding for EU | **admissible** | domain rule change |

<!-- Fewer than 3 admissible? Say so here and do NOT substitute chores.
     Report it under coverage as a limit on what this review can determine. -->

---

## 1. What changes have already cost

### Trace A - <what the change did, one line>

**Commit:** `<sha>` · <date> · `<subject>`
**Command:** `git show --stat <sha>`

| | Files | Modules |
|---|---|---|
| Essential *(contains the feature's logic)* | | |
| Incidental *(touched only because of coupling)* | | |
| **Amplification** | **<incidental ÷ essential>** | |

**Essential**
- `path/to/file.ext` - <what it did>

**Incidental** ← *this list is the finding*
- `path/to/other.ext:44` - <why it had to change, though it holds no feature logic>

**Feeds:** <ARCH-00N as Gate 2(a) evidence>

---

### Trace B - …

---

## Toll booths

<!--
Files appearing in EVERY trace regardless of what the change was. These are the
architecture's toll booths and are usually the review's highest-value findings.

  git log --since=<N>.days --no-merges --name-only --format='---' \
    | grep -v '^---$' | grep -v '^$' | sort | uniq -c | sort -rn | head -15
-->

| File | Appears in | Why | Holds feature logic? |
|---|---|---|---|
| `src/config/index.ts` | 4 of 4 traces | Every feature adds a key | No |
| `src/api/routes.ts` | 4 of 4 traces | Central registration | No |

<!-- Cross-reference against churn.txt. High in both lists + belongs to no single
     feature = architectural bottleneck. Category: change-amplification. -->

---

## 2. Anchored projections

> **Admissible only after section 1.** Record the history command that found no
> comparable change, and give every scenario a real anchor. An unanchored
> hypothetical is not evidence and fails Gate 2.

**History searched:** `<command>` → <what it found or did not find>

### Scenario 1 - <the named change>

**Anchor:** <TODO at file:line | issue/roadmap the user pointed at | existing near-duplicate | user statement in Phase 0>

<!-- NOT an anchor: "codebases usually need to scale", "you might want to swap
     databases someday", "what if you had 100x traffic", best-practice reasoning. -->

**Files that must change** - traced by opening them and following imports, not estimated:

| File | Why | Essential? |
|---|---|---|
| `src/billing/stripe.ts:1-240` | the logic itself | yes |
| `src/api/checkout.ts:56-71` | constructs Stripe directly | no |
| `prisma/schema.prisma:88` | `stripeChargeId` column - needs a migration | no |

**Essential: <N> · Incidental: <N> · Amplification: <N>×**

**Feeds:** <ARCH-00N>

---

## 3. Scalability paths

<!-- One row per claim. A scalability finding with an empty cell is not filed. -->

| Dimension that grows | What breaks first (`file:line`) | Why | Rough magnitude | Currently near it? |
|---|---|---|---|---|
| Rows per tenant | `src/reports/build.ts:70` | loads the full result set into memory before filtering | somewhere past a few thousand | no - largest tenant ~200 |

**Order of magnitude only.** "Past a few thousand rows" is honest; "at 4,200 rows" is fabrication.

**Architectural, not performance:** the test is *would fixing this require changing the shape of the code, or just the contents of one function?* Only the former belongs here.

**Team scalability** counts too - the toll-booth files above are merge-conflict funnels and review bottlenecks, already measured.

---

## 4. Reconciliation

| Finding | Before | After | Why |
|---|---|---|---|
| ARCH-003 | (c) forced, Low | (a) historical, High | Trace B showed it already cost 6 incidental files |
| ARCH-007 | Medium | **dropped** | No traced change touched it; Cold + Contained → Informational |

<!-- Be willing to delete your own work here. A finding that has never cost
     anything and sits in code nobody touches is not a finding. -->
