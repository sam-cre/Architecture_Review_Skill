# Tooling — Dependency Graph

Produces the import graph, the cycle list, and fan-in/fan-out. Feeds `phase-2-structure.md` entirely and the Blast Radius axis in `rules.md` §5.

**Never install into the reviewed project** (`rules.md` §1). Run ephemerally — `npx -y`, `uvx`, `go run`, a global tool, or a temp virtualenv. If the only way to get a tool is adding it to the project's manifest, ask the user; until they say yes, use the fallback below and accept ceiling **C2**.

Raw output to `.architecture-review/evidence/`, summaries into context.

---

## Per stack

| Stack | Tool | Invocation |
|---|---|---|
| JS/TS | **madge** | `npx -y madge --circular --extensions ts,tsx,js,jsx src/` |
| JS/TS (richer) | **dependency-cruiser** | `npx -y dependency-cruiser --no-config --output-type err-long src/` |
| Python | **pydeps** | `uvx pydeps <pkg> --show-deps --no-output --max-bacon 2` |
| Python (cycles) | **import-linter** | needs a contract file — usually skip; use the fallback |
| Go | built-in | `go mod graph`, and `go list -deps ./...` for the internal graph |
| Java/Kotlin | **jdeps** | `jdeps -verbose:class -recursive build/libs/app.jar` |
| Rust | **cargo-modules** | `cargo modules structure --bin <name>` (or `--lib`) · cycles: `cargo modules dependencies --bin <name> --acyclic` |
| C# | **dotnet** | `dotnet list reference`, or Roslyn analyzers |
| PHP | **deptrac** | `npx -y deptrac analyse` (needs config) — usually fallback |
| Ruby | — | no good general tool; use the fallback |

**Pick the target that exists.** `--lib` fails on a binary-only crate; use `--bin <name>` from `Cargo.toml`'s `[[bin]]`. Add `--all-features` or the `#[cfg]`-gated modules vanish from the graph and read as absent.

**`cargo install cargo-modules` tracks the latest rustc.** If it refuses with *"requires rustc X or newer"*, the error names a compatible release — install that (`--version 0.26.0`) rather than skipping the measurement and taking the C2 ceiling. It installs to `~/.cargo/bin`, which is a **global** install, not one into the reviewed project (`rules.md` §1).

Useful madge extras:

```bash
npx -y madge --json --extensions ts,tsx src/ > .architecture-review/evidence/graph.json
npx -y madge --summary --extensions ts,tsx src/
npx -y madge --orphans --extensions ts,tsx src/     # dead modules
```

Fan-in from `graph.json` (who imports X — the Blast Radius basis):

```bash
python3 - <<'EOF' > .architecture-review/evidence/fan-in.txt
import json, collections
g = json.load(open('.architecture-review/evidence/graph.json'))
fan_in = collections.Counter()
for src, deps in g.items():
    for d in deps: fan_in[d] += 1
for f, n in fan_in.most_common(30): print(n, f)
EOF
```

---

## Fallback — when no tool is available

Fully acceptable. Findings become `[proxy]` and are capped at **Medium** by ceiling C2 (`rules.md` §3). Say so in the tool availability table; do not present it as a real graph.

**Fan-in by grep** — count who imports a module:

```bash
# JS/TS
grep -rn --include='*.ts' --include='*.tsx' -E "from ['\"].*config" src/ | wc -l
# Python
grep -rn --include='*.py' -E '^\s*(from|import)\s+.*\bconfig\b' src/ | wc -l
# Rust — see the undercount caveat below; grepping `use` alone is not enough
grep -rn --include='*.rs' -E "use crate::config(::|;)|\bconfig::" src/ | wc -l
# Go
grep -rn --include='*.go' -E '"[^"]*/config"' . | wc -l
```

**Rust undercount caveat — the crate root is a different language.** A `use crate::X` grep misses real usage, and the biggest blind spot is not where you would guess:

- **The crate root (`main.rs` / `lib.rs`) needs its own pattern.** `mod X;` puts `X` in scope *there*, so the root calls `X::func()` with no `use` line at all. Census the root separately for bare `\bX::`. (Measured case: on a Rust TUI, censusing `main.rs` with the non-root pattern reported three modules at **fan-in 0**; all three were live, one called nine times from `main.rs` alone.)
- **`pub use` re-exports** route callers through a *different* path, and `mod.rs` re-exports hide the origin.
- **`use crate::{a, b, c}`** brace-grouped imports — one line, several edges. Match inside the braces or you undercount.
- **Items imported by name** — `use crate::x::Thing;` then bare `Thing` at the call site. The `use` line is still the edge, so this is covered, but do not then also grep for `x::` and expect to find it.

**Outside the root, a bare `X::` does not resolve in edition 2018+** — it needs `use crate::X` first. So `use crate::X` plus `crate::X::` is exhaustive for a modern non-root file, and adding bare `X::` there mostly buys false positives from comments and unrelated identifiers. Edition 2015 is the exception, where bare paths do resolve; check `edition` in `Cargo.toml` before choosing the pattern.

Either way, treat a "fan-in 0" as *unconfirmed* until you have read the module's callers — it is far more often a grep blind spot than a dead module. **Strip comment lines before matching**, or prose about a module becomes an edge to it.

**Fan-out for one file** — read its import block. This is a `[read]` line, and it is exact.

**Cycles by hand** — only worth doing on a suspected pair, not the whole repo:

1. List module A's imports; note any that resolve into module B.
2. List module B's imports; look for anything resolving back into A.
3. Walk it edge by edge, recording `file:line` for each.

`rules.md` §8.3: a cycle you cannot walk edge by edge is not one you can report. A two-edge cycle found this way is `[read]`-backed and can reach High if a `[git]` line supplies the cost — the C2 cap applies to the *proxy* measurement, not to a cycle you traced by reading.

**Layer violations by grep** — cheap and often decisive when the project asserts a pattern:

```bash
# domain importing infrastructure — should return nothing
grep -rn --include='*.ts' -E "from ['\"].*(infra|db|http|prisma|axios)" src/domain/
```

---

## Reading the output

- **Cycles** — every one gets explained or dismissed in Phase 2 §4. Same-module cycles are usually noise; cross-module ones rarely are.
- **Fan-in outliers** — the top few are the blast-radius centers and the `boundary-erosion` candidates. Cross-reference against churn: high fan-in + high churn is the worst combination in the repo.
- **Fan-out outliers** — a file importing thirty things is doing too much, or is a legitimate composition root. Check which before filing.
- **Orphans** — dead modules. Cheap `Note only` findings; verify they aren't loaded dynamically or by a build step before claiming it.
- **Type-only edges** — TypeScript `import type`, Python `TYPE_CHECKING` blocks. These vanish at runtime and are usually *not* real coupling. Check before costing an edge; graph tools routinely over-report them.

---

## Ledger form

```
[tool]  npx -y madge --circular --extensions ts src/
        ✖ Found 1 circular dependency:
        1) auth/session.ts > user/profile.ts > auth/session.ts

[proxy] grep -rn "from '.*config'" src/ | wc -l → 61
        (substitute for madge fan-in; madge unavailable — no network.
         Counts textual imports only: misses dynamic imports and re-exports,
         may double-count multi-import lines.) → ceiling C2
```

A `[proxy]` line must always name the tool it replaces **and** its limitation (`rules.md` §2).
