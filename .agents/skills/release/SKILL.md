---
name: release
description: Cut a Spellbook release using its release checklist and verify published artifacts. Use only when explicitly asked to release, tag, or publish a version.
---

# Release

The policy is `standards/release.md`; this is the runbook. Versions come from tags, so releasing is tagging: there is no version number to edit.

## 1. Choose the version

- SemVer: a breaking change to data or behavior bumps MINOR while below 1.0, MAJOR after; new features bump MINOR; fixes only bump PATCH. A hyphen makes a prerelease (`0.1.0-rc.1`).
- The latest tag: `git describe --tags --match "v[0-9]*" --abbrev=0`.

## 2. Check

```powershell
git switch main; git pull --ff-only
pwsh scripts/release.ps1 -Version X.Y.Z -DryRun   # clean tree, tag free, changelog has entries, check-all green
```

Then run the checklist in `standards/release.md` and quote each line's evidence in the release section of the plan (`D05 T02 §5` for v0.1.0). The installer and clean-machine lines are manual until the installer exists.

## 3. Package locally

```powershell
pwsh scripts/package.ps1            # artifacts/dist/Spellbook-X.Y.Z-...zip and SHA256SUMS
```

The version in the file name comes from the build. Before tagging it reads `X.Y.(Z+1)-alpha.N` or similar; that is expected. The workflow builds from the tag.

## 4. Tag and push

```powershell
pwsh scripts/release.ps1 -Version X.Y.Z    # moves Unreleased to [vX.Y.Z] - date, commits "release: vX.Y.Z", tags vX.Y.Z
git push origin main vX.Y.Z
```

Pushing the tag runs `.github/workflows/release.yml`: build, test, smoke, package, and a GitHub release with the ZIP, `SHA256SUMS`, and the changelog section.

## 5. Verify

```powershell
gh run watch (gh run list --workflow release.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh release view vX.Y.Z
gh release download vX.Y.Z --dir build/release-check
```

Check each downloaded file's `Get-FileHash` against `SHA256SUMS`, and run the ZIP's `Spellbook.exe --smoke --data-dir build/release-check/data`.

## If it goes wrong

- A failed workflow before `gh release create`: fix on `main`, delete the tag locally and remotely (`git tag -d vX.Y.Z; git push origin :refs/tags/vX.Y.Z`) only if no release was published, and release again.
- A published release is never replaced: ship `X.Y.(Z+1)`.

Codex owns this independent skill. Use `git -c core.hooksPath=.codex/githooks commit` for commits; inspect every dirty file first and preserve safe user side edits.
