"""Read actual startup MessageBox text, using only processes and data we own."""

import argparse
import ctypes
from ctypes import wintypes
import json
from pathlib import Path
import shutil
import subprocess
import time


def read_dialog(exe: Path, arguments: list[str]) -> dict:
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    user32.EnumChildWindows.argtypes = [wintypes.HWND, callback_type, wintypes.LPARAM]
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]

    def text(handle, class_name=False):
        buffer = ctypes.create_unicode_buffer(8192)
        api = user32.GetClassNameW if class_name else user32.GetWindowTextW
        api(handle, buffer, len(buffer))
        return buffer.value

    process = subprocess.Popen([str(exe), *arguments], creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        dialogs = []

        @callback_type
        def find_dialog(handle, _):
            owner = wintypes.DWORD()
            user32.GetWindowThreadProcessId(handle, ctypes.byref(owner))
            if owner.value == process.pid and text(handle, True) == "#32770":
                dialogs.append(handle)
            return True

        deadline = time.monotonic() + 20
        while not dialogs and process.poll() is None and time.monotonic() < deadline:
            user32.EnumWindows(find_dialog, 0)
            time.sleep(0.05)
        if not dialogs:
            raise AssertionError("Expected an interactive startup failure dialog")
        handle = dialogs[0]
        body = []

        @callback_type
        def read_child(child, _):
            if text(child, True) == "Static" and text(child):
                body.append(text(child))
            return True

        user32.EnumChildWindows(handle, read_child, 0)
        result = {"title": text(handle), "body": "\n".join(body)}
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(handle, ctypes.byref(owner))
        if owner.value != process.pid:
            raise AssertionError("Dialog ownership changed before dismissal")
        user32.PostMessageW(handle, 0x10, 0, 0)
        result["exit"] = process.wait(timeout=10)
        return result
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("exe", type=Path)
    parser.add_argument("probe_root", type=Path)
    args = parser.parse_args()
    exe = args.exe.resolve(strict=True)
    root = args.probe_root.resolve(strict=True)
    corrupt = root / "interactive corrupt database"
    corrupt.mkdir()
    (corrupt / "spellbook.db").write_bytes(b"Not a database; disposable dialog probe.")
    broken_app = root / "app without resources"
    # Copy our built payload, never remove or alter the real application's PRI.
    shutil.copytree(exe.parent, broken_app, ignore=shutil.ignore_patterns("Spellbook.pri", "*.pdb", "*.lib", "*.exp"))
    cases = [
        ("database startup failure", exe, ["--data-dir", str(corrupt)], "not a database"),
        ("argument startup failure", exe, ["--data-dir", str(root / "arguments"), "--unknown"], "Unknown command-line option"),
        ("resource startup failure", broken_app / exe.name, ["--data-dir", str(root / "resources")], None),
    ]
    results = []
    failed = False
    for name, binary, arguments, reason in cases:
        result = {"name": name}
        try:
            result.update(read_dialog(binary, arguments))
            assert result["title"] == "Spellbook", result
            # Invalid XAML resources may terminate with a native WinUI failure code.
            assert result["exit"] != 0, result
            assert reason is None or result["exit"] == 1, result
            prefix = "Spellbook could not start."
            assert result["body"].startswith(prefix), result
            assert result["body"][len(prefix):].strip(), result
            assert reason is None or reason in result["body"], result
            print(f"PASS: {name} names the action and reason (exit {result['exit']})")
        except Exception as error:
            result["failure"] = str(error)
            failed = True
            print(f"FAIL: {name}: {error}")
        results.append(result)
    (root / "startup-dialogs.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
