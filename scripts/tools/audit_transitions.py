#!/usr/bin/env python3
"""Audits every clip-to-clip connection of the hooded boy's locomotion (prototype frames, before packaging).

    /tmp/imgenv/bin/python scripts/tools/audit_transitions.py

For each connection the game makes (A's last frame -> B's first frame, or the frame the phase tables pick), the two silhouettes are
aligned by the feet and compared: how many pixels differ (as a share of the bigger one), the height ratio and the width ratio. Anything
above ~12% difference or off by more than 4% in height shows on the screen as a jump. Also prints the standing height of every
video: the clips come from different Seedance videos and the boy is not drawn at exactly the same size in each.
"""
import glob
import json
from pathlib import Path

import numpy as np
from PIL import Image

CLIPS = Path(__file__).resolve().parents[2] / "assets/art/prototypes/hood_clips"


def count(name):
    return len(glob.glob(str(CLIPS / name / "frame_*.png")))


def mask(name, index):
    if index < 0:
        index = count(name) + index
    return np.array(Image.open(CLIPS / name / ("frame_%03d.png" % index)).convert("RGBA"))[..., 3] > 128


def root_of(name, index):
    manifest = json.loads((CLIPS / name / "manifest.json").read_text())
    root = manifest["root"]
    if name == "climb":
        # the climb is rooted at the ledge corner; where he stands at the start / end is in the manifest
        key = "start_feet" if (index == 0) else "end_feet"
        return (root[0] + manifest[key][0], root[1] + manifest[key][1])
    return (root[0], root[1])


def aligned(name, index):
    """The silhouette placed on a common canvas with the clip's own root (the feet) at (300, 500)."""
    m = mask(name, index)
    rx, ry = root_of(name, index if index >= 0 else count(name) - 1)
    ys, xs = np.where(m)
    out = np.zeros((700, 700), bool)
    ny, nx = np.round(ys - ry + 500).astype(int), np.round(xs - rx + 300).astype(int)
    ok = (ny >= 0) & (ny < 700) & (nx >= 0) & (nx < 700)
    out[ny[ok], nx[ok]] = True
    return out


def size(m):
    ys, xs = np.where(m)
    return ys.max() - ys.min() + 1, xs.max() - xs.min() + 1


def report(label, a, b):
    ma, mb = mask(*a), mask(*b)
    fa, fb = aligned(*a), aligned(*b)
    diff = int((fa ^ fb).sum()) / max(1, max(int(fa.sum()), int(fb.sum())))
    ha, wa = size(ma)
    hb, wb = size(mb)
    flag = "  <-- JUMP" if diff > 0.30 or abs(hb / ha - 1) > 0.04 else ""
    print("%-46s differ %4.0f%%  height x%.2f  width x%.2f%s" % (label, diff * 100, hb / ha, wb / wa, flag))


print("standing height of each source (px of the 384 canvas, native scale 0.528):")
for label, clip, index in [("idle_left (the reference picture)", "idle_left", 0), ("video a: tired_start, first frame", "tired_start", 0),
                           ("video b: clumsy_stand_takeoff, first frame", "clumsy_stand_takeoff", 0), ("video f: tired_rise, last rise frame", "tired_rise", -1)]:
    print("  %-46s %d" % (label, size(mask(clip, index))[0]))
print()
pairs = [
    ("idle_left -> tired_start", ("idle_left", 0), ("tired_start", 0)),
    ("tired_start end -> tired_run start", ("tired_start", -1), ("tired_run", 0)),
    ("tired_run end -> tired_run start (loop)", ("tired_run", -1), ("tired_run", 0)),
    ("tired_stop end -> tired_idle start", ("tired_stop", -1), ("tired_idle", 0)),
    ("tired_idle -> tired_rise start", ("tired_idle", 0), ("tired_rise", 0)),
    ("tired_rise end -> idle_left", ("tired_rise", -1), ("idle_left", 0)),
    ("tired_stop end -> tired_run (key pressed)", ("tired_stop", -1), ("tired_run", 0)),
    ("idle_left -> clumsy_stand_takeoff", ("idle_left", 0), ("clumsy_stand_takeoff", 0)),
    ("clumsy_stand_land end -> idle_left", ("clumsy_stand_land", -1), ("idle_left", 0)),
    ("clumsy_run_land end -> idle_left", ("clumsy_run_land", -1), ("idle_left", 0)),
    ("clumsy_run_land end -> tired_run start", ("clumsy_run_land", -1), ("tired_run", 0)),
    ("clumsy_stand_fall end -> clumsy_stand_land start", ("clumsy_stand_fall", -1), ("clumsy_stand_land", 0)),
    ("clumsy_run_fall end -> clumsy_run_land start", ("clumsy_run_fall", -1), ("clumsy_run_land", 0)),
    ("tired_run -> clumsy_run_takeoff (frame 0)", ("tired_run", 0), ("clumsy_run_takeoff", 0)),
    ("climb end -> idle_left", ("climb", -1), ("idle_left", 0)),
    ("clumsy_stand_fall end -> climb start", ("clumsy_stand_fall", -1), ("climb", 0)),
    ("clumsy_stand_apex -> climb start", ("clumsy_stand_apex", -1), ("climb", 0)),
]
for label, a, b in pairs:
    try:
        report(label, a, b)
    except Exception as error:  # a clip that is not there
        print("%-46s (%s)" % (label, error))
