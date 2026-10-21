#!/usr/bin/env python3
"""Cuts the two jump videos (first AND last frame given, so both start and end on the anchor poses) into the clumsy_* clips.

    /tmp/imgenv/bin/python scripts/tools/build_jump_clips.py STAND_JUMP_VIDEO RUN_JUMP_VIDEO

STAND_JUMP_VIDEO (Seedance 8241): idle -> crouch -> low jump -> heavy landing -> back to the idle picture (last frame = idle_left).
RUN_JUMP_VIDEO   (Seedance 3158, the upright jog; the earlier 7407 was the hunched one): jog -> low jump -> heavy landing -> back to the jog.

Rules: the videos have near-duplicate frames (every pose of the run jump is held on 1-2 frames in places), so duplicates are dropped
before RIFE makes the 60 fps in-betweens (interpolating between doubles shows as stutter). The airborne clips (rise / apex / fall) are
dropped onto the ground line: the physics moves the body. Clip lengths follow the physics (rise 0.24 s, apex 0.12 s, fall 0.2 s).
The takeoff is the crouch played fast (0.125 s: the jump itself is instant); the landing runs to the end of the video's recovery, whose
last frame is the idle. Also written: for the run jump, `entry_from_run` (a tired_run frame -> the takeoff frame that looks most like
it) on the takeoff, and `exit_to_run` (a landing frame -> the tired_run frame to continue from) on the landing.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import build_tired_clips as btc  # noqa: E402

OUT = btc.OUT
# the jog in the run-jump video sits about 6 canvas px (11.6 source px) off the jog of the run video: its root is shifted so that
# both runs are on the same spot (compared by the centroid of the silhouettes)
GATHER_START = 3
ROOT_X = {"s": 456.8, "r": 456.8 - 11.6}
# name, video (s: stand jump, r: run jump), first, last (source frames, 0-based), pin to ground, frames after RIFE, fps
CLIPS = [
    ("clumsy_stand_takeoff", "s", 12, 29, False, 8, 64.0),
    ("clumsy_stand_rise", "s", 30, 37, True, 14, 60.0),
    ("clumsy_stand_apex", "s", 38, 41, True, 7, 60.0),
    ("clumsy_stand_fall", "s", 42, 45, True, 10, 60.0),
    ("clumsy_stand_land", "s", 46, 84, False, 40, 60.0),
    # the running jump (Seedance 3158: the new upright jog): no crouch in this one, the push-off is the last strides
    ("clumsy_run_takeoff", "r", 31, 38, False, 8, 64.0),
    ("clumsy_run_rise", "r", 39, 47, True, 14, 60.0),
    ("clumsy_run_apex", "r", 48, 50, True, 7, 60.0),
    ("clumsy_run_fall", "r", 51, 58, True, 12, 60.0),
    ("clumsy_run_land", "r", 59, 72, False, 27, 60.0),
]


def alpha(path):
    return np.array(Image.open(path).convert("RGBA"))[..., 3] > 128


def dedupe(name):
    folder = OUT / name
    kept = []
    for path in sorted(folder.glob("frame_*.png")):
        mask = alpha(path)
        if kept and int((mask ^ kept[-1][1]).sum()) < 100:
            path.unlink()
            continue
        kept.append((path, mask))
    for number, (path, _m) in enumerate(kept):
        path.rename(folder / ("tmp_%03d.png" % number))
    for number in range(len(kept)):
        (folder / ("tmp_%03d.png" % number)).rename(folder / ("frame_%03d.png" % number))
    manifest = json.loads((folder / "manifest.json").read_text())
    before = int(manifest["frames"])
    manifest["frames"] = len(kept)
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2))
    return before, len(kept)


def main():
    videos = {"s": sys.argv[1], "r": sys.argv[2]}
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else None
    for name, video, first, last, pin, frames, fps in CLIPS:
        if only is not None and name not in only:
            continue
        shutil.rmtree(btc.PROJECT / "artifacts/hood-frames/24fps" / name, ignore_errors=True)
        btc.extract(videos[video], name, first, last, False, False, pin, ROOT_X[video])
        before, after = dedupe(name)
        result = subprocess.run([sys.executable, str(btc.RIFE), name, "--frames", str(frames)], capture_output=True, text=True)
        print(result.stdout.strip() or result.stderr.strip()[-300:])
        path = OUT / name / "manifest.json"
        manifest = json.loads(path.read_text())
        manifest["fps"] = fps
        manifest["loop"] = False
        path.write_text(json.dumps(manifest, indent=2))
        print("%-22s source %d-%d: %d frames, %d distinct -> %d frames @ %g fps" % (name, first, last, before, after, int(manifest["frames"]), fps))
    run_tables()


def masks(name):
    count = len(list((OUT / name).glob("frame_*.png")))
    return [alpha(OUT / name / ("frame_%03d.png" % i)) for i in range(count)]


def run_tables():
    run = masks("tired_run")
    takeoff_path = OUT / "clumsy_run_takeoff" / "manifest.json"
    land_path = OUT / "clumsy_run_land" / "manifest.json"
    takeoff, land = masks("clumsy_run_takeoff"), masks("clumsy_run_land")
    # only the first GATHER_START frames are candidates: the jump gathers (the video's sink before the push-off), and a late match would
    # skip the gather and show only the push-off
    entry = [int(np.argmin([int((run[i] ^ t).sum()) for t in takeoff[:GATHER_START]])) for i in range(len(run))]
    exit_index = [int(np.argmin([int((l ^ r).sum()) for r in run])) for l in land]
    manifest = json.loads(takeoff_path.read_text())
    manifest["entry_from_run"] = entry
    takeoff_path.write_text(json.dumps(manifest, indent=2))
    manifest = json.loads(land_path.read_text())
    manifest["exit_to_run"] = exit_index
    land_path.write_text(json.dumps(manifest, indent=2))
    print("entry_from_run", entry[:10], "... exit_to_run", exit_index[::4])


if __name__ == "__main__":
    main()
