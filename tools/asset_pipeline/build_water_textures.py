"""Build tileable water normals from CC0 wave heights, and original foam noise.

Requires NumPy and Pillow. Run from any directory; --check is read-only.
The two small original frames are retained so rebuilding does not need a download.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/water"
SOURCE = OUT / "source"
SOURCE_URL = "https://opengameart.org/content/seamless-looping-waves-heightmaps"
ARCHIVE_URL = "https://opengameart.org/sites/default/files/waves5.zip"


def png_bytes(pixels: np.ndarray) -> bytes:
    buffer = io.BytesIO()
    Image.fromarray(pixels).save(buffer, format="PNG", compress_level=9)
    return buffer.getvalue()


def water_normal(frame: Path, rms_slope: float) -> bytes:
    height = np.asarray(Image.open(frame).convert("L"), dtype=np.float64) / 255.0
    # Periodic centered derivatives preserve the source's seamless boundaries.
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    scale = rms_slope / np.sqrt(np.mean(dx * dx + dy * dy))
    normal = np.stack((-dx * scale, -dy * scale, np.ones_like(height)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    return png_bytes(np.rint((normal * 0.5 + 0.5) * 255).astype(np.uint8))


def foam_mask() -> bytes:
    """Periodic cellular foam with several scales of slowly varying turbulence."""
    size, cells = 512, 19
    rng = np.random.default_rng(15052026)
    y, x = np.mgrid[:size, :size].astype(np.float64)
    x, y = x * cells / size, y * cells / size
    base_x, base_y = np.floor(x).astype(int), np.floor(y).astype(int)
    jitter = rng.uniform(0.15, 0.85, (cells, cells, 2))
    closest = np.full((size, size), np.inf)
    second = closest.copy()
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            gx, gy = base_x + ox, base_y + oy
            offset = jitter[gy % cells, gx % cells]
            distance = np.square(x - gx - offset[..., 0]) + np.square(y - gy - offset[..., 1])
            second = np.minimum(second, np.maximum(closest, distance))
            closest = np.minimum(closest, distance)
    edges = np.exp(-(np.sqrt(second) - np.sqrt(closest)) * 12.0)
    turbulence = np.zeros((size, size))
    for kx, ky, amplitude, phase in ((2, 3, 0.22, 0.3), (5, -4, 0.13, 1.8), (9, 7, 0.08, 2.9)):
        turbulence += amplitude * np.sin(2 * np.pi * (kx * x + ky * y) / cells + phase)
    foam = np.clip(0.14 + edges * 0.56 + turbulence * 0.48, 0, 1)
    return png_bytes(np.rint(foam * 255).astype(np.uint8))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="Optional downloaded waves5.zip; keeps only frames 000/067")
    parser.add_argument("--check", action="store_true", help="Verify output bytes without writing")
    args = parser.parse_args()
    if args.archive:
        if args.check:
            parser.error("--archive cannot be combined with read-only --check")
        SOURCE.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.archive) as archive:
            for name in ("000", "067"):
                data = archive.read(f"waves5/{name}.png")
                with Image.open(io.BytesIO(data)) as image:
                    if image.size != (512, 512):
                        raise ValueError("Unexpected source dimensions")
                (SOURCE / f"waves5_{name}.png").write_bytes(data)
        (SOURCE / ".gdignore").write_text("", encoding="utf-8")
    outputs = {
        "water_normal.png": water_normal(SOURCE / "waves5_000.png", 0.16),
        "water_detail_normal.png": water_normal(SOURCE / "waves5_067.png", 0.10),
        "water_foam.png": foam_mask(),
    }
    receipt = {
        "author": "zookeeper",
        "source_page": SOURCE_URL,
        "archive_url": ARCHIVE_URL,
        "license": "CC0-1.0",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "frames": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(SOURCE.glob("*.png"))},
        "method": "Periodic centered derivatives of source heights; normalized tangent-space +Y normals. Original periodic cellular foam.",
        "outputs": {name: hashlib.sha256(data).hexdigest() for name, data in outputs.items()},
    }
    outputs["source_receipt.json"] = (json.dumps(receipt, indent=2) + "\n").encode()
    for name, data in outputs.items():
        target = OUT / name
        if args.check:
            if not target.exists() or target.read_bytes() != data:
                raise SystemExit(f"FAIL reproducibility: {name}")
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        print(f"{'VERIFIED' if args.check else 'WROTE'} {name} {len(data)} bytes")


if __name__ == "__main__":
    main()
