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
import posixpath
from pathlib import Path
import xml.etree.ElementTree as ET

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
    normalized = inc.replace("\\", "/").lower()
    headers = {p.name.lower() for p in (ROOT / "src/app").rglob("*") if p.suffix in {".h", ".hpp"}}
    return "/app/" in "/" + normalized or normalized.rsplit("/", 1)[-1] in headers | {
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


def project_coverage(files: dict[str, str], project: str) -> list[str]:
    """Require every owned app source to participate in the analyzed MSBuild app."""
    location = "src/app/Spellbook.vcxproj"
    findings = []
    try:
        root = ET.fromstring(project)
    except ET.ParseError as error:
        return [f"{location}:1:app-project:invalid XML: {error}"]
    included = set()
    parents = {child: parent for parent in root.iter() for child in parent}
    for item in root.iter():
        if item.tag.rsplit("}", 1)[-1] != "ClCompile":
            continue
        # This static gate deliberately accepts only unconditional owned-source
        # declarations. It must not credit a file that MSBuild can skip later.
        if any(child.tag.rsplit("}", 1)[-1] == "ExcludedFromBuild" for child in item):
            findings.append(f"{location}:1:app-project:ExcludedFromBuild is unsupported; owned sources must compile in every configuration")
        if any(key in item.attrib for key in ("Remove", "Update", "Exclude")):
            findings.append(f"{location}:1:app-project:source removal/update/exclusion is unsupported")
        if "Include" not in item.attrib:
            continue
        ancestors = [item]
        while ancestors[-1] in parents:
            ancestors.append(parents[ancestors[-1]])
        if any("Condition" in ancestor.attrib or ancestor.tag.rsplit("}", 1)[-1]
               in {"Choose", "When", "Otherwise", "Target", "ItemDefinitionGroup"}
               for ancestor in ancestors):
            findings.append(f"{location}:1:app-project:conditional or dynamic source declaration is unsupported")
        name = item.attrib["Include"].replace("\\", "/")
        if name == "$(GeneratedFilesDir)module.g.cpp":
            continue  # C++/WinRT-generated module, not an owned source.
        path = posixpath.normpath("src/app/" + name)
        if "$" in name or "*" in name or ":" in name or name.startswith("/") or not path.startswith("src/app/"):
            findings.append(f"{location}:1:app-project:unresolved or out-of-layer source: {name}")
        elif path not in files:
            findings.append(f"{location}:1:app-project:source does not exist: {name}")
        elif path in included:
            findings.append(f"{location}:1:app-project:duplicate source: {name}")
        included.add(path)
    for path in files:
        if path.startswith("src/app/") and path.endswith(".cpp") and path not in included:
            findings.append(f"{path}:1:app-project:owned source is absent from the MSBuild analyzer target")
    return findings


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
        ({"src/core/src/a.cpp": '#include "MainWindow.xaml.h"\n'}, ["core-app"]),
        ({"src/storage/src/a.cpp": '#include "../app/App.xaml.h"\n'}, ["storage-app"]),
    ]
    failed = 0
    for i, (files, want) in enumerate(cases, 1):
        got = [f.split(":")[2] for f in scan(files)]
        if got != want:
            failed += 1
            print(f"self-test case {i}: want {want}, got {got}")
    project_cases = [
        ('<Project><ClCompile Include="a.cpp" /></Project>', False),
        ('<Project />', True),
        ('<Project><ClCompile Include="../core/a.cpp" /></Project>', True),
        ('<Project><ClCompile Include="missing.cpp" /></Project>', True),
        ('<Project><ClCompile Include="$(Unknown)source.cpp" /></Project>', True),
        ('<Project><ClCompile Include="a.cpp" /><ClCompile Include="a.cpp" /></Project>', True),
        ('<Project><ClCompile Include="a.cpp" /><ClCompile Include="$(GeneratedFilesDir)module.g.cpp" /></Project>', False),
        ('<Project><ClCompile Include="a.cpp"><ExcludedFromBuild>true</ExcludedFromBuild></ClCompile></Project>', True),
        ('<Project><ClCompile Include="a.cpp" Condition="false" /></Project>', True),
        ('<Project><ItemGroup Condition="false"><ClCompile Include="a.cpp" /></ItemGroup></Project>', True),
        ('<Project><ClCompile Include="a.cpp" Exclude="a.cpp" /></Project>', True),
        ('<Project><ClCompile Include="a.cpp" /><ClCompile Remove="a.cpp" /></Project>', True),
        ('<Project><ClCompile Include="a.cpp" /><ClCompile Update="a.cpp"><ExcludedFromBuild>true</ExcludedFromBuild></ClCompile></Project>', True),
        ('<Project><ClCompile Include="a.cpp" /><ItemDefinitionGroup><ClCompile><ExcludedFromBuild>true</ExcludedFromBuild></ClCompile></ItemDefinitionGroup></Project>', True),
        ('<Project><Choose><When Condition="false"><ItemGroup><ClCompile Include="a.cpp" /></ItemGroup></When></Choose></Project>', True),
        ('<Project><Target Name="Unused"><ItemGroup><ClCompile Include="a.cpp" /></ItemGroup></Target></Project>', True),
    ]
    for project, should_fail in project_cases:
        got = project_coverage({"src/app/a.cpp": ""}, project)
        if bool(got) != should_fail:
            failed += 1
            print(f"project coverage self-test: {project}: {got}")
    print(f"check-layering self-test: {len(cases) + len(project_cases) - failed} passed, {failed} failed")
    return 1 if failed else 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    files = tree()
    findings = scan(files)
    project = ROOT / "src/app/Spellbook.vcxproj"
    if project.is_file():
        findings += project_coverage(files, project.read_text(encoding="utf-8"))
    else:
        findings.append("src/app/Spellbook.vcxproj:1:app-project:MSBuild app project is missing")
    for f in findings:
        print(f)
    print(f"{len(findings)} findings")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
