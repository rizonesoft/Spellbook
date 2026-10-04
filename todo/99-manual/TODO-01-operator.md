---
schema_version: 1
id: operator-steps
domain: 99-manual
status: active
title: "TODO-01 -- Operator Steps"
depends_on: []
---

# TODO-01 -- Operator Steps

> **Goal:** The steps no agent session can or should take on its own (creating and configuring the GitHub repository, deciding ownership, and accepting the import of real prompts) are listed with exact commands, so they never stall a runner silently.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** The operator created `https://github.com/rizonesoft/Spellbook` (public, default branch `main`) on 2026-10-04, and `main` is pushed (§1). Labels, security settings, and branch protection (§2) are not applied yet.

## Inputs

- -> XREF: D00 T01 §10 -- CI goes green only after §1 pushes

## Outcome

- The GitHub repository exists, `main` is pushed, CI has run, labels and security settings are applied.
- Ownership and branding decisions are recorded in `AGENTS.md`.
- The operator has accepted the import of their real prompt library.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Create the GitHub repository and push main | -- |  [x]   |
|   2   |   §2    | Repository settings: labels, security, branch protection | §1 |  [ ]   |
|   3   |   §3    | Accept the import of the real prompt library | D02 T01 §5 |  [ ]   |
|   4   |   §4    | Confirm ownership, branding, and the publisher | -- |  [ ]   |

---

## 1. Create the GitHub Repository and Push Main

- [x] Confirm the owner and name (the tree assumes `rizonesoft/Spellbook`, public). Done when: recorded in `AGENTS.md`; a different owner means one commit replacing the URL everywhere (`git grep -n "rizonesoft/Spellbook"`).
- [x] `gh repo create rizonesoft/Spellbook --public --source . --remote origin --description "Your grimoire of AI prompts."` then `git push -u origin main`. Done when: the repository page shows the README.
- [x] Commit: none (repository state).

**Test checkpoint:** Driven run: `git ls-remote origin main` prints the local `main` hash, and the `ci` workflow has started.

> **Verified:** 2026-10-04 | §1 | the operator created rizonesoft/Spellbook (public, empty, default branch main) through the GitHub web UI instead of `gh repo create`; recorded in AGENTS.md; `git push -u origin main` pushed b39045c; `git ls-remote origin main` printed b39045c83d74, equal to the local main; ci run 37164511590 started on b39045c and completed success
> **Implementer:** Claude (claude-opus-5-5)

## 2. Repository Settings: Labels, Security, Branch Protection

- [ ] Apply `.github/labels.yml` (for each entry: `gh label create "<name>" --color <color> --description "<description>" --force`). Done when: `gh label list` shows every entry.
- [ ] Enable private vulnerability reporting and Dependabot alerts (Settings, Code security). Done when: the Security tab offers "Report a vulnerability".
- [ ] Protect `main`: require the `ci` checks (`build-and-test`, `plan-gates`), no force pushes. Done when: a probe PR shows the required checks.
- [ ] Commit: none (repository state).

**Test checkpoint:** Driven run: `gh api repos/rizonesoft/Spellbook/branches/main/protection` lists both required checks.

## 3. Accept the Import of the Real Prompt Library

- [ ] Run Import scrolls over the real Notepad prompt folder into a fresh data folder (`Spellbook.exe --data-dir <tmp>`), review the preview, commit. Done when: the operator confirms nothing is missing or doubled, in words quoted here.
- [ ] Commit: `"todo: record the operator's import acceptance"`

**Test checkpoint:** Driven run: the import summary counts, quoted here with the operator's acceptance.

## 4. Confirm Ownership, Branding, and the Publisher

- [ ] Confirm the copyright line (the tree uses "Copyright (c) 2026 Rizonetech (Pty) Ltd", MIT, publisher Rizonesoft, as Isotone does) and whether "Spellbook" needs a trademark pre-screen before release, as Isotone's names had. Done when: the decision is a bullet in AGENTS.md "The decisions this project runs on".
- [ ] Commit: `"workspace: record the ownership and branding decision"`

**Test checkpoint:** Static evidence: `grep -n "Rizonetech" LICENSE AGENTS.md src/app/res/version.rc.in` agrees with the recorded decision.

## Verification

- [ ] `python scripts/todo-graph.py validate` clean
