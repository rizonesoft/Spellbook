---
name: process-plan
description: Front door for todo/implementation-plan.md -- audit the plan, then run process-phase on the first phase with a runnable-now row, and the next after each closeout or park, until nothing runnable now is left. Use when the operator says process the plan, run the plan, or asks how to run it unattended. --audit is audit only; a named phase is one phase and does not chain.
---

# Process the Implementation Plan

The only front door for `todo/implementation-plan.md` when the operator did not name a single phase. The file is a derived projection: processing it is not "pick a row and improvise", and it is not "tick the boxes". This skill does not ship a section and does not write a stamp; it chains `process-phase`, which chains `process-todo-section` and `review-todo-section`. The run is the only writer on the tree.

## The loop

One continuous loop. You do not stop.

1. Finish every checklist item of the open section, in order. A green suite and a commit are the middle of the work, not the end of the turn.
2. When the section's checklist is done, review it in a fresh context (`review-todo-section`), stamp it, sync the plan, commit, and push. Then open the next runnable-now section of the phase in the same turn.
3. When no runnable-now row is left in the phase, close it out or park it, and start the next phase that has a runnable-now row.
4. Stop only when `python scripts/todo-graph.py query ready` ends with `0 runnable now`, or the operator says stop.

A report to the operator is not a stop. The self-correcting parts of the loop stay in it: correct drifted plan claims before building (`process-todo-section` step 2), file every gap through `add-todo`, record lessons in the run file, and fix your own red gates.

## Operator-only work is never started

Every section in `todo/99-manual/` is operator-only (accounts, secrets, approvals, machine-wide installs, judging by eye or ear). `query ready` lists them as runnable elsewhere; `resolve` exits 5 for one. Never start one, never do the operator's part "to unblock" a row, and never pass `--context operator`. A row waiting on operator work is a leftover: ship everything else, then park.

## 0. Route

```bash
git status -sb
python scripts/todo-graph.py validate
python scripts/todo-graph.py query ready
```

| State | Do this |
| ----- | ------- |
| Uncommitted work you did not make | Stop and ask. Two writers on one tree is how a change ships without its interface. |
| Argument is `--audit` | Audit below, then stop. Do not start a run. |
| Argument is a phase (`0`, `Phase 3`) | That is `process-phase` for that phase only. It does not chain. |
| Empty argument, "the plan", "process the plan" | Audit, then start `process-phase` on the first phase with a runnable-now row, in this same turn. After its closeout or park, pick the next. Repeat until `0 runnable now`. |

An audit-only reply is a process defect: starting the phase is the next action, in the same turn.

## 1. Audit the whole plan

```bash
python scripts/todo-graph.py validate
python scripts/todo-graph.py plan --check
python scripts/todo-graph.py query ready
python scripts/todo-graph.py query blocked
pwsh scripts/setup.ps1 -Verify
```

Fix every FATAL first. If `plan --check` is stale, run `plan --sync` and re-check. If `setup.ps1 -Verify` fails on a leg an agent can repair, run `pwsh scripts/setup.ps1`; if it needs the operator (a machine-wide install in `todo/99-manual/`), that row is a leftover. Never tick a box in `implementation-plan.md` by hand.

Record in the run file's findings, not as the turn's last words: the fatal count, the plan currency, the runnable-now and runnable-elsewhere counts with the first ref per phase, the blocked count and its blockers, and the phase being started and why.

If nothing is runnable now, report the runnable-elsewhere rows (the operator's to-do list, in order) and stop. That is the only genuine halt.

## 2. The run guard

A run without a guard dies quietly at the first end of turn. Starting the first phase starts the guard, always, in this order:

1. `CronList`. If a job whose prompt starts with `Claude run-guard heartbeat for Spellbook` exists, adopt it. Otherwise `CronCreate` with cron `3-59/5 * * * *`, recurring true, and the canonical prompt below with `<N>` and `<run file>` filled in.
2. Write `build/claude-campaign-guard.json` (gitignored): `runner` `claude`, `workspace` the absolute repository path, `phase` the phase number, `run_file` the repo-relative run file (`docs/phase-runs/<YYYY-MM-DD>-phase-<N>.md`), `session_id` the value of `$CLAUDE_CODE_SESSION_ID` read in the shell, `cron_id` the job id. Delete any stale `build/claude-campaign-state.json`.
3. Record the job id and the guard write in the run file's Critical events.

The Stop hook (`.claude/hooks/campaign-stop.ps1`, wired in `.claude/settings.json`, built by `D00 T03 §3`) blocks this session's end of turn while the run is open, naming the next runnable row. It lets the turn end when the guard file is gone, the run file has a `## Closeout` heading or a column-0 `PARKED` line, or `query ready` reports `0 runnable now`; after three blocks with no change to the tree it trips its stall breaker and lets the turn end. The heartbeat covers what the hook cannot: a tripped breaker, an API error, a crash out of the turn. It dies with the session and a recurring job expires after 7 days: a run still open on day 7 creates a new job and rewrites `cron_id`; a run resumed in a new session rewrites the guard with the new `session_id`.

The run file's end markers are exact: a line `## Closeout` followed by the closeout, or a column-0 line `PARKED <UTC stamp> <one-line reason>` followed by the park record.

Operator stop: Esc interrupts without the hook firing. A stop or pause said in words deletes the guard file, the state file, and the job (`CronDelete`), in that order, before confirming. Resume recreates all three before any other step.

Canonical heartbeat prompt:

```text
Claude run-guard heartbeat for Spellbook Phase <N> (run file <run file>). This session went idle while a process-plan run may still be open. Check, then act, in this turn.

1. If build/claude-campaign-guard.json is missing, or <run file> has a line "## Closeout" or a column-0 line starting "PARKED": the run is over. CronDelete this job (find it with CronList by this prompt's first sentence), delete build/claude-campaign-state.json if present, and reply RUN FINISHED.
2. If build/claude-campaign-state.json has trips of 2 or more: the run stalled twice with no change to the tree. Do not resume. Append a Critical events line to the run file naming what blocks it, delete the guard file and the state file, CronDelete this job, and report the stall to the operator.
3. Otherwise resume under process-plan: re-run `python scripts/todo-graph.py query ready`, pick up the open section in the run file exactly where it stopped, and keep shipping: finish the section, review and stamp it, commit and push, then the next section, then the next phase. A commit is not a stop. Never start a section in todo/99-manual/. Stop only at closeout, park, 0 runnable now, or an operator stop.
```

## 3. After a phase closeout or park

```bash
python scripts/todo-graph.py query ready
```

A parked phase is not complete and not a stall. If another phase has a runnable-now row, re-point the guard (`CronDelete` the old job, `CronCreate` a new one from the canonical prompt, rewrite `run_file`, `phase`, and `cron_id`, delete the state file, record the new id) and start `process-phase` on it in the same turn. If nothing is runnable now, delete the guard file, the state file, and the job, record the deletions in the run file, and report: what shipped, what parked and why, and the operator's runnable-elsewhere list in order.

## 4. Deny

- Do not ship a row outside `process-todo-section` plus `review-todo-section`.
- Do not start a section in `todo/99-manual/`, and do not pass `--context operator`.
- Do not start a second run, or resume a paused run unless the operator said resume.
- Do not tick `implementation-plan.md` by hand.
- Do not claim a phase complete while its table has `[ ]` rows.
- Do not end the turn on the audit table.
- Do not start a run without its guard file and heartbeat job, and do not end, stop, or pause one without deleting both.
- Do not delete the guard file to get out of a turn. The exits are closeout, park, `0 runnable now`, the stall breaker, and the operator.
- Do not tag, force-push, amend a pushed commit, or skip a hook (ADR 0003).
