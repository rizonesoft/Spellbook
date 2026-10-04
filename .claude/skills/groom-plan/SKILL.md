---
name: groom-plan
description: Harden the todo tree for an unattended run -- sequence check, drift sweep, gap scan, complete-feature pass, and the operator-only check -- without moving rows between phases, ticking boxes, or starting a run. Use before a long process-plan run, or when the plan feels stale.
---

# Groom Plan

Hardening the tree so an unattended executor can run it. Grooming adds prerequisites and fills gaps; it never moves a row out of its phase, never ticks a box, and never starts a run.

## 1. Sequence check

For every dependency edge, confirm the prerequisite sits no later than its consumer in phase and row order (`validate` reports `plan-order` when it does not). Where an edge points later, add or split a prerequisite section under the consumer's phase with a dated note; never move the consumer's row. Record each fix with `**Groomed YYYY-MM-DD:**`. Run `python scripts/todo-graph.py validate` after every structural edit.

## 2. Drift sweep

Walk every open section's concrete claims against today's repository: files, functions, paths, counts, versions, tool pins, and protocol shapes. Correct drift in place with dated notes, as `process-todo-section` step 2 does, but tree-wide and without building anything. Fan the claim checks out to parallel read-only subagents, one per TODO file with no overlap; each returns claims with `path:line` evidence, and the lead decides and writes every correction. Watch "nothing exists yet" claims that are no longer true, versions and counts quoted confidently, deferrals whose owners drifted, and XREFs whose targets moved.

## 3. Operator-only check

No section outside `todo/99-manual/` may need a person: a checkpoint that needs a clean machine, another display scale, Narrator, an account, a secret, money, or someone's judgement by eye is rewritten to an agent-provable form (the UI driver `scripts/drive.ps1` that `D00 T03 §4` builds), and the human remainder moves to an operator section with an XREF. Every operator section states exactly what the operator does and how its result is recorded.

## 4. Gap scan

Read the plan as the user will use the finished product, domain by domain, and ask what has no owner: surfaces, controls, handoffs, error paths, settings without consumers, writes without read-back. File each gap with `add-todo`, place the row in its phase, and sync the plan.

## 5. Complete-feature pass

For every surface, confirm the feature is whole: list, find, create, edit, delete (or the honest not-applicable), undo where it destroys, settings with consumers, and the reverse of every create. For every protocol (OpenRouter, ACP, the update check), confirm both directions, cancellation, timeouts, and failure handling. File what is missing; do not redesign what exists.

## 6. Report and commit

Write the groom record (what was sequenced, what drifted and was corrected, what moved to operator sections, what gaps were filed and where), then `python scripts/todo-graph.py validate`, `plan --sync`, and `plan --check`, and commit as `todo: groom <scope> (<date>)`.

## Guardrails

- Do not move a row out of its phase. Add or split prerequisites instead.
- Do not tick a box. Grooming never ships.
- Do not start a run. Grooming prepares one.
- Do not redesign sections. Harden them.
- Do not leave the tree unvalidated.
