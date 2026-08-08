# Domain — CLI, TUI & Local Tool

**Primary failure mode: the decide/emit boundary.** In a program whose whole purpose is to read input and print output, logic and I/O grow into each other — and because there is no network, no database and no framework forcing a seam, nothing ever pushes them apart.

Everything else on this page is a symptom of that one thing. Business rules that `println!` mean the rules can only be tested by capturing stdout. A second output mode (`--json`, a TUI, a quiet flag) then has to reimplement every decision the first one made. And the exit-code and error contract — the actual public API of a CLI — ends up asserted in thirty places instead of one.

Applies to: command-line tools, TUIs, REPLs, local desktop utilities, and their frequent cousins — **game loops** and **interpreter/DSL hosts** (§5, §6).

---

## 1. Where the decisions live

Trace one real command end to end: parse → decide → emit. Write down which file each step happens in.

- **Logic that prints.** A function that both computes and writes to stdout can only be tested by capturing output. Count them, then check the tests: if assertions are string-matching on captured stdout to verify *business* behaviour, the seam is missing and the tests are telling you where.
- **Exit codes decided far from the logic that knows.** A CLI's exit code is part of its contract — scripts branch on it. `exit(1)` scattered across a dozen call sites is a contract asserted in a dozen places. Grep for exits and count the distinct codes; if the meaning of `2` is not written down anywhere, nothing enforces it.
- **The output-mode split.** Once `--json`/`--quiet`/`--verbose` exists, ask whether it branches at the *edge* (one formatter, chosen once) or is threaded through the logic as a flag. The second is `cross-cutting-placement`, and adding a third mode is the cost.
- **Global config as ambient state.** Verbosity, colour, width, dry-run held in globals or singletons. Idiomatic and usually right for a single-threaded binary — **do not file it on principle** (`rules.md` §7.3). File it when you can show a cost, and the usual demonstrable cost is the test suite: parallel test runners share the process, so per-test setup gets duplicated and state leaks between tests. Look for a manual save/restore in the tests — a comment like *"restore the default for other tests"* is the codebase telling you, and it is Gate 2(b) evidence sitting in the repo.

## 2. Two front-ends over one core

The moment a tool grows a second interface — a TUI beside the REPL, `--json` beside human output, a library API beside the binary — the question becomes: **do both front-ends make the same decisions, or do they share them?**

Walk the two paths side by side and list the decisions each makes, in order. If the sequences match and differ only in how output is emitted, that is `missing-abstraction`, and the bar for N=2 parallel implementations is in `phase-3-abstraction.md` §1 — read it, because the naïve three-occurrence rule does not apply and the fix has a specific shape:

- **Extract the decision. Leave the rendering.** The reason two front-ends exist is real. A recommendation that collapses the rendering too is an overengineering finding wearing a fix.
- **Check whether the seam already exists.** These codebases usually already have a shared state struct that the front-ends both hold. If it does, the decision belongs *on it*, and the fix is filling in an established pattern rather than introducing one — which makes Gate 3 easy.
- **Look for the untested front-end.** The less-used path (`--classic`, `--no-tui`) is where silent divergence lands. Check coverage for both.

## 3. The argument surface

- **Flags parsed in more than one place**, or a flag whose meaning is re-derived at the point of use. Grep the flag string; it should appear once outside its own definition.
- **Mutually exclusive flags with no single place that says so.** The validation is either in one function or scattered through the code that consumes them.
- **Subcommands that share everything by copy.** Each subcommand re-reading config, re-opening the same file, re-implementing the same lookup. Count the repeats before recommending anything — a small tool with three subcommands does not need a command framework (`rules.md` §7.5).
- **Env vars as an undeclared second config channel.** Census them. Where a setting can arrive from a flag *and* an env var *and* a config file, one place should resolve the precedence; if three do, they will disagree.

## 4. What the filesystem is to a local tool

There is no database, so the filesystem *is* the persistence layer and it deserves the same census the schema gets elsewhere (`phase-2-structure.md` §6):

- Enumerate every path the tool reads and writes — dotfiles in `$HOME`, caches, lockfiles, temp dirs. For each: who writes it, who reads it, what happens when it is absent or malformed.
- **A file written by one module and read by another with no import edge between them is coupling the graph cannot see.** It is the local-tool version of a shared table.
- **Format compatibility is a contract.** A hand-rolled save/cache format read by a future version of the tool is an unversioned published contract — `contract-stability`. Check for a version field and for a test that reads an old file.
- Silent-failure writes (`let _ = write(...)`, `except: pass`) are robustness, **not architecture** — one line in the report, do not investigate (`rules.md` §1).

## 5. Game loops and other stateful loops

A game loop, a watch mode, a daemon's tick — same shape: state advances one step per input, and something decides what happens next.

- **Where does "what happens next" live?** If the answer differs per front-end, see §2. If it is inline in the input handler, the loop cannot be tested without driving I/O.
- **Determinism is a testability property, and a big one.** A seeded PRNG and pure state transitions mean the whole program is testable headlessly with no mocking. Where you find that, **say so as a strength** — it is a real architectural achievement and reviews systematically fail to credit it. Where the loop is *nearly* deterministic, the specific impurity (a syscall, a clock read, an unseeded random) is the finding, because it is what forces the mocking.
- **Content indexed by position.** Levels, steps, objectives, or scenes addressed by their index in an array, while the code's own comments name them semantically. Adding or reordering an entry silently re-points everything downstream, and the compiler cannot see it because the indices stay valid. Check what guards it: id-existence checks and bounds checks do **not** guard identity. This is `coupling`, and the cheap fix is a pinning test, not a redesign.

## 6. Interpreter and DSL hosts

A tool that parses its own little language — a config DSL, a rules file, embedded content — has a second, softer boundary: **what the DSL can express vs. what the host hardcodes.**

- **Does branching live in the content or in the host?** If the project claims the former, verify it: census the conditions in the content files and the branches in the host. A host that grew a `match` per content variant has an abstraction leak.
- **String keys are an unchecked contract.** Flags, variables, event names, rule ids — the compiler checks none of it. This is exactly the writer/reader ledger (`tooling/data-flow.md` §7) and it is where the real defects are: a key written and never read is a feature that silently does nothing.
- **Check the guard's channel coverage, not just its existence.** A project sophisticated enough to test its own DSL invariants usually guards *one* kind of key and not the others — the check enumerates one variant and drops the rest into a catch-all arm. Read the guard, list the channels it actually inspects, and compare against the channels the DSL actually has. A guard that covers one of three is the finding, and the escaped key is its proof.
- **Parse errors as a contract.** If content authors are the users, an error with no line number is a usability defect in the tool's primary interface.

---

## Reviewing this shape well

**Run the tool, then read one command end to end.** These programs are small enough to understand completely, which is rare — take the opportunity. The decide/emit boundary is visible in a single trace.

**Read the test suite before the source.** In a tool with no framework and no network, the tests are the most honest map of the seams: what they can call directly is what has an interface, what they drive through captured stdout does not, and what is untested is usually what is hardest to reach.

**Grade the ceremony budget hard.** These projects are almost always T1–T2. A CLI does not need ports and adapters, a command bus, or a plugin system, and the single most common way to fail this domain is to recommend the architecture of a service for a program that reads a file and prints a line. If your recommendation would not fit in one commit, re-read Gate 3.
