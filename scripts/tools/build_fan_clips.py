#!/usr/bin/env python3
"""Cuts the fan video (Seedance 8081) into clips, without the rod, and keeps the rod's pose per frame.

    ffmpeg -i VIDEO -fps_mode passthrough FRAMES/%04d.png
    /tmp/imgenv/bin/python scripts/tools/remove_thin_rod.py FRAMES CLEAN
    ffmpeg -framerate 24.06 -i CLEAN/%04d.png -c:v libx264 -crf 0 -pix_fmt yuv444p CLEAN.mp4
    /tmp/imgenv/bin/python scripts/tools/build_fan_clips.py CLEAN.mp4 CLEAN/rod.json

The generator drew a thin black rod (the fan's handle) in the boy's hands, and lying on the ground at the left
at the start and the end. `remove_thin_rod.py` takes it out of the picture and records where it was; here that
record becomes `rod` in every manifest, so the game can draw the fan (handle + leaf) exactly where the rod was:
per frame [near x, near y, tip x, tip y, angle in degrees], canvas px from the root, near = the end by the hand,
interpolated over the frames where the rod is hidden behind the body.

Clips (native facing left, 384 px canvas, root (192, 348), scale 0.528, root-x 456.8, ground 759):
  fan_pickup    14-54    bends to the rod on the ground, lifts it, stands with the right hand holding it at the waist
  fan_hold      70       one frame (same stance as small_hold)
  fan_swing_1   84-139   left hand joins, the body turns toward the screen, winds up, turns back and swings, ends with the
                         right hand holding it at the waist
  fan_swing_2   152-191  the same again, quicker
  fan_putdown   195-232  bends and lays it on the ground, straightens up (ends in the resting pose)
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np

PROJECT = Path(__file__).resolve().parents[2]
OUT = PROJECT / "assets/art/prototypes/hood_clips"
TOOL = PROJECT / "scripts/tools/seedance_frames.py"
SCALE = 0.528
ROOT_SRC = (456.8, 759.0)

CLIPS = [
    ("fan_pickup", 14, 54),
    ("fan_hold", 70, 70),
    ("fan_swing_1", 84, 139),
    ("fan_swing_2", 152, 191),
    ("fan_putdown", 195, 232),
]


def canvas(point):
    return [(point[0] - ROOT_SRC[0]) * SCALE, (point[1] - ROOT_SRC[1]) * SCALE]


def main():
    video, rod_path = sys.argv[1], sys.argv[2]
    rod = {int(k): v for k, v in json.loads(Path(rod_path).read_text()).items()}
    known = sorted(rod)
    for name, first, last in CLIPS:
        subprocess.run([
            sys.executable, str(TOOL), video, "--name", name, "--out", str(OUT),
            "--start", str(first), "--end", str(last),
            "--scale", str(SCALE), "--root-x", str(ROOT_SRC[0]), "--ground-y", str(ROOT_SRC[1]), "--key", "green", "--canvas", "384",
        ], check=True, capture_output=True)
        manifest_path = OUT / name / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        poses = []
        for i in range(first, last + 1):
            if i in rod:
                near, tip = rod[i]["near"], rod[i]["tip"]
            else:
                lows = [k for k in known if k < i]
                highs = [k for k in known if k > i]
                if lows and highs:
                    lo, hi = lows[-1], highs[0]
                    t = (i - lo) / (hi - lo)
                    near = [rod[lo]["near"][j] * (1 - t) + rod[hi]["near"][j] * t for j in range(2)]
                    tip = [rod[lo]["tip"][j] * (1 - t) + rod[hi]["tip"][j] * t for j in range(2)]
                else:
                    ref = rod[lows[-1] if lows else highs[0]]
                    near, tip = ref["near"], ref["tip"]
            n, t = canvas(near), canvas(tip)
            angle = float(np.degrees(np.arctan2(t[1] - n[1], t[0] - n[0])))
            poses.append(n + t + [angle])
        manifest["rod"] = poses
        manifest["hidden_rod_frames"] = [i - first for i in range(first, last + 1) if i not in rod]
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print(name, manifest["frames"], "frames,", len(manifest["hidden_rod_frames"]), "with the rod hidden")


if __name__ == "__main__":
    main()
