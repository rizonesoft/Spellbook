# Reference Conventions

What Spellbook copied from the operator's existing repositories, read on 2026-10-04 at `R:\GitHub\Isotone` (`rizonesoft/Isotone`, the operator's named best example), `R:\GitHub\Resolute` (`rizonesoft/Resolute`), and `R:\GitHub\ScratchPad` (`rizonesoft/ScratchPad`). Where they establish a convention, Spellbook copies it; where Spellbook diverges, the last section says where and why.

All three share one lineage: Isotone's TODO system is "a port of the Resolute TODO system (2026-09-26), which was itself a port of the ScratchPad and Intelligent Notepad ones" (`Isotone/todo/README.md`). Isotone and ScratchPad are C# (.NET, WPF and WinUI 3); Resolute is the only C++ one (CMake, llvm-mingw).

## 1. The todo system

| Aspect | The reference convention | Spellbook |
| ------ | ------------------------ | --------- |
| Location | `todo/` with `README.md` (the format spec), `TODO-00-INDEX.md` (domain order and active work), `implementation-plan.md`, `backlog.md`, and one folder per domain | Same |
| Domains | `NN-kebab-name/` with an `INDEX.md` (TODOs table, Completed table, In scope, Out of scope); flat-numbered in allocation order; `99-manual` for operator-only work | Same. Domains follow the milestones (`00-workspace` to `05-ship`) plus `99-manual` |
| Files | `TODO-NN-short-name.md`, NN local to the domain, never reused | Same |
| Frontmatter | `schema_version`, `id` (kebab-case, unique), `domain`, `status` (draft, active, blocked, done, superseded), `title: "TODO-NN -- Title"`; optional `depends_on`, `frozen`, `track`, `superseded_by` | Same (no `track`) |
| Anatomy | Goal, Current state (`> [!IMPORTANT]`, dated), Inputs (with `-> XREF:`), Outcome (with an Adjacency line), Implementation Order table, `## N.` sections, `## Verification` last | Same, without the Adjacency line |
| IDs and references | `§N`, `TNN §N`, `DNN TNN §N`; XREFs must point both ways | Same |
| Statuses | The Implementation Order row `[ ]` or `[x]`, flipped only with a `> **Verified:**` stamp; `Deferred:` and `Resolved:` lines with owners | Same |
| Items | `- [ ]` micro-steps: one action, a named path, `Done when:`, the cheaper substitute, max 30 per section; a final `Commit:` item; a falsifiable `**Test checkpoint:**` | Same |
| Tooling | `scripts/todo-graph.py` (stdlib Python): validate, plan --sync/--check, query, resolve, self-test; enforced by the pre-commit hook and CI | Same commands, in a compact port (see divergences) |

## 2. The plan file

`todo/implementation-plan.md` in all three: a title, a generated `> **Progress:** **N of M sections complete (P%).**` line, "How to use this" with a paste-ready row (`process todo section: | [ ] | \`D00 T01 §1\` | ... |`), an IMPORTANT callout that the boxes are derived and never ticked by hand, "The acceptance bar" (an Aim to Owned-by table), then `### Phase <N> -- <Title>` headings, each with one paragraph and one `| ✔ | Section | Deliverable | Items |` table. Every section sits in exactly one row; `plan --sync` rewrites boxes and counts, `plan --check` gates CI. Spellbook copies this, mapping milestones M0 to M5 to Phases 0 to 5, and keeps Resolute's closing "What this plan deliberately does not do".

## 3. Agent setup

| Aspect | The reference convention | Spellbook |
| ------ | ------------------------ | --------- |
| Rules file | `AGENTS.md` is canonical; `CLAUDE.md` is a stub: "See @AGENTS.md" | Same |
| AGENTS.md shape | What the project is (a path table), the decisions it runs on, the TODO system, choose the work contract, what counts as proof (five proofs), working rules, the commit hook, unknowns, validation commands, credentials | Same order, plus Layering, Code style, and the Definition of done the brief asks for |
| Skills | `.claude/skills/<name>/SKILL.md`, frontmatter `name` and `description` only ("what -- detail. Use when ..."); TODO skills add-todo, create-todo (with `todo-template.md`), process-todo-section, review-todo-section, process-todo-file, process-phase, process-plan, groom-plan | `.claude/skills/` with the same frontmatter; the four core TODO skills plus the engineering skills the brief asks for |
| Agents | `.claude/agents/*.md` delegates (Sonnet, read-only or docs-only) | Not copied (see divergences) |
| Settings and hooks | `.claude/settings.json` with `includeCoAuthoredBy: false` and empty `attribution`; Stop and PreToolUse hooks for the campaign guard and model pins | The attribution settings only |
| Workflows | No separate workflows folder: the skills are the runbooks | Same: `add-feature`, `fix-bug`, and `release` are the runbooks |

## 4. Runners and scripts

| Aspect | The reference convention | Spellbook |
| ------ | ------------------------ | --------- |
| Language | PowerShell (`#Requires -Version 7.0` in Isotone, 5.1 in ScratchPad's tools), comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`), `[CmdletBinding()]`, `$ErrorActionPreference = 'Stop'`, `Split-Path -Parent $PSScriptRoot` for the root | Same, PowerShell 7 |
| Shared helpers | `scripts/_common.ps1`, dot-sourced, with `Write-Step` and `Invoke-Native` (Isotone) | Same file and functions |
| Parameters | `-Config Debug|Release` (Isotone, Resolute), `-SkipBuild`, `-Verify`, `-Filter` | Same names |
| One gate command | `scripts/check-all.ps1`: every gate runs, a PASS/FAIL table, exit 1 on any failure | Same |
| Provisioning | `tools/provision.ps1` with legs and `-Verify` (Isotone); `toolchain.json` pins with SHA-256 and a repo-local tool folder (Resolute's `reskit/`, Isotone's `.tools/`) | `scripts/setup.ps1` with legs and `-Verify`, `toolchain.json`, `.tools/` |
| Python | stdlib-only gates with `--self-test`, `file:line:rule:message` output | Same (`todo-graph.py`, `check-layering.py`, `check-docs.py`) |
| Editor tasks | No `.vscode/tasks.json` or `launch.json` in any of the three (Resolute has only `settings.json`) | None, as the brief allows ("if the reference repos do this") |

## 5. README style

Isotone's is the "premium" one: a centred `<div>` with a `<picture>` wordmark (dark and light SVG sources), a two-line pitch, a badge block (workflow badges, then shields.io flat badges for release, license, runtime, platform, with logos), a cover image with an italic caption saying what it is, a `> [!NOTE]` status callout, a Contents list, "Why <name>" bullets in bold-lead style, a Features table with the legend ✅ 🚧 📋, a Mermaid architecture diagram, `<details>` blocks for the stack and the layout, Download, Build from source, Versioning, Roadmap, Contributing, License, Acknowledgements, and a centred footer. Resolute and ScratchPad are plainer (no banner; ScratchPad has a hero screenshot). Spellbook copies Isotone's style.

## 6. GitHub configuration

| Item | The reference convention | Spellbook |
| ---- | ------------------------ | --------- |
| Workflows | Isotone: `build.yml` (windows, push and PR to main, `concurrency`, `permissions: contents: read`), `plan.yml` (the TODO gates and a hook mode check), `release.yml` (tag-driven); actions pinned by SHA with a version comment | `ci.yml` (build and test job plus a plan-gates job with the hook check) and `release.yml`, with Isotone's exact action pins |
| Issue templates | Isotone: YAML forms `bug_report.yml` (`[Bug]: `, labels bug and triage), `feature_request.yml` (`[Feature]: `), `config.yml` with blank issues off and security and website links. Resolute and ScratchPad use Markdown templates | Isotone's YAML forms |
| PR template | Summary, Plan reference (`DNN TNN §N`), area checkboxes, how tested, a checklist | Same shape |
| Dependabot | Isotone: NuGet and GitHub Actions, weekly on Monday, grouped | GitHub Actions only (vcpkg is not a Dependabot ecosystem) |
| FUNDING | `github: rizonesoft` | Same |
| CODEOWNERS, labels file | None in any of the three | No CODEOWNERS; a `labels.yml` record because the brief asks for a labels list |

## 7. Code style

| Aspect | The reference convention | Spellbook |
| ------ | ------------------------ | --------- |
| Line endings | `.gitattributes`: `* text=auto`; LF for scripts, docs, YAML, JSON, hooks; CRLF for Windows-native sources and project files; binaries marked | Same, with C++ and `.rc` as the Windows-native sources |
| EditorConfig | UTF-8, LF, 4 spaces, final newline, trimmed whitespace; CRLF for native sources; 2 spaces for XML, JSON, YAML; Markdown keeps trailing spaces | Same layout rules (the C# analyzer block does not apply) |
| C++ formatting | None committed in any of the three: Resolute formats by review | `.clang-format` (see divergences) |
| Static analysis | Resolute's `.clang-tidy`: bugprone, clang-analyzer, performance, misc; modernize and readability out; each exclusion with its reason | Copied, with the reasons |
| Warnings | Resolute's `cmake/ResoluteWarnings.cmake`: per-target policy plus a configure-time completeness audit | Copied as `cmake/SpellbookWarnings.cmake`, with MSVC flags |
| Naming (C++) | Resolute: namespace `rui::`, include prefix `resolute/`, PascalCase files | Namespace `spellbook::`, include prefix `spellbook/`, but snake_case files (see divergences) |
| Commits | The real history of all three: `<area>: <imperative lowercase summary>` with the plan ref (`workspace: convert UI suite to focus-free input (D00 T02 §10)`); areas like workspace, todo, docs, brand. Trunk-based main, one section per commit, no `--no-verify`, no amending, no force-push | Same |
| Hooks | `tools/githooks/pre-commit` (POSIX sh, LF, mode 100755) validating the staged tree in a temp checkout; `commit-msg` stripping AI attribution (Isotone); `core.hooksPath` set by provisioning | Same files |
| Prose | No em dashes; one line per paragraph and list item; `--` in titles | Same, checked by `scripts/check-docs.py` |

## Divergences, and why

| Where | The reference does | Spellbook does | Why |
| ----- | ------------------ | -------------- | --- |
| TODO tooling size | Isotone's `todo-graph.py` is 11,257 lines plus about 18,000 more across claims, findings, runs, panel, campaign guard, and design-lint scripts | A 640-line `scripts/todo-graph.py` keeping the core contract (parity, stamps, partial flips, deps, cycles, XREF reciprocity, stale deferrals, plan sync, index listing, skill refs) | Those scripts enforce machinery Spellbook does not run (below). Copying them would fail on files that do not exist here, or need them all |
| Review panel and campaigns | `.conclave/panel.toml` (GPT reviewer slots), `.claude/agents/` delegates, `campaign_guard.py` with a Stop hook, `process-phase`, `process-plan`, `groom-plan`, `process-todo-file` skills, `docs/reviews/` and `docs/phase-runs/` | Not copied. `review-todo-section` asks for a fresh-context reviewer instead | A single-developer app at M0 has no external review panel or unattended campaigns to guard. They can be ported when one runs |
| Budget, backlog ratchets, claims, design lines | `budget.json`, `.warning-baseline`, `.design-baseline`, `<!-- claim: -->` re-measurement, `**Design:**` and `**Fidelity:**` lines against `docs/design/` | A plain `backlog.md` in the same line format; no claims or design lines | There is no design-system repo for Spellbook and no budget decisions yet; `Job:`, `Treatment:`, `Chrome:` are kept because they carry over |
| Adjacency line | Every TODO Outcome carries a nine-key `**Adjacency:**` declaration | Omitted | Its keys (permissions, audit, reporting) are tuned for creative suites; the surface rules in `todo/README.md` cover what matters here |
| Skills folder | `.claude/skills/` | Same, not `.agents/skills/` as the brief's default | The brief says to match the reference layout |
| Plan and TODO file names | `todo/implementation-plan.md` and the `todo/` tree | Used instead of root `PLAN.md` and `TODO.md` | The brief allows "the reference repos' equivalents", and two plans would drift |
| Setup script location | `tools/provision.ps1` | `scripts/setup.ps1` | The brief names the script; `tools/` keeps the git hooks, as Isotone |
| `Invoke-Native` | `$file, $rest = $args` | `$rest` forced to an array | Isotone's form splats a lone argument one character at a time; found by the first `setup.ps1` run (`bootstrap-vcpkg.bat -disableMetrics` arrived as `- d i s ...`) |
| Version source | MinVer from tags with per-app prefixes (`stilus-v*`) | `git describe` in CMake, one prefix `v*` | One app, and no MSBuild |
| Binary distribution | Isotone ships binaries only from rizonesoft.com; a GitHub release carries no installer or ZIP | The release workflow attaches the ZIP and `SHA256SUMS` (and the installer from M5) | The brief asks for "attach artifacts"; open question 3 in the initialisation report asks whether to follow Isotone instead |
| License | GPL-3.0 with DCO sign-off (Isotone) | MIT, no DCO sign-off | The brief chose MIT; DCO was tied to Isotone's GPL contributor terms |
| Commit convention in CONTRIBUTING | Isotone's CONTRIBUTING.md and `standards/shared.md` say Conventional Commits (`feat(stilus): ...`), but its history (and Resolute's and ScratchPad's) uses `<area>: <summary>` | `<area>: <summary>`, everywhere | The brief says to use the reference convention, and the history is what the repos actually do |
| C++ formatting | No `.clang-format` in any reference | `.clang-format` based on Microsoft style, Allman braces, 110 columns, include regrouping that keeps `<windows.h>` first | The brief requires a format check; no reference convention exists to copy |
| C++ file names | Resolute: PascalCase files (`Settings.h`) | `snake_case.cpp` and `.hpp` | Matches the snake_case function style chosen for a std-like codebase; Resolute's naming follows its llvm-mingw and Direct2D code |
| Docs layout | Isotone: `docs/dev/architecture.md` | `docs/architecture.md`, `docs/adr/`, `docs/dev/build.md` | The brief names `docs/architecture.md` and ADRs |
| Workflow file names | `build.yml` and `plan.yml` | `ci.yml` (with a plan-gates job) | The brief names `ci.yml` |
| CI runner | `windows-2025` pinned | `windows-latest` | The brief names `windows-latest`; the scripts accept VS 2022 or newer, so an image change does not break CI |
