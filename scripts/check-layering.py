"""Enforce the layering rule in docs/architecture.md, by include directive.

    core     <- storage <- app

* src/core never includes a Windows header, a storage header, or an app header.
* src/storage never includes a Windows header or an app header.
* tests/core includes only core (and the test framework and the standard library).

Prints file:line:rule:message per violation and exits 1 if any; prints
"0 findings" otherwise. Stdlib only. `--self-test` runs the fixtures below.

    python scripts/check-layering.py
    python scripts/check-layering.py --self-test
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INCLUDE = re.compile(r'^\s*#\s*include\s*[<"]([^>"]+)[>"]')

# Headers that mean "this code depends on Windows". Matched case-insensitively
# against the header's file name.
WINDOWS_HEADERS = {
    "windows.h", "winbase.h", "winuser.h", "windef.h", "winnt.h", "shlobj.h", "shellapi.h",
    "commctrl.h", "dwmapi.h", "uxtheme.h", "objbase.h", "combaseapi.h", "knownfolders.h",
    "wrl.h", "winrt", "atlbase.h", "tchar.h", "winres.h",
}

RULES = [
    # (source prefix, rule name, predicate on the include path, message)
    ("src/core/", "core-windows", lambda inc: _is_windows(inc), "core must not include Windows headers"),
    ("src/core/", "core-storage", lambda inc: inc.startswith("spellbook/storage/"), "core must not depend on storage"),
    ("src/core/", "core-app", lambda inc: _is_app(inc), "core must not depend on the app"),
    ("src/storage/", "storage-windows", lambda inc: _is_windows(inc), "storage must not include Windows headers"),
    ("src/storage/", "storage-app", lambda inc: _is_app(inc), "storage must not depend on the app"),
    ("tests/core/", "test-core-storage", lambda inc: inc.startswith("spellbook/storage/"), "core tests must not need storage"),
]


def _is_windows(inc: str) -> bool:
    name = inc.replace("\\", "/").split("/")[-1].lower()
    top = inc.replace("\\", "/").split("/")[0].lower()
    return name in WINDOWS_HEADERS or top in WINDOWS_HEADERS


def _is_app(inc: str) -> bool:
    return inc.startswith("app/") or inc in {
        "main_window.hpp", "app_paths.hpp", "logging.hpp", "res/resource.h", "resource.h",
    }


def scan(files: dict[str, str]) -> list[str]:
    """files maps a repo-relative POSIX path to its text."""
    findings = []
    for rel, text in sorted(files.items()):
        for lineno, line in enumerate(text.splitlines(), 1):
            m = INCLUDE.match(line)
            if not m:
                continue
            inc = m.group(1)
            for prefix, rule, pred, msg in RULES:
                if rel.startswith(prefix) and pred(inc):
                    findings.append(f"{rel}:{lineno}:{rule}:{msg} (#include {inc})")
    return findings


def tree() -> dict[str, str]:
    out = {}
    for base in ("src", "tests"):
        for p in (ROOT / base).rglob("*"):
            if p.suffix in {".cpp", ".hpp", ".h", ".in"} and p.is_file():
                out[p.relative_to(ROOT).as_posix()] = p.read_text(encoding="utf-8", errors="replace")
    return out


def self_test() -> int:
    cases = [
        ({"src/core/src/a.cpp": "#include <windows.h>\n"}, ["core-windows"]),
        ({"src/core/src/a.cpp": '#include "spellbook/storage/database.hpp"\n'}, ["core-storage"]),
        ({"src/core/src/a.cpp": '#include "main_window.hpp"\n'}, ["core-app"]),
        ({"src/storage/src/a.cpp": "#include <ShlObj.h>\n"}, ["storage-windows"]),
        ({"src/storage/src/a.cpp": '#include "spellbook/core/text.hpp"\n#include <sqlite3.h>\n'}, []),
        ({"src/app/main.cpp": "#include <windows.h>\n#include \"spellbook/storage/database.hpp\"\n"}, []),
        ({"tests/core/a.cpp": '#include "spellbook/storage/migrations.hpp"\n'}, ["test-core-storage"]),
        ({"src/core/src/a.cpp": "  #  include <winrt/base.h>\n"}, ["core-windows"]),
    ]
    failed = 0
    for i, (files, want) in enumerate(cases, 1):
        got = [f.split(":")[2] for f in scan(files)]
        if got != want:
            failed += 1
            print(f"self-test case {i}: want {want}, got {got}")
    print(f"check-layering self-test: {len(cases) - failed} passed, {failed} failed")
    return 1 if failed else 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    findings = scan(tree())
    for f in findings:
        print(f)
    print(f"{len(findings)} findings")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
