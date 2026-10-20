#!/usr/bin/env python3
"""Cuts the water video (Seedance 4762, no water in the picture) into clips.

    /tmp/imgenv/bin/python scripts/tools/build_water_clips.py VIDEO        (then rife_upsample.py on the clips)

The video: stand 0-14, wade 15-53 (slow, high knees, arms out), drop into deep water 53-76 (a crouch, then he
kicks up with his arms thrown up), flail at the surface 76-108, swim 108-182 (the generator laid him flat,
a crawl), tire 182-190, drown 183-240 (arms up, sinking: he sinks out of the bottom of the picture, so only the
first part, while he is still in the frame, is used).

Everything is native facing left, 384 px canvas, scale 0.528. The water is drawn by the game over the lower body.

  water_wade     35-49   absolute (ground 759, root-x 456.8): the feet are on the bottom. Not a clean loop (7.2k seam).
  water_plunge   53-82   absolute: crouch and kick up out of the water.
  water_tread    83-94   centroid pinned to the canvas centre (192, 192): a floating body is positioned by the physics, the
                         clip only gives the pose; loop of 12 frames.
  water_swim     116-127 centroid pinned, loop of 12 frames (a crawl stroke), flat in the water.
  water_drown    183-212 top of the silhouette pinned at canvas row 60: the rest of the sinking is the physics' job.
"""
import json
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
OUT = PROJECT / "assets/art/prototypes/hood_clips"
TOOL = PROJECT / "scripts/tools/seedance_frames.py"

# name, first, last, loop, extra args
CLIPS = [
    ("water_wade", 35, 49, True, []),
    ("water_plunge", 53, 82, False, []),
    ("water_tread", 83, 94, True, ["--pin-centroid", "--root-pos", "192,192"]),
    ("water_swim", 116, 127, True, ["--pin-centroid", "--root-pos", "192,192"]),
    ("water_drown", 183, 212, False, ["--pin-top", "--root-pos", "192,60"]),
]


def main():
    video = sys.argv[1]
    for name, first, last, loop, extra in CLIPS:
        command = [
            sys.executable, str(TOOL), video, "--name", name, "--out", str(OUT),
            "--start", str(first), "--end", str(last),
            "--scale", "0.528", "--root-x", "456.8", "--ground-y", "759", "--key", "green", "--canvas", "384",
        ] + extra
        if loop:
            command.append("--loop")
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode not in (0, 2):
            print(result.stderr)
            raise SystemExit(result.returncode)
        manifest = json.loads((OUT / name / "manifest.json").read_text())
        print(name, manifest["frames"], "frames", "(warnings: %d)" % result.stdout.count("WARNING"))


if __name__ == "__main__":
    main()
