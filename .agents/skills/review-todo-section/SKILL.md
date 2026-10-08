---
name: review-todo-section
description: Independently review one built TODO section against its contract, then write its Verified stamp and flip its row -- or refuse with findings. Use after process-todo-section, or to audit a shipped section.
---

# Review TODO Section

The reviewer's job is to find the gap between what the section promised and what the commit range delivers. Approving work that does not meet its section costs more later than refusing it now.

## Use a fresh context

Review in a context that did not write the code: spawn a fresh Codex reviewer subagent without the writer's conversation history, or use a separate reviewer session or human. Give it only the section ref and candidate diff scope. It reads this Codex skill, the section, and standards itself. The writer does not review itself. If review is unavailable, report the blocker without stamping or shipping.

The candidate includes tracked and untracked changes: use a base commit plus the full working tree before the section's single commit, or an exact commit range after it. Independently run the checkpoint and gates, identify the reviewed candidate, and return a verdict with evidence and actual model identity if available. A code change after approval requires renewed review. Only the reviewer writes the stamp and flips the row; the writer then syncs the plan and commits. Review never starts a campaign, edits implementation, pushes, or changes another agent's files.

## The checks

1. **Scope:** every item is `[x]` and its `Done when:` is observably true in the tree. A ticked item whose condition does not hold is a finding.
2. **Checkpoint:** rerun the Test checkpoint yourself. Its output must match what the writer quoted. A checkpoint that cannot fail is a finding.
3. **Gates:** `pwsh scripts/check-all.ps1` exits 0 at the reviewed commit.
4. **Layering and style:** no logic in `src/app/` that a test would want; no Windows header in core or storage; names and errors per `standards/cpp.md`.
5. **Tests:** every new public core function has a named test; failure paths are tested for every write.
6. **User data:** writes are transactional; migrations are new files; nothing in tests touches the real `%LOCALAPPDATA%\Spellbook`.
7. **Surfaces:** `Job:`, `Treatment:`, `Chrome:` hold; every control is accounted for; captures exist; `docs/user/` is updated; labels come from the vocabulary table.
8. **Docs and changelog:** updated for anything a user sees.

## Outcome

**Approve:** write the stamp at the end of the section, then flip its Implementation Order row to `[x]`:

```
> **Verified:** YYYY-MM-DD | §N | <the evidence, quoted: gate results, test names, log lines, captures>
> **Implementer:** <name (model-id)>
```

Then `python scripts/todo-graph.py plan --sync` and `validate`.

**Refuse:** list each finding with `path:line`, what the section asked, and what the tree does. The writer fixes them in commits appended to the same range, and the review runs again on the whole range. Never stamp partial scope.

Codex owns this independent skill. Use `git -c core.hooksPath=.codex/githooks commit` for commits; inspect every dirty file first and preserve safe user side edits.
