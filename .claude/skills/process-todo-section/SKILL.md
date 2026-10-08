---
name: process-todo-section
description: Process exactly one TODO section end to end -- resolve it, fact-check the plan against the repository, correct drifted claims, build it, run its gates and checkpoint, and commit. Use whenever asked to process, implement, ship, continue, or finish a TODO section or a plan row.
---

# Process TODO Section

One section. One commit. The section is the contract, and a contract is checked before it is signed: a section written weeks ago against code that has since moved is a plan with a bug in it. Do not improvise around the plan, and do not implement a plan you have found to be wrong: correct it in the file, visibly, then build the corrected version.

## Step 0: resolve the argument

Run `python scripts/writer.py assert claude` before implementation. If another writer is selected, stop implementation without changing the setting; independent review is still permitted.

Never hand-translate a reference into a file name:

```bash
python scripts/todo-graph.py resolve "$ARGUMENTS"
```

It accepts a `DNN TNN §N` ref or a row pasted from `todo/implementation-plan.md`.

| Exit | Meaning | Do this |
| :-: | ------- | ------- |
| 0 | open, dependencies met | continue |
| 2 | not found | report the input and stop |
| 3 | already shipped | stop; auditing shipped work is `review-todo-section` |
| 4 | a dependency is unmet | report the unmet ref and stop, or process that one first if asked to run the plan |
| 5 | operator-only (`todo/99-manual/`) | never build it as an agent; report it as the operator's step and stop |

## Step 1: read

The section, its file's Goal, Current state, and Inputs, every dependency's stamp, `CLAUDE.md`, and the standards the section touches. For engineering steps, the matching skill: `add-feature`, `add-migration`, `win32-ui-patterns`, `fix-bug`.

## Step 2: fact-check the plan

For every path, function, and claim the section names, check the repository. A file that moved, a function that already exists, a dependency that shipped differently: fix the section text in the same commit, and note what you corrected in the commit body. Rewording an item a `Deferred:` line quotes is not allowed; add a new item instead.

## Step 3: build

Work the items in order. Tick each `[x]` when its `Done when:` holds, not before. Write the code to `standards/cpp.md` and `standards/ui.md`. Keep the app layer thin.

## Step 4: gates

```powershell
pwsh scripts/check-all.ps1
```

Then run the section's **Test checkpoint exactly as written** and keep the output. A checkpoint that cannot fail is a defect in the section: fix the checkpoint before claiming it.

## Step 5: hand to review, then commit

Run this agent's `review-todo-section`: independent Codex CLI review using global model/effort first, then a quick fresh Sonnet review using the latest alias at high effort. Both must approve the same candidate before the independent Codex reviewer stamps it and flips the row. Then:

```bash
python scripts/todo-graph.py plan --sync
python scripts/todo-graph.py validate
```

and commit once, with the section's `Commit:` message and the ref: `<area>: <summary> (DNN TNN §N)`.

## Guardrails

- Do not tick an item whose `Done when:` you have not observed.
- Do not stamp your own work without the review step.
- Anything genuinely unshippable now is filed through `add-todo` with an owner, and recorded as a `Deferred:` line naming that owner.
