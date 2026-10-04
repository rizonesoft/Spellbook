---
schema_version: 1
id: operator-steps
domain: 99-manual
status: active
title: "TODO-01 -- Operator Steps"
depends_on: []
---

# TODO-01 -- Operator Steps

> **Goal:** The steps no agent session can or should take on its own (creating and configuring the GitHub repository, installing machine-wide tools, deciding ownership, accepting the import of real prompts, judging what only eyes and ears can judge, approving the release, and anything that needs an account, a secret, or money) are listed with exact commands, so they never stall a runner silently. Every section here is operator-only: `query ready` lists them as runnable elsewhere and an unattended run never starts one (`D00 T03 §1`).

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** The operator created `https://github.com/rizonesoft/Spellbook` (public, default branch `main`) on 2026-10-04, and `main` is pushed (§1). Labels, security settings, and branch protection (§2) were applied on 2026-10-04; the social preview upload is outstanding. The Visual Studio 2026 C++ and WinUI workloads (§5) were installed on 2026-10-04.

## Inputs

- -> XREF: D00 T01 §10 -- CI goes green only after §1 pushes
- -> XREF: D00 T02 §2 -- the toolchain pins that need §5's Visual Studio 2026 workloads
- -> XREF: D00 T03 §5 -- the checkpoint sweep that moves human-only checks into §10
- -> XREF: D05 T02 §5 -- the release that waits for §6 and §7
- -> XREF: D05 T02 §10 -- channel publishing, which needs §8's accounts and secrets
- -> XREF: D05 T02 §11 -- signing and the Store, which need §9
- -> XREF: D06 T01 §3 -- the AI features §11 tries with a real key and agent
- -> XREF: D05 T03 §1 -- backups exist before §3's real import
- -> XREF: D05 T01 §5 -- the accessibility pass whose Narrator and high-contrast checks §10 takes

## Outcome

- The GitHub repository exists, `main` is pushed, CI has run, labels and security settings are applied.
- Ownership and branding decisions are recorded in `AGENTS.md`.
- The operator has accepted the import of their real prompt library.
- Visual Studio 2026 has the C++ desktop and WinUI workloads.
- The release candidate has passed a clean-machine check and the operator has approved the v0.1.0 tag in writing.
- The channel accounts, secrets, signing, and Store account exist when their sections need them.
- The visual, screen-reader, and live AI checks no agent can judge have been done and recorded.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Create the GitHub repository and push main | -- |  [x]   |
|   2   |   §2    | Repository settings: labels, security, branch protection | §1 |  [ ]   |
|   3   |   §3    | Accept the import of the real prompt library | D02 T01 §5 |  [ ]   |
|   4   |   §4    | Confirm ownership, branding, and the publisher | -- |  [ ]   |
|   5   |   §5    | Install the Visual Studio 2026 C++ and WinUI workloads | -- |  [x]   |
|   6   |   §6    | Check the release candidate on a clean machine | D05 T02 §3 |  [ ]   |
|   7   |   §7    | Approve the v0.1.0 release | §6, §10, §11 |  [ ]   |
|   8   |   §8    | Channel accounts and secrets: winget, Scoop, Chocolatey | -- |  [ ]   |
|   9   |   §9    | Code signing and a Partner Center account | -- |  [ ]   |
|  10   |   §10   | The visual and screen-reader pass | D05 T02 §3 |  [ ]   |
|  11   |   §11   | Try AI assist with a real key and a real agent | D06 T01 §10 |  [ ]   |
|  12   |   §12   | Submit Spellbook to the Microsoft Store | D05 T02 §11 |  [ ]   |

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
- [ ] Protect `main`: require the `ci` checks (`build-and-test`, `plan-gates`) for pull requests, no force pushes, no deletion, with repository admins allowed to bypass so an unattended run's direct pushes after each section still land (ADR 0003). Done when: a probe PR shows the required checks and a direct push by the operator's account succeeds.
- [ ] Set `assets/brand/social-preview.png` as the social preview (Settings, General, Social preview, Edit, Upload an image). Done when: a link to the repository pasted into a chat app shows the teal card.
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

## 5. Install the Visual Studio 2026 C++ and WinUI Workloads

**Corrected 2026-10-04:** the first install used `Microsoft.VisualStudio.ComponentGroup.WindowsAppSDK.Cpp`, which does not exist in the VS 2026 catalog and was ignored without an error; the component is `Microsoft.VisualStudio.Component.WindowsAppSdkSupport.Cpp`. PowerShell also needs the `&` call operator before the quoted `setup.exe` path, and a pasted long line can wrap, so the command below uses variables.

The stack moves to WinUI 3 on Visual Studio 2026 (operator decision 2026-10-04, `D00 T02`). Visual Studio Professional 2026 18.10.3 is installed with only the Core Editor and Web workloads, so it has no C++ compiler. Modifying an installation needs elevation and changes the machine, so the operator runs it.

- [x] From an elevated PowerShell: `$setup = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"`, then `$vs = "C:\Program Files\Microsoft Visual Studio\18\Professional"`, then `& $setup modify --installPath $vs --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Component.WindowsAppSdkSupport.Cpp --includeRecommended --passive` (or tick "Desktop development with C++" and, under "WinUI application development", the C++ WinUI app tools in the Installer). Done when: `C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Tools\MSVC` holds a 14.50 or later folder.
- [x] Commit: none (machine state).

**Test checkpoint:** Driven run: `& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -version "[18.0,19.0)" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.WindowsAppSdkSupport.Cpp -property installationPath` prints the VS 2026 path.

> **Verified:** 2026-10-04 | §5 | the operator ran the installer elevated twice: the first run added Microsoft.VisualStudio.Workload.NativeDesktop (MSVC 14.51.36231 in VC\Tools\MSVC) and silently ignored the non-existent ComponentGroup.WindowsAppSDK.Cpp id; the second added Microsoft.VisualStudio.Component.WindowsAppSdkSupport.Cpp 18.10.12020.329 (with Microsoft.WindowsAppSDK.Cpp.Dev17 2.0.251210006); the checkpoint's vswhere query printed C:\Program Files\Microsoft Visual Studio\18\Professional, exit 0
> **Implementer:** the operator, recorded by Claude (claude-opus-5-5)

## 6. Check the Release Candidate on a Clean Machine

Operator decision 2026-10-04: install tests run unattended on the development PC and in CI (`D05 T02 §8`); a truly clean machine is checked by hand before the release.

- [ ] On a Windows 11 machine (and, if one is at hand, Windows 10 22H2) that has never had Spellbook or the Windows App SDK: download the release candidate's installer from the draft release (`D05 T02 §3`), install for me, import a folder of three `.txt` files, cast a prompt with a rune, open a `.spell` file by double-click, uninstall keeping data; then run the portable ZIP from a USB stick. Done when: each step's result is written here, with Windows' version (`winver`).
- [ ] Commit: `"todo: record the clean-machine check (D99 T01 §6)"`

**Test checkpoint:** Driven run: the recorded results, every step passing, quoted here.

## 7. Approve the v0.1.0 Release

The tag is irreversible in practice (channels pick it up), so it waits for the operator's own words.

- [ ] Read the draft release notes, the `docs/phase-runs/` closeouts, and the §6, §10, and §11 results; then write "Approved for v0.1.0" with the date and the commit hash here. Done when: the approval line is present.
- [ ] Commit: `"todo: approve the v0.1.0 release (D99 T01 §7)"`

**Test checkpoint:** Static evidence: the approval line names the commit `D05 T02 §5` tags.

## 8. Channel Accounts and Secrets: winget, Scoop, Chocolatey

- [ ] Create the public repository `rizonesoft/scoop-bucket` with a `bucket/` folder (`gh repo create rizonesoft/scoop-bucket --public --description "Scoop bucket for Rizonesoft apps"`). Done when: it exists.
- [ ] Create a fine-grained GitHub token with Contents read and write on `rizonesoft/scoop-bucket` and add it as the `SCOOP_BUCKET_TOKEN` secret of `rizonesoft/Spellbook`; create a classic token with `public_repo` for winget pull requests and add it as `WINGET_TOKEN`. Done when: `gh secret list` shows both names.
- [ ] Create a Chocolatey community account, copy its API key, and add it as `CHOCOLATEY_API_KEY`. Done when: `gh secret list` shows it.
- [ ] Commit: none (repository state).

**Test checkpoint:** Driven run: `gh secret list --repo rizonesoft/Spellbook` lists `SCOOP_BUCKET_TOKEN`, `WINGET_TOKEN`, and `CHOCOLATEY_API_KEY` (names only).

## 9. Code Signing and a Partner Center Account

Operator decision 2026-10-04: v0.1.0 ships unsigned; the Microsoft Store waits for signing.

- [ ] Choose and set up signing: Azure Artifact Signing (an Azure subscription, a signing account, identity validation for Rizonetech (Pty) Ltd, a certificate profile) or an OV or EV certificate from a CA in the Microsoft Trusted Root Program; record the choice and how `scripts/package.ps1 -Sign` reaches it (secret names only) here. Done when: recorded.
- [ ] Register a Microsoft Partner Center developer account for Rizonesoft and reserve the name "Spellbook". Done when: the reservation is confirmed.
- [ ] Commit: `"todo: record the signing setup (D99 T01 §9)"`

**Test checkpoint:** Static evidence: the recorded choice and secret names; the Partner Center reservation confirmation date.

## 10. The Visual and Screen-Reader Pass

The checks an agent cannot judge, moved here by the checkpoint sweep (`D00 T03 §5`): each item names the section it came from.

- [ ] Display scales: run the release candidate at 100, 150, and 200 percent (Settings, Display, Scale) in light and dark; look at the main window, the popup, the fill-in dialog, Settings, and the taskbar and Explorer icons (from `D05 T02 §1`). Done when: anything wrong is filed through `add-todo` and the pass is recorded here.
- [ ] Narrator: with Narrator on, create, find, and cast a spell using the keyboard only; Narrator must read the spell list rows, the editor fields, the popup results, and the fill-in dialog (from `D05 T01 §5`). Done when: recorded, with gaps filed.
- [ ] High contrast: one pass with a contrast theme on (from `D05 T01 §5`). Done when: recorded.
- [ ] Commit: `"todo: record the visual and screen-reader pass (D99 T01 §10)"`

**Test checkpoint:** Driven run: the recorded results; every gap found has a filed section named here.

## 11. Try AI Assist with a Real Key and a Real Agent

Every AI test in the plan runs against mocks, so nothing spends money unattended. This is the live trial.

- [ ] Enter a real OpenRouter key, keep the default cap, and run Refine, Adapt, Write, Rune-ify, Critique, Suggest, and semantic search on ten real spells; note the costs shown. Done when: each feature's outcome and the month's spend are recorded.
- [ ] Add one ACP agent from the registry (for example the Claude agent through `npx`) and run Refine and Critique through it. Done when: recorded, including any sign-in step the agent needed.
- [ ] Commit: `"todo: record the live AI trial (D99 T01 §11)"`

**Test checkpoint:** Driven run: the recorded outcomes; anything broken is filed through `add-todo` and named here.

## 12. Submit Spellbook to the Microsoft Store

- [ ] In Partner Center, create the EXE app submission from `packaging/store/` (`D05 T02 §11`): the signed installer's versioned HTTPS URL, silent switches, listing text, screenshots, age rating, and privacy statement; submit for certification. Done when: certification passes and the listing URL is recorded here.
- [ ] Commit: `"todo: record the Microsoft Store listing (D99 T01 §12)"`

**Test checkpoint:** Driven run: the Store listing URL opens and offers Install.

## Verification

- [ ] `python scripts/todo-graph.py validate` clean
