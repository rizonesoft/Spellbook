"""Disposable payload fixtures: round trips, complete notices, and safe refusal."""

import hashlib
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest import mock
import zipfile

from package_payload import REQUIRED_PAYLOAD, package


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="spellbook-package-tests-\u00e9-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.app = self.repo / "artifacts/build/release/app"
        for name in REQUIRED_PAYLOAD:
            self.write(f"artifacts/build/release/app/{name}", f"payload:{name}".encode())
        self.write("artifacts/build/release/app/nested/runtime.bin", bytes(range(256)))
        self.write("artifacts/build/release/app/Spellbook.pdb", b"development only")
        self.write("artifacts/build/release/src/core/generated/spellbook/core/build_info.hpp",
                   b'constexpr auto kSemVer = "1.2.3-alpha.4";')
        self.write("LICENSE", b"Spellbook MIT")
        self.write("README.md", b"fixture")
        pins = {"Microsoft.WindowsAppSDK": {"version": "2.5.1"},
                "Microsoft.Windows.CppWinRT": {"version": "3.0.260818.1"}}
        self.write("toolchain.json", json.dumps({"packages": pins}).encode())
        libraries = {}
        for name, version, notices in [
            ("Microsoft.WindowsAppSDK", "2.5.1", ["license.txt", "NOTICE.txt"]),
            ("Microsoft.WindowsAppSDK.Runtime", "2.5.1", ["license.txt", "NOTICE.txt"]),
            ("Microsoft.Windows.CppWinRT", "3.0.260818.1", ["LICENSE"]),
        ]:
            path = f"{name.lower()}/{version}"
            libraries[f"{name}/{version}"] = {"type": "package", "path": path, "files": notices}
            for notice in notices:
                self.write(f"artifacts/nuget/{path}/{notice}", f"vendor:{name}/{notice}".encode())
        self.assets = {"libraries": libraries, "packageFolders": {str(self.repo / "artifacts/nuget"): {}}}
        self.save_assets()
        for name in ("fmt", "spdlog", "sqlite3", "nlohmann-json"):
            self.write(f"artifacts/vcpkg_installed/x64-windows-static/share/{name}/copyright", name.encode())

    def write(self, name, value):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value)

    def save_assets(self):
        self.write("artifacts/nuget-obj/project.assets.json", json.dumps(self.assets).encode())

    def test_full_payload_and_vendor_notices_round_trip_with_checksum(self):
        archive = package(self.repo)
        with zipfile.ZipFile(archive) as saved:
            self.assertEqual(saved.read("nested/runtime.bin"), bytes(range(256)))
            for name in REQUIRED_PAYLOAD:
                self.assertEqual(saved.read(name), (self.app / name).read_bytes())
            self.assertNotIn("Spellbook.pdb", saved.namelist())
            self.assertEqual(saved.read("LICENSE"), b"Spellbook MIT")
            self.assertEqual(saved.read("THIRD-PARTY-NOTICES/NuGet/microsoft.windowsappsdk/2.5.1/NOTICE.txt"),
                             b"vendor:Microsoft.WindowsAppSDK/NOTICE.txt")
            self.assertEqual(saved.read("THIRD-PARTY-NOTICES/NuGet/microsoft.windows.cppwinrt/3.0.260818.1/LICENSE"),
                             b"vendor:Microsoft.Windows.CppWinRT/LICENSE")
            for name in ("fmt", "spdlog", "sqlite3", "nlohmann-json"):
                self.assertEqual(saved.read(f"THIRD-PARTY-NOTICES/vcpkg/{name}/copyright"), name.encode())
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        self.assertEqual((archive.parent / "SHA256SUMS").read_text(), f"{digest}  {archive.name}\n")
        self.assertFalse(list((self.repo / "artifacts/stage").iterdir()))

    def test_missing_runtime_refuses_incomplete_package(self):
        (self.app / "Microsoft.UI.Xaml.dll").unlink()
        with self.assertRaisesRegex(ValueError, "Incomplete self-contained"):
            package(self.repo)
        self.assertFalse((self.repo / "artifacts/dist").exists())

    def test_missing_vendor_terms_preserves_previous_publication(self):
        archive = package(self.repo)
        old = archive.read_bytes()
        sums = (archive.parent / "SHA256SUMS").read_bytes()
        (self.repo / "artifacts/nuget/microsoft.windowsappsdk/2.5.1/NOTICE.txt").unlink()
        with self.assertRaisesRegex(ValueError, "Required package file missing"):
            package(self.repo)
        self.assertEqual(archive.read_bytes(), old)
        self.assertEqual((archive.parent / "SHA256SUMS").read_bytes(), sums)

    @unittest.skipUnless(os.name == "nt", "Windows read-only publication semantics")
    def test_read_only_checksum_preserves_previous_zip_and_checksum(self):
        archive = package(self.repo)
        sums = archive.parent / "SHA256SUMS"
        previous = archive.read_bytes(), sums.read_bytes()
        self.write("artifacts/build/release/app/nested/runtime.bin", b"changed payload")
        sums.chmod(stat.S_IREAD)
        try:
            with self.assertRaises(PermissionError):
                package(self.repo)
        finally:
            sums.chmod(stat.S_IREAD | stat.S_IWRITE)
        self.assertEqual((archive.read_bytes(), sums.read_bytes()), previous)

    def test_checksum_publish_failure_removes_new_version_and_keeps_old_pair(self):
        archive = package(self.repo)
        sums = archive.parent / "SHA256SUMS"
        previous = archive.read_bytes(), sums.read_bytes()
        self.write("artifacts/build/release/src/core/generated/spellbook/core/build_info.hpp",
                   b'constexpr auto kSemVer = "1.2.4";')
        replace = Path.replace

        def fail_checksum(source, destination):
            if Path(destination) == sums:
                raise PermissionError("checksum publication refused")
            return replace(source, destination)

        with mock.patch.object(Path, "replace", fail_checksum):
            with self.assertRaisesRegex(PermissionError, "checksum publication refused"):
                package(self.repo)
        self.assertEqual((archive.read_bytes(), sums.read_bytes()), previous)
        self.assertFalse((archive.parent / "Spellbook-1.2.4-win-x64-portable.zip").exists())

    def test_failed_rollback_retains_previous_archive_for_recovery(self):
        archive = package(self.repo)
        sums = archive.parent / "SHA256SUMS"
        previous = archive.read_bytes(), sums.read_bytes()
        self.write("artifacts/build/release/app/nested/runtime.bin", b"changed payload")
        replace = Path.replace
        archive_publications = 0

        def fail_checksum_and_rollback(source, destination):
            nonlocal archive_publications
            if Path(destination) == sums:
                raise PermissionError("checksum publication refused")
            if Path(destination) == archive:
                archive_publications += 1
                if archive_publications > 1:
                    raise PermissionError("archive rollback refused")
            return replace(source, destination)

        with mock.patch.object(Path, "replace", fail_checksum_and_rollback):
            with self.assertRaisesRegex(RuntimeError, "Recovery files retained"):
                package(self.repo)
        self.assertEqual(sums.read_bytes(), previous[1])
        backups = list((self.repo / "artifacts/stage").glob("package-*/previous.zip"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), previous[0])

    def test_restore_must_match_direct_pins(self):
        del self.assets["libraries"]["Microsoft.WindowsAppSDK/2.5.1"]
        self.save_assets()
        with self.assertRaisesRegex(ValueError, "does not match the pinned"):
            package(self.repo)

    def test_dependency_path_cannot_escape_package_root(self):
        self.assets["libraries"]["Microsoft.WindowsAppSDK/2.5.1"]["path"] = "../../outside"
        self.save_assets()
        with self.assertRaisesRegex(ValueError, "Unsafe relative package path"):
            package(self.repo)

    def test_version_cannot_choose_output_path(self):
        self.write("artifacts/build/release/src/core/generated/spellbook/core/build_info.hpp",
                   b'kSemVer = "../../outside";')
        with self.assertRaisesRegex(ValueError, "unsafe git-derived"):
            package(self.repo)


if __name__ == "__main__":
    unittest.main()
