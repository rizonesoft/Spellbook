---
name: review-todo-section
description: Independently review one built TODO section against its contract, then write its Verified stamp and flip its row -- or refuse with findings. Use after process-todo-section, or to audit a shipped section.
---

# Review TODO Section

The reviewer's job is to find the gap between what the section promised and what the commit range delivers. Approving work that does not meet its section costs more later than refusing it now.

## Required review order

Run a fresh full Claude CLI review first (rolling `opus` alias, high effort), then a fresh quick Sonnet CLI review at high effort. Neither may be the writer's session, and an ordinary subagent of the writer replaces neither: each is a separate `claude` process with no writer conversation. A child explicitly assigned Stage 1, Stage 2, or Finalize performs only that role and does not recursively invoke this pipeline.

Before launch, freeze the complete candidate: base commit plus tracked and untracked changes, or an exact commit range. Save a manifest of candidate paths and content hashes, excluding ignored build output. Give each reviewer the section ref, candidate scope, and evidence locations without writer conversation or a suggested verdict. Check inputs for secrets. Store prompts, reports, CLI logs, exit codes, manifest, and model evidence in a unique ignored `build/reviews/<id>/`. The writer remains paused until review ends. Reviewers cannot edit implementation, stage, commit, push, or start a run.

### First: full review with the latest Opus at high effort

Write a Stage 1 prompt with the section/candidate and the checks below. The reviewer reads this skill and the standards, runs the exact checkpoint and full `pwsh scripts/check-all.ps1`, and reports APPROVE or REFUSE with `path:line` findings, without stamping. It may run commands but has no file-editing tools; the manifest is rechecked afterwards, so a review that changed the candidate is void.

```powershell
$claudeExe = (Get-Command claude).Source
$reviewDir = "build/reviews/<id>"   # the unique ignored review folder
$stage1Session = [guid]::NewGuid().ToString()
Get-Content -Raw "$reviewDir/stage1-prompt.txt" | & $claudeExe --print --model opus --effort high --session-id $stage1Session --tools Read,Glob,Grep,Bash,PowerShell --allowedTools Read,Glob,Grep,Bash,PowerShell --disallowedTools Edit,Write,NotebookEdit --strict-mcp-config --mcp-config '{"mcpServers":{}}' --settings '{"fallbackModel":[]}' --max-turns 80 --output-format json > "$reviewDir/stage1-review.json" 2> "$reviewDir/stage1-cli.log"
$stage1Exit = $LASTEXITCODE
```

Always select the rolling `opus` alias, never a version-pinned model, and keep session persistence on: Finalize resumes exactly `$stage1Session`. Verify the resolved model from JSON `modelUsage`, and record the CLI version, session ID, and explicit high-effort invocation. A successful process exit is necessary but does not substitute for an explicit approval.

### Second: quick latest Sonnet at high effort

After Stage 1 approves, start a fresh Claude process with a Stage 2 prompt. Ask it to inspect the same diff and relevant surrounding contracts for defects, omissions, regression risk, missing tests, and unsafe assumptions, with a concise APPROVE/REFUSE verdict and actionable `path:line` findings. It forms its own assessment before reading the earlier review's test evidence. Repeating the full build is unnecessary unless a finding demands it. Keep the scope quick while retaining high reasoning effort.

```powershell
Get-Content -Raw "$reviewDir/sonnet-prompt.txt" | & $claudeExe --print --model sonnet --effort high --tools Read,Glob,Grep --allowedTools Read,Glob,Grep --strict-mcp-config --mcp-config '{"mcpServers":{}}' --settings '{"fallbackModel":[]}' --max-turns 12 --no-session-persistence --output-format json > "$reviewDir/sonnet-review.json" 2> "$reviewDir/sonnet-cli.log"
$sonnetExit = $LASTEXITCODE
```

Always select the rolling `sonnet` alias, never a version-pinned model. For both stages, inspect environment/settings for `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, provider routing, and model allowlists before launch. Verify the resolved model using JSON `modelUsage` or runtime metadata against the current official Sonnet release and alias mapping, and record the CLI version and explicit high-effort invocation (effective effort metadata too when exposed). Do not silently use an older provider mapping, a fallback model, or override managed policy. A stale installation, missing access to the latest Sonnet, turn limit, error result, nonzero exit, or incomplete verdict blocks shipping. Report the blocker rather than automatically changing global settings or installations. If Claude refuses a nested invocation, use a separate external process/session; never reuse the writer conversation or disguise the execution environment to evade that protection.

### Complete the review

Confirm both explicit approvals and that the candidate manifest still matches. Resume only the exact Stage 1 session with a Finalize prompt carrying Sonnet's report and routing evidence; Finalize may edit only the TODO tree and the derived plan:

```powershell
Get-Content -Raw "$reviewDir/finalize-prompt.txt" | & $claudeExe --print --resume $stage1Session --model opus --effort high --tools Read,Glob,Grep,Bash,PowerShell,Edit --allowedTools Read,Glob,Grep,Bash,PowerShell,'Edit(todo/**)' --disallowedTools Write,NotebookEdit --strict-mcp-config --mcp-config '{"mcpServers":{}}' --settings '{"fallbackModel":[]}' --max-turns 30 --output-format json > "$reviewDir/finalize.json" 2> "$reviewDir/finalize-cli.log"
```

Never use `--continue`. Before committing, rerun the manifest check allowing only `todo/` paths to differ: a Finalize that wrote anywhere else is void. Only that independent reviewer writes the stamp and flips the row after checking both approvals; it cannot fix implementation. The writer then syncs/validates and commits. Any implementation change after either approval invalidates both and restarts the sequence. Inspect stamp/derived-plan-only changes separately before committing. Never bypass permission checks or hook trust to obtain a review.

## The checks

1. **Scope:** every item is `[x]` and its `Done when:` is observably true in the tree. A ticked item whose condition does not hold is a finding.
2. **Checkpoint:** rerun the Test checkpoint yourself. Its output must match what the writer quoted. A checkpoint that cannot fail is a finding.
3. **Gates:** `pwsh scripts/check-all.ps1` exits 0 at the reviewed commit.
4. **Layering and style:** no logic in `src/app/` that a test would want; no Windows header in core or storage; names and errors per `standards/cpp.md`.
5. **Tests:** every new public core function has a named test; failure paths are tested for every write.
6. **User data:** writes are transactional; migrations are new files; nothing in tests touches the real `%LOCALAPPDATA%\Spellbook`.
7. **Surfaces:** `Job:`, `Treatment:`, `Chrome:` hold; every control is accounted for; captures exist; `docs/user/` is updated; app resources own the themed/plain labels.
8. **Docs and changelog:** updated for anything a user sees.

## Outcome

**Approve:** write the stamp at the end of the section, then flip its Implementation Order row to `[x]`:

```
> **Verified:** YYYY-MM-DD | §N | <the evidence, quoted: gate results, test names, log lines, captures>
> **Implementer:** <name (model-id)>
> **Reviewer:** Claude <resolved Opus model>, alias opus, effort high, session <id>, candidate <manifest/diff identity>, <report path>.
> **Second reviewer:** Claude <resolved Sonnet model>, alias sonnet, effort high, <report path>.
```

Then `python scripts/todo-graph.py plan --sync` and `validate`.

**Refuse:** list each finding with `path:line`, what the section asked, and what the tree does. The writer fixes them in commits appended to the same range, and the review runs again on the whole range. Never stamp partial scope.
