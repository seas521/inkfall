#!/usr/bin/env python3
"""Builds `rest_to_run`: a few interpolated frames from the resting pose into the run loop.

    /tmp/imgenv/bin/python scripts/tools/build_transition.py [--frames 4]     (after rife_upsample.py)

Cutting straight from the upright resting pose to the hunched run is a one-frame change of a few pixels
(head 4-7 px, legs). This morphs between the two over `--frames` frames (4 at 60fps = 67 ms, short enough
that the run still starts the instant the key goes down) with the same RIFE interpolation as the rest of
the clips (silhouette and eye separately). The run loop then continues at `exit_run_index`.
"""
import argparse
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

from rife_upsample import CLIPS, compose, eye_mask

RIFE = Path(os.path.expanduser("~/tools/rife-ncnn-vulkan-20221029-macos"))


def frames_of(name):
    folder = CLIPS / name
    manifest = json.loads((folder / "manifest.json").read_text())
    return manifest, [np.array(Image.open(folder / ("frame_%03d.png" % i)).convert("RGBA")) for i in range(int(manifest["frames"]))]


def features(rgba):
    ys, _ = np.where(rgba[..., 3] > 128)
    return int(ys.min()), float(ys.mean())


def cost(a, b):
    fa, fb = features(a), features(b)
    return float(((a[..., 3] > 128) ^ (b[..., 3] > 128)).sum()) + 700.0 * (abs(fa[0] - fb[0]) + abs(fa[1] - fb[1]))


def interpolate(first, last, count):
    results = []
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        for tag, extract in (("sil", lambda f: 255 - f[..., 3]), ("eye", lambda f: 255 - (np.clip(eye_mask(f), 0, 1) * 255).astype(np.uint8))):
            inp = work / ("in_" + tag)
            out = work / ("out_" + tag)
            inp.mkdir()
            out.mkdir()
            for i, frame in enumerate((first, last)):
                Image.fromarray(extract(frame).astype(np.uint8), "L").convert("RGB").save(inp / ("%08d.png" % (i + 1)))
            subprocess.run(
                [str(RIFE / "rife-ncnn-vulkan"), "-i", str(inp), "-o", str(out), "-m", "rife-v4.6", "-n", str(count + 2), "-x", "-z"],
                check=True, capture_output=True, cwd=RIFE,
            )
            results.append([np.array(Image.open(p).convert("L")) for p in sorted(out.glob("*.png"))])
    return [compose(results[0][i], results[1][i]) for i in range(1, count + 1)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames", type=int, default=4)
    args = parser.parse_args()
    _, idle = frames_of("idle_left")
    _, run = frames_of("run_left")
    rest = idle[0]
    best = min(range(len(run)), key=lambda k: cost(rest, run[k]))
    print("the run starts at run_left frame", best, "head", features(rest)[0], "->", features(run[best])[0])
    bridge = interpolate(rest, run[best], args.frames)
    folder = CLIPS / "rest_to_run"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir()
    for i, frame in enumerate(bridge):
        Image.fromarray(frame, "RGBA").save(folder / ("frame_%03d.png" % i))
    manifest = {
        "name": "rest_to_run", "frames": len(bridge), "fps": 60.0, "loop": False, "canvas": 256,
        "root": [128.0, 232.0], "frame_factor": 1.0, "upsampled": True, "exit_run_index": best,
        "note": "interpolated frames from the resting pose into run_left[exit_run_index]",
    }
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print("wrote", len(bridge), "frames")


if __name__ == "__main__":
    main()
