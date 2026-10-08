---
name: process-phase
description: Take one phase of todo/implementation-plan.md to 100 percent -- open a run file, repair the phase, gap-audit it, then ship section after section through process-todo-section and review-todo-section, committing and pushing each, and park only when every leftover row is blocked or operator-only. Use when the operator says process, run, or finish a phase, or when process-plan starts one.
---

# Process Phase

One phase, start to 100 percent, or parked when the rest of it is blocked or operator-only. You do not stop in between.

**Exactly three endings.** Zero open rows and a written closeout. Every leftover row blocked or operator-only, so the phase is parked and `process-plan` moves on. Or the operator's own stop. A parked phase is neither complete nor a stall.

The whole plan is `process-plan`; this skill is one phase. Entered through `process-plan`, return to it after closeout or park; pinned to one phase, end here.

**Completion never buys a bypass.** `--no-verify`, amending a pushed commit, force-pushing, and tagging are forbidden to a run (ADR 0003). A red gate is work: diagnose and fix the cause. A failed push is a red gate.

**Interruptible, not stoppable.** When the operator writes mid-run, answer briefly and continue in the same turn. If the operator says stop or pause, obey at once: delete the run guard first (guard file, state file, heartbeat job), confirm, and wait. Resume recreates the guard before any other step.

## Step 0: open the run

Run `python scripts/writer.py assert claude` before implementation and before each section. Register or repoint the guard only through the Claude-only helper specified by `process-plan`; the neutral selector never owns Claude's runtime state.

Check that no other writer holds the tree (`git status`; ask about uncommitted work you did not make). Open `docs/phase-runs/<YYYY-MM-DD>-phase-<N>.md` and append every finding the moment it is made:

```markdown
# Phase run: Phase <N> -- <title>

## Phase repairs              (step 1: what was wrong with the plan, what was corrected, where)
## Shipped-row verification   (step 1b: each spine row: stamp ok, checkpoint re-run result)
## Gap audit                  (step 2: gaps found, where each was filed; the park record lands here)
## Sections                   (step 3: one entry per section: ref, commit, push, review verdict, corrections)
## Critical events            (every stop, pause, resume, session death, guard write)
## Lessons                    (what was learned this run)
```

Read the latest earlier run file for this phase, if one exists: anything unresolved there is this run's first input. If this session entered through `process-plan`, the plan owns the guard: verify it (`CronList` and `build/claude-campaign-guard.json` naming this session and this run file) and record the check. If pinned standalone, start the guard exactly as `process-plan` specifies.

## Step 1: repair the phase before running it

1. `python scripts/todo-graph.py validate`: fix every FATAL now.
2. `python scripts/todo-graph.py plan --check`: if stale, `plan --sync`.
3. For every open row in the phase, `python scripts/todo-graph.py resolve '<ref>'` and record the exit code. Exit 4 with an unmet dependency outside this phase is a leftover. Exit 5 is operator-only: a leftover, never shipped by you. Exit 2 means a broken reference: repair it against the TODO file (repairable work blocks a park).
4. Read each open section's TODO file for phase-level staleness only: work already shipped elsewhere, sections made moot by a later decision, callouts whose blocker is gone. Correct them with dated `**Corrected YYYY-MM-DD:**` notes.

### Step 1b: shipped rows are verified, not trusted

For each `[x]` row an open row in this phase depends on: confirm its `Verified:` stamp (`resolve` exits 3), and re-run its Test checkpoint when it names a command. A checkpoint that no longer passes is a regression: fix it forward as this phase's work and re-review it with `review-todo-section` in audit stance.

## Step 2: gap-audit the phase

Read the phase as the user will use it and ask what is missing: surfaces with no owner, controls with no section, handoffs nobody specified, a write with no read-back. File each gap with `add-todo`, place its row in the phase, and sync the plan, in the same turn.

## Step 3: ship the phase, one row at a time

In table order, for each open row whose `resolve` exits 0:

1. Before starting, read the previous push's CI result: `pwsh scripts/gh.ps1 run list --branch main --limit 1` (the wrapper finds the GitHub CLI when it is not on PATH). A failed run is this run's work first; one still running is checked again before the next section.
2. `process-todo-section` on the row, then this agent's `review-todo-section`: a fresh Codex CLI review with global model/effort followed by a quick fresh Sonnet review at high effort. After both approve the same candidate, the independent Codex reviewer stamps it and flips the row. Fix any findings and repeat both stages on the changed candidate.
3. `python scripts/todo-graph.py plan --sync` and `validate`, then commit once with the section's `Commit:` message and its ref (this is `process-todo-section` step 5, not a second commit).
4. `git push origin main`. A rejected push is a red gate: fetch, rebase only your unpushed commits if the remote moved, re-run the gates, push again. Never force.
5. Record the ref, the commit, the push, and the verdict in the Sections log.

Skip rows whose `resolve` is not 0 and re-check them after each stamp: the graph moves as rows flip. When every remaining open row exits 4 or 5, park: write a column-0 `PARKED <UTC stamp> <one-line reason>` line in the run file, then the park record (each leftover, what blocks it, and for operator-only rows the exact step the operator must take), commit and push the run file, and return to `process-plan` (or, pinned standalone, delete the guard and end).

## Step 4: closeout

When the phase table is all `[x]`: run `pwsh scripts/check-all.ps1` once more, run `process-todo-file` on every TODO file whose rows are now all `[x]`, confirm the plan shows the phase complete, and write the closeout under a `## Closeout` heading in the run file (what shipped, what was repaired, what was learned). Commit and push. Pinned standalone, delete the guard file, the state file, and the heartbeat job; chained, `process-plan` re-points them. A phase is complete when its table says so and the closeout is written.

## Guardrails

- Do not ship a row outside `process-todo-section` plus `review-todo-section`.
- Do not start a section in `todo/99-manual/`.
- Do not tick `implementation-plan.md` by hand.
- Do not claim a phase complete while its table has `[ ]` rows, and do not call a parked phase complete or a stall.
- Do not end the turn on the audit: ship, park, or close out.
- Do not leave a run guarded after it ends, and do not pause with the guard live.
