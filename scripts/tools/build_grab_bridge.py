#!/usr/bin/env python3
"""Builds the `grab_bridge` clip: the frames between the air pose he is in and the reach of the climb.

    /tmp/imgenv/bin/python scripts/tools/build_grab_bridge.py

The jump clips and the climb come from different videos, so when he takes hold of a ledge the picture used to cut from the air pose
(arms out) to a pose of the reach (hands up): a hard cut. For every second frame of every air clip (standing and running; rise, apex,
fall) this makes BRIDGE_FRAMES in-between frames with RIFE: from the air frame to the lead-in frame of the climb that looks most like it
(`from_air` in the climb manifest, see build_climb_tables.py); the last bridge frame IS that lead-in frame. All frames are rooted at the
FEET (root (192, 348) like every other clip): the lead-in frame is laid so that its feet are on the root; the game draws the bridge at
his feet while the feet path takes him to the hanging place, and then carries on with the climb clip from that frame.

Manifest: `bridge_start[air clip][frame]` = the first bridge frame to play, `bridge_lead[air clip][frame]` = the climb frame it ends on,
`bridge_frames` = frames per bridge.
"""
import glob
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import rife_upsample as ru  # noqa: E402

OUT = TOOLS.parents[1] / "assets/art/prototypes/hood_clips"
AIR = [("clumsy_%s_%s" % (s, p)) for s in ("stand", "run") for p in ("rise", "apex", "fall")]
BRIDGE_FRAMES = 6
STEP = 2
RIFE_DIR = Path(os.path.expanduser("~/tools/rife-ncnn-vulkan-20221029-macos"))


def feet_of(rgba):
    ys, xs = np.where(rgba[..., 3] > 128)
    bottom = int(ys.max())
    return float(xs[ys >= bottom - 4].mean()), bottom


def interpolate(a, b, count):
    sil = [(255 - f[..., 3]).astype(np.uint8) for f in (a, b)]
    eyes = [(255 - (np.clip(ru.eye_mask(f), 0, 1) * 255).astype(np.uint8)) for f in (a, b)]
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        sil_out = ru.run_rife(RIFE_DIR, sil, count + 1, work, "sil")
        eye_out = ru.run_rife(RIFE_DIR, eyes, count + 1, work, "eye")
    return [ru.compose(sil_out[i], eye_out[i]) for i in range(1, count + 1)]


def lead_on_feet(k):
    """The climb's lead-in frame k on a 384 px canvas with its feet on the root (192, 348)."""
    src = np.array(Image.open(OUT / "climb" / ("frame_%03d.png" % k)).convert("RGBA"))
    fx, fb = feet_of(src)
    dx, dy = int(round(192 - fx)), int(347 - fb)
    out = np.zeros((384, 384, 4), np.uint8)
    ys, xs = np.where(src[..., 3] > 0)
    ny, nx = ys + dy, xs + dx
    ok = (ny >= 0) & (ny < 384) & (nx >= 0) & (nx < 384)
    out[ny[ok], nx[ok]] = src[ys[ok], xs[ok]]
    return out


def main():
    climb = json.loads((OUT / "climb/manifest.json").read_text())
    from_air = climb["from_air"]
    folder = OUT / "grab_bridge"
    shutil.rmtree(folder, ignore_errors=True)
    folder.mkdir(parents=True)
    index = 0
    start_of = {}
    lead_of = {}
    cache = {}
    for clip in AIR:
        count = len(glob.glob(str(OUT / clip / "frame_*.png")))
        sources = list(range(0, count, STEP))
        if (count - 1) not in sources:
            sources.append(count - 1)
        for frame in sources:
            k = int(from_air[clip][frame])
            air = np.array(Image.open(OUT / clip / ("frame_%03d.png" % frame)).convert("RGBA"))
            if k not in cache:
                cache[k] = lead_on_feet(k)
            frames = interpolate(air, cache[k], BRIDGE_FRAMES)
            frames[-1] = cache[k]
            for image in frames:
                Image.fromarray(image, "RGBA").save(folder / ("frame_%03d.png" % index))
                index += 1
            start_of[(clip, frame)] = index - BRIDGE_FRAMES
            lead_of[(clip, frame)] = k
        print("%-18s %d sources" % (clip, len(sources)))
    bridge_start = {}
    bridge_lead = {}
    for clip in AIR:
        count = len(glob.glob(str(OUT / clip / "frame_*.png")))
        keys = sorted(f for (c, f) in start_of if c == clip)
        bridge_start[clip] = []
        bridge_lead[clip] = []
        for frame in range(count):
            nearest = min(keys, key=lambda s: abs(s - frame))
            bridge_start[clip].append(start_of[(clip, nearest)])
            bridge_lead[clip].append(lead_of[(clip, nearest)])
    manifest = {"name": "grab_bridge", "frames": index, "fps": 60.0, "loop": False, "scale": 0.528, "root": [192.0, 348.0], "canvas": 384,
                "bridge_frames": BRIDGE_FRAMES, "bridge_start": bridge_start, "bridge_lead": bridge_lead}
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print("grab_bridge: %d frames (%d bridges of %d)" % (index, index // BRIDGE_FRAMES, BRIDGE_FRAMES))


if __name__ == "__main__":
    main()
