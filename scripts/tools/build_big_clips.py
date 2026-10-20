#!/usr/bin/env python3
"""Cuts the heavy two-handed item video (Seedance 3540) into clips, and tracks the hands.

    ffmpeg -i VIDEO -fps_mode passthrough FRAMES/%04d.png
    /tmp/imgenv/bin/python scripts/tools/build_big_clips.py VIDEO FRAMES

The video: stand 0-18, deep squat and lift 19-80 (arms forward, hands low, then up), hold 82-104,
heavy walk 108-142 (slow steps, arms held forward), wind-up 146-163 (arms raised behind the head),
throw 164-170 (a black ball is drawn leaving the hands in 164-166; it is a separate piece and is cut away
with the other specks), recover 176-216 bent over, stand.

Clips (native facing left, 384 px canvas, root (192, 348), scale 0.528, root-x 456.8, ground 759):
  big_pickup          19-80    squat, grab, stand up with the item (put down = reversed)
  big_hold            90       one frame, holding the item
  big_walk            114-134  loop of 2 slow steps
  big_throw_charge    144-162  lean back, arms up behind the head
  big_throw_release   163-178  the heave and the stumble forward (the item leaves at `release_orig_frame`)
  big_throw_recover   178-222  bent over, catches breath, stands up, ends in the resting pose

`hold_points`: where the hands are (the item is held against them), canvas px from the root:
tracked by following the extreme points of the silhouette from the held pose (frame 100) backwards to the
squat and forwards through the walk and the wind-up; in the release frames (164+) the arms are straight
ahead and the forward-most point is used.
"""
import glob
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import ConvexHull

PROJECT = Path(__file__).resolve().parents[2]
OUT = PROJECT / "assets/art/prototypes/hood_clips"
TOOL = PROJECT / "scripts/tools/seedance_frames.py"
SCALE = 0.528
ROOT_SRC = (456.8, 759.0)

CLIPS = [
    ("big_pickup", 19, 80, False),
    ("big_hold", 90, 90, False),
    ("big_walk", 114, 134, True),
    ("big_throw_charge", 144, 162, False),
    ("big_throw_release", 163, 178, False),
    ("big_throw_recover", 178, 222, False),
]


def main():
    video, frames = sys.argv[1], sys.argv[2]
    files = sorted(glob.glob(str(Path(frames) / "*.png")))
    cache = {}

    def mask(i):
        if i not in cache:
            a = np.array(Image.open(files[i]).convert("RGB")).astype(int)
            g = a[..., 1] - np.maximum(a[..., 0], a[..., 2])
            m = (g < 60) & (a.sum(2) < 260)
            lab, n = ndimage.label(m)
            if n > 1:
                sizes = ndimage.sum(m, lab, range(1, n + 1))
                m = lab == (int(np.argmax(sizes)) + 1)
            cache[i] = m
        return cache[i]

    def hull(m):
        edge = m & ~ndimage.binary_erosion(m)
        ys, xs = np.where(edge)
        pts = np.stack([xs, ys], 1)
        return pts[ConvexHull(pts).vertices].astype(float)

    def front(i):
        ys, xs = np.where(mask(i))
        sel = xs <= xs.min() + 6
        return np.array([xs[sel].mean(), ys[sel].mean()])

    seed = front(100)
    path = {100: seed}

    def follow(order, start, max_step=140):
        pos = start.copy()
        for i in order:
            hv = hull(mask(i))
            d = np.linalg.norm(hv - pos, axis=1)
            if d.min() <= max_step:
                pos = hv[int(np.argmin(d))]
            path[i] = pos.copy()

    follow(range(99, 13, -1), seed)
    follow(range(101, 164), seed)
    for i in range(164, 232):
        path[i] = front(i)

    for name, first, last, loop in CLIPS:
        command = [
            sys.executable, str(TOOL), video, "--name", name, "--out", str(OUT),
            "--start", str(first), "--end", str(last),
            "--scale", str(SCALE), "--root-x", str(ROOT_SRC[0]), "--ground-y", str(ROOT_SRC[1]), "--key", "green", "--canvas", "384",
        ]
        if loop:
            command.append("--loop")
        subprocess.run(command, check=True, capture_output=True)
        manifest_path = OUT / name / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        points = []
        for i in range(first, last + 1):
            points.append([float((path[i][0] - ROOT_SRC[0]) * SCALE), float((path[i][1] - ROOT_SRC[1]) * SCALE)])
        manifest["hold_points"] = points
        if name == "big_pickup":
            manifest["grasp_orig_frame"] = 62 - first  # the hands are on the item and start to rise
        if name == "big_throw_release":
            manifest["release_orig_frame"] = 164 - first
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print(name, manifest["frames"], "frames")


if __name__ == "__main__":
    main()
