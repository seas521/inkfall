#!/usr/bin/env python3
"""Leg-phase tables so that clips join without a pop in the stride.

    /tmp/imgenv/bin/python scripts/tools/build_phase_tables.py

The run is a loop of strides and the other clips (start, stop, jump takeoff, landing) were cut from
other places in the video, so a plain hand-over would jump from one leg position to another. For every
frame of `run_left` this finds the best matching frame (silhouette difference) in the clip that takes
over, and the reverse. Indices are in the ORIGINAL 24fps frames (the manifests' `frame_factor` converts
them to the interpolated clip). Results are written into the manifests:

  run_left.entry_from_rest      run_left frame to start the run from the resting pose (no start-up clip)
  stop_left.exit_to_run         for each stop_left frame: run_left frame to resume the run at
  stop_left.entry_from_run      for each run_left frame: stop_left frame to start from (first 6)
  run_takeoff.entry_from_run    for each run_left frame: run_takeoff frame to start from (first 4)
  run_land.exit_run_frame       run_left frame to continue with after run_land ends
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
CLIPS = PROJECT / "assets/art/prototypes/hood_clips"
BACKUP = PROJECT / "artifacts/hood-frames/24fps"
CANVAS = 384
ROOT = np.array([192, 348])


def load(name):
    folder = BACKUP / name if (BACKUP / name).exists() else CLIPS / name
    manifest = json.loads((folder / "manifest.json").read_text())
    count = int(manifest.get("original_frames", manifest["frames"]))
    root = np.array(manifest["root"], dtype=int)
    masks = []
    for i in range(count):
        alpha = np.array(Image.open(folder / ("frame_%03d.png" % i)).convert("RGBA"))[..., 3] > 128
        big = np.zeros((CANVAS, CANVAS), bool)
        oy, ox = ROOT[1] - root[1], ROOT[0] - root[0]
        big[oy:oy + alpha.shape[0], ox:ox + alpha.shape[1]] = alpha[: CANVAS - oy, : CANVAS - ox]
        masks.append(big)
    return Seq(masks)


def features(mask):
    rows = np.where(mask.any(axis=1))[0]
    ys, _ = np.where(mask)
    return int(rows.min()), float(ys.mean())  # head top, body centre height


def diff(a, b):
    return int((a ^ b).sum())


class Seq:
    """A clip's masks plus the height features of each frame."""

    def __init__(self, masks):
        self.masks = masks
        self.feat = [features(m) for m in masks]

    def __len__(self):
        return len(self.masks)


def cost(a, ia, b, ib, window=3):
    """Silhouette difference of the last `window` frames up to ia / ib, plus how far apart the head and the
    body centre are: matching legs alone gave a hand-over where the body jumped up a few pixels (the start
    clip ends hunched, the run frame with the best legs was an upright one)."""
    total = 0.0
    for offset in range(window):
        x = max(0, ia - offset)
        y = max(0, ib - offset)
        total += diff(a.masks[x], b.masks[y])
        total += 700.0 * (abs(a.feat[x][0] - b.feat[y][0]) + abs(a.feat[x][1] - b.feat[y][1]))
    return total


def write(name, **fields):
    path = CLIPS / name / "manifest.json"
    manifest = json.loads(path.read_text())
    manifest.update(fields)
    path.write_text(json.dumps(manifest, indent=2))


def main():
    run = load("run_left")
    stop = load("stop_left")
    takeoff = load("run_takeoff")
    land = load("run_land")
    n = len(run)

    idle = load("idle_left")
    best = min(range(n), key=lambda k: cost(idle, 0, run, k))
    write("run_left", entry_from_rest=best)
    print("leaving the resting pose, the run starts at run_left frame", best, "head", idle.feat[0][0], "->", run.feat[best][0])

    exits = [min(range(n), key=lambda k: cost(stop, j, run, k)) for j in range(len(stop))]
    write("stop_left", exit_to_run=exits)
    print("stop -> run", exits)

    entry = [min(range(min(6, len(stop))), key=lambda j: cost(run, k, stop, j)) for k in range(n)]
    write("stop_left", entry_from_run=entry)
    print("stop entry", entry)

    entry = [min(range(min(4, len(takeoff))), key=lambda j: cost(run, k, takeoff, j)) for k in range(n)]
    write("run_takeoff", entry_from_run=entry)
    print("takeoff entry", entry)

    best = min(range(n), key=lambda k: cost(land, len(land) - 1, run, k))
    write("run_land", exit_run_frame=best)
    print("run_land ends like run_left frame", best, "top", land.feat[-1][0], "->", run.feat[best][0], "diff", diff(run.masks[best], land.masks[-1]))


if __name__ == "__main__":
    main()
