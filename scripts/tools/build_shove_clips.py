#!/usr/bin/env python3
"""Cuts the "pushed back by a heavy rolling thing" video (Seedance 4209, no object) into clips.

    /tmp/imgenv/bin/python scripts/tools/build_shove_clips.py VIDEO        (then rife_upsample.py shoved shoved_out)

The boy starts already braced (leaning hard, palms flat on an invisible weight, back leg driving, front knee bent)
and is pushed backwards: his whole body drifts to the right in the picture while the feet scrape. 4-84 braced and
pushed, 84-120 the weight leaves, he lurches forward, straightens and stands.

Clips (native facing left, 384 px canvas, root (192, 348), scale 0.528, ground 759):
  shoved      50-71   a loop of two scrapes. The hands are kept 65 canvas px left of the root (`--pin-hands`), because the
                      hands stay on the weight while the body drifts: the game puts the weight's face at root - 65 px
                      and moves both along (the rock's speed).
  shoved_out  84-120  the weight leaves; root-x is the video's own (456.8) so it ends in the resting pose. The first
                      frame has the hands at the same 65 px, so it follows `shoved` without a jump.
  shoved_in   (made by build_transition.py --from rest --to shoved)  a few interpolated frames from the resting pose into
                      the braced pose.
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

CLIPS = [
    ("shoved", 50, 71, True, ["--pin-hands", "122.8"]),
    ("shoved_out", 84, 120, False, []),
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
        subprocess.run(command, check=True, capture_output=True)
        folder = OUT / name
        manifest_path = folder / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        tips = []
        for i in range(int(manifest["frames"])):
            alpha = np.array(Image.open(folder / ("frame_%03d.png" % i)).convert("RGBA"))[..., 3] > 128
            tips.append(float(np.where(alpha.any(axis=0))[0].min()) - manifest["root"][0])
        manifest["hand_offsets"] = tips
        manifest["hand_offset"] = float(np.median(tips[:6]))
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print(name, manifest["frames"], "frames, hand offset", round(manifest["hand_offset"], 1))


if __name__ == "__main__":
    main()
