# Tooling - Module Inventory, Duplication, Complexity

Covers Phase 1 measurements 1, 4, and 5. Same rules as the other tooling files: run ephemerally, never install into the reviewed project, raw output to `.architecture-review/evidence/`, `[proxy]` fallbacks carry ceiling C2 (`rules.md` §3).

---

## 1. Module inventory & size distribution

Establishes the Phase 0 tier and the Blast Radius denominator. Always exclude generated, vendored, and build paths - `git ls-files` does this for free where `.gitignore` is correct.

```bash
# LOC per top-level source directory
git ls-files 'src/*' | xargs wc -l 2>/dev/null | sort -rn | head -30
git ls-files | grep -E '\.(ts|tsx|js|py|go|rs|java|kt|rb|cs)$' \
  | cut -d/ -f1-2 | sort | uniq -c | sort -rn

# file count and total source LOC
git ls-files | grep -E '\.(ts|tsx|py|go|rs)$' | wc -l
git ls-files | grep -E '\.(ts|tsx|py|go|rs)$' | xargs cat | wc -l
```

If **`scc`** or **`cloc`** is available, prefer them - they classify comments and blanks properly and cost one command:

```bash
scc --by-file --sort lines src/ > .architecture-review/evidence/loc.txt
cloc --by-file --quiet src/
```

**Size is context, never a finding on its own** (`rules.md` §7.1). Use the distribution to set the tier and to spot outliers worth *investigating* for cohesion. A large file becomes a finding only when Phase 2 §5 shows separate co-change clusters inside it.

---

## 2. Duplication

```bash
npx -y jscpd src/ --min-lines 8 --min-tokens 60 --reporters json,console \
  --output .architecture-review/evidence/jscpd
```

Language-specific alternatives: `pmd cpd --minimum-tokens 60 --dir src` (JVM/multi-language), `simian`, `dupl` (Go), `pylint --disable=all --enable=duplicate-code` (Python).

Tuning matters more than the tool. Defaults are too aggressive and will bury you in framework boilerplate:

- `--min-lines 8` or higher - shorter matches are almost always noise
- `--min-tokens 60` - filters out identical import blocks and getters
- Exclude tests, generated code, migrations, fixtures, and vendored paths explicitly

**The tool output is input to triage, not a finding.** Phase 3 §4 decides which clones share a *reason to change*. Expect to discard most of the report - that is normal and correct.

### Fallback

```bash
# repeated long lines, a crude but real signal
git ls-files '*.ts' | xargs cat | grep -vE '^\s*(//|import|export|\}|\{|$)' \
  | sed 's/^\s*//' | awk 'length > 60' | sort | uniq -c | sort -rn | head -30

# a specific suspected duplicate: find its siblings
grep -rn --include='*.ts' -F 'const TAX_RATES = {' src/
```

The second form is more valuable than the first. When you *suspect* a rule is duplicated, grep its distinctive literal - a constant, an error string, a magic number, a regex. This catches **different-shape/same-reason** duplication (Phase 3 §4), which no clone detector finds and which matters most.

---

## 3. Complexity & hotspots

Complexity is a *pointer*, not a finding. High complexity in cold, contained code is not this skill's concern; high complexity in a Hot, high-fan-in file is where to look first.

| Stack | Tool |
|---|---|
| JS/TS | `npx -y eslint --no-eslintrc --rule '{"complexity":["warn",10]}' src/` |
| Python | `uvx radon cc -s -a src/`, `uvx xenon --max-absolute B src/` |
| Go | `go run github.com/fzipp/gocyclo/cmd/gocyclo@latest -top 20 .` |
| Java/Kotlin | PMD, Checkstyle `CyclomaticComplexity` |
| Rust | `cargo clippy -- -W clippy::cognitive_complexity` |
| Multi | `scc --by-file` reports a complexity estimate alongside LOC - often enough |

### The hotspot join - the one to actually run

Complexity × churn. Cross-reference the complexity output against `evidence/churn.txt` from `git-history.md`:

**Complex + Hot** is where design problems cost real money. **Complex + Cold** is usually fine and should not be reported - nobody is paying for it. This join is the cheapest prioritization signal available and it takes one pass over two files you already have.

### Fallback

Function length and nesting depth by eye, on the files the hotspot join already flagged. Tag `[read]`, not `[proxy]` - you read it, you didn't measure it. Do not report a complexity *number* you did not compute (`rules.md` §8.1); describe the structure instead: "six levels of nesting across four branches on a discriminator that also appears in three other files."

---

## 4. Reachability sweep (dead code)

Run this **before** recording the other numbers - it corrects the corpus they are computed over (`phase-1-evidence.md`, measurement hygiene). It is not a hunt for findings.

| Stack | Tool |
|---|---|
| JS/TS | `npx -y knip` (best), `npx -y ts-prune`, `npx -y madge --orphans --extensions ts,tsx src/` |
| JS/TS deps | `npx -y depcheck` - unused and undeclared dependencies |
| Python | `uvx vulture src/ --min-confidence 80`, `uvx deptry .` |
| Go | `go run honnef.co/go/tools/cmd/staticcheck@latest -checks U1000 ./...`, `go mod tidy -diff` |
| Rust | `cargo +nightly udeps`, plus `dead_code` warnings from a normal build |
| Java/Kotlin | `mvn dependency:analyze`, `gradle dependencies --configuration ...` |
| Any | `git log --diff-filter=A --format=%ad --date=short -- <file> \| tail -1` - when was it added, and has it been touched since? |

### Fallback

```bash
# files never imported anywhere (TS/JS) - corpus stated, full result recorded
git ls-files 'src/**/*.ts' | while read -r f; do
  base=$(basename "$f" .ts)
  hits=$(rg -l --glob '!'"$f" -F "/$base" src/ | wc -l)
  [ "$hits" -eq 0 ] && echo "$f"
done > .architecture-review/evidence/unreferenced.txt
```

### Unused assets - images, fonts, media (dead *files*, not dead code)

The code tools above track the import graph; **assets are not imported, so none of them see a stranded file.** Yet a vibecoded repo accumulates them fast - an old logo, a PNG replaced by a WebP, a hero image from a scrapped section - and clearing them is exactly the cleanup an owner of a codebase in disarray wants. Assets are referenced by *basename* from HTML `<img>/<link>`, CSS `url()`, JS/JSON string paths, and manifests, so census them that way:

```bash
# Corpus diff, TWO passes - not one grep per asset. A per-file loop is O(assets)
# git-greps and times out on a media-heavy repo (200+ files); build the reference
# set once, then diff. (git grep needs no rg; confirm it RAN - see empty≠clean below.)
git grep -hoE "[A-Za-z0-9_.-]+\.(png|jpe?g|webp|gif|svg|woff2?|mp4)" \
  -- '*.html' '*.css' '*.js' '*.ts' '*.jsx' '*.tsx' '*.json' '*.md' '*.svg' \
  | sed 's|.*/||' | sort -u > .architecture-review/evidence/asset-refs.txt
git ls-files -- '*.png' '*.jpg' '*.jpeg' '*.webp' '*.gif' '*.svg' '*.woff*' '*.mp4' \
  | sed 's|.*/||' | sort -u \
  | comm -23 - .architecture-review/evidence/asset-refs.txt \
  > .architecture-review/evidence/unreferenced-assets.txt
```

Comparing by **basename** (not full path) is deliberate: if any file of that name is referenced, none of them is flagged - the census errs toward *not* calling a live file dead, which is the safe direction.

**The dynamic-reference caveat is not optional - it is the whole story for assets.** A basename that appears nowhere as a literal is *not* dead if it is loaded dynamically:
- **Bundler globs** - `import.meta.glob('./**/images/*')`, webpack `require.context`, Vite `?url` imports. The single highest source of false positives; a glob pulls in a whole directory by pattern, and no individual filename appears anywhere.
- **String-built paths** - `` `/assets/ew/${id}/${slug}-front.webp` ``, `src={\`/img/\${name}.png\`}`. The basename is assembled at runtime.
- **CSS custom-property / attribute URLs**, `srcset`, `<picture>` sources.
- **Build-hashed output** - `cover-DYn_ZCKDOJ.jpg`, `index-a1b2c3.js`. If a repo commits its `dist/`, these are generated files whose references live in *other* generated files under the same content hash. Treat committed build output as generated (`rules.md` §7.10 - excluded), not as dead assets; the `[A-Za-z0-9]{6,}` hash suffix and a `dist/`/`build/` path are the tells. Cross-check the git add-date: a hashed name added once and never touched is build output, not a hand-placed asset.

So the same coverage discipline applies as for the data-flow census: if a directory is glob-loaded or paths are string-built, that whole tree is **coverage-`partial`** - do not call its files dead. State the coverage. The honest output for the format-replacement case *is* reliable, though: if `hero.png`'s basename is referenced nowhere and `hero.webp` is referenced instead, and neither sits under a glob, the `.png` is a defensible cleanup candidate.

Feed this into the **same bounded inventory** as dead code (below) - a count, total bytes reclaimable, the largest items, and the false-positive risk. Never one finding per image.

### Confirm before believing any of it

**The list of what defeats static reachability lives in `rules.md` §7 "Dead code - inventory, not findings".** Apply it there; it is not restated here - and it now covers unused *assets* as well as unused code: both are inventory, both are defeated by dynamic reference, both need the coverage caveat above.

**A search that returned nothing must be confirmed to have run** before you read it as "nothing is unreferenced" - a missing `rg`/`git grep` or a bad path yields the same empty file as a clean repo, and trusting it marks live files as dead. Positive-control your search (grep a token you know exists) before believing an empty result.

One tooling-specific check to add: cross-reference every candidate against the implicit-coupling census from `phase-2-structure.md` §6. A file that looks orphaned to a static tool may be registered by a string key, which is exactly what that census enumerates.

Write `evidence/reachability.md` with: what looked dead, what survived the dynamic check, what was excluded from the metrics, and **the false-positive risk of the method used**. Then record the corrected numbers, noting both where the difference is material.

Per `rules.md` §7, this produces a bounded **inventory section** in the report - a count, the largest items, and the method's reliability. Never one entry per unused symbol.

---

## 5. What not to measure

Skip these - they generate noise without evidence and several are on the do-not-report list (`rules.md` §7):

- Comment density and docstring coverage - item 2
- Naming-convention conformance - item 7
- Raw line counts as a quality signal - item 1
- Maintainability indices, "code health" scores, technical-debt-in-hours estimates - these are fabricated aggregates (`rules.md` §8.6) regardless of which tool emits them. If a tool prints one, do not carry it into the report.
- Test coverage percentage as a design metric - coverage is useful in Phase 3 §6 only to locate *what is hard to test*, never as a quality score.

---

## Ledger form

```
[tool]  npx -y jscpd src/ --min-lines 8 --min-tokens 60
        Found 12 clones, 340 duplicated lines (4.2% of 8,100)
        Largest: src/api/orders.ts:44-98 ↔ src/api/invoices.ts:51-105 (54 lines)

[proxy] git ls-files '*.ts' | xargs cat | awk 'length > 60' | sort | uniq -c
        → `validateTaxRegion(` appears identically at 4 sites
        (substitute for jscpd; unavailable offline. Line-level only:
         misses reformatted or renamed clones, over-counts boilerplate.) → C2
```
