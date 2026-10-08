---
schema_version: 1
id: workspace-unattended-runner
domain: 00-workspace
status: draft
title: "TODO-03 -- The Unattended Runner: Contexts, Run Skills, the Run Guard, and the UI Driver"
depends_on: []
---

# TODO-03 -- The Unattended Runner: Contexts, Run Skills, the Run Guard, and the UI Driver

> **Goal:** `process-plan` runs this repository's plan unattended from the first ready row to the last: the graph tells agent work from operator work, the run skills chain section to section and phase to phase, a Stop hook keeps the session working until the run closes out or parks, every surface section can be proven by a scripted UI Automation driver instead of a person, and no open section's checkpoint needs a human.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** The operator asked on 2026-10-04 that "the todo system and plan should be able to run unattended with process plan" (ADR 0003). Spellbook has `add-todo`, `create-todo`, `process-todo-section`, and `review-todo-section`, but not `process-plan`, `process-phase`, `process-todo-file`, or `groom-plan`, which `docs/reference-conventions.md` records as deliberately not copied at M0. `scripts/todo-graph.py query ready` lists every open row with met dependencies, including operator-only rows in `todo/99-manual/`, and prints no runnable-now count. `.claude/settings.json` has no hooks. There is no UI driver: every "driven run" checkpoint assumes a person at the keyboard. The reference implementation is ScratchPad (`R:\GitHub\ScratchPad\.claude\skills\process-plan\SKILL.md`, `process-phase`, `process-todo-file`, `groom-plan`, and `.claude\hooks\campaign-stop.ps1`), which is the right size for a single-developer app; Isotone's adds an external reviewer panel Spellbook does not have.

## Inputs

- [`../../scripts/todo-graph.py`](../../scripts/todo-graph.py) -- the validator whose `query ready` and `resolve` this file extends
- [`../README.md`](../README.md) -- the format spec and the proof table this file changes
- [`../../docs/adr/0003-v0.1.0-scope-and-distribution.md`](../../docs/adr/0003-v0.1.0-scope-and-distribution.md) -- push after each section, never tag, operator work in `todo/99-manual/`
- ScratchPad's `process-plan`, `process-phase`, `process-todo-file`, `groom-plan` skills and `campaign-stop.ps1` -- the shape to port
- Microsoft Learn: "UI Automation Overview" and `System.Windows.Automation` (`AutomationElement.FindFirst`, `InvokePattern`, `ValuePattern`) -- the driver's API
- -> XREF: D00 T02 §3 -- the WinUI shell the UI driver drives
- -> XREF: D00 T02 §6 -- the WinUI retarget this file's checkpoint sweep follows
- -> XREF: D99 T01 §10 -- the visual and screen-reader pass that takes the human-only checks

## Outcome

- `python scripts/todo-graph.py query ready` ends with `N runnable now, M runnable elsewhere`, where elsewhere means operator-only; `resolve` exits 5 for an operator-only section.
- `process-plan`, `process-phase`, `process-todo-file`, and `groom-plan` exist under `.claude/skills/`, adapted to Spellbook's gates, its push-per-section rule, and its fresh-context reviewer.
- A Stop hook holds a run's session until the run file has a closeout or a park, and releases it after three blocks with no change to the tree.
- `pwsh scripts/drive.ps1 -Scenario <name>` launches Spellbook against a temporary data folder, drives it by AutomationId, saves captures, and reads the database back.
- No open section outside `todo/99-manual/` needs a person to pass its checkpoint.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Operator-only work in the graph: runnable now and elsewhere | -- |  [x]   |
|   2   |   §2    | The run skills: process-plan, process-phase, process-todo-file, groom-plan | §1 |  [x]   |
|   3   |   §3    | The run guard: the Stop hook and its probe | §2 |  [x]   |
|   4   |   §4    | The UI driver for driven runs | D00 T02 §3 |  [ ]   |
|   5   |   §5    | Unattended proof rules and the checkpoint sweep | §4, D00 T02 §6 |  [ ]   |

|   6   |   §6    | Independent Codex writer workflow and supervised runner | §1, §2, §3 |  [x]   |

---

## 1. Operator-Only Work in the Graph: Runnable Now and Elsewhere

An unattended run must never start a section only the operator can do (creating accounts, approving a release, judging a capture by eye), and it must be able to tell "nothing left for me" from "nothing left at all". The rule is structural, so it cannot drift: every section in `todo/99-manual/` is operator-only, and nothing outside it is.

- [x] `scripts/todo-graph.py query ready`: split ready rows into runnable now (agent) and runnable elsewhere (operator, domain 99), print each group, and end with the exact line `<N> runnable now, <M> runnable elsewhere`. `--context operator` treats domain 99 as runnable now. Done when: on today's tree the output lists `D99 T01 §2` under elsewhere and the summary line parses with the regex `(\d+) runnable now`.
- [x] `resolve` prints `context  operator` and exits 5 for an open, dependency-met section in domain 99 (exit codes documented in the module docstring and `todo/README.md` Tooling). Done when: `python scripts/todo-graph.py resolve 'D99 T01 §2'; echo $?` prints 5.
- [x] `self-test` fixtures: an operator row lands in elsewhere; `--context operator` moves it to now; `resolve` exits 5 then 0 with the flag. Done when: `python scripts/todo-graph.py self-test` passes the new cases.
- [x] Commit: `"workspace: operator-only rows in the todo graph (D00 T03 §1)"`

**Test checkpoint:** Unit test: `python scripts/todo-graph.py self-test` passes; a mutant that drops the domain-99 rule fails the elsewhere case. Driven run: `query ready` on the real tree prints the summary line.

> **Verified:** 2026-10-04 | §1 | self-test "todo-graph self-test: 16 passed, 0 failed"; query ready lists D99 T01 §2 under "runnable elsewhere" and ends "7 runnable now, 5 runnable elsewhere" (regex `(\d+) runnable now` -> 7); resolve 'D99 T01 §2' prints "context  operator", exit 5, and with --context operator exit 0; mutant with runnable_here always True: "todo-graph self-test: 14 passed, 2 failed", exit 1; check-all "all gates passed" (build/check-all-d00t03s1.log), validate 0 fatal 0 warnings, check-docs 0 findings
> **Implementer:** Claude (claude-opus-5-5)

## 2. The Run Skills: process-plan, process-phase, process-todo-file, groom-plan

Port ScratchPad's four skills, keeping their loop discipline (one continuous loop; a commit is not a stop; three endings: closeout, park, operator stop) and changing what differs here.

- [x] `.claude/skills/process-plan/SKILL.md`: route, audit (`validate`, `plan --check`, `query ready`, `query blocked`, `pwsh scripts/setup.ps1 -Verify`), start the run guard (§3) and the heartbeat (`CronCreate`, prompt naming "Claude run-guard heartbeat for Spellbook"), chain phases. Adapt: `python` not `python3`; no reviewer panel (review is `review-todo-section` in a fresh subagent); operator rows are runnable elsewhere and are never started. Done when: the file has `name` and `description` frontmatter and names only commands that exist.
- [x] `.claude/skills/process-phase/SKILL.md`: open `docs/phase-runs/<YYYY-MM-DD>-phase-<N>.md` (sections: Phase repairs, Shipped-row verification, Gap audit, Sections, Critical events, Lessons), repair, gap-audit, ship row by row through `process-todo-section` and `review-todo-section`, park or close out. Spellbook rules: after each stamped section `git push origin main` (a failed push is a red gate); before each section, read the previous push's CI result with `pwsh scripts/gh.ps1 run list --branch main --limit 1` and treat red as this run's work (**Corrected 2026-10-04:** the GitHub CLI is installed at `C:\Program Files\GitHub CLI` but is not on every session's PATH, so `scripts/gh.ps1` finds it and forwards the arguments); never `--no-verify`, `--amend` a pushed commit, force-push, or tag. Done when: the push and CI steps are explicit.
- [x] `.claude/skills/process-todo-file/SKILL.md` and `.claude/skills/groom-plan/SKILL.md`, adapted to `pwsh scripts/check-all.ps1` as the full suite and `python scripts/todo-graph.py` commands. Done when: no `dotnet`, `python3`, or ScratchPad path remains (`grep -rn "dotnet\|python3\|ScratchPad" .claude/skills` prints nothing).
- [x] `docs/phase-runs/README.md` (what a run file is, the two end markers) and the skill list in `AGENTS.md` "Choose the work contract"; `docs/reference-conventions.md` records that the run skills are now ported. Done when: `python scripts/check-docs.py` passes.
- [x] Commit: `"workspace: the run skills, process-plan to groom-plan (D00 T03 §2)"`

**Test checkpoint:** Static evidence: `python scripts/todo-graph.py validate` finds no dead ref in the skills, `python scripts/check-docs.py` prints `0 findings`, and every command the skills name runs with `-Help` or `--help` without error.

> **Verified:** 2026-10-04 | §2 | validate "17 files, 116 sections, 0 fatal, 0 warnings" (skill refs D00 T03 §3, §4 live); check-docs "0 findings"; `grep -rn "dotnet\|python3\|ScratchPad" .claude/skills` printed nothing (exit 1); plan --check "current"; query ready "7 runnable now, 5 runnable elsewhere"; query blocked exit 0; setup.ps1 -Verify "setup: all legs green" exit 0; setup.ps1, check-all.ps1, gh.ps1 -Help exit 0; `pwsh scripts/gh.ps1 run list --branch main --limit 1` "completed success ... main push 37164939910" exit 0 (`--json conclusion,headBranch` passed through); `gh.ps1 no-such-command` exit 1; gh missing from PATH, Program Files, and LOCALAPPDATA prints "gh.ps1: the GitHub CLI is not installed (winget install --id GitHub.cli)..." exit 1; all four skills carry name and description frontmatter; process-phase step 3 names `git push origin main` and the CI read; check-all "all gates passed" (build/check-all-d00t03s2.log, written after every changed file)
> **Implementer:** Claude (claude-opus-5-5)

## 3. The Run Guard: the Stop Hook and Its Probe

Without a guard a run dies quietly at the first end of turn. Port ScratchPad's `campaign-stop.ps1`, which blocks only the session named in the guard file, releases on closeout, park, or zero runnable rows, and trips a stall breaker after three blocks with no change to the tree.

- [x] `.claude/hooks/campaign-stop.ps1` (PowerShell 7 and Windows PowerShell compatible, fail open): reads `build/claude-campaign-guard.json` (`runner`, `workspace`, `phase`, `run_file`, `session_id`, `cron_id`) and writes `build/claude-campaign-state.json`; calls `python scripts/todo-graph.py query ready`. Done when: it matches ScratchPad's behaviour with `python` in place of `python3`.
- [x] `.claude/settings.json`: a `Stop` hook running it with `pwsh -NoProfile -File`, keeping `includeCoAuthoredBy: false` and the empty `attribution`. Done when: `python -m json.tool .claude/settings.json` succeeds and both attribution keys are unchanged.
- [x] `scripts/check-campaign-stop.ps1`: feeds the hook JSON payloads in a temp workspace copy and asserts: no guard allows; another session allows; an open run blocks with `"decision":"block"`; a `## Closeout` heading allows; a column-0 `PARKED` line allows; a fourth block with an unchanged tree allows and records a trip. `check-all.ps1` runs it. Done when: it passes, and breaking the session check makes it fail.
- [x] Commit: `"workspace: the run guard stop hook and its probe (D00 T03 §3)"`

**Test checkpoint:** Unit test: `pwsh scripts/check-campaign-stop.ps1` passes all six cases; `pwsh scripts/check-all.ps1` exits 0 with it included.

> **Verified:** 2026-10-04 | §3 | `pwsh scripts/check-campaign-stop.ps1` "check-campaign-stop: all 6 cases passed" exit 0 (no guard, another session, open run blocks, Closeout, PARKED, stall breaker); negative probe on a temp copy with the session check removed: "FAIL  another session is never blocked ... \"decision\":\"block\"", "1 of 6 cases failed" exit 1 (real hook untouched); diff against ScratchPad's hook: `python` first with `python3` fallback (missing interpreter allows), next-row filter `^D\d{2} T\d{2} ` (skips the operator-only "runnable elsewhere" lines), message names fresh-context review and todo/99-manual/ instead of the panel, comments only otherwise; `python -m json.tool .claude/settings.json` exit 0, `includeCoAuthoredBy` false, `attribution` commit "" and pr ""; the hook runs as `pwsh -NoProfile -ExecutionPolicy Bypass -Command` with `[Environment]::GetEnvironmentVariable('CLAUDE_PROJECT_DIR')` in place of `-File "$CLAUDE_PROJECT_DIR..."` so neither cmd nor bash expands a variable: the settings command line printed nothing exit 0 from bash and from a cmd batch with no guard, and printed `{"decision":"block",...}` from both against a probe workspace; Windows PowerShell 5.1 blocks the owner and allows another session; fail open: malformed stdin "campaign-stop: Conversion from JSON failed..." on stderr exit 0, empty stdin exit 0; check-all "run guard probe PASS 7,40", "check-all: all gates passed" (build/check-all-d00t03s3.log, written after every changed file); validate "17 files, 116 sections, 0 fatal, 0 warnings"; check-docs "0 findings"
> **Implementer:** Claude (claude-opus-5-5)

## 4. The UI Driver for Driven Runs

A driven run an agent cannot perform is not unattended. This section gives every surface section a scripted way to launch, drive, capture, and read back, and a rule that every interactive control carries an `AutomationProperties.AutomationId` (which is also what Narrator and Accessibility Insights read).

- [ ] `tests/ui/SpellbookUia.psm1` (PowerShell 7, `Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes`): `Start-Spellbook` (launches the build with `--data-dir <temp>` and waits for the main window), `Get-Element -AutomationId`, `Invoke-Element`, `Set-ElementValue`, `Send-Keys` (SendInput), `Save-Capture` (window PNG through `PrintWindow` with `PW_RENDERFULLCONTENT`, at the machine's native scale, file name records the DPI), `Read-Log`, `Stop-Spellbook`. Done when: each function has comment-based help.
- [ ] `tests/ui/dbread.py`: stdlib `sqlite3`, opens a database read-only (`file:...?mode=ro`) and prints a query's rows as JSON. Done when: it reads `PRAGMA user_version` from a smoke database.
- [ ] `scripts/drive.ps1 -Scenario <name> [-Config Debug|Release] [-Keep]`: runs `tests/ui/scenarios/<name>.ps1` with the module loaded, writes captures to `docs/captures/<scenario>/` and logs to `build/drive/`, exits non-zero on any failed assertion. Done when: `-Help` documents it.
- [ ] `tests/ui/scenarios/shell.ps1`: launches, asserts the window title is `Spellbook` and the empty-state heading exists by AutomationId, captures, closes, asserts `spellbook.log` has the starting and exiting lines and `user_version` is the latest schema. Done when: `pwsh scripts/drive.ps1 -Scenario shell` exits 0.
- [ ] `standards/ui.md` and the `winui-patterns` skill: every interactive control has an `AutomationProperties.AutomationId` (kebab-case, stable) and an accessible name from the vocabulary table. Done when: both say so.
- [ ] Commit: `"workspace: the UI Automation driver for driven runs (D00 T03 §4)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario shell` exits 0 and writes `docs/captures/shell/main-window-<dpi>dpi.png`; changing the expected title in the scenario makes it exit 1.

## 5. Unattended Proof Rules and the Checkpoint Sweep

The proof table assumed a person. This section rewrites it for an agent and fixes every open checkpoint that still needs one, moving the genuinely human checks to the operator's visual pass.

- [ ] `todo/README.md` proof table: a driven run is `pwsh scripts/drive.ps1 -Scenario <name>` with a scenario committed by the section; captures are taken at the machine's native scale; checks at other display scales, with Narrator, and on a clean machine belong to `D99 T01 §10` and `D99 T01 §6`, never to a feature section. `standards/testing.md` says the same. Done when: `check-docs.py` passes.
- [ ] Sweep every open section outside `todo/99-manual/` for a checkpoint that needs a person ("clean VM", "200 percent", "Narrator", "operator confirms", "by eye") and rewrite it to an agent-provable form, adding a `**Corrected YYYY-MM-DD:**` note; move the human remainder to `D99 T01 §10` as an item naming the section. Done when: `grep -rn -i "clean windows 11 vm\|200 percent\|narrator\|by eye" todo/0[0-5]*` prints only lines inside stamped sections or lines naming `D99 T01 §10`.
- [ ] Commit: `"todo: unattended proof rules and the checkpoint sweep (D00 T03 §5)"`

**Test checkpoint:** Static evidence: the grep above, quoted; `python scripts/todo-graph.py validate` clean; `python scripts/todo-graph.py query ready` lists no operator-only work as runnable now.

## 6. Independent Codex Writer Workflow and Supervised Runner

Operator decision 2026-10-08: make Codex the primary writer, with separate skills, hooks, instructions, configuration, and state. Share scripts conservatively only when they are agent-neutral repository gates. Existing Claude skills, lifecycle hooks, settings, and run records remain independent; turn `CLAUDE.md` into standalone instructions so it no longer imports the Codex writer contract.

- [x] Assign Codex the writer role in `AGENTS.md` and preserve the Claude workflow in standalone `CLAUDE.md`. Done when: neither instruction file imports the other and both forbid concurrent writers.
- [x] Add independent Codex-discoverable skills under `.agents/skills/`. Done when: all fourteen contracts resolve locally, preserve section checkpoints and fresh-context review, and never call Claude tools or load Claude skills.
- [x] Add `.codex/scripts/campaign.py` and `run-plan.ps1`. Done when: the supervisor locks out concurrent Codex runs, checks the plan in agent context, resumes only its recorded session, preserves pause and recovery evidence, and stops after bounded failures or lack of progress. Cheaper substitute: an unbounded loop that resumes the latest unrelated session.
- [x] Add `.codex/hooks.json`, `.codex/hooks/`, and independent `.codex/githooks/`. Done when: native Stop and Interrupt events respect ownership and pause, unrelated sessions pass, and Codex commits validate the staged tree without changing Claude's hook configuration.
- [x] Add `.codex/tests/` and `.codex/scripts/check-workflow.py`, wire them into repository gates and CI, and validate both skill trees through `scripts/todo-graph.py`. Done when: regression cases cover guard ownership, no work, closeout, phase scope, stall, pause/resume, CLI failures, and isolation.
- [x] Document invocation, trust, recovery, limitations, and the shared-script boundary in `docs/dev/codex.md` and update `CHANGELOG.md`. Done when: a fresh Codex session can audit and start the runner from the documented commands without assuming Claude tools or automatically activating a campaign.
- [x] Commit: `"workspace: establish an independent Codex writer workflow (D00 T03 §6)"`

**Test checkpoint:** `python .codex/scripts/check-workflow.py`, `python -m unittest discover -s .codex/tests -v`, `pwsh .codex/scripts/run-plan.ps1 -Action audit`, and `pwsh scripts/check-all.ps1` exit 0; an independent reviewer verifies the candidate and quotes the results. Use temporary fixtures for campaign mutation and CLI simulation; setup must not start real plan execution.

> **Verified:** 2026-10-08 | §6 | Independent review of base `fcc2b83a0702a2039d78b2cd66675654d24962df` plus all tracked and untracked candidate changes. `python .codex/scripts/check-workflow.py`: "codex workflow: 14 skills, 0 findings", exit 0; `python -m unittest discover -s .codex/tests -v`: "Ran 22 tests in 15.832s", "OK", exit 0 (`build/review-codex-campaign-tests.log`); `pwsh .codex/scripts/run-plan.ps1 -Action audit`: "7 runnable now, 3 runnable elsewhere", "codex campaign: audit passed; no run started", exit 0 (`build/review-codex-audit.log`); independent `pwsh scripts/check-all.ps1`: all 19 gates PASS, "check-all: all gates passed", exit 0 (`build/review-check-all-codex-writer.log`). Regression cases prove exact-session resume, pause preservation, worker ownership after supervisor interruption, exclusion of committed run-record chatter from progress, bounded failures, phase scope, and unrelated-session isolation. Native hook transport was tested with temporary fixtures; project hook trust remains an operator/session prerequisite, and no real implementation campaign was started.
> **Implementer:** Codex (GPT-6; exact model ID unavailable).
> **Reviewer:** Independent fresh-context Codex reviewer (GPT-6; exact model ID unavailable).

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `python scripts/todo-graph.py validate` clean
- [ ] A `process-plan` run started in a fresh session reaches its first section without operator input
