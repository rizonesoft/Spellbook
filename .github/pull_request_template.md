## Summary

<!-- What does this change do, and why? One or two sentences. -->

## Plan reference

<!-- The TODO section this implements, as `DNN TNN §N` (for example `D01 T01 §2`), or the issue it fixes. -->

- Plan: `DNN TNN §N`
- Fixes: #

## Area

- [ ] Core (`src/core`)
- [ ] Storage or migrations (`src/storage`, `migrations/`)
- [ ] UI (`src/app`)
- [ ] Scripts, CI, or tooling
- [ ] Documentation

## How was this tested?

<!-- Tests added or updated (by name), and the driven checks with what they showed (screenshots for UI changes). -->

## Checklist

- [ ] `pwsh scripts/check-all.ps1` is green locally
- [ ] Every new public core function has a unit test; a bug fix has a test that failed before the fix
- [ ] A schema change is a new file in `migrations/`, never an edit to a shipped one
- [ ] The TODO section is updated and `python scripts/todo-graph.py plan --sync` was run
- [ ] Docs updated (`docs/user/` for anything a user sees, `docs/` for architecture or build changes)
- [ ] `CHANGELOG.md` has an entry under **Unreleased** for anything a user notices
- [ ] Commits follow `<area>: <imperative lowercase summary>` (see CONTRIBUTING.md)
