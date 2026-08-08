# Architecture Review Skill

An evidence-based architecture review for any codebase. It answers one question: **"is this actually designed well?"**: and it is built to refuse to answer it with opinion.

Not a bug hunter, not a linter, not a security scanner.

## Use

From any project directory:

```
/architecture-review              full review (standard)
/architecture-review quick        structural triage: graph, cycles, hotspots
/architecture-review deep         wider evidence sweep, more change scenarios
/architecture-review pr           review the design of a diff
/architecture-review diff         re-review; did the debt move?
```

It also triggers on plain requests like: *"is this overengineered?"*, *"why is this so hard to change?"*, *"review my architecture"*, *"do I have circular dependencies?"*

## How it works

| Phase | |
|---|---|
| 0 | Recon & intent: profile, and set the **ceremony budget** (T1–T4) that every finding is graded against |
| 1 | Evidence harvest: run the tools, record raw output, form **no** judgments |
| 2 | Structure: module organization, boundaries, dependency direction, cycles |
| 3 | Abstraction: SOLID lens, missing/incorrect abstraction, duplication, overengineering |
| 4 | Change-cost simulation: what past changes actually cost; anchored projections only after |
| 5 | Adversarial self-review: defend every finding, then audit the ledger |
| 6 | Prioritized plan: "accept & document" and "change nothing" are valid outputs |
| 7 | Report: with a mandatory coverage statement |

Measurement comes before reading, deliberately: reading first and measuring afterward produces cherry-picked evidence.

## Honesty guarantees

- No architecture score, grade, or health index. Severity is ordinal: Blast Radius × Change Frequency: with `(measured)` or `(judged)` marked on every axis.
- No metric it did not compute; no file or line it did not open.
- If a tool is missing, it says so, uses a documented fallback, and caps the resulting confidence.
- Every report states what was **measured**, what was **reasoned**, and what was **not reached**.
- A clean review is a valid outcome. If your design is sound for what it is, the report says so and stays short.