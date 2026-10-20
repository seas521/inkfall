#!/usr/bin/env python3
"""Builds `shoved_in`: a few interpolated frames from the resting pose into the braced pose of `shoved`.

    /tmp/imgenv/bin/python scripts/tools/build_shove_in.py [--frames 5]     (after rife_upsample.py shoved)

The video starts already braced, so the moment the weight arrives (upright -> leaning hard with the palms up)
is made with the same RIFE interpolation as the other bridges. Canvas 384 like `shoved`.
"""
import argparse
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

from build_transition import frames_of, interpolate
from rife_upsample import CLIPS


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames", type=int, default=5)
    args = parser.parse_args()
    _, idle = frames_of("idle_left")
    manifest, shoved = frames_of("shoved")
    rest = np.zeros((384, 384, 4), dtype=np.uint8)
    rest[116:372, 64:320] = idle[0]  # 256 canvas root (128, 232) -> 384 canvas root (192, 348)
    bridge = interpolate(rest, shoved[0], args.frames)
    folder = CLIPS / "shoved_in"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir()
    for i, frame in enumerate(bridge):
        Image.fromarray(frame, "RGBA").save(folder / ("frame_%03d.png" % i))
    out = {"name": "shoved_in", "frames": len(bridge), "fps": 60.0, "loop": False, "canvas": 384, "root": [192.0, 348.0],
           "frame_factor": 1.0, "upsampled": True, "hand_offset": manifest["hand_offset"]}
    (folder / "manifest.json").write_text(json.dumps(out, indent=2))
    print("wrote", len(bridge), "frames")


if __name__ == "__main__":
    main()
