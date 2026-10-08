---
name: process-plan
description: Run Spellbook's plan unattended with the Codex-only supervisor, or audit it without starting execution.
---

# Process the Plan with Codex

Codex is the primary writer. This skill owns plan execution, not requests merely to configure or inspect the workflow. Read `AGENTS.md` and `docs/dev/codex.md`. Use independent skills in `.agents/skills/`, hooks in `.codex/`, state in `build/codex/`, and records in `docs/codex-runs/`. Never activate another agent's workflow.

## Enter through the supervisor

For `--audit`, run `pwsh .codex/scripts/run-plan.ps1 -Action audit`, inspect ready/blocked rows, and report without starting a run. A named phase scopes execution to that phase; an unnamed plan request chains phases.

If `SPELLBOOK_CODEX_RUN` is absent, start `pwsh .codex/scripts/run-plan.ps1 -Action start -CodexExe <native-executable>`, with `-Phase N` only for a named phase. Locate the installed native executable as documented; do not guess a model or change permissions. Explicit resume uses `-Action resume`, preserving its session and scope. The launching session monitors the supervisor and never becomes a second writer. Use a pseudoterminal or a hidden process on Windows.

Inside the worker, read `build/codex/campaign.json`. Require `runner` equal to `codex`, `workspace` equal to this checkout, `run_id` equal to `SPELLBOOK_CODEX_RUN`, and `status` equal to `running`. The supervisor captures `session_id` from `thread.started`. Never overwrite it or use `resume --last`. Do not start another supervisor or a scheduler/heartbeat job. The external supervisor provides continuation after CLI exits; native hooks add in-turn continuation where trusted.

## Execute

1. Audit TODO `validate`, `plan --check`, `query ready`, and `query blocked`; verify the toolchain with `pwsh scripts/setup.ps1 -Verify`. Repair agent-repairable failures. Record operator dependencies without doing operator-only work.
2. Inspect every dirty file. Preserve safe user side edits in the next coherent commit; stop for a concrete unsafe/conflicting edit. A dirty tree alone does not prove another writer. Require no other active writer.
3. Read the current record and prior Codex records for unresolved work. Run `process-phase` for the first phase in scope with runnable rows. Follow table order and the actual dependency graph.
4. Finish each section through `process-todo-section` and independent `review-todo-section`; stamp, sync, validate, commit with Codex Git hooks, push `main`, and check CI for the exact pushed commit. A report, commit, or green test is not an end of work.
5. Continue to the next phase in scope. Never enter `todo/99-manual/`, use `--context operator`, tag, force-push, amend a pushed commit, or skip a hook.

Before each action and section, inspect `build/codex/runs/<run_id>/pause.json`. If present, stop immediately. On explicit operator stop/pause call `pwsh .codex/scripts/run-plan.ps1 -Action pause` first, record the event, then end work. A question is steering, not a pause. Recovery requires explicit resume; never remove a pause marker yourself.

## End honestly

When no runnable rows remain in scope, write final `## Closeout` only if all scoped rows are complete. Otherwise write column-zero `PARKED <UTC stamp> <reason>` and list every blocked/operator-only row. Intermediate phase endings use `### Phase N closeout` or `### Phase N parked`, never a campaign terminal marker while another scoped phase can run.

Commit/push the final record using `git -c core.hooksPath=.codex/githooks commit` and verify its CI. The supervisor checks the graph before accepting a terminal marker and retains logs and session identity. Three turns without content progress or three consecutive CLI failures pause the campaign; log-only edits do not reset the counter. Missing prerequisites or unprovable checkpoints are concrete blockers, never reasons to invent a stamp.
