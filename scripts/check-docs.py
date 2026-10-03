"""Check the docs and GitHub templates. Stdlib only, so CI's Linux job runs it as-is.

* Every relative link in a tracked Markdown file resolves to a file or folder
  (anchors and external URLs are not followed).
* Every issue form under .github/ISSUE_TEMPLATE/ carries name, description, and body.
* No authored prose uses an em dash (the Isotone and Resolute rule: write `--`,
  a colon, or a new sentence).

Prints file:line:rule:message per problem and exits 1 if any.

    python scripts/check-docs.py
    python scripts/check-docs.py --self-test
"""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)|<img[^>]+src=\"([^\"]+)\"|srcset=\"([^\"]+)\"")
SKIP_DIRS = {".tools", "artifacts", "build", ".git", "node_modules"}
EM_DASH = "—"


def markdown_files(root: Path) -> list[Path]:
    try:
        out = subprocess.run(["git", "ls-files", "-co", "--exclude-standard", "*.md"], cwd=root,
                             capture_output=True, text=True, check=True).stdout.split()
        return [root / p for p in out if (root / p).exists()]
    except (OSError, subprocess.CalledProcessError):
        return [p for p in root.rglob("*.md") if not SKIP_DIRS & set(p.relative_to(root).parts)]


def check_links(root: Path, files: list[Path]) -> list[str]:
    found = []
    for f in files:
        in_fence = False
        for ln, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for m in LINK.finditer(line):
                target = next(g for g in m.groups() if g)
                if re.match(r"^[a-z]+:", target) or target.startswith("#") or target.startswith("mailto:"):
                    continue
                path = target.split("#")[0].split("?")[0]
                if not path:
                    continue
                resolved = (f.parent / path).resolve()
                if not resolved.exists():
                    found.append(f"{f.relative_to(root).as_posix()}:{ln}:dead-link:{target}")
            if EM_DASH in line:
                found.append(f"{f.relative_to(root).as_posix()}:{ln}:em-dash:use --, a colon, or a new sentence")
    return found


def check_forms(root: Path) -> list[str]:
    found = []
    forms = root / ".github" / "ISSUE_TEMPLATE"
    for f in sorted(forms.glob("*.yml")) if forms.exists() else []:
        if f.name == "config.yml":
            continue
        text = f.read_text(encoding="utf-8")
        for key in ("name", "description", "body"):
            if not re.search(rf"^{key}:", text, re.M):
                found.append(f"{f.relative_to(root).as_posix()}:1:form-key:missing top-level '{key}'")
    return found


def run(root: Path) -> list[str]:
    files = markdown_files(root)
    return check_links(root, files) + check_forms(root)


def self_test() -> int:
    failed = 0
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "docs").mkdir()
        (root / "docs" / "a.md").write_text("[ok](b.md) [bad](missing.md) [web](https://x.y) [anchor](#top)\n"
                                            "```\n[fenced](nowhere.md)\n```\n", encoding="utf-8")
        (root / "docs" / "b.md").write_text("plain " + EM_DASH + " dash\n", encoding="utf-8")
        (root / ".github" / "ISSUE_TEMPLATE").mkdir(parents=True)
        (root / ".github" / "ISSUE_TEMPLATE" / "bug.yml").write_text("name: Bug\nbody:\n", encoding="utf-8")
        files = [root / "docs" / "a.md", root / "docs" / "b.md"]
        got = sorted(f.split(":")[2] for f in check_links(root, files) + check_forms(root))
        want = ["dead-link", "em-dash", "form-key"]
        if got != want:
            failed += 1
            print(f"self-test: want {want}, got {got}")
    print(f"check-docs self-test: {1 - failed} passed, {failed} failed")
    return 1 if failed else 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    found = run(ROOT)
    for f in found:
        print(f)
    print(f"{len(found)} findings")
    return 1 if found else 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv[1:]))
