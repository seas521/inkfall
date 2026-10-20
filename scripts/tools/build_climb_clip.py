#!/usr/bin/env python3
"""Cuts the climb (Seedance 566494…raw: the boy and a flat blue block) into the `climb` clip.

    /tmp/imgenv/bin/python scripts/tools/build_climb_clip.py CLIMB_VIDEO

The video: the boy stands in front of a blue block, jumps, hooks his hands over the top corner, hangs kicking, pulls himself up,
crawls on top, kneels, stands hunched. The block is keyed out. Unlike every other clip the clip's root is the CORNER he climbs
over (source (497, 446), canvas (192, 192)), not his feet: the whole movement is in the frames, so the game only puts the corner of
the clip on the corner of the real ledge.

Kept lean: the video's crawl on all fours, its hunched kneel and its tired, slowly straightening stand (back humped, body
stretched and shrunk again) all read as extra beats, so they are not used. The reach (22-34) is kept, the hang skipped through
(34 -> 41 -> 47), the pull-up kept whole (50-78); from there only two poses are used (90: over the edge, on his knees; 104:
rising) and RIFE makes quick in-betweens, then a morph from the 104 pose into the idle picture itself, feet on the same spot: the
last frame IS idle_left's frame, and the game switches to the idle without any change on the screen. The clip is on a taller
canvas (384 x 480, root (192, 288)) because the standing idle is taller than the space above the corner in the video's canvas.

`lead_frames` (the reach, until the hands are on the corner), `start_feet`, `end_feet` (the idle's root, canvas px from the corner,
facing left; the game mirrors them) are in the manifest.
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import rife_upsample as ru  # noqa: E402

PROJECT = TOOLS.parents[1]
OUT = PROJECT / "assets/art/prototypes/hood_clips"
video = sys.argv[1]
video = sys.argv[1]
FIRST, LAST = 22, 104
PULL_KEYS = list(range(22, 35)) + [41, 47] + list(range(50, 79))
PULL_SPEED = 1.5  # output frames per source frame in the pull-up (1.6x the recorded speed)
STAND_FRAMES = 13  # 78 -> 90 -> 104
MORPH_FRAMES = 15
SHIFT = 96  # px of canvas added above
GAP = 24  # canvas px (about 9 game px): the arch under a body lying on the ledge at most this high is closed
MIN_RUN = 2  # columns: a notch narrower than this is a pixel-wide gap in the body, filled as well
RIFE = PROJECT / "scripts/tools/rife_upsample.py"


def pad(rgba):
    out = np.zeros((rgba.shape[0] + SHIFT, rgba.shape[1], 4), np.uint8)
    out[SHIFT:] = rgba
    return out


def interpolate(images, out_count):
    sil = [(255 - f[..., 3]).astype(np.uint8) for f in images]
    eyes = [(255 - (np.clip(ru.eye_mask(f), 0, 1) * 255).astype(np.uint8)) for f in images]
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        rife_dir = Path("/tmp/rife/rife-ncnn-vulkan-20221029-macos")
        sil_out = ru.run_rife(rife_dir, sil, out_count, work, "sil")
        eye_out = ru.run_rife(rife_dir, eyes, out_count, work, "eye")
    return [ru.compose(sil_out[i], eye_out[i]) for i in range(out_count)]


def feet_of(rgba):
    ys, xs = np.where(rgba[..., 3] > 128)
    bottom = int(ys.max())
    return float(xs[ys >= bottom - 4].mean()), bottom


shutil.rmtree(OUT / "climb_src", ignore_errors=True)
subprocess.run([sys.executable, str(TOOLS / "seedance_frames.py"), video, "--name", "climb_src", "--out", str(OUT),
                "--start", str(FIRST), "--end", str(LAST), "--scale", "0.528", "--root-x", "497", "--ground-y", "446",
                "--root-pos", "192,192", "--key", "green", "--canvas", "384", "--exclude-blue"], capture_output=True)  # exit 2 only warns about the canvas border
src = OUT / "climb_src"
manifest = json.loads((src / "manifest.json").read_text())


def source(number):
    return pad(np.array(Image.open(src / ("frame_%03d.png" % (number - FIRST))).convert("RGBA")))


pull = interpolate([source(n) for n in PULL_KEYS], int(round((len(PULL_KEYS) - 1) * PULL_SPEED)) + 1)
lead_frames = int(round(PULL_KEYS.index(34) * (len(pull) - 1) / (len(PULL_KEYS) - 1)))
stand = interpolate([source(78), source(90), source(104)], STAND_FRAMES)
last = source(104)
shutil.rmtree(src)

# the idle picture on this canvas, feet on the same spot as the last stand frame
idle_manifest = json.loads((OUT / "idle_left/manifest.json").read_text())
idle_src = np.array(Image.open(OUT / "idle_left/frame_000.png").convert("RGBA"))
feet_cx, feet_bottom = feet_of(last)
idle_cx, idle_bottom = feet_of(idle_src)
ox, oy = int(round(feet_cx - idle_cx)), int(feet_bottom - idle_bottom)
idle = np.zeros((384 + SHIFT, 384, 4), np.uint8)
idle[oy:oy + 256, ox:ox + 256] = idle_src
idle_root = (ox + float(idle_manifest["root"][0]), oy + float(idle_manifest["root"][1]))
morph = interpolate([last, idle], MORPH_FRAMES + 1)[1:]
morph[-1] = idle

frames = pull + stand[1:] + morph


def close_slivers(rgba):
    """Where the body lies on the ledge its underside is a little arched: a sliver of background (a thin light line on the box
    top in the game) stays between the body and the surface. For every run of columns on the ledge side whose lowest pixel is within
    GAP rows of the surface line, with nothing below it, the body is extended down to the line: it lies flat on the ledge."""
    surface = int(192.0 + SHIFT)  # the corner row: the ledge's top surface
    opaque = rgba[..., 3] > 128
    columns = []
    for x in range(0, 192):
        rows = np.where(opaque[: surface + 1, x])[0]
        if len(rows) == 0:
            columns.append(None)
            continue
        lowest = int(rows.max())
        gap = surface + 1 - lowest
        # nothing at or below the line in this column (a hanging leg or a standing foot is not a sliver)
        if 1 <= gap <= GAP and not opaque[lowest + 1: surface + 8, x].any():
            columns.append(lowest)
        else:
            columns.append(None)
    out = rgba.copy()
    # (b) a thin slit between a part of the body above the line and a part at / below it (a knee, a hanging foot): closed too
    lo, hi = surface - 16, surface + 10
    for x in range(0, 192):
        column = opaque[lo:hi, x]
        y = 0
        while y < len(column):
            if column[y]:
                y += 1
                continue
            end = y
            while end < len(column) and not column[end]:
                end += 1
            if y > 0 and end < len(column) and (end - y) <= GAP:
                out[lo + y: lo + end, x] = (0, 0, 0, 255)
            y = end
    x = 0
    while x < len(columns):
        if columns[x] is None:
            x += 1
            continue
        end = x
        while end + 1 < len(columns) and columns[end + 1] is not None:
            end += 1
        if end - x + 1 >= MIN_RUN:
            for column in range(x, end + 1):
                out[columns[column] + 1: surface + 3, column] = (0, 0, 0, 255)
        x = end + 1
    return out


def clean_body(rgba):
    """Closes the thin light slits and pin holes inside the body (the gaps RIFE leaves between an arm and the belly are a pixel or
    two wide: in the game they are bright dashes on the black body) and every hole the body completely encloses."""
    opaque = rgba[..., 3] > 128
    closed = ndimage.binary_closing(opaque, structure=np.ones((3, 3), bool), iterations=2)
    filled = ndimage.binary_fill_holes(closed)
    out = rgba.copy()
    new = filled & ~opaque
    out[new] = (0, 0, 0, 255)
    # the half-transparent specks inside the body (alpha between): solid
    inside = ndimage.binary_erosion(filled, iterations=2) & (out[..., 3] < 255)
    out[inside] = np.where(out[inside][:, 3:4] > 0, out[inside], 0)
    out[inside, 3] = 255
    return out


frames = [close_slivers(clean_body(frame)) for frame in frames]
folder = OUT / "climb"
if folder.exists():
    shutil.rmtree(folder)
folder.mkdir(parents=True)
for index, frame in enumerate(frames):
    Image.fromarray(frame, "RGBA").save(folder / ("frame_%03d.png" % index))
manifest["name"] = "climb"
manifest["frames"] = len(frames)
manifest["fps"] = 60.0
manifest["loop"] = False
manifest["root"] = [192.0, 192.0 + SHIFT]
manifest["lead_frames"] = lead_frames
manifest["climb_frames"] = len(pull) + len(stand) - 1
for key in ("from_climb", "original_frames", "original_fps", "frame_factor", "source_frames"):
    manifest.pop(key, None)
x0, b0 = feet_of(frames[0])
manifest["start_feet"] = [x0 - 192.0, float(b0 + 1) - (192.0 + SHIFT)]
manifest["hang_feet"] = list(manifest["start_feet"])
manifest["end_feet"] = [idle_root[0] - 192.0, idle_root[1] - (192.0 + SHIFT)]
(folder / "manifest.json").write_text(json.dumps(manifest, indent=2))
print("climb: %d frames (%d lead-in, pull %d, stand %d, morph %d), start feet %s, end feet %s" % (len(frames), lead_frames, len(pull), len(stand) - 1, MORPH_FRAMES, manifest["start_feet"], manifest["end_feet"]))
