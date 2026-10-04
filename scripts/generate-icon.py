"""Render the Spellbook icon from its masters into the .ico and the 256 px PNG.

Reads assets/brand/spellbook-icon-small.svg (the 16 to 32 px drawing: one
sparkle, heavier text lines) and assets/brand/spellbook-icon.svg (40 px and up),
and writes assets/spellbook.ico (16, 20, 24, 32, 40, 48, 64, 256 px, each frame
rendered at its own size, never resampled) and assets/spellbook-256.png. Rerun
it after changing a master:

    python scripts/generate-icon.py

The masters come from the Spellbook brand kit (Rizonesoft branding, "Spellbook",
Source Files/build-kit.py), which also writes the logo, banners, and web files.
Needs Pillow (pip install pillow) and Microsoft Edge or Google Chrome, which
renders the SVGs. Not part of any gate: the outputs are committed.
"""
from __future__ import annotations

import base64
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
BRAND = ASSETS / "brand"
SIZES = (16, 20, 24, 32, 40, 48, 64, 256)
SMALL_MAX = 32
BROWSERS = (
    Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
    Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
    Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
)


def browser() -> Path:
    for b in BROWSERS:
        if b.exists():
            return b
    raise SystemExit("generate-icon: Microsoft Edge or Google Chrome is required to render the SVG masters")


def render(svg: Path, size: int, out: Path) -> Image.Image:
    data = base64.b64encode(svg.read_bytes()).decode("ascii")
    page = out.with_suffix(".html")
    page.write_text(
        f'<html><body style="margin:0;background:transparent"><img src="data:image/svg+xml;base64,{data}" '
        f'style="display:block;width:{size}px;height:{size}px"></body></html>',
        encoding="utf-8",
    )
    subprocess.run(
        [str(browser()), "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
         "--default-background-color=00000000", f"--window-size={size},{size}", f"--screenshot={out}", page.as_uri()],
        check=True, capture_output=True, timeout=120,
    )
    img = Image.open(out).convert("RGBA")
    if img.size != (size, size):
        raise SystemExit(f"generate-icon: rendered {img.size} for a {size} px frame")
    return img


def main() -> None:
    with tempfile.TemporaryDirectory() as td:
        frames = []
        for s in SIZES:
            master = BRAND / ("spellbook-icon-small.svg" if s <= SMALL_MAX else "spellbook-icon.svg")
            frames.append(render(master, s, Path(td) / f"frame-{s}.png"))
        ico = ASSETS / "spellbook.ico"
        frames[-1].save(ico, format="ICO", sizes=[(s, s) for s in SIZES], append_images=frames[:-1])
        frames[-1].save(ASSETS / "spellbook-256.png")
    # Every frame must be the drawing rendered for its size, not a resample of the 256 px one.
    check = Image.open(ico)
    for s, frame in zip(SIZES, frames):
        check.size = (s, s)
        if check.copy().convert("RGBA").tobytes() != frame.tobytes():
            raise SystemExit(f"generate-icon: the {s} px frame was resampled")
    print(f"wrote {ico} ({', '.join(map(str, SIZES))} px) and {ASSETS / 'spellbook-256.png'}")


if __name__ == "__main__":
    main()
