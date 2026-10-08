---
name: process-todo-file
description: Close out a TODO file whose sections are all shipped -- run its Verification block, sweep for loose ends, reconcile deferrals and the frozen contract, update the indexes, and set its status to done. Use when every Implementation Order row of a file is [x], when process-phase closes a phase, or when asked to close a whole TODO file.
---

# Process TODO File

The last pass over a finished TODO file. It catches what section-by-section work cannot see: the loose ends between sections, the deferrals nobody picked up, and the gap between "every row is `[x]`" and "this works end to end".

Do not use it to force a file closed. If sections remain open, they get implemented or explicitly deferred with owners, not swept.

## 1. Confirm the file is exhausted

```bash
python scripts/todo-graph.py validate
```

Every row `[x]`, every `[x]` covered by a `Verified:` stamp, zero FATAL.

## 2. Run the file's Verification block

Run every item in `## Verification` and record the real output. For a code file that means the full suite, not the filtered runs the sections used:

```powershell
pwsh scripts/check-all.ps1
```

plus every scenario the block names (`pwsh scripts/drive.ps1 -Scenario <name>`, the UI driver from `D00 T03 §4`) and any other item, each executed, none trimmed.

## 3. Loose-end sweep

- **Stubs.** Grep the touched paths for `TODO`, `FIXME`, and not-implemented markers added during the work. Each is finished now or gets an owning section and an XREF.
- **Partial items.** An item ticked when only part shipped is split.
- **Orphaned deferrals.** Every `Deferred:` line names a live, open owner.
- **Integration.** Is each feature reachable where a user would look for it, wired end to end, with every write read back by its consumer?

## 4. Reconcile the frozen contract

If the file is `frozen: true`: every `**Freeze check:**` ran and passed, with the result in a stamp; no frozen behaviour moved without the operator's recorded approval; golden fixtures are committed.

## 5. Update status and indexes

Set `status: done` in the frontmatter; move the file's row in the domain `INDEX.md` to Completed with the date; update `todo/TODO-00-INDEX.md` Active TODOs.

## 6. Commit and report

```
<area>: complete TODO-NN -- <what now works>

<full-suite evidence>
<deferrals carried forward, with their owners>
```

Then `python scripts/todo-graph.py plan --sync` and `validate`. Report what now works in the user's terms, what was deferred and to whom, and anything the sweep filed.

## Guardrails

- Do not close a file with open sections or with deferrals that point nowhere.
- Do not claim the Verification block passed without running it: quote the output.
- Do not delete section detail on closure: the shipped file is the record of how it was built.
- Do not set `status: done` on a frozen file whose freeze checks did not run.

Codex owns this independent skill. Use `git -c core.hooksPath=.codex/githooks commit` for commits; inspect every dirty file first and preserve safe user side edits.
