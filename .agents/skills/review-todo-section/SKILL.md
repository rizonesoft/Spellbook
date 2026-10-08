---
name: review-todo-section
description: Independently review one built TODO section against its contract, then write its Verified stamp and flip its row -- or refuse with findings. Use after process-todo-section, or to audit a shipped section.
---

# Review TODO Section

The reviewer's job is to find the gap between what the section promised and what the commit range delivers. Approving work that does not meet its section costs more later than refusing it now.

## Two sequential, independent reviews

This contract applies with either writer. Stage 1 is a new native Codex CLI session, not a subagent inheriting the writer's model. Stage 2 is a new native Claude CLI session using `--model sonnet --effort high`. The writer coordinates these review-only processes but cannot supply either verdict. Review stages do not launch their own review pipeline: a prompt naming Stage 1, Stage 2, or Finalize executes only that role.

Give reviewers only the section reference, base commit plus the complete tracked/untracked candidate (or exact commit range), and evidence locations. Do not pass the writer's conversation or proposed verdict. Record a candidate manifest with path/content hashes, including untracked source files; exclude ignored build output. Pause implementation while reviewing. Any implementation change invalidates both approvals and requires both stages again. Final stamp and derived plan metadata may change after approval, but inspect that final diff separately.

Create a unique ignored `build/reviews/<id>/` directory for prompts, candidate manifest, reports, CLI logs, exit codes, and runtime identities. Inspect candidate inputs for secrets before sending them. Neither stage edits implementation, stages, commits, pushes, starts campaigns, or switches writers. Never bypass permissions or hook trust to make review run.

### Stage 1: full Codex review

Resolve the installed native `codex.exe`. Write a prompt naming Stage 1, the candidate, this Codex skill, and the checks below; instruct it to return APPROVE or REFUSE with findings and evidence, without stamping. Start a fresh session from the repository root:

```powershell
Get-Content -Raw "$reviewDir/codex-prompt.txt" | & $codexExe exec --color never --output-last-message "$reviewDir/codex-review.md" - > "$reviewDir/codex-cli.log" 2>&1
$codexExit = $LASTEXITCODE
```

Do not supply `--model`, `--profile`, a model/effort `--config` override, `--ignore-user-config`, an alternate `CODEX_HOME`, or a resumed writer session. Repository Codex configuration must not pin model or reasoning effort. The CLI loads the current global settings automatically; record its effective model, effort, and exact reviewer session ID from runtime metadata or the CLI header. If settings are unexpectedly overridden or cannot be verified, stop without approval. Never copy current global values into the repository. Stage 1 independently runs the section checkpoint and full `pwsh scripts/check-all.ps1`, then reviews the checks below. A zero CLI exit alone is not approval.

### Stage 2: quick Sonnet review at high effort

Only after Stage 1 approves, write a Stage 2 prompt identifying the same candidate and section. Ask for a concise second pass over the diff and nearby contracts: correctness, missed requirements, regressions, tests, and unsafe assumptions. It may read the first stage's test evidence after forming its own view. Do not rerun the entire build by default. Quick means bounded scope, not lower effort or an optional verdict.

```powershell
Get-Content -Raw "$reviewDir/sonnet-prompt.txt" | & $claudeExe --print --model sonnet --effort high --tools Read,Glob,Grep --allowedTools Read,Glob,Grep --strict-mcp-config --mcp-config '{"mcpServers":{}}' --settings '{"fallbackModel":[]}' --max-turns 12 --no-session-persistence --output-format json > "$reviewDir/sonnet-review.json" 2> "$reviewDir/sonnet-cli.log"
$sonnetExit = $LASTEXITCODE
```

Use installed Claude authentication and its own instruction/hook discovery; do not import its skills into Codex. Resolve the rolling `sonnet` alias on every new invocation, never pin a version such as 5.5. Before launch check for alias pins (`ANTHROPIC_DEFAULT_SONNET_MODEL` in the environment/settings), provider routing, and model allowlists. Do not silently accept an older alias mapping or override managed settings. Verify the resolved model from Claude's JSON `modelUsage`/runtime metadata against the current official Sonnet release and alias mapping; the local CLI must be current enough to resolve it. Record the CLI version, resolved model, and explicit `--effort high` invocation (plus effective effort metadata when exposed). A stale CLI, unavailable latest model, unexpected fallback, error result, turn limit, nonzero exit, or missing verdict is a blocker, not approval. Do not update global tools or routing merely to hide a blocker.

### Finalize with the independent Codex reviewer

After Sonnet explicitly approves and the candidate manifest still matches, resume only the exact Stage 1 Codex reviewer session with `codex exec resume <reviewer-session-id>`, supplying the Sonnet report, identity evidence, and finalization-only instructions. Never use `--last` or the writer's session. That reviewer checks both verdicts, resolves any findings, and writes the stamp/row only if both approve the unchanged candidate. It may not fix code. Missing or ambiguous evidence blocks stamping. A finding returns the candidate to the writer and restarts both reviews after correction.

## The checks

1. **Scope:** every item is `[x]` and its `Done when:` is observably true in the tree. A ticked item whose condition does not hold is a finding.
2. **Checkpoint:** rerun the Test checkpoint yourself. Its output must match what the writer quoted. A checkpoint that cannot fail is a finding.
3. **Gates:** `pwsh scripts/check-all.ps1` exits 0 at the reviewed commit.
4. **Layering and style:** no logic in `src/app/` that a test would want; no Windows header in core or storage; names and errors per `standards/cpp.md`.
5. **Tests:** every new public core function has a named test; failure paths are tested for every write.
6. **User data:** writes are transactional; migrations are new files; nothing in tests touches the real `%LOCALAPPDATA%\Spellbook`.
7. **Surfaces:** `Job:`, `Treatment:`, `Chrome:` hold; every control is accounted for; captures exist; `docs/user/` is updated; labels resolve from app `.resw` vocabulary resources.
8. **Docs and changelog:** updated for anything a user sees.

## Outcome

**Approve:** write the stamp at the end of the section, then flip its Implementation Order row to `[x]`:

```
> **Verified:** YYYY-MM-DD | §N | <the evidence, quoted: gate results, test names, log lines, captures>
> **Implementer:** <name (model-id)>
> **Reviewer:** Codex <effective model>, effort <effective effort>, session <id>, candidate <manifest/diff identity>, <report path>.
> **Second reviewer:** Claude <resolved Sonnet model>, alias sonnet, effort high, <report path>.
```

Then `python scripts/todo-graph.py plan --sync` and `validate`.

**Refuse:** list each finding with `path:line`, what the section asked, and what the tree does. The writer fixes them in commits appended to the same range, and the review runs again on the whole range. Never stamp partial scope.

Codex owns this independent skill. Use `git -c core.hooksPath=.codex/githooks commit` for commits; inspect every dirty file first and preserve safe user side edits.
