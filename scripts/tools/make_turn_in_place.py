#!/usr/bin/env python3
"""Builds a turn-in-place clip out of existing frames: the resting pose cross-fades into the
front-facing part of the brake-turn clip (arms down, hunched), which then finishes the turn.

    python scripts/tools/make_turn_in_place.py [--first 18] [--blend 3]
"""
import argparse
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "artifacts/hood-frames"


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--first", type=int, default=18, help="brake_turn frame where the turn part starts")
    ap.add_argument("--blend", type=int, default=3, help="cross-fade frames from the standing pose")
    args = ap.parse_args()
    out = ROOT / "turn_in_place"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("frame_*.png"):
        old.unlink()
    brake = sorted((ROOT / "brake_turn").glob("frame_*.png"))
    standing = load(ROOT / "idle_left" / "frame_000.png")[:, ::-1, :]  # the resting pose, facing right
    start = load(brake[args.first])
    frames = []
    for i in range(1, args.blend + 1):
        t = i / (args.blend + 1)
        a = standing[:, :, 3] * (1 - t) + start[:, :, 3] * t
        rgb = standing[:, :, :3] * (1 - t) + start[:, :, :3] * t
        frames.append(np.dstack([rgb, a]))
    frames += [load(p) for p in brake[args.first:]]
    for index, frame in enumerate(frames):
        Image.fromarray(np.uint8(np.clip(frame * 255.0, 0, 255)), "RGBA").save(out / f"frame_{index:03d}.png")
    manifest = json.loads((ROOT / "brake_turn" / "manifest.json").read_text())
    manifest.update({"name": "turn_in_place", "frames": len(frames), "loop": False,
                     "note": f"idle_left/0 (mirrored) cross-fade x{args.blend} + brake_turn {args.first}..{len(brake) - 1}"})
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print("turn_in_place:", len(frames), "frames")


if __name__ == "__main__":
    main()
