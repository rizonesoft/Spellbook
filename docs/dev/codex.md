# Codex Writer Workflow

The primary implementation owner is selected in `writer.json`: either Codex or Claude. Both have equal writer authority when selected. `AGENTS.md` governs Codex. `CLAUDE.md` contains a separate complete Claude contract; neither imports the other. Only one writer may use this checkout at a time. Setup and switching do not start the implementation plan.

## Select the primary writer

```powershell
python scripts/writer.py status
python scripts/writer.py select claude
python scripts/writer.py select codex
```

You can also tell either agent "make Claude the primary writer" or "make Codex the primary writer". Either may perform the selection operation; only the selected agent may then implement or resume its own runner. The other agent may independently review. The tracked `writer.json` is the single selection, initially `codex`; preserve its change in the next coherent commit. Existing sessions must recheck it before implementation, each section, and resume. Do not edit it manually to bypass the switch guard.

Before switching, stop/pause the current writer and wait for its active worker to finish. The selector refuses an active Codex supervisor/worker, an unpaused Codex campaign, or any Claude campaign guard. The selection lock also serializes Codex startup and Claude's separate guard registration against switching. Uncertain stale state is a blocker to inspect, never deleted automatically. A paused Codex session remains paused with its identity and logs intact; switching back does not resume it. Claude retains its own pause/resume rules and records. Interactive writers must obey the same no-concurrent-writers rule; the selector cannot detect arbitrary editors or agents that ignore the protocol.

Only the small, agent-neutral `scripts/writer.py` and selection metadata are shared for coordination. It reads activity indicators and writes only `writer.json` and its transition lock. Each agent registers and runs its own workflow. It imports neither agent runtime, starts no processes, changes no hooks, and copies no session state.

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

Each section runs its exact checkpoint and full gates, receives both reviews described below, then is stamped, synchronized, committed, and pushed once during unattended execution. The next section waits for CI tied to that SHA. A stale review or self-review is insufficient.

## Review order for either primary writer

1. A new Codex CLI session performs the full independent review and reruns the checkpoint and repository gates. Its model and reasoning effort come from the operator's global Codex configuration automatically. The invocation supplies no model, effort, profile, or alternate configuration home; repository config does not pin them. Record the effective values from the runtime, not the parent writer's identity.
2. A new Claude CLI session performs a quick second pass with `--model sonnet --effort high`. The rolling alias avoids a version pin. Quick refers to reviewing the changed scope and nearby contracts; it does not reduce effort or waive a verdict. Record the resolved model from Claude's runtime JSON, CLI version, and explicit high-effort invocation.
3. Both must approve the same candidate. The exact independent Codex reviewer session then checks the Sonnet evidence and writes the final stamp. Findings return to the writer; implementation changes require both reviews again. Missing reviewers, incomplete evidence, or unavailable models block shipping.

The commands and role boundaries live separately in each agent's own `review-todo-section` skill. Cross-provider CLI review is authorized; skills, lifecycle hooks, campaign scripts, configuration, and session state are not shared. The writer passes only the section, candidate identity, and evidence paths to fresh reviewers. The review directory under `build/reviews/<id>/` holds a manifest covering tracked and untracked candidate files, raw logs, reports, exit codes, and actual model identities. Stamp metadata names both reviewers and reports.

The [Codex configuration precedence](https://learn.chatgpt.com/docs/config-file/config-basic) puts CLI/project settings above user defaults, so neither review commands nor project config override the global model/effort. The [Claude model configuration](https://code.claude.com/docs/en/model-config) documents that aliases can depend on installed CLI version, provider routing, and explicit alias pins. Verify the resolved Sonnet against the current official release; do not silently accept a stale alias, older provider mapping, fallback, or allowlist restriction as "latest". Keep installations current through the operator's normal update process; review itself does not rewrite global settings or auto-upgrade tools.

Per-turn JSONL/stderr stays in `build/codex/runs/<run_id>/`; session identity stays in `build/codex/campaign.json`. Three consecutive CLI failures or three attempts without content progress pause the run; record chatter is excluded from progress. Paused is not complete. Terminal `## Closeout`/`PARKED` markers require no runnable rows in scope, with operator/blocked remainders recorded. Intermediate phase endings use level-three headings.

```powershell
python .codex/scripts/check-workflow.py
python -m unittest discover -s .codex/tests -v
pwsh .codex/scripts/run-plan.ps1 -Action audit
pwsh scripts/check-all.ps1
```

Tests use temporary Git/plan fixtures and simulated CLI lifecycles to exercise continuation, bounded failures, identity, pause, phase scope, and hook transport. They do not start the real product plan or spend model tokens.
