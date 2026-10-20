#!/usr/bin/env python3
"""Cuts the small-item (one hand) video (Seedance 2968) into clips.

    /tmp/imgenv/bin/python scripts/tools/build_small_clips.py VIDEO

The video: stand 0-13, pick up 14-39, hold 40-64, [a fan swing 65-82: the generator drew a black fan there,
unusable, so that part is cut out and made again], hold 83-95, carry run 96-136, carry jump 137-171,
throw charge 172-192, throw 193-214, recover 214-230, stand.

Clips (native facing left, 384 px canvas, root (192, 348), scale 0.528, root-x 456.8, ground 759):
  small_pickup         13-39    bend, pick up, straighten with the hand held in front (put down = reversed)
  small_hold           50       one frame, standing with the item in the hand
  small_run            103-115  loop of 2 steps, item in the hand
  small_jump_takeoff   144-146  \\
  small_jump_rise      147-149   | the jump, split like the empty-handed jump (the video's own height is
  small_jump_apex      150-153   | removed: airborne frames are put on the ground line, the physics decides
  small_jump_fall      154-157  /  the height)
  small_jump_land      158-171  landing and recovery
  small_throw_charge   172-188  arm drawn back behind the head (hold the last frame while charging)
  small_throw_release  192-214  the whip and the follow-through (the item leaves at `release_frame`)
  small_throw_recover  214-230  straightens up, ends in the resting pose

Every manifest also gets `hold_points`: per frame, where the item sits (the front-most hand point, in canvas
px from the root), so the game can draw the item in the hand.
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

# name, first, last, loop, fps (None = native), pin airborne frames down
CLIPS = [
    ("small_pickup", 13, 39, False, None, False),
    ("small_hold", 50, 50, False, None, False),
    ("small_run", 103, 115, True, None, False),
    ("small_jump_takeoff", 144, 146, False, 32.0, True),
    ("small_jump_rise", 147, 149, False, 10.0, True),
    ("small_jump_apex", 150, 153, False, None, True),
    ("small_jump_fall", 154, 157, False, None, True),
    ("small_jump_land", 158, 171, False, None, False),
    ("small_throw_charge", 172, 188, False, None, False),
    ("small_throw_release", 192, 214, False, None, False),
    ("small_throw_recover", 214, 230, False, None, False),
]


def bottom_row(rgba):
    rows = np.where(rgba[..., 3] > 128)[0]
    return int(rows.max()) if len(rows) else 0


def main():
    video = sys.argv[1]
    for name, first, last, loop, fps, pin in CLIPS:
        command = [
            sys.executable, str(TOOL), video, "--name", name, "--out", str(OUT),
            "--start", str(first), "--end", str(last),
            "--scale", "0.528", "--root-x", "456.8", "--ground-y", "759", "--key", "green", "--canvas", "384",
        ]
        if loop:
            command.append("--loop")
        subprocess.run(command, check=True, capture_output=True)
        folder = OUT / name
        points = []
        paths = sorted(folder.glob("frame_*.png"))
        manifest_path = folder / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        root = manifest["root"]
        for path in paths:
            image = np.array(Image.open(path).convert("RGBA"))
            if pin:
                shift = GROUND_ROW - bottom_row(image)
                if shift > 6:
                    moved = np.zeros_like(image)
                    moved[shift:] = image[: image.shape[0] - shift]
                    image = moved
                    Image.fromarray(image, "RGBA").save(path)
            alpha = image[..., 3] > 128
            columns = np.where(alpha.any(axis=0))[0]
            x_front = int(columns.min())
            ys, xs = np.where(alpha[:, x_front: x_front + 7])
            points.append([float(x_front - root[0]), float(ys.mean() - root[1])])
        manifest["hold_points"] = points
        if fps:
            manifest["fps"] = fps
        manifest["pinned_to_ground"] = pin
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print(name, len(paths), "frames, hold point at the end", [round(v, 1) for v in points[-1]])


if __name__ == "__main__":
    main()
