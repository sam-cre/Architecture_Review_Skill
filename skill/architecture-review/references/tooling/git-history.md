# Tooling — Git History

**The only source of *demonstrated* cost — Gate 2(a) in `rules.md` §4 — when the repository can support it.** Stack-independent, always available, needs nothing installed.

**Its rank is earned, not assumed.** On a mature repo with focused commits this is the strongest evidence in the review and it leads. On the repo this skill most often meets — assembled feature-by-feature, one author, bundled or squashed commits, days rather than years of history — it fails its own survivor sample (§2 below) and leads nothing. `phase-1-evidence.md` sets the ranking; **the mechanical survivor-sample result decides it, never a hunch about the project.**

So: always run it. Then let §2 tell you whether you may quote it. Two of the three measurements here degrade gracefully and survive a weak history — **churn** (§1) and **change amplification** (§3) are single-commit observations, not pairwise aggregates. Only the **co-change matrix** (§2) collapses, and it collapses completely: unusable means *not quoted at all*, not quoted at low confidence.

Always redirect raw output to `.architecture-review/evidence/` and read back only summaries (`phase-1-evidence.md`, context discipline).

Set a window and **state it in the report**. Default `--since=180.days`; use full history on repos younger than that; narrow to 90 days on very high-traffic repos.

---

## Availability

| Situation | Do this |
|---|---|
| Git repo present | Everything below. Findings get `[git]`. |
| Shallow clone (`git rev-parse --is-shallow-repository` → true) | Say so. Offer `git fetch --unshallow`. Until then, treat depth as the window and state it. |
| No VCS at all | **Every finding is capped at Medium by ceiling C1** unless a `[tool]` line backs it. State this in the coverage section — it is a major limitation, not a footnote. |
| Squash-merge-only history | One commit per PR is still a change unit. Amplification measurement works fine; per-file blame is less useful. Note it. |

---

## 1. Churn — which files actually change

Feeds the **Change Frequency** axis (`rules.md` §5). Without this, nothing may be rated Hot.

```bash
git log --since=180.days --name-only --format='' \
  | grep -v '^$' | sort | uniq -c | sort -rn \
  > .architecture-review/evidence/churn.txt
head -30 .architecture-review/evidence/churn.txt
```

Top decile = Hot. Present but below it = Warm. Absent = Cold.

```bash
# how many files have any commits in the window — for the decile cut
wc -l < .architecture-review/evidence/churn.txt
```

Per-module rollup:

```bash
git log --since=180.days --name-only --format='' \
  | grep -v '^$' | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -20
```

---

## 2. Co-change coupling — the real module boundaries

**The most important query here.** Two files that change together repeatedly are coupled, whether or not they import each other. This measures cohesion directly and catches the coupling the import graph cannot see (`phase-2-structure.md` §6).

Dump commit→files, then count pairs:

```bash
git log --since=180.days --no-merges --name-only --format='---%h' \
  > .architecture-review/evidence/commit-files.txt
```

```bash
# FANOUT caps how many files a commit may touch before it is excluded.
# A 40-file commit contributes 780 pairs, nearly all of them noise.
awk -v FANOUT=12 '
  function flush(  i, j) {
    if (n > 0 && n <= FANOUT)
      for (i in f) for (j in f) if (i < j) pair[i"  <->  "j]++
    else if (n > FANOUT) skipped++
    delete f; n = 0
  }
  /^---/ { flush(); next }
  NF     { if (!($0 in f)) { f[$0] = 1; n++ } }
  END    { flush()
           for (p in pair) if (pair[p] >= 3) print pair[p], p
           print "# excluded " skipped " commits over " FANOUT " files" > "/dev/stderr" }
' .architecture-review/evidence/commit-files.txt \
  | sort -rn | head -40 \
  > .architecture-review/evidence/co-change.txt
```

**The fanout cap does three jobs, and the third is a warning about the other two.**

1. **Validity.** A commit bundling unrelated changes makes every file in it co-change with every other, for no design reason. Without the cap the matrix measures **what got bundled into a pull request**, not what is coupled.
2. **Tractability.** Pair generation is O(n²) per commit. A bulk import, vendor drop, or scaffold commit touching ~9,000 files generates roughly 40 million pairs on its own and will hang the uncapped `awk` indefinitely. Most repositories have at least one such commit.
3. **It is a leaky proxy.** File count detects *large* bundles. It is deaf to *small* ones — a nine-file commit doing four unrelated things passes untouched. In single-author repositories small bundles are often the dominant style, which means the cap can look effective while the matrix stays thoroughly confounded.

Because of (3), **the exclusion percentage tells you nothing about whether the history is usable.** A cap excluding 32% of commits can still leave a matrix built mostly from small bundles. Validate the corpus by sample instead.

### Survivor sampling — required before quoting any co-change number

Open **N random commits that survived the cap** — N = 5 for repositories under ~200 commits, 10 above — and classify each against the admissible/inadmissible lists in `rules.md` §4:

- **Focused** — one coherent concern.
- **Bundle** — several unrelated concerns, *at any file count*.
- **Unclassifiable from the subject** — open the diff and decide. Never count it focused by default.

```bash
git log --no-merges --since=180.days --format='%h %s' | shuf -n 5   # or: sort -R | head -5
git show --stat <sha>
```

**If more than half the sample is bundles, the co-change matrix is not usable evidence for this repository.** State that in the coverage section, fall back to the import graph and the §6 implicit-coupling census, and **do not quote pair counts at all** — not even at Medium. A number that cannot be validated is not weaker evidence, it is not evidence.

If roughly a third or more are bundles, co-change survives but every finding built on it requires the full C5 per-pair spot-check with no re-derivation shortcut. Note that in coverage too.

Record the sample — the commits, each classification, and the verdict. **An unstated sample is itself an unvalidated aggregate**, which is the failure this whole protocol exists to prevent.

### Commit subjects as a bundle signal

Cheap, and it catches precisely the small-bundle class the fanout cap misses. A subject announces a bundle when it contains:

- Multiple imperative verbs — *"Fix backend-URL duplication, health flag, fragile analytics init, stale docs"*
- Semicolons, or commas joining independent clauses
- Multiple conventional-commit types, or one type plus unrelated trailing clauses
- Conjunctions joining unrelated concerns — *"perf: on-demand Firebase/Chart.js, lazy gallery, dep split, hardening"*

```bash
# candidate bundles by subject shape, at any file count
git log --no-merges --format='%h %s' \
  | grep -nE '; |, .*, |\b(and|plus|also)\b.*\b(fix|add|remove|update)\b'
```

**This detector is positive-only.** A multi-clause subject *proves* a bundle. A terse or vague subject — *"idk lol"*, *"minor fixes"*, *"updates"* — proves nothing and must be classified by opening the diff. Never read an uninformative message as evidence of a focused commit.

Read it as: **pairs with a high count that live in different modules are the finding.** Same-module pairs are expected and are evidence of *good* cohesion.

> **This number is an aggregate and carries ceiling C5** (`rules.md` §3): it caps at Medium until you validate the specific pair — re-derive it against filtered history, or open some of the contributing commits and confirm they are admissible changes rather than bundles. Do that before quoting it in a High-confidence finding. Running the command is not the same as measuring the right thing.

Directional strength for a specific suspected pair — this is the number to quote in a ledger line:

```bash
A=src/billing; B=src/users
total=$(git log --since=180.days --format=%h --name-only -- $A | grep -c '^[0-9a-f]\{7,\}$')
both=$(git log --since=180.days --format=%h --name-only -- $A \
       | awk '/^[0-9a-f]{7,}$/{h=$0} $0 ~ "^'"$B"'"{print h}' | sort -u | wc -l)
echo "$B appears in $both of $total commits touching $A"
```

> `[git]` … → 27 of 41 commits touching `src/billing` also touched `src/users`

**Windows / PowerShell** — if `awk` is unavailable, use the same dump file with:

```powershell
$commits = (Get-Content .architecture-review\evidence\commit-files.txt) -join "`n" -split '---\w+'
$pairs = @{}
foreach ($c in $commits) {
  $files = $c -split "`n" | Where-Object { $_ -and $_ -notmatch '^\s*$' } | Sort-Object -Unique
  for ($i=0; $i -lt $files.Count; $i++) { for ($j=$i+1; $j -lt $files.Count; $j++) {
    $k = "$($files[$i])  <->  $($files[$j])"; $pairs[$k] = 1 + $pairs[$k] } }
}
$pairs.GetEnumerator() | Where-Object Value -ge 3 | Sort-Object Value -Descending |
  Select-Object -First 40 | Format-Table -AutoSize
```

Cap the pair count on huge repos — restrict the log to one or two directories at a time rather than the whole tree, or the pair space explodes.

---

## 3. Change amplification — what a feature costs

Feeds Phase 4 Step 1 directly.

```bash
# substantive multi-file commits, largest first
git log --since=180.days --no-merges --format='%h|%ad|%s' --date=short --shortstat \
  > .architecture-review/evidence/commit-sizes.txt

# what one change touched, grouped by module
git show --stat --format='%h %s' <sha>
git show --name-only --format='' <sha> | cut -d/ -f1-2 | sort | uniq -c | sort -rn
```

Then split the file list into **essential** (contains the feature's logic) and **incidental** (touched only because of coupling). The ratio is the amplification number.

Files appearing across *many* different feature commits — the toll booths:

```bash
git log --since=180.days --no-merges --name-only --format='---' \
  | grep -v '^---$' | grep -v '^$' | sort | uniq -c | sort -rn | head -15
```

Cross-reference against churn: a file that is high in *both* lists and belongs to no single feature is an architectural bottleneck. This is usually the review's best finding.

---

## 4. Growth and age

```bash
git log --format=%cd --date=short --reverse | head -1     # first commit
git log --diff-filter=A --since=180.days --name-only --format='' \
  | grep -v '^$' | wc -l                                   # files added in window
git shortlog -sn --since=180.days | head -20               # active contributors
```

Contributor count feeds the Phase 0 tier. A module touched by many authors needs clearer boundaries than one owned by a single person — and one touched by exactly one author for two years may be knowledge-siloed, which is a real risk but usually `Note only`.

Monotonic growth in a `shared/` or `utils/` module is the `boundary-erosion` evidence from `phase-2-structure.md` §2:

```bash
git log --since=365.days --format='%ad' --date=short --numstat -- src/utils \
  | awk 'NF==3 {add+=$1; del+=$2} END {print "added:", add, "deleted:", del}'
```

---

## 5. Blame, for Chesterton's fence

Gate 4 (`rules.md` §4) asks why something is the way it is. History answers it.

```bash
git log -L 88,142:src/billing/invoice.ts --format='%h %ad %an %s' --date=short | head -40
git log --format='%h %ad %s' --date=short --follow -- src/billing/invoice.ts | head -20
```

A commit message explaining the odd edge is a rebuttal you must engage with. **"The rationale existed and no longer applies" is a much stronger finding than "no rationale evident"** — and the two must be reported differently.

---

## Ledger form

```
[git] git log --since=180.days --format=%h --name-only -- src/billing
      → 41 commits touch src/billing; 27 of those also touch src/users
[git] git show --stat a3f9c21  ("add Adyen provider")
      → 9 files, 4 modules; 7 of the 9 contain no payment logic
```

Always include the command and the actual number. A paraphrase is `[infer]`, not `[git]` (`rules.md` §2.1).
