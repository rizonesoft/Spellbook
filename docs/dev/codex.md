# Codex Writer Workflow

Codex is Spellbook's primary implementation owner. `AGENTS.md` governs Codex. `CLAUDE.md` contains a separate complete Claude contract; neither imports the other. Only one writer may use this checkout at a time. This setup does not start the implementation plan.

## Isolation

| Concern | Codex | Claude |
| ------- | ----- | ------ |
| Instructions | `AGENTS.md` | `CLAUDE.md` |
| Skills | `.agents/skills/` | `.claude/skills/` |
| Lifecycle configuration | `.codex/config.toml`, `.codex/hooks.json` | `.claude/settings.json` |
| Lifecycle handlers | `.codex/hooks/` | `.claude/hooks/` |
| Controller | `.codex/scripts/` | Existing skill and cron workflow |
| Git hooks | `.codex/githooks/`, selected per commit | Existing `tools/githooks/` |
| State/logs | `build/codex/` | Existing `build/claude-campaign-*.json` |
| Run records | `docs/codex-runs/` | `docs/phase-runs/` |

These are independent files, not symlinks, imports, dispatchers to the other agent, or synchronized copies. Codex engineering skills initially preserve established repository requirements, then evolve separately. Codex reads only the presence of the Claude guard to refuse concurrent unattended writers; it never adopts or modifies it. Claude also obeys the no-concurrent-writers instruction; this is not an adversarial lock against arbitrary external processes.

Conservatively shared scripts are repository build/test/format/lint/setup/packaging runners, the GitHub CLI wrapper, documentation/layering gates, and TODO validation. They enforce repository rules without choosing a model, session, permissions, or continuation. Common check-all/CI entrypoints run each agent's separate probes. Agent-specific control stays under its owner. Codex commits use `git -c core.hooksPath=.codex/githooks commit ...`; do not rewrite clone-wide `core.hooksPath` because setup and Claude retain the original hooks.

## Session setup

Checked against native Codex CLI 0.161.0. Codex discovers `.agents/skills/` up to the repository root, per [OpenAI's skills documentation](https://learn.chatgpt.com/docs/build-skills). Start a fresh Codex session in this checkout to load the new catalog/configuration. Inspect it with `/skills`.

Native Stop and Interrupt hooks follow [OpenAI's hook contract](https://learn.chatgpt.com/docs/hooks). Open `/hooks` to review and trust the exact definitions. Project hooks need a trusted project layer and explicit hook trust; changed definitions can require trust again. No script bypasses trust or changes model, sandbox, or approval policy.

The supervisor independently checks continuation after CLI exits, so absent hook trust does not silently disable continuation. Native hooks add continuation within a running CLI turn and persist a user interrupt. Tests exercise stdin/stdout through the configured command; they do not claim the desktop app has trusted or activated hooks.

## Commands

From the repository root in PowerShell 7:

```powershell
pwsh .codex/scripts/run-plan.ps1 -Action audit
pwsh .codex/scripts/run-plan.ps1 -Action status
```

Start/resume require native `codex.exe`, not npm shell shims. For the standard npm installation, locate and verify it:

```powershell
$codexNative = Join-Path $env:APPDATA 'npm/node_modules/@openai/codex/node_modules/@openai/codex-win32-x64/vendor/x86_64-pc-windows-msvc/bin/codex.exe'
& $codexNative --version
pwsh .codex/scripts/run-plan.ps1 -Action start -CodexExe $codexNative
# A named phase does not chain:
# pwsh .codex/scripts/run-plan.ps1 -Action start -Phase 0 -CodexExe $codexNative
```

For other installations pass the actual native executable path. It launches without a shell and with no-window flags, inherits configured model/permissions, and receives prompts on stdin. No approval/sandbox bypass is added. Permission, authentication, or toolchain failures remain real blockers. Do not start while another session is writing. A session asked to process the plan monitors this supervisor; only its child writes implementation.

Keep the supervisor alive in its existing terminal/pseudoterminal for continuation. No scheduler, Windows task, or machine-wide service is installed. A machine restart or supervisor crash requires explicit recovery.

```powershell
pwsh .codex/scripts/run-plan.ps1 -Action pause
pwsh .codex/scripts/run-plan.ps1 -Action status
pwsh .codex/scripts/run-plan.ps1 -Action resume -CodexExe $codexNative
```

Pause immediately persists a marker and prevents further continuation. The worker checks it before actions; it does not cancel an already-running shell command. Interrupting the supervisor records a pause; an existing no-window worker can still be draining its current action. A separate worker process holds its own OS lock for the actual CLI's entire lifetime, so resume refuses while that worker remains alive, even after the supervisor crashes. Never kill unrelated Codex helpers. Explicit resume acquires the supervisor lock and checks the worker lock before removing only this run's pause/counter files; it resumes the recorded UUID and original phase scope, never `--last`. Without a captured UUID automatic resume is refused; inspect logs and reconcile work before replacing the run.

## Proof and recovery

Each section runs its exact checkpoint and full gates, receives independent fresh-context review, then is stamped, synchronized, committed, and pushed once. The next section waits for CI tied to that SHA. A stale review or self-review is insufficient. Report observed implementer/reviewer identities without inventing model IDs.

Per-turn JSONL/stderr stays in `build/codex/runs/<run_id>/`; session identity stays in `build/codex/campaign.json`. Three consecutive CLI failures or three attempts without content progress pause the run; record chatter is excluded from progress. Paused is not complete. Terminal `## Closeout`/`PARKED` markers require no runnable rows in scope, with operator/blocked remainders recorded. Intermediate phase endings use level-three headings.

```powershell
python .codex/scripts/check-workflow.py
python -m unittest discover -s .codex/tests -v
pwsh .codex/scripts/run-plan.ps1 -Action audit
pwsh scripts/check-all.ps1
```

Tests use temporary Git/plan fixtures and simulated CLI lifecycles to exercise continuation, bounded failures, identity, pause, phase scope, and hook transport. They do not start the real product plan or spend model tokens.
