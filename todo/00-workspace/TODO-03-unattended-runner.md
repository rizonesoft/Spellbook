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

**Corrected 2026-10-08:** The operator requires full automated visual testing. Launch smoke, UI interaction, and saving a screenshot are each insufficient on their own: the acceptance loop must drive the required UI states, capture actual rendered images across the required display/theme matrix, inspect those images, detect regressions, and refuse acceptance on missing or failed evidence. Sections §4, §9, and §5 implement that loop. They remain unimplemented; a passing runner readiness audit or the current 21 gates does not prove visual readiness. The operator's visual pass is supplementary and cannot replace this automated gate.

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
- -> XREF: D99 T01 §10 -- supplementary human visual and screen-reader feedback, never a replacement for the automated visual gate

## Outcome

- `python scripts/todo-graph.py query ready` ends with `N runnable now, M runnable elsewhere`, where elsewhere means operator-only; `resolve` exits 5 for an operator-only section.
- `process-plan`, `process-phase`, `process-todo-file`, and `groom-plan` exist under `.claude/skills/`, adapted to Spellbook's gates, its push-per-section rule, and its fresh-context reviewer.
- A Stop hook holds a run's session until the run file has a closeout or a park, and releases it after three blocks with no change to the tree.
- `pwsh scripts/drive.ps1 -Scenario <name>` launches Spellbook against a temporary data folder, drives it by AutomationId, saves captures, and reads the database back.
- `pwsh scripts/visual-test.ps1 -Scenario <name>` runs the automated visual matrix, checks its evidence manifest and baseline comparisons, and supplies real images to independent reviewers; a capture alone cannot produce an accepted visual result.
- No open section outside `todo/99-manual/` needs a person to pass its checkpoint.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Operator-only work in the graph: runnable now and elsewhere | -- |  [x]   |
|   2   |   §2    | The run skills: process-plan, process-phase, process-todo-file, groom-plan | §1 |  [x]   |
|   3   |   §3    | The run guard: the Stop hook and its probe | §2 |  [x]   |
|   4   |   §4    | The UI driver for driven runs | D00 T02 §3 |  [ ]   |
|   5   |   §5    | Unattended proof rules and the checkpoint sweep | §4, §9, D00 T02 §6 |  [ ]   |

|   6   |   §6    | Independent Codex writer workflow and supervised runner | §1, §2, §3 |  [x]   |
|   7   |   §7    | Switch the primary writer between Codex and Claude | §6 |  [x]   |
|   8   |   §8    | Sequential global-configured Codex and latest-Sonnet review | §7 |  [x]   |
|   9   |   §9    | Automated visual matrix, image review, and acceptance gate | §4, §8, D00 T02 §6 |  [ ]   |

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

A driven run an agent cannot perform is not unattended. This section gives every surface section a scripted way to launch, drive, capture, and read back, and a rule that every interactive control carries an `AutomationProperties.AutomationId` (which is also what Narrator and Accessibility Insights read). This is the interaction/capture foundation, not the completed visual acceptance gate; §9 adds the matrix and actual image review. The earlier WinUI shell is bootstrap infrastructure and must be exercised by §9 before later UI feature acceptance.

- [ ] `tests/ui/SpellbookUia.psm1` (PowerShell 7, `Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes`): `Start-Spellbook` (launches the build with `--data-dir <temp>` and waits for the main window), `Get-Element -AutomationId`, `Invoke-Element`, `Set-ElementValue`, `Send-Keys` (SendInput), `Save-Capture` (window PNG through `PrintWindow` with `PW_RENDERFULLCONTENT`, at the machine's native scale, file name records the DPI), `Read-Log`, `Stop-Spellbook`. Done when: each function has comment-based help.
- [ ] `tests/ui/dbread.py`: stdlib `sqlite3`, opens a database read-only (`file:...?mode=ro`) and prints a query's rows as JSON. Done when: it reads `PRAGMA user_version` from a smoke database.
- [ ] `scripts/drive.ps1 -Scenario <name> [-Config Debug|Release] [-Keep]`: runs `tests/ui/scenarios/<name>.ps1` with the module loaded, writes captures to `docs/captures/<scenario>/` and logs to `build/drive/`, exits non-zero on any failed assertion. Record scenario/state, build identity, actual window bounds/DPI/theme, image dimensions and hash, and assertion results in a machine-readable manifest; refuse missing, blank, stale, or wrong-window captures. Done when: `-Help` documents it and negative capture probes fail. Cheaper substitute: a PNG file exists but contains no usable evidence of the tested UI.
- [ ] `tests/ui/scenarios/shell.ps1`: launches, asserts the window title is `Spellbook` and the empty-state heading exists by AutomationId, captures, closes, asserts `spellbook.log` has the starting and exiting lines and `user_version` is the latest schema. Done when: `pwsh scripts/drive.ps1 -Scenario shell` exits 0.
- [ ] `standards/ui.md` and the `winui-patterns` skill: every interactive control has an `AutomationProperties.AutomationId` (kebab-case, stable) and an accessible name from the vocabulary table. Done when: both say so.
- [ ] Commit: `"workspace: the UI Automation driver for driven runs (D00 T03 §4)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario shell` exits 0 and writes `docs/captures/shell/main-window-<dpi>dpi.png`; changing the expected title in the scenario makes it exit 1.

## 5. Unattended Proof Rules and the Checkpoint Sweep

The proof table assumed a person. This section rewrites it for automated acceptance and fixes every open checkpoint that still needs one. Visual judgement and display-scale coverage stay in the automated contract; only supplementary human experience and genuinely external operator actions remain in operator sections.

- [ ] `todo/README.md` proof table and `standards/testing.md`: distinguish smoke, functional UI assertions, and visual acceptance. UI sections require §9's full automated matrix, image inspection, and candidate-bound evidence; an unavailable display environment or image-capable reviewer is a blocker, never a skipped PASS. Keep optional human visual/Narrator experience in `D99 T01 §10` and external clean-machine provisioning in `D99 T01 §6`, without waiving automated coverage. Done when: the standards and section review contracts agree and `check-docs.py` passes.
- [ ] Sweep every open UI section outside `todo/99-manual/`, adding a dated correction, concrete scenario/state coverage, and a dependency on §9 where it is not already transitive. Replace manual-only visual/DPI/theme checkpoints with the automated gate; retain keyboard and accessibility-tree assertions and identify any separate spoken-Narrator experience honestly. Update each agent's own `groom-plan`, `process-todo-section`, and `review-todo-section` skills independently so grooming cannot move required automated visual coverage to operator work. Done when: a recorded per-section audit shows every UI checkpoint has an executable scenario and no launch-only, screenshot-exists-only, or manual-only acceptance path; the dependency graph validates.
- [ ] Commit: `"todo: unattended proof rules and the checkpoint sweep (D00 T03 §5)"`

**Test checkpoint:** Static evidence: quote the per-section coverage audit and prove every open UI section names §9's gate and a scenario (or has a recorded non-UI reason). `python scripts/todo-graph.py validate` is clean and `query ready` lists no operator-only work as runnable now. Negative probe: remove a required scenario/receipt from a temporary candidate and prove its UI acceptance is refused, without asking a person to replace the missing automated proof.

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

## 7. Switch the Primary Writer Between Codex and Claude

Operator clarification 2026-10-08: either Codex or Claude must be selectable as the primary writer, with equal authority when selected. Keep their instructions, skills, hooks, runners, and runtime state independent. A small neutral selector may coordinate the choice; switching is not permission to start a run or transfer another agent's session.

- [x] Add `writer.json` and `scripts/writer.py` for status, explicit selection, and selected-writer assertions. Done when: either direction works, malformed selection fails closed, active runners refuse switching, and paused state is preserved byte for byte. Cheaper substitute: rewriting instructions while an old worker remains active.
- [x] Update `AGENTS.md`, `CLAUDE.md`, and each agent's own plan/phase/section skills. Done when: both consult the selection, neither silently selects itself, either may perform an explicit administrative switch, and independent review remains available to the other agent.
- [x] Integrate the selection check and transition lock into `.codex/scripts/campaign.py`; add Claude-only `.claude/scripts/write-campaign-guard.py` for serialized registration. Done when: start/resume/registration cannot race a selection change and a wrong-writer resume cannot clear pause.
- [x] Add selector tests in `scripts/test_writer.py` and separate runner tests under `.codex/tests/` and `.claude/tests/`; wire repository gates and CI. Done when: both directions, active locks/guards, malformed state, paused-state preservation, and wrong-writer registration/resume are proven with temporary fixtures.
- [x] Update `docs/dev/codex.md` and `CHANGELOG.md`. Done when: status and both switch commands are documented, along with active-run refusal and the independent-state boundary.
- [x] Commit: `"workspace: allow switching the primary writer (D00 T03 §7)"`

**Test checkpoint:** `python scripts/test_writer.py -v`, `python -m unittest discover -s .claude/tests -v`, `python -m unittest discover -s .codex/tests -v`, and `pwsh scripts/check-all.ps1` exit 0; `python scripts/writer.py status` reads the selected writer. Exercise both selection directions only in temporary fixtures; do not start real campaigns. An independent reviewer checks and stamps the candidate.

> **Verified:** 2026-10-08 | §7 | Independent review of `f3255a0ca6c8292e3e57119760fbe655f6a6da99` plus the complete tracked/untracked candidate tree. `python scripts/test_writer.py -v`: "Ran 7 tests", "OK"; `python -m unittest discover -s .claude/tests -v`: "Ran 4 tests", "OK"; `python -m unittest discover -s .codex/tests -v`: "Ran 23 tests", "OK". Tests prove both switch directions, active locks/guards, invalid selection, preserved paused state, serialized Claude registration, and wrong-writer resume refusal using temporary fixtures. `pwsh scripts/check-all.ps1`: exit 0, "check-all: all gates passed" (21 gates; full log `build/review-check-all-writer-switch.log`). `python scripts/writer.py status`: "primary writer: codex". No real campaign started or writer switched.
> **Implementer:** Codex (GPT-6; exact model ID unavailable).
> **Reviewer:** Independent fresh-context Codex subagent (GPT-6; exact model ID unavailable).

## 8. Sequential Codex and Sonnet Review for Either Writer

Operator decision 2026-10-08: every implemented section gets independent Codex review using its global model and effort, then a quick review using the latest Sonnet at high effort. Keep each agent's skills and runtime independently maintained; invoking the other native CLI for review is a narrow exception, not a shared runner or imported skill.

- [x] Update `AGENTS.md`, `CLAUDE.md`, and each agent's own review/section/phase skills. Done when: both primary writers require Codex first and Sonnet second, children execute only their assigned stage, and only the independent reviewer stamps after both approvals. Cheaper substitute: a writer-inherited subagent silently choosing a different model.
- [x] Document executable review commands, settings inheritance, model evidence, and latest-alias verification in each review skill and `docs/dev/codex.md`. Done when: Codex has no model/effort/profile override, Sonnet uses the rolling alias with explicit high effort, and stale aliases or incomplete reviews block shipping.
- [x] Bind both reviews to the complete tracked/untracked candidate and preserve failure handling. Done when: changed implementation requires both stages again; raw evidence, actual identities, and both verdicts are recorded; no review starts a campaign or changes writer selection.
- [x] Update `CHANGELOG.md` and prove the new sequence on this section. Done when: a real independent Codex review picks up current global settings, then an actual Sonnet review resolves the current alias at high effort, and the independent Codex reviewer checks both before stamping.
- [x] Commit: `"workspace: require sequential Codex and Sonnet reviews (D00 T03 §8)"`

**Test checkpoint:** `python .codex/scripts/check-workflow.py`, `python scripts/check-docs.py`, `python scripts/todo-graph.py validate`, and `pwsh scripts/check-all.ps1` exit 0. Execute the two real review stages on this candidate, capture Codex's effective model/effort and Sonnet's resolved model plus explicit high-effort invocation, and require both explicit approvals before stamping. Do not start a campaign, change global settings, or switch the writer.

> **Verified:** 2026-10-08 | §8 | Independent checkpoint exits 0: "codex workflow: 14 skills, 0 findings", "0 findings", "todo-graph validate: 17 files, 119 sections, 0 fatal, 0 warnings"; full `pwsh scripts/check-all.ps1` exits 0, "check-all: all gates passed" (21 gates; Debug and Release each "100% tests passed out of 29"; Release smoke exit 0). Evidence: `build/reviews/d00-t03-s8/stage1-evidence.md` and `stage1-check-all.log` in that directory. Both sequential reviews explicitly APPROVE with exit 0; all 186 candidate hashes matched before finalization. Sonnet's three non-blocking notes were examined: existing entrypoints route to the updated review skill, and the official configuration URL was verified.
> **Implementer:** Codex (GPT-6; exact writer model ID unavailable).
> **Reviewer:** Codex `gpt-6-astra`, effort `high`, session `01a11a51-904d-7952-9117-7e7af1ccf20c`, confirmed from the runtime header and matching global configuration. Candidate: base `d5d15208f10c7b799032040bf387ac43ec45b353` plus the complete tracked/untracked tree in `build/reviews/d00-t03-s8/candidate.json`, manifest SHA-256 `c0d9e56cb05bb43f347d73e48c0b2b14e7ce779fa2c48aa8e68061dca43416d4`. Report: `build/reviews/d00-t03-s8/codex-review.md`; identity: `build/reviews/d00-t03-s8/stage1-identity.json`; final candidate check: `build/reviews/d00-t03-s8/finalize-manifest-before.json`.
> **Second reviewer:** Claude `claude-sonnet-5-5`, alias `sonnet`, effort `high` by explicit invocation, CLI `2.1.294`, session `b665a556-ea17-4a65-b2b8-a2b834b5802f`. Runtime `modelUsage` identifies only that model on `firstParty`; result `subtype: success`, `is_error: false`; no separate effective-effort field is exposed. Report: `build/reviews/d00-t03-s8/sonnet-review.json`; invocation: `build/reviews/d00-t03-s8/sonnet-invocation.json`; current-alias and routing evidence: `build/reviews/d00-t03-s8/routing-evidence.json`.

## 9. Automated Visual Matrix, Image Review, and Acceptance Gate

**Added 2026-10-08:** Full automated visual testing was intended, but §4 stopped at driving and capturing, while §5 deferred visual judgement and display scales to a person. This section supplies the missing acceptance loop before Phase 1 UI work. It exercises the bootstrap shell from `D00 T02 §3`; future UI sections extend its scenarios as their surfaces are built. It must not claim testing of surfaces that do not exist yet.

- [ ] Add `tests/ui/visual-matrix.json` and `scripts/visual-test.ps1` over §4's driver. Cover each implemented surface/state in light and dark at actual 100, 150, and 200 percent display scaling, plus high contrast, minimum/default/resized windows, keyboard focus, and applicable empty/populated/error/disabled/overflow/long-text states. Record justified non-applicable states explicitly. Run in an isolated, provisioned interactive Windows test session or VM, never change the operator's display/theme settings. Done when: the shell matrix completes unattended and each case records observed DPI/theme/bounds; missing environments/cases fail rather than skip. Cheaper substitute: resize a screenshot or spoof a DPI field instead of rendering the application at that scale.
- [ ] Add reproducible fixture data, settling criteria, scenario assertions, UI Automation tree/bounds/focus snapshots, and baseline/actual/difference images under `tests/ui/` and `docs/captures/`. Detect clipping, overlap, missing controls/text/icons, wrong theme/contrast, and unexpected layout changes with declared tolerances/masks; preserve unmasked captures. Done when: deliberately clipped/hidden/wrong-theme/blank-capture fixtures fail and the correct fixtures pass. First baselines require independent visual approval; an implementation run cannot auto-accept its own changed baseline.
- [ ] Extend each agent's own review skill and review invocation independently: the full Codex reviewer must actually inspect candidate images, followed by the quick Sonnet/high reviewer inspecting the required visual set. Preserve Codex global model/effort and the dynamic Sonnet alias. Supply images through each CLI's supported image input, verify image capability, and record which image hashes were inspected with an explicit visual verdict. Bound review batches so every required capture is examined; a text-only summary or an exhausted review limit cannot approve unseen images. Done when: both reviewers identify an injected visible defect and missing image capability/evidence blocks acceptance. No shared agent skills, hooks, or campaign scripts.
- [ ] Implement candidate-bound visual evidence preparation and final receipt acceptance in `check-all.ps1`, each agent's own section/phase/review workflow, and the Windows CI job. Use an explicit `-ReviewStage Prepare` path to run builds, all deterministic gates, scenarios/capture/comparison, and freeze a hashed artifact bundle; its successful result is labelled `pre-review checks passed; visual acceptance pending`, never final acceptance. Codex Stage 1 runs/inspects that preparation before approving; Sonnet Stage 2 then inspects the frozen images. Only afterward may the independent Codex finalizer issue the two-verdict receipt and call `-ReviewStage Verify -Evidence <manifest>` against the exact frozen bundle without rebuilding or recapturing it. Bind the bundle and receipt to source/build identity, fixtures/scenarios/matrix, images, baselines, gate results, both reviewers and verdicts; require all mandated cases. Default UI acceptance, stamping, and shipping require Verify success; Prepare cannot waive it. Done when: a fresh candidate with no prior receipt completes Prepare -> Codex -> Sonnet -> receipt -> Verify, while absent/stale/rejected/missing-case evidence fails final acceptance. Declare and test only the narrow stamp/derived-plan metadata allowance.
- [ ] Retain/upload the approved artifact bundle and receipt for CI verification without model credentials. The CI visual job downloads that bundle, checks all hashes and its source-tree identity against the checkout (with the declared metadata allowance), then runs Verify without replacing the reviewed executable or images. A separate CI build does not inherit approval for a different binary; promoting a rebuilt artifact requires its own capture/review cycle. Done when: the original approved bundle verifies unchanged, replacing its executable/image/fixture/matrix invalidates approval, and a missing bundle blocks the visual job instead of rebuilding its way to a false PASS.
- [ ] Add a readiness report separating `runnable infrastructure` from `visual acceptance ready`, and make §5's sweep block later UI acceptance until §4 and this section are verified. Document isolated Windows display provisioning, recovery/artifact retention, baseline changes, and how to inspect failures in `docs/dev/visual-testing.md`. Keep machine/model access failures visible and retryable; no manual screenshot substitution. Done when: the current bootstrap workflow cannot advertise full visual readiness before the actual matrix and image-review proof exists.
- [ ] Commit: `"workspace: automate visual matrix and image acceptance (D00 T03 §9)"`

**Test checkpoint:** Start with no receipt: `pwsh scripts/check-all.ps1 -ReviewStage Prepare` runs all deterministic gates plus `pwsh scripts/visual-test.ps1 -Scenario shell`, producing the complete matrix with observed display settings, assertions, usable images, and a frozen artifact bundle labelled pending. Both independent reviewers inspect those images and approve; the finalizer issues the receipt, then `pwsh scripts/check-all.ps1 -ReviewStage Verify -Evidence <manifest>` and CI's downloaded-bundle verification pass without rebuilding/recapturing. Quote successful evidence for this fresh-candidate sequence and nonzero final-acceptance results for the injected-defect, absent/stale receipt, missing case, and replaced executable/fixture/image/baseline probes. No model credentials are supplied to CI. Commands named here are deliverables of this open section, not claims that they exist today.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `python scripts/todo-graph.py validate` clean
- [ ] A `process-plan` run started in a fresh session reaches its first section without operator input
