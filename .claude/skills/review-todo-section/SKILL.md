---
name: review-todo-section
description: Independently review one built TODO section against its contract, then write its Verified stamp and flip its row -- or refuse with findings. Use after process-todo-section, or to audit a shipped section.
---

# Review TODO Section

The reviewer's job is to find the gap between what the section promised and what the commit range delivers. Approving work that does not meet its section costs more later than refusing it now.

## Required review order

For either primary writer, run a fresh Codex CLI review first, then a fresh quick Sonnet CLI review at high effort. Neither may be the writer's session. An ordinary Claude subagent does not replace the Codex stage. Keep this Claude contract independent; the Codex child loads its own instructions rather than importing them into Claude. A child explicitly assigned Stage 1, Stage 2, or Finalize performs only that role and does not recursively invoke this pipeline.

Before launch, freeze the complete candidate: base commit plus tracked and untracked changes, or an exact commit range. Save a manifest of candidate paths and content hashes, excluding ignored build output. Give each reviewer the section ref, candidate scope, and evidence locations without writer conversation or a suggested verdict. Check inputs for secrets. Store prompts, reports, CLI logs, exit codes, manifest, and model evidence in a unique ignored `build/reviews/<id>/`. The writer remains paused until review ends. Reviewers cannot edit implementation, stage, commit, push, start a campaign, or select a writer.

### First: independent Codex using global settings

Use the installed native `codex.exe` from the repository root. Write a Stage 1 prompt with the section/candidate and the checks below. The reviewer reads its own Codex review skill and standards, runs the exact checkpoint and full `pwsh scripts/check-all.ps1`, and reports APPROVE or REFUSE without stamping.

```powershell
Get-Content -Raw "$reviewDir/codex-prompt.txt" | & $codexExe exec --color never --output-last-message "$reviewDir/codex-review.md" - > "$reviewDir/codex-cli.log" 2>&1
$codexExit = $LASTEXITCODE
```

Leave model and reasoning effort to Codex's global settings. Never add `--model`, `--profile`, model/effort config overrides, `--ignore-user-config`, or a replacement `CODEX_HOME`; do not resume a writer session. Repository Codex settings may not pin model/effort. Verify the actual model, effort, and exact session ID from the CLI header/runtime metadata. Missing identity evidence or unexpected overrides blocks review. Do not hardcode today's global values in this skill. A successful process exit is necessary but does not substitute for an explicit approval.

### Second: quick latest Sonnet at high effort

After Codex approves, start a fresh Claude process with a Stage 2 prompt. Ask it to inspect the same diff and relevant surrounding contracts for defects, omissions, regression risk, missing tests, and unsafe assumptions, with a concise APPROVE/REFUSE verdict and actionable `path:line` findings. It forms its own assessment before reading the earlier review's test evidence. Repeating the full build is unnecessary unless a finding demands it. Keep the scope quick while retaining high reasoning effort.

```powershell
Get-Content -Raw "$reviewDir/sonnet-prompt.txt" | & $claudeExe --print --model sonnet --effort high --tools Read,Glob,Grep --allowedTools Read,Glob,Grep --strict-mcp-config --mcp-config '{"mcpServers":{}}' --settings '{"fallbackModel":[]}' --max-turns 12 --no-session-persistence --output-format json > "$reviewDir/sonnet-review.json" 2> "$reviewDir/sonnet-cli.log"
$sonnetExit = $LASTEXITCODE
```

Always select the rolling `sonnet` alias, never a version-pinned model. Inspect environment/settings for `ANTHROPIC_DEFAULT_SONNET_MODEL`, provider routing, and model allowlists before launch. Verify the resolved model using JSON `modelUsage` or runtime metadata against the current official Sonnet release and alias mapping, and record the CLI version and explicit high-effort invocation (effective effort metadata too when exposed). Do not silently use an older provider mapping, a fallback model, or override managed policy. A stale installation, missing access to the latest Sonnet, turn limit, error result, nonzero exit, or incomplete verdict blocks shipping. Report the blocker rather than automatically changing global settings or installations. If Claude refuses a nested invocation, use a separate external process/session; never reuse the writer conversation or disguise the execution environment to evade that protection.

### Complete the review

Confirm both explicit approvals and that the candidate manifest still matches. Resume only the exact Codex reviewer session with `codex exec resume <reviewer-session-id>` and a Finalize prompt carrying Sonnet's report and routing evidence. Never use `--last`. Only that independent reviewer writes the stamp and flips the row after checking both approvals; it cannot fix implementation. The writer then syncs/validates and commits. Any implementation change after either approval invalidates both and restarts the sequence. Inspect stamp/derived-plan-only changes separately before committing. Never bypass permission checks or hook trust to obtain a review.

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
> **Reviewer:** Codex <effective model>, effort <effective effort>, session <id>, candidate <manifest/diff identity>, <report path>.
> **Second reviewer:** Claude <resolved Sonnet model>, alias sonnet, effort high, <report path>.
```

Then `python scripts/todo-graph.py plan --sync` and `validate`.

**Refuse:** list each finding with `path:line`, what the section asked, and what the tree does. The writer fixes them in commits appended to the same range, and the review runs again on the whole range. Never stamp partial scope.
