#!/usr/bin/env python3
"""Cuts `fall_loop` out of the long-fall video (Seedance 8804): an upright, flailing free fall that loops.

    /tmp/imgenv/bin/python scripts/tools/build_fall_loop.py VIDEO        (then rife_upsample.py fall_loop)

The video: stand 0-14, he drops and from frame 16 flails the same way every 0.5 s (arms thrown up and waving, legs
kicking, hood tip and cloak streaming up). Frames 74-99 are a 26-frame loop (seam 511 against an ordinary step of
1766). The body bobs about in the picture, so the silhouette's centre is pinned to the middle of the canvas
(root (192, 192)): the controller's physics decides where he is, the clip only gives the pose.
"""
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
subprocess.run([
    sys.executable, str(PROJECT / "scripts/tools/seedance_frames.py"), sys.argv[1], "--name", "fall_loop",
    "--out", str(PROJECT / "assets/art/prototypes/hood_clips"), "--start", "74", "--end", "99", "--loop",
    "--scale", "0.528", "--root-x", "456.8", "--ground-y", "759", "--key", "green", "--canvas", "384",
    "--pin-centroid", "--root-pos", "192,192",
], check=True)
