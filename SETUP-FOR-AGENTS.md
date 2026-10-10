# Setup guide for AI agents

You were asked to set up the architecture-review skill and run a review of the current repository. Follow these steps in order. Do the work yourself. Stop for the user only at steps marked **Ask**, and keep messages short: what you found, the exact command, and why.

## Ground rules

- Install only this skill. Do not install any other software, and do not change the target repository's dependencies.
- Install nothing inside the target repository. Setup writes to `~/.claude/skills/` and to a clone folder outside the target.
- Never run `git commit`, `git push`, or change any git setting in the target repository.
- The review is read-only with respect to the target. Its only output is `.architecture-review/` inside the target.
- If anything here does not match what you see, stop and **Ask** instead of improvising.

## 1. Find the target

- The target is your current working folder. **Ask** only if the folder is not a git repository or looks like a home directory.
- Note the operating system. Windows uses PowerShell; macOS and Linux use `sh`.

## 2. Get the skill

Clone it to a folder **outside** the target:

```sh
git clone https://github.com/sam-cre/Architecture_Review_Skill "$HOME/architecture-review-src"
```

If that folder already exists, update it instead of cloning again:

```sh
git -C "$HOME/architecture-review-src" pull --ff-only
```

Note the folder's path. This guide calls it `<src>`.

## 3. Check for an existing install

The skill lives at `~/.claude/skills/architecture-review`. Check whether it already exists:

- Windows: `Test-Path "$HOME\.claude\skills\architecture-review"`
- macOS or Linux: `test -e "$HOME/.claude/skills/architecture-review" && echo exists`

- **Not there:** go to step 4.
- **There, and it is a symbolic link:** the user is developing the skill from a checkout. Do not replace it. Go to step 5 and read the skill from its link target.
- **There, and it is a normal folder:** **Ask** whether to replace it with this version. Only replace it on a clear yes.

## 4. Install

From `<src>`:

- macOS or Linux: `sh install.sh --force`
- Windows: `powershell -ExecutionPolicy Bypass -File install.ps1 -Force`

`--force` and `-Force` skip the installer's own prompt, which an agent cannot answer. Only use them when step 3 says the install is safe to replace. The script copies the skill and checks that the key files are present. If it reports `installation incomplete`, stop and show the user its output.

## 5. Load the skill for this session

Claude Code and the desktop app load newly installed skills only after a restart. So:

- If `/architecture-review` is available in this session, use it.
- If not, do not wait. Read `<src>/skill/architecture-review/SKILL.md` (or the linked folder from step 3) and follow it. Every `references/...` path in it is relative to that `skill/architecture-review/` folder, not to the target. Load `references/rules.md` before any phase.

## 6. Run the review

Run a **standard** review of the target, which is the full design review. Follow the skill's phases in order, one at a time, and write its outputs to `.architecture-review/` in the target:

- `architecture-review.md` (the report)
- `findings.json` (the hand-off for refactor mode)
- `metrics-baseline.json`

The skill decides which tools to run. It must not install tools into the target. If a tool is missing, it uses its documented fallback and says so in the coverage statement.

If the target is very large (over about 300 source files or three or more languages), the skill's `references/parallel-review.md` applies. Say so before you start.

## 7. Report to the user

Finish with a short summary:

- where the report and `findings.json` are;
- the number of findings, and the titles of the *Fix now* group;
- the coverage statement, in one line: what was measured, what was reasoned, what was not reached;
- that the target was not modified, and that `.architecture-review/` may be worth adding to `.gitignore`. Do not edit `.gitignore` unless the user asks;
- the next step: `/architecture-review refactor` applies one finding at a time, and each one waits for the user's approval before any change.

If the user later asks for a refactor, run it only through the skill's refactor mode and its approval gate.
