#!/usr/bin/env python3
"""Cuts the fall video (Seedance 2341) into clips for the physics-driven actor.

    /tmp/imgenv/bin/python scripts/tools/build_fall_clips.py VIDEO

The video: stand, trip (20-31), tumble in the air (32-55), hit the ground and lie (56-72), lie still
(73-97), get up (98-150), stand (150-176), flinch back (177-200), settle. Clips (native facing left,
384 px canvas, root (192, 348), scale 0.528, root-x 456.8, ground 759, like the jump clips):

  fall_air     20-55   the trip and the tumble, played once and held on its last pose until he lands.
                       The video's own fall (he is thrown up and drops) is removed: every airborne frame is
                       moved down until its lowest point is on the ground line, because the actor's height
                       comes from the physics.
  fall_impact  56-72   hits the ground and settles flat.
  downed       76-96   lying still (loop, boomerang).
  get_up       98-152  crawl, kneel, stand, settle in the resting pose.
  flinch       177-238 the recoil from a scare; the video drifts sideways, so the feet are pinned to the root.

The ground in the lying frames sits 10-14 px lower than the standing feet in the video; those frames are
lifted (smoothed, so there is no flicker) to put the body on the ground line.
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
OUT = PROJECT / "assets/art/prototypes/hood_clips"
TOOL = PROJECT / "scripts/tools/seedance_frames.py"
GROUND_ROW = 347

# name, first, last, loop, extra tool flags, mode: "air" (pin airborne frames down) / "ground" (lift lying frames) / ""
CLIPS = [
    ("fall_air", 20, 55, False, [], "air"),
    ("fall_impact", 56, 72, False, [], "both"),
    ("downed", 76, 96, True, ["--boomerang"], "ground"),
    ("get_up", 98, 152, False, [], "ground"),
    ("flinch", 177, 238, False, ["--pin-feet"], ""),
]


def bottom_row(array):
    rows = np.where(array[..., 3] > 128)[0]
    return int(rows.max()) if len(rows) else 0


def shift_vertical(array, amount):
    moved = np.zeros_like(array)
    if amount > 0:
        moved[amount:] = array[: array.shape[0] - amount]
    elif amount < 0:
        moved[:amount] = array[-amount:]
    else:
        moved = array
    return moved


def main():
    video = sys.argv[1]
    for name, first, last, loop, flags, mode in CLIPS:
        command = [
            sys.executable, str(TOOL), video, "--name", name, "--out", str(OUT),
            "--start", str(first), "--end", str(last),
            "--scale", "0.528", "--root-x", "456.8", "--ground-y", "759", "--key", "green", "--canvas", "384",
        ] + flags
        if loop and "--boomerang" not in flags:
            command.append("--loop")
        subprocess.run(command, check=True, capture_output=True)
        folder = OUT / name
        paths = sorted(folder.glob("frame_*.png"))
        arrays = [np.array(Image.open(p).convert("RGBA")) for p in paths]
        bottoms = np.array([bottom_row(a) for a in arrays])
        if mode == "air":
            shifts = [GROUND_ROW - b if GROUND_ROW - b > 6 else 0 for b in bottoms]
        elif mode == "both":
            # the first frames are still in the air (pin them down), the rest lie on a ground that sits low
            excess = np.maximum(bottoms - GROUND_ROW, 0)
            smooth = [int(np.median(excess[max(0, i - 3): i + 4])) for i in range(len(excess))]
            shifts = [(GROUND_ROW - b) if GROUND_ROW - b > 6 else -smooth[i] for i, b in enumerate(bottoms)]
        elif mode == "ground":
            excess = bottoms - GROUND_ROW
            excess = np.maximum(excess, 0)
            # median over 7 frames so the body does not flicker up and down
            smooth = [int(np.median(excess[max(0, i - 3): i + 4])) for i in range(len(excess))]
            shifts = [-s for s in smooth]
        else:
            shifts = [0] * len(arrays)
        for path, array, shift in zip(paths, arrays, shifts):
            if shift:
                Image.fromarray(shift_vertical(array, int(shift)), "RGBA").save(path)
        manifest_path = folder / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["mode"] = mode
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print(name, len(paths), "frames, shifts", sorted(set(int(s) for s in shifts))[:8])


if __name__ == "__main__":
    main()
