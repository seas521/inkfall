#!/usr/bin/env python3
"""Cuts the push/pull video (Seedance 3039, no object in the picture) into clips.

    /tmp/imgenv/bin/python scripts/tools/build_pushpull_clips.py VIDEO

The boy presses his palms against an invisible wall (the box is drawn by the game). In the video he stands
still on the spot (the camera is fixed), the hands stay at one place in the picture and the legs step.
Frames: stand 0-20, reach 21-28, hold 28-62, push 63-106 (steps), brace 107-128, step in and change grip
128-146, pull 147-190 (steps), release 205-218, stand again.

Clips (native facing left, 384 px canvas, root (192, 348), scale 0.528, ground 759):
  grip_engage   20-29    the arms reach out to the box (feet stay)
  grip_hold     45       one frame, braced against the box
  push          73-94    loop of 2 steps (22 frames)
  grip_to_pull  128-147  the grip changes, he steps in closer; feet pinned to the root
  pull          157-178  loop of 2 steps, hands pulling; root-x is the middle of the feet in the video
  grip_release  204-222  hands let go, straightens up; feet pinned to the root

Every manifest gets `hand_offset` (the hand tip, canvas px left of the root, median of the frames) and
`hand_offsets` (per frame): the box face goes at root + hand offset, so the hands stay on the box.
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

# name, first, last, loop, root-x, extra flags
CLIPS = [
    ("grip_engage", 20, 29, False, 456.8, []),
    ("grip_hold", 45, 45, False, 456.8, []),
    ("push", 73, 94, True, 456.8, []),
    ("grip_to_pull", 128, 147, False, 456.8, ["--pin-feet"]),
    ("pull", 157, 178, True, 574.0, []),
    ("grip_release", 204, 222, False, 456.8, ["--pin-feet"]),
]


def main():
    video = sys.argv[1]
    for name, first, last, loop, root_x, flags in CLIPS:
        command = [
            sys.executable, str(TOOL), video, "--name", name, "--out", str(OUT),
            "--start", str(first), "--end", str(last),
            "--scale", "0.528", "--root-x", str(root_x), "--ground-y", "759", "--key", "green", "--canvas", "384",
        ] + flags
        if loop:
            command.append("--loop")
        subprocess.run(command, check=True, capture_output=True)
        folder = OUT / name
        manifest_path = folder / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        root = manifest["root"]
        offsets = []
        for i in range(int(manifest["frames"])):
            alpha = np.array(Image.open(folder / ("frame_%03d.png" % i)).convert("RGBA"))[..., 3] > 128
            columns = np.where(alpha.any(axis=0))[0]
            offsets.append(float(columns.min()) - root[0])
        manifest["hand_offsets"] = offsets
        manifest["hand_offset"] = float(np.median(offsets))
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print(name, manifest["frames"], "frames, hand offset", round(manifest["hand_offset"], 1), "range", round(min(offsets), 1), round(max(offsets), 1))


if __name__ == "__main__":
    main()
