# Contributing to Spellbook

Thank you for helping build Spellbook. This guide covers how work is organised, how to build and test, and what a pull request needs before it can merge.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Security problems go through the private process in [SECURITY.md](SECURITY.md), never through public issues.

## Contents

- [Ways to contribute](#ways-to-contribute)
- [How work is organised: the TODO tree](#how-work-is-organised-the-todo-tree)
- [Set up and build](#set-up-and-build)
- [Code style](#code-style)
- [Commit messages](#commit-messages)
- [Pull requests](#pull-requests)
- [Licensing](#licensing)

## Ways to contribute

- **Report a bug** with the [bug report form](https://github.com/rizonesoft/Spellbook/issues/new?template=bug_report.yml): the version, your Windows version, steps, and the log lines.
- **Suggest a feature** with the [feature request form](https://github.com/rizonesoft/Spellbook/issues/new?template=feature_request.yml). Describe the problem first, then the solution.
- **Improve the docs**: fixes to `docs/` and the README are always welcome.
- **Send code**: pick a ready section from the plan (below) or an issue labelled `help wanted`, and say so on the issue before starting larger work.

## How work is organised: the TODO tree

The plan lives in the repository, not in a tracker.

- [`todo/`](todo/) holds one folder per milestone, one file per subject, and numbered sections inside each file. Start with [`todo/README.md`](todo/README.md).
- [`todo/implementation-plan.md`](todo/implementation-plan.md) is the ordered plan. `python scripts/todo-graph.py query ready` lists the sections whose dependencies have shipped.
- Every section has checkbox items with a "Done when" condition, and a test checkpoint. A section is finished when its checkpoint passes, not when the code compiles.
- Sections are referenced as `DNN TNN §N` (domain, file, section), for example `D01 T01 §2`. Use that reference in commits and pull requests.
- **Every change updates its TODO section and the plan** in the same commit: tick the items, and run `python scripts/todo-graph.py plan --sync`. The pre-commit hook refuses a tree that does not validate.

If your change has no section, open an issue first so it can be planned. Typos and obvious one-line fixes do not need one.

## Set up and build

You need Windows 10 22H2 or 11 (x64), Visual Studio 2026 with Desktop development with C++ (v145), a Windows SDK, and `Microsoft.VisualStudio.Component.WindowsAppSdkSupport.Cpp`, PowerShell 7, Git, and Python 3. Everything else is pinned in `toolchain.json` and provisioned into `.tools/`.

```powershell
git clone https://github.com/rizonesoft/Spellbook.git
cd Spellbook

pwsh scripts/setup.ps1        # pinned toolchain into .tools/, and the git hooks
pwsh scripts/build.ps1        # Debug build
pwsh scripts/test.ps1         # unit tests
pwsh scripts/run.ps1          # launch
pwsh scripts/check-all.ps1    # every gate CI runs
```

If `check-all.ps1` is green locally, CI should be green too. Details: [docs/dev/build.md](docs/dev/build.md).

## Code style

- **Formatting** is `.clang-format`: run `pwsh scripts/format.ps1` before committing; CI checks it.
- **No warnings:** `/W4 /WX` for our code. Fix a warning, never suppress it without a recorded reason.
- **Layers:** `core` (no Windows headers) <- `storage` <- `app`. Logic belongs in core, where it can be tested; the Win32 layer stays thin. `scripts/check-layering.py` enforces the includes.
- **Tests:** every public core function has a unit test; a bug fix comes with a test that failed before the fix.
- **Schema changes** are new files in `migrations/`, never edits to a shipped one.
- **UI copy** follows [`standards/ui.md`](standards/ui.md), including the theme vocabulary: themed words in labels, plain words in code.
- **Docs:** user-visible changes update [`docs/user/`](docs/user/README.md) and the `CHANGELOG.md` Unreleased section.
- **Prose:** no em dashes (use `--`, a colon, or a new sentence), one line per paragraph in Markdown.
- The full rules: [`standards/`](standards/README.md).

## Commit messages

`<area>: <imperative lowercase summary>`, with the plan reference in parentheses or in the body: the convention of the other Rizonesoft repositories.

```text
storage: prompt create, read, update, delete, and list (D01 T01 §1)
app: the Import scrolls preview dialog (D02 T01 §4)
docs: the find and cast guide and the shortcut table
```

Areas: `workspace`, `core`, `storage`, `app`, `todo`, `docs`, `ci`, `installer`, `brand`, `release`. Keep the summary under about 72 characters. One section is one logical change.

## Pull requests

1. Fork and branch from `main` (`library/prompt-crud`, `fix/import-utf16`).
2. Keep each pull request to one section or one fix.
3. Fill in the pull request template: the plan reference, what changed, and how you tested it.
4. Before requesting review: `pwsh scripts/check-all.ps1` is green, docs and the changelog are updated, the TODO section is ticked.
5. A maintainer reviews, may ask for changes, and merges once CI is green.

Do not bump version numbers: versions come from git tags (`standards/release.md`).

## Licensing

Spellbook is released under the [MIT License](LICENSE). By contributing, you agree that your contribution is licensed under the same terms. Do not submit code copied from projects with incompatible licenses or from sources you are unsure about; when you include third-party code under a compatible license, keep its notice and mention it in the pull request.
