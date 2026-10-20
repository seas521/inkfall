#!/usr/bin/env python3
"""Builds the `settle` clip: the feet-together pose every stop/turn clip ends in cross-fades into
the first frame of the idle loop (feet apart), so coming to rest does not pop.

    python scripts/tools/make_settle.py [--blend 6]

Native orientation is facing left (like stop_left); the idle frame is mirrored to match.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "artifacts/hood-frames"


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--blend", type=int, default=6)
    args = ap.parse_args()
    out = ROOT / "settle"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("frame_*.png"):
        old.unlink()
    rest = load(sorted((ROOT / "stop_left").glob("frame_*.png"))[-1])
    idle = load(ROOT / "idle_right" / "frame_000.png")[:, ::-1, :]
    for i in range(1, args.blend + 1):
        t = i / (args.blend + 1)
        t = t * t * (3.0 - 2.0 * t)
        alpha = rest[:, :, 3] * (1 - t) + idle[:, :, 3] * t
        rgb = rest[:, :, :3] * (1 - t) + idle[:, :, :3] * t
        Image.fromarray(np.uint8(np.clip(np.dstack([rgb, alpha]) * 255.0, 0, 255)), "RGBA").save(out / f"frame_{i - 1:03d}.png")
    manifest = json.loads((ROOT / "stop_left" / "manifest.json").read_text())
    manifest.update({"name": "settle", "frames": args.blend, "loop": False})
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print("settle:", args.blend, "frames")


if __name__ == "__main__":
    main()
