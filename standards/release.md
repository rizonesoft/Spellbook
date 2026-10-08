# Release Standards

How Spellbook is versioned, packaged, and released. The mechanics are in `scripts/release.ps1`, `scripts/package.ps1`, and `.github/workflows/release.yml`; this file is the policy they implement.

## Versions and tags

- SemVer 2.0, derived from git tags `v<MAJOR.MINOR.PATCH>[-prerelease]` by `cmake/SpellbookVersion.cmake`. No version string is typed into a project file (`vcpkg.json` carries `0.0.0` because the field is required and unused).
- Between tags the build is `<next patch>-alpha.<commits since the tag>`; before the first tag it is `0.0.0-alpha.<commit count>`.
- A tag with a hyphen is a prerelease.
- Tags are made by `pwsh scripts/release.ps1 -Version X.Y.Z` from a clean `main`, never by hand.

## Changelog

- `CHANGELOG.md` follows Keep a Changelog 1.1.0. Every user-visible change adds a line under `## [Unreleased]` in the commit that makes it.
- `release.ps1` renames `## [Unreleased]` to `## [vX.Y.Z] - YYYY-MM-DD`, and the release workflow lifts that section as the release notes.

## Artifacts

Each release produces, under `artifacts/dist/` and attached to the GitHub release:

- `Spellbook-<version>-win-x64-portable.zip`: the complete WinUI application folder (DLLs, PRI/resources, and icon), `LICENSE`, `README.md`, and `THIRD-PARTY-NOTICES/`. Development symbols and link libraries are excluded.
- `Spellbook-<version>-win-x64-Setup.exe`: the Inno Setup 7 installer (from `D05 T02 §2`), per-user by default with an all-users option, and an uninstaller that keeps the user's data unless asked.
- `SHA256SUMS` covering both.

Divergence from Isotone, recorded: Isotone ships binaries only from rizonesoft.com and never attaches them to a GitHub release; Spellbook's brief asks for attached artifacts, so they are attached.

## Supported systems

Windows 11 and Windows 10 22H2, x64.

## Signing

Not yet: there is no certificate (backlog `B-006`). When one exists it is supplied to the packaging script from outside the repository, never in a tracked file or an argument.

## The release checklist

A release tag is pushed only when every line holds, each quoted from a real run in the release section's evidence:

1. `pwsh scripts/check-all.ps1` exits 0 at the commit being tagged.
2. `CHANGELOG.md` lists every user-visible change since the last release.
3. The user guide in `docs/user/` covers every surface the release ships.
4. `pwsh scripts/package.ps1` (with `-Installer` from M5) produces the artifacts locally.
5. The installer installs, launches, and uninstalls on a clean Windows 11 machine, per-user and all-users; an upgrade over the previous release keeps the user's data.
6. The portable ZIP runs from an empty folder.
7. After the tag is pushed, the `release` workflow is green and the release page lists the artifacts with hashes matching `SHA256SUMS`.
