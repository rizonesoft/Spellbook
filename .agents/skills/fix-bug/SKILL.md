---
name: fix-bug
description: Runbook for fixing a defect -- reproduce, write the failing test first, fix in the right layer, prove it, and record it in the plan and changelog. Use for any bug report, failing behavior, or regression.
---

# Fix a Bug

## 1. Reproduce

- Get the exact steps, the version (`Help > About`, or the commit), and the log lines (`%LOCALAPPDATA%\Spellbook\logs\spellbook.log`; the reporter's, or reproduce with `pwsh scripts/run.ps1 -DataDir build/bug-<n>`).
- Reproduce it on the current `main`. If you cannot, say what you tried and ask for what is missing; do not guess a fix.

## 2. Find the layer

- Wrong data, wrong rule, wrong text conversion: core.
- Wrong query, lost write, migration problem: storage.
- Wrong layout, wrong focus, a message not handled: app. If the app is doing logic, the fix moves that logic into core.

## 3. Write the failing test first

- A Catch2 case named after the behavior that should hold (`"import keeps a file whose name has an emoji"`), in the layer's test file.
- Run it and see it fail for the reported reason: `pwsh scripts/test.ps1 -Filter "<case>"`. Quote the failure.
- UI-only bugs with no testable seam: write the driven reproduction steps into the section instead, and add the seam if the fix creates one.

## 4. Fix

- The smallest change that makes the test pass without weakening another one.
- Never change a shipped migration; a data repair is a new migration (`add-migration`).

## 5. Prove it

- The new test passes; `pwsh scripts/check-all.ps1` is green.
- Re-run the original reproduction and quote the result.

## 6. Record it

- In the plan: if the bug is in a shipped section, add a new section to that TODO file (never rewrite a stamped checklist), titled for the defect, with the test as its checkpoint; stamp it. If the bug is in open work, fix it inside that section.
- `CHANGELOG.md` under `## [Unreleased]`, "Fixed": what the user saw, in their words.
- Commit: `<area>: fix <what> (DNN TNN §N)`, body naming the cause.

Codex owns this independent skill. Use `git -c core.hooksPath=.codex/githooks commit` for commits; inspect every dirty file first and preserve safe user side edits.
