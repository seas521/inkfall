#!/usr/bin/env python3
"""Cuts the two Seedance clips of the tired, clumsy boy into game clips.

    /tmp/imgenv/bin/python scripts/tools/build_tired_clips.py TIRED_RUN_VIDEO CLUMSY_JUMP_VIDEO

TIRED_RUN_VIDEO  (Seedance 7549): stands, lurches into a run, runs, staggers to a stop, pants bent over.
CLUMSY_JUMP_VIDEO (Seedance 7490): a standing jump and a running jump, low and heavy.

Everything is native facing left, 384 px canvas, root (192, 348), scale 0.528, root-x 456.8, ground 759 (the same as every
other clip of the hooded boy). Source frame numbers are 0-based, like the extractor's.

Playing rules the clips are cut for (the feel of the controls comes first, the animation follows the player):
- the run is a slow, heavy one: one loop (two steps, 74 frames = 1.23 s, about the speed it was recorded at) plays at 1.0x at
  HOOD_RUN_SPEED (171 px/s, a little faster than its own feet, so they slide a little); every frame lasts a whole number
  of refreshes;
- the start is the run's own first steps (it ends on the frame the loop begins with), so it hands over without a jump;
- the stop and the start can be cut short at any frame by the player: phase tables say which frame of the other clip
  to continue from (entry_from_run, exit_to_run);
- the jumps are physics-driven like level 1's: takeoff / rise / apex / fall / land are picked by the vertical speed,
  airborne frames are dropped onto the ground line (the physics moves him).
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
OUT = PROJECT / "assets/art/prototypes/hood_clips"
EXTRACT = PROJECT / "scripts/tools/seedance_frames.py"
RIFE = PROJECT / "scripts/tools/rife_upsample.py"
GROUND_ROW = 347

# name, video (a: tired run, b: clumsy jump), first, last, loop, boomerang, pin airborne frames, retime to N frames (0: x2.5), fps afterwards
CLIPS = [
    ("tired_start", "a", 26, 50, False, False, False, 63, 60.0),  # the same frames-per-source-frame as the run (2.64): the same cadence from the first step
    ("tired_run", "a", 51, 78, True, False, False, 74, 60.0),
    ("tired_stop", "a", 88, 106, False, False, False, 36, 60.0),
    ("tired_idle", "a", 108, 120, True, True, False, 0, 60.0),
    # tired_rise (Seedance 1205) is made by build_rise_clip.py: it also morphs into the idle picture
    # the jumps (clumsy_*) are made by build_jump_clips.py from Seedance 8241 / 7407 (first and last frame = the idle / the run)
]


def extract(video, name, first, last, loop, boomerang, pin, root_x=456.8):
    command = [sys.executable, str(EXTRACT), video, "--name", name, "--out", str(OUT), "--start", str(first), "--end", str(last),
               "--scale", "0.528", "--root-x", str(root_x), "--ground-y", "759", "--key", "green", "--canvas", "384"]
    if loop:
        command.append("--loop")
    if boomerang:
        command.append("--boomerang")
    subprocess.run(command, check=True, capture_output=True)
    folder = OUT / name
    count = 0
    for path in sorted(folder.glob("frame_*.png")):
        count += 1
        if not pin:
            continue
        array = np.array(Image.open(path).convert("RGBA"))
        rows = np.where(array[..., 3] > 128)[0]
        shift = GROUND_ROW - int(rows.max())
        if shift > 6:  # airborne: drop it onto the ground line
            moved = np.zeros_like(array)
            moved[shift:] = array[: array.shape[0] - shift]
            Image.fromarray(moved, "RGBA").save(path)
    manifest_path = folder / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["fps"] = 24.0
    manifest["loop"] = loop
    manifest["pinned_to_ground"] = pin
    manifest_path.write_text(json.dumps(manifest, indent=2))
    return count


def silhouette(folder, index):
    alpha = np.array(Image.open(folder / ("frame_%03d.png" % index)).convert("RGBA"))[..., 3] > 128
    return alpha


def distance(a, b):
    return int((a ^ b).sum())


def phase_tables():
    run = OUT / "tired_run"
    stop = OUT / "tired_stop"
    run_manifest = json.loads((run / "manifest.json").read_text())
    stop_manifest = json.loads((stop / "manifest.json").read_text())
    run_count, stop_count = int(run_manifest["frames"]), int(stop_manifest["frames"])
    runs = [silhouette(run, i) for i in range(run_count)]
    stops = [silhouette(stop, i) for i in range(stop_count)]
    # from the run into the stop: for every run frame, the first frames of the stop that look most like it
    entry = []
    for i in range(run_count):
        scores = [distance(runs[i], stops[j]) for j in range(0, min(10, stop_count))]
        entry.append(int(np.argmin(scores)))
    # from the stop back into the run (the player pressed a key half way through the stagger)
    exit_index = []
    for j in range(stop_count):
        scores = [distance(stops[j], runs[i]) for i in range(run_count)]
        exit_index.append(int(np.argmin(scores)))
    stop_manifest["entry_from_run"] = entry
    stop_manifest["exit_to_run"] = exit_index
    (stop / "manifest.json").write_text(json.dumps(stop_manifest, indent=2))
    print("phase tables: entry_from_run", entry[:8], "...  exit_to_run", exit_index[:8], "...")


def main():
    videos = {"a": sys.argv[1], "b": sys.argv[2], "f": sys.argv[4] if len(sys.argv) > 4 else "/tmp/dv/f.mp4"}
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else None  # re-make just these clips
    for name, video, first, last, loop, boomerang, pin, retime, fps_after in CLIPS:
        if only is not None and name not in only:
            continue
        count = extract(videos[video], name, first, last, loop, boomerang, pin)
        command = [sys.executable, str(RIFE), name, "--redo"]
        if retime:
            command += ["--frames", str(retime)]
        result = subprocess.run(command, capture_output=True, text=True)
        print(result.stdout.strip() or result.stderr.strip()[-400:])
        manifest_path = OUT / name / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["fps"] = fps_after
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print("%-22s %2d source frames -> %3d frames @ %g fps" % (name, count, int(manifest["frames"]), fps_after))
    phase_tables()


if __name__ == "__main__":
    main()
