"""Package the complete WinUI folder and its vendor notices, using stdlib only."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile
import zipfile


REQUIRED_PAYLOAD = (
    "Spellbook.exe", "Spellbook.pri", "spellbook.ico",
    "Microsoft.UI.Xaml.dll", "Microsoft.UI.Xaml.Controls.dll",
    "Microsoft.WindowsAppRuntime.dll",
)
DEVELOPMENT_SUFFIXES = {".pdb", ".lib", ".exp", ".ilk", ".ipdb", ".iobj"}


def contained(root: Path, relative: str) -> Path:
    """Reject absolute/traversing input and reparse points escaping a named root."""
    value = Path(relative)
    if value.is_absolute() or ".." in value.parts or ":" in relative:
        raise ValueError(f"Unsafe relative package path: {relative}")
    result = (root / value).resolve()
    if not result.is_relative_to(root.resolve()) or result == root.resolve():
        raise ValueError(f"Package path escapes its root: {relative}")
    return result


def copy_file(source: Path, destination: Path) -> None:
    if not source.is_file():
        raise ValueError(f"Required package file missing: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def collect_notices(repo: Path, stage: Path) -> None:
    """Copy terms from the resolved dependency closure, not stale cache entries."""
    assets = json.loads((repo / "artifacts/nuget-obj/project.assets.json").read_text(encoding="utf-8-sig"))
    pins = json.loads((repo / "toolchain.json").read_text(encoding="utf-8"))["packages"]
    libraries = assets["libraries"]
    for name in ("Microsoft.WindowsAppSDK", "Microsoft.Windows.CppWinRT"):
        if f"{name}/{pins[name]['version']}" not in libraries:
            raise ValueError(f"Restore does not match the pinned {name}; rebuild first")
    index = [
        "# Third-party notices", "",
        "Spellbook's LICENSE covers Spellbook source. Bundled Microsoft and other third-party components retain their own terms below.",
        "This directory preserves notices from the restored dependency closure, including build dependencies; it does not claim every dependency binary is shipped.", "",
    ]
    for identity, library in sorted(libraries.items()):
        if library.get("type") != "package":
            continue
        package_path = library["path"]
        roots = [contained(Path(root), package_path) for root in assets["packageFolders"]]
        source = next((p for p in roots if p.is_dir()), None)
        if source is None:
            raise ValueError(f"Restored package missing: {identity}")
        notices = [name for name in library["files"]
                   if any(word in Path(name).name.lower() for word in ("license", "notice", "copyright"))
                   and Path(name).suffix.lower() in {"", ".txt", ".md"}]
        required = []
        if identity.startswith(("Microsoft.WindowsAppSDK/", "Microsoft.WindowsAppSDK.Runtime/")):
            required = ["license.txt", "NOTICE.txt"]
        elif identity.startswith("Microsoft.Windows.CppWinRT/"):
            required = ["LICENSE"]
        for name in required:
            if name not in notices:
                raise ValueError(f"Required vendor terms absent from restore: {identity}/{name}")
        for name in notices:
            target = contained(stage / "THIRD-PARTY-NOTICES/NuGet", f"{package_path}/{name}")
            copy_file(contained(source, name), target)
        if notices:
            index.append(f"- NuGet `{identity}`: `NuGet/{package_path}/` ({len(notices)} notice files).")
        else:
            index.append(f"- NuGet `{identity}` supplies no standalone notice file in its restored manifest; consult its package metadata and the SDK terms.")
    for name in ("fmt", "spdlog", "sqlite3", "nlohmann-json"):
        copy_file(repo / f"artifacts/vcpkg_installed/x64-windows-static/share/{name}/copyright",
                  stage / f"THIRD-PARTY-NOTICES/vcpkg/{name}/copyright")
        index.append(f"- vcpkg `{name}`: `vcpkg/{name}/copyright`.")
    (stage / "THIRD-PARTY-NOTICES/README.md").write_text("\n".join(index) + "\n", encoding="utf-8")


def package(repo: Path) -> Path:
    repo = repo.resolve(strict=True)
    release = repo / "artifacts/build/release"
    header = (release / "src/core/generated/spellbook/core/build_info.hpp").read_text(encoding="utf-8")
    match = re.search(r'kSemVer = "([^"]+)"', header)
    if not match or not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?", match[1]):
        raise ValueError("Missing or unsafe git-derived package version; rebuild Release")
    version = match[1]
    app = release / "app"
    for name in REQUIRED_PAYLOAD:
        if not (app / name).is_file():
            raise ValueError(f"Incomplete self-contained output: {name}")
    dist = contained(repo, "artifacts/dist")
    stages = contained(repo, "artifacts/stage")
    dist.mkdir(parents=True, exist_ok=True)
    stages.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix="package-", dir=stages)).resolve()
    archive = dist / f"Spellbook-{version}-win-x64-portable.zip"
    temporary_archive = stage / "payload.zip"
    payload = stage / "payload"
    payload.mkdir()
    try:
        for source in sorted(app.rglob("*")):
            if source.is_symlink() or not source.resolve().is_relative_to(app.resolve()):
                raise ValueError(f"Reparse/escaping payload entry: {source}")
            if source.is_file() and source.suffix.lower() not in DEVELOPMENT_SUFFIXES:
                copy_file(source, contained(payload, source.relative_to(app).as_posix()))
        for name in ("LICENSE", "README.md"):
            copy_file(repo / name, payload / name)
        collect_notices(repo, payload)
        with zipfile.ZipFile(temporary_archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
            for source in sorted(payload.rglob("*")):
                if source.is_file():
                    output.write(source, source.relative_to(payload).as_posix())
        with temporary_archive.open("rb") as stream:
            hasher = hashlib.sha256()
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                hasher.update(block)
            digest = hasher.hexdigest()
        # Publish only after payload and notices are complete. A failed preflight
        # leaves any previously published ZIP and checksum untouched.
        temporary_archive.replace(archive)
        sums = stage / "SHA256SUMS"
        sums.write_text(f"{digest}  {archive.name}\n", encoding="ascii")
        sums.replace(dist / "SHA256SUMS")
        print(f"package: {archive.name}, {archive.stat().st_size} bytes, SHA256 {digest}")
        return archive
    finally:
        resolved = stage.resolve()
        if resolved.parent != stages.resolve() or not resolved.name.startswith("package-"):
            raise ValueError(f"Refusing unsafe package scratch cleanup: {resolved}")
        shutil.rmtree(resolved)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parent.parent)
    options = parser.parse_args()
    package(options.repo)
