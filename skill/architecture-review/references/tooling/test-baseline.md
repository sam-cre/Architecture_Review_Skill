# Test and Build Baseline

_Used by `refactor` mode only (`references/refactor-protocol.md` §1 step 4). Hold this file and the plan. Output: the baseline section of the refactor plan._

A refactor is only proven behavior-preserving if the project's own build and tests pass before and after. This file finds the commands. It does not invent them.

## 1. Find the commands, in this order

Take the first source that gives a runnable command, and record which source it came from.

| # | Source | Where to look |
|---|---|---|
| 1 | The user said so | Their message. Always wins. |
| 2 | CI | `.github/workflows/*.yml`, `.gitlab-ci.yml`, `azure-pipelines.yml`. The commands CI runs are what the project asserts. Prefer them. |
| 3 | Package scripts | `package.json` `scripts.test` and `scripts.build`; `Makefile`, `justfile`, `Taskfile.yml` targets named `test`, `build`, `check`. |
| 4 | Language default | `cargo test`, `go test ./...`, `pytest` (only if a pytest config or `tests/` exists), `dotnet test`, `./gradlew test`, `mvn -q test`. |

If two sources disagree, say so and ask. CI passing and the local script failing is information, not a tie to break silently.

## 2. Do not install into the project to get a baseline

Running a test command may need dependencies the project has not installed. Installing them writes into the project (`node_modules`, `.venv`, `target/`). `rules.md` §1 and the refactor protocol's read-only-until-YES rule both apply: ask first, and name the install command. Build output directories that the project already gitignores are acceptable to write to; say so when you run them.

## 3. Record the baseline

For each command, record in the plan file:

- the exact command, and its source from §1
- the exit code
- the pass and fail counts, verbatim from the output
- the wall-clock time

Transcribe at the moment of observation (`rules.md` §9). A baseline you reconstruct later is not a baseline.

## 4. When there is no baseline

- **No command found anywhere:** stop. Say that no build or test command exists, so a refactor cannot be shown to preserve behavior. Offer the two real options: the user names a command, or the user adds a test runner first. Do not write a test runner into the project as part of the refactor.
- **A command exists but is slow:** record the time. A baseline that takes longer than the user is willing to wait is still a baseline; ask before skipping any part of it.
- **Tests are flaky:** run the suite twice before the first change. If the two runs disagree, the baseline is not green. Name the test that flipped and stop.

## 5. Scope

Run the whole suite, not only the tests nearest the finding. A refactor can break a distant consumer, and the nearby tests will not show it. If the whole suite is too slow for an interactive session, say so and ask whether a named subset is acceptable, recording that the baseline covers only that subset.
