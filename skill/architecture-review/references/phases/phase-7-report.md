# Phase 7 - Report

_Hold: `rules.md`, `findings.md`, the tool availability table, the tier. Release: everything else - the report is written from the findings file, not from memory. Output: `architecture-review.md`, `findings.json`, `metrics-baseline.json`._

---

## 1. Answer the question first

If the user asked something specific in Phase 0 - "is this overengineered", "why is this so hard to change", "should I split this up" - **the report opens by answering it in one paragraph**, with the evidence, before any findings list.

> You asked whether this is overengineered. Partly: the `strategy/` package has five interfaces with one implementation each and none has gained a second in the 19 months since it was added, which costs you a file per operation and an indirection on every read. The rest of the codebase is proportionate to its size. The coupling you have been feeling is not overengineering - it is `config/index.ts`, which 61 of 94 modules import, and which appeared in all four feature commits I traced.

Do not hedge into an enumeration. Answer, then support.

If the user asked nothing specific, open with the single most consequential finding and the honest one-line verdict on the design overall.

---

## 2. Write the human report

`.architecture-review/architecture-review.md`, from `references/templates/architecture-report-template.md`.

Required sections, in order:

1. **Answer / verdict** - as above
2. **What this project is** - type, tier, size, the tier's reasoning in two lines, and the **evidence posture**: `history-usable` or `history-unusable (survivor sample: N/N bundles)` from `tool-availability.md`. Stating it lets a reader who knows the repo is actually mature override a misclassification (`phase-1-evidence.md`).
3. **What the system actually does** - the data-flow map and the external-assumptions checklist (§2a below). **Reveal before you critique.**
4. **Coverage** - §3 below. Not optional, not at the end.
5. **Findings** - grouped by the Phase 6 priority groups, not by severity
6. **What I am not recommending** - from Phase 6 §4
7. **Considered and dropped** - from Phase 5, one line each with the gate that failed
8. **Informational** - gate-failed items still worth a mention
9. **Baseline** - the metric table, for comparison on the next run

### 2a. Reveal before you critique - two deliverables the owner often needs more than the findings

For a codebase in disarray whose owner may not fully understand it, *what it does* is as valuable as *what is wrong*. Lead with two artifacts built from Phase 1 measurements 7 and 8:

- **Data-flow map.** The writer/reader ledger (`evidence/data-flow.md`), rendered readably: for each store/event/contract, who writes it and who reads it, with the coverage gaps (`data-flow-gap` findings) marked in place. This is the map no one drew while prompting the app into existence.
- **External-assumptions checklist.** The load-bearing seams from the integration inventory (`evidence/integrations.md`) that the code depends on but the repo cannot prove is wired (`integration-gap`), **ranked by blast radius and tied to the flow each threatens** - money/auth/durable-write seams first; routine framework config and analytics seams stay in `evidence/`, off the list (`rules.md` §6, `integration-gap`). Actionable form: *"`STRIPE_WEBHOOK_SECRET` is read at `api/server.js:314`, is the only thing that marks orders paid, and appears in no config source - verify it is set wherever the backend runs, or no order is ever fulfilled."* Low-confidence by construction (absence of evidence), which is exactly why they belong in a checklist to verify, not the findings list.

On a mature repo with neither gap, these sections are one line each ("data-flow is single-source; no unwired seams found"). On a vibecoded one they are the heart of the report.

---

## 3. Coverage statement - mandatory

Three categories, stated plainly. This is what separates a review with known limits from one that quietly overstates itself.

**Measured** - what tool or history output backs. Reproduce the tool availability table from Phase 1 verbatim, including the rows where a tool did not run.

**Reasoned** - what was read and judged without tool backing, and why (no tool for this stack, or the concern is irreducibly qualitative). Note that these findings are capped at Medium and why.

**Not reached** - directories skipped, languages not analyzable, generated code not verified as still generated, runtime behavior not observable, anything the user scoped out. Name it. *"I could not assess the Python service because no dependency tool was available and it holds 40% of the code"* is a more valuable sentence than any Medium-confidence finding.

State the history window used, and the tool versions where a tool produced a number.

---

## 4. Write and verify the machine artifacts

**`findings.json`** - conforms to `references/templates/findings-schema.json`. This is the hand-off for a separate, scoped refactoring session and the input to `diff` mode. Every field from `rules.md` §6, including the full evidence ledger with its tags and the applied ceiling. Do not summarize the ledger away; the tags are what make the JSON auditable downstream.

**`metrics-baseline.json`** - updated from Phase 1. Only measured numbers; omit keys you could not fill rather than writing nulls.

### Write to disk, then verify - never emit JSON into the response and hope

A long, deeply-nested array generated at the end of a long context is the single most fragile output this skill produces. Truncation, a dropped closing bracket, an invented key, a trailing comma - all are silent, and all produce a file that looks fine until something downstream tries to read it.

**Write incrementally.** Append each finding to `findings.json` as Phase 5 confirms it, rather than composing the whole array here. One malformed entry is recoverable; one truncated 800-line generation is not.

**Then run the verification ladder.** Do not skip to the report until it passes.

```bash
# 1. Does it parse? Always possible - no dependencies.
python -c "import json; d=json.load(open('.architecture-review/findings.json')); print('parse OK -', len(d['findings']), 'findings')"
# or:  jq -e 'type == "object" and (.findings | type == "array")' .architecture-review/findings.json

# 2. Does it validate against the schema? Best effort - skip if unavailable.
python -c "
import json, jsonschema
d = json.load(open('.architecture-review/findings.json'))
s = json.load(open('<skill>/references/templates/findings-schema.json'))
jsonschema.validate(d, s); print('schema OK')
"
# or:  npx -y ajv-cli validate -s <schema> -d .architecture-review/findings.json --spec=draft7
```

**3. If no validator is available, spot-check by hand** - read the file back and confirm: it parses, the `findings` array length matches your count, the last entry is complete and closed, every entry has a non-empty `evidence` array with at least one `read` tag, and every `cost_demonstrated.kind: "forced"` carries both `history_searched` and `anchor`.

**On failure, fix the file and re-run the ladder.** Do not report a validation failure as a caveat and move on - an invalid hand-off artifact is a broken deliverable, and the whole point of the schema is that ungrounded findings fail loudly rather than reading fine. Repeat until step 1 passes and either step 2 passes or you have recorded that no validator was available.

Record the outcome in the coverage section: `findings.json - parsed OK, schema-validated (ajv)` or `parsed OK, schema not validated (no validator available)`.

---

## 5. Report hygiene

- **No aggregate score, grade, index, or maturity level.** `rules.md` §8.6. The verdict is a sentence, not a number.
- **Finding count is not a quality measure** and must not be framed as one. Six well-evidenced findings is a better review than twenty.
- **Every location is `path:line-range`.** Clickable, checkable, and never a bare filename.
- **Every number traces to a command**, named in the ledger.
- **Confidence and the applied ceiling are visible on every finding**, not buried in the JSON.
- **No fabricated urgency.** If nothing is urgent, the report says nothing is urgent.
- **Length is proportionate to findings.** Do not pad a short review to look thorough. A clean review is a valid outcome (`rules.md` §9).

---

## 6. Hand off

Close by telling the user what exists and what to do with it:

- `architecture-review.md` - read this
- `findings.json` - feed this to a scoped refactoring session, one finding at a time
- `metrics-baseline.json` - re-run in `diff` mode later to see whether debt moved

Remind them nothing in their project was modified.

---

## Gate

Done when: the user's question is answered in the first paragraph, the coverage statement contains all three categories, `findings.json` validates against the schema, and no number in the report lacks a source.
