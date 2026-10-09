"""Publish a capture/receipt pair with recovery for ordinary filesystem failures."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import uuid


def publish(image, manifest, destination, recovery):
    image, manifest, destination, recovery = map(Path, (image, manifest, destination, recovery))
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    if hashlib.sha256(image.read_bytes()).hexdigest() != payload["Capture"]["Sha256"]:
        raise ValueError("capture hash differs from the manifest")
    if Path(payload["PublishedPath"]).resolve() != destination.resolve():
        raise ValueError("manifest names another publication destination")
    receipt = Path(str(destination) + ".json")
    destination.parent.mkdir(parents=True, exist_ok=True)
    recovery.mkdir(parents=True, exist_ok=False)
    originals = {}
    prepared = []
    published = []
    try:
        for source, target in ((image, destination), (manifest, receipt)):
            if target.is_symlink():
                raise ValueError("refusing a symlink publication destination")
            backup = recovery / target.name
            if target.exists():
                if not target.is_file():
                    raise ValueError("publication destination is not a regular file")
                shutil.copy2(target, backup)
                originals[target] = backup
            else:
                originals[target] = None
            temporary = target.with_name(target.name + "." + uuid.uuid4().hex + ".tmp")
            prepared.append((temporary, target))
            with source.open("rb") as incoming, temporary.open("xb") as outgoing:
                shutil.copyfileobj(incoming, outgoing)
                outgoing.flush()
                os.fsync(outgoing.fileno())
        for temporary, target in prepared:
            os.replace(temporary, target)
            published.append(target)
    except BaseException as error:
        failures = []
        for target in reversed(published):
            try:
                backup = originals[target]
                if backup is None:
                    target.unlink()
                else:
                    # Keep the recovery copy even after a successful restoration.
                    restore = target.with_name(target.name + ".restore." + uuid.uuid4().hex)
                    shutil.copy2(backup, restore)
                    os.replace(restore, target)
            except OSError as rollback:
                failures.append(str(rollback))
        if failures:
            raise RuntimeError(f"publication and restoration failed; recovery: {recovery}; {failures}") from error
        raise
    finally:
        for temporary, _ in prepared:
            if temporary.exists():
                temporary.unlink()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for argument in ("image", "manifest", "destination", "recovery"):
        parser.add_argument(argument, type=Path)
    args = parser.parse_args()
    publish(args.image, args.manifest, args.destination, args.recovery)
