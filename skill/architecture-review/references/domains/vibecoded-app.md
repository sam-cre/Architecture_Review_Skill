# Domain — Vibecoded / Prompt-Assembled App

**Primary failure mode: second sources of truth and unwired integrations.** The app was built feature-by-feature by prompts — often one author, often an LLM holding only the current file in view — so **no one ever held the whole data-flow or the full set of external contracts in their head.** Each feature works in isolation. The breakages live *between* them: a store written by one feature and read by none of the others, a webhook the code depends on that nothing registers, the same rule expressed three different ways because it was prompted three times.

This is a **delta guide** — load it *with* the shape guide that matches the stack (`backend-service`, `frontend-app`, `distributed-services`). It does not replace them; it changes what you look for first and how much you trust history.

Read it for that failure mode. It is not a checklist.

---

## 1. The tells — confirm you are in this shape

Before reviewing *as* a vibecoded app, confirm it is one. Signals, from Phase 0/1:
- Single author or two; commit history bundled (`"fix stuff"`, `"add 404; rename CTA; drop dead css"`) and its survivor sample fails (`tooling/git-history.md` §2).
- No ADRs, no `ARCHITECTURE.md`, no dependency-rule config. Folder names assert a pattern the code does not keep.
- Heavy external-service surface for the size — Firebase/Supabase/Stripe/Clerk/Resend/webhooks — glued directly into feature code.
- Duplicated scaffolding, half-built features, and config for things that never vary, side by side.

If those hold, **history is not your primary evidence** (`phase-1-evidence.md`, inverted hierarchy). The writer/reader ledger and integration inventory are.

---

## 2. Second sources of truth (`data-flow-gap`) — look here first

The signature bug. A feature was added by copying an existing one and swapping the store: `guest_orders` beside `orders`, `v2_users` beside `users`, a Redis cache beside the table. The copy works. What breaks is every *other* consumer that still only knows about the original.

Work the writer/reader ledger (`phase-2-structure.md` §6): for each concept with more than one source store, list every consumer and check each reads **all** the sources. The one that reads a subset — the admin page querying `orders` but never `guest_orders` — is the finding, and it needs no history to prove. This is where the highest-value finding on most vibecoded repos lives.

---

## 3. Unwired integrations (`integration-gap`) — the checklist that saves them

The code assumes things about the world outside the repo, and the assembling model never verified them: a webhook handler with no registered endpoint, an env var read but never provisioned, a secret set in two places. Work the integration inventory (`phase-2-structure.md` §6b).

Most of these cap at Low (absence of evidence) and become the **external-assumptions-to-verify checklist** — which for a codebase in disarray is frequently the most valuable page you produce. The exception is the load-bearing one: a payment or auth flow whose only path runs through a seam nothing wires. Trace that flow end to end and file it.

---

## 4. Parallel implementations of one rule

Prompted three times, implemented three ways. The same price calculation on the client and the server that can disagree; validation in the request schema and again in the handler, drifting; three different error-handling styles because three sessions. This is the *different-shape/same-reason* duplication no clone detector finds (`phase-3-abstraction.md` §4). Grep the distinctive constant or rule, not the shape. A client/server rule that can disagree is `data-flow-gap` or `duplication` with a `priority_override` when the disagreement is externally visible (money, auth).

---

## 5. Over-abstraction the model reached for — but grade against tier

LLMs reach for ceremony: a factory with one product, a `*Manager`/`*Service` that only forwards, an interface with one implementer, config for a value that never varies. These are real `overengineering` findings **and the cheapest to fix (deletion)** — but grade against the Phase 0 tier (`rules.md` §4 Gate 5). At T1–T2, most of it is a finding. Do not, however, let this become the whole report: over-abstraction is cosmetic next to a second source of truth that loses orders. Rank accordingly.

---

## Reviewing this shape well

**Build the ledger and the integration inventory before you read for opinions, and trace one money-or-data path end to end** — checkout, signup, the thing that matters — naming every store it writes, every store the *rest* of the app reads for the same concept, and every external seam it depends on. That single trace surfaces the partial readers and the unwired contracts at once.

Then remember what the report is *for*: the owner may not understand their own codebase. Lead with what you found the system actually does — the data-flow map and the assumptions checklist — and only then what is wrong. Reveal before you critique.
