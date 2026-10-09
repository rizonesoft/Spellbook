"""Claude run guard registration: one owning session, an existing run record, a serialized atomic write."""
import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]


@contextmanager
def registration_lock(root: Path):
    """Exclusive while held: a second registration fails instead of racing the ownership check."""
    path = root / "build/claude-campaign-guard.lock"
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        handle = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        raise OSError(f"guard registration in progress; delete {path} only if no registration is running") from None
    try:
        os.close(handle)
        yield
    finally:
        path.unlink(missing_ok=True)


def register(root: Path, session: str, phase: int, run_file: str, cron: str) -> None:
    if not session or not cron or phase not in range(6):
        raise ValueError("session, cron ID, and phase 0 through 5 are required")
    record = (root / run_file).resolve()
    if not record.is_relative_to((root / "docs/phase-runs").resolve()) or not record.is_file():
        raise ValueError("run record must be an existing file under docs/phase-runs")
    with registration_lock(root):
        path = root / "build/claude-campaign-guard.json"
        if path.exists():
            old = json.loads(path.read_text(encoding="utf-8-sig"))
            if (old.get("session_id") != session or old.get("runner") != "claude"
                    or Path(old.get("workspace", "")).resolve() != root.resolve()):
                raise ValueError("another Claude session owns the guard; pause it before transferring ownership")
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
        try:
            temporary.write_text(json.dumps({"runner": "claude", "workspace": str(root.resolve()),
                                            "phase": phase, "run_file": record.relative_to(root.resolve()).as_posix(),
                                            "session_id": session, "cron_id": cron}) + "\n", encoding="utf-8")
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session', required=True)
    parser.add_argument('--phase', required=True, type=int)
    parser.add_argument('--run-file', required=True)
    parser.add_argument('--cron', required=True)
    args = parser.parse_args()
    try:
        register(ROOT, args.session, args.phase, args.run_file, args.cron)
        print('claude campaign: guard registered')
    except (OSError, ValueError) as error:
        print(f'claude campaign: {error}', file=sys.stderr)
        sys.exit(1)
