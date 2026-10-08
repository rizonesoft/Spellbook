---
name: process-phase
description: Execute one Spellbook phase through the Codex supervisor with independent section review and per-section pushes.
---

# Process a Phase with Codex

Before implementation and each section, run `python scripts/writer.py assert codex`. Switching the primary writer is an explicit operator action; this runner never selects itself automatically.

Enter through `.agents/skills/process-plan/SKILL.md`; outside an owned worker, start its supervisor with `-Phase N`. A named phase does not chain. Inside a full-plan run, return to `process-plan` when this phase ends. Use the campaign's `docs/codex-runs/<run_id>.md`.

1. Inspect dirty files and pause state. Read prior Codex evidence. Record Phase repairs, Shipped-row verification, Gap audit, Sections, Critical events, and Lessons.
2. Run TODO `validate` and `plan --check`. Resolve each open row: 0 ready, 2 broken reference to repair, 3 shipped, 4 blocked, 5 operator-only. Correct stale claims visibly before implementation.
3. Verify prerequisite stamps and rerun checkpoints. File regressions forward without rewriting shipped checklists. Use `add-todo` for gaps in surfaces, handoffs, errors, or data read-back.
4. Before each row check the previous pushed commit's CI: `pwsh scripts/gh.ps1 run list --branch main --commit <sha> --json databaseId,headSha,status,conclusion`. Match the SHA, wait for pending required runs, and fix failures before the next section. No matching result is inconclusive.
5. Use `process-todo-section`, including the two-stage Codex-then-Sonnet review, checkpoint, full gates, stamp, sync, and one commit using `git -c core.hooksPath=.codex/githooks commit`. Then `git push origin main` and record SHA, both verdicts, and push. If rejected, fetch and inspect; integrate remote changes while preserving user edits, rerun gates and both reviews on changed implementation, and retry without force.
6. Re-query after each stamp. Continue until all rows ship or every leftover is blocked/operator-only. An implementation obstacle with runnable work remaining is paused and recorded, not a successful park.

For a complete phase run full gates and `process-todo-file` on exhausted files. Record `### Phase N closeout`; for blocked phases use `### Phase N parked` with exact refs and blockers. Return to `process-plan`, which alone writes a campaign terminal marker after checking the entire scope. Check final-commit CI before claiming success.

On operator stop invoke the Codex pause command and end immediately. Never remove ownership state to evade the guard. Missing review, a failed gate/push, or unknown CI cannot be stamped as success.
