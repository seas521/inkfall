#!/usr/bin/env python3
"""Tables for the climb clip: where in its lead-in (the reach, `lead_frames` long) to start from the air pose he is in.

    /tmp/imgenv/bin/python scripts/tools/build_climb_tables.py

The jump clips (standing and running; rise, apex, fall) and the climb come from different videos, so when he takes hold of a ledge
the picture used to cut from the air pose to the first frame of the reach. For every frame of every air clip this finds the frame of
the lead-in that looks most like it (silhouettes laid on top of each other by their centres, fewest differing pixels), so the climb
carries on from there: `from_air[clip][frame] = lead frame`. `lead_feet[frame]` is where his feet are in each lead frame (canvas px
from the clip's root, the ledge corner), for the placement.
"""
import glob
import json
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets/art/prototypes/hood_clips"
AIR = [("clumsy_%s_%s" % (s, p)) for s in ("stand", "run") for p in ("rise", "apex", "fall")]


def mask(path):
    return np.array(Image.open(path).convert("RGBA"))[..., 3] > 128


def centred(m):
    ys, xs = np.where(m)
    out = np.zeros((700, 700), bool)
    out[np.clip(np.round(ys - ys.mean()).astype(int) + 350, 0, 699), np.clip(np.round(xs - xs.mean()).astype(int) + 350, 0, 699)] = True
    return out


def main():
    manifest = json.loads((OUT / "climb/manifest.json").read_text())
    lead = int(manifest["lead_frames"])
    root = manifest["root"]
    lead_masks = [mask(OUT / "climb" / ("frame_%03d.png" % i)) for i in range(lead + 1)]
    lead_c = [centred(m) for m in lead_masks]
    feet = []
    for m in lead_masks:
        ys, xs = np.where(m)
        bottom = int(ys.max())
        feet.append([float(xs[ys >= bottom - 4].mean()) - float(root[0]), float(bottom + 1) - float(root[1])])
    table = {}
    for clip in AIR:
        count = len(glob.glob(str(OUT / clip / "frame_*.png")))
        entry = []
        for i in range(count):
            c = centred(mask(OUT / clip / ("frame_%03d.png" % i)))
            entry.append(int(np.argmin([int((c ^ l).sum()) for l in lead_c])))
        table[clip] = entry
    manifest["lead_feet"] = feet
    manifest["from_air"] = table
    (OUT / "climb/manifest.json").write_text(json.dumps(manifest, indent=2))
    for clip, entry in table.items():
        print("%-20s -> lead frames %s" % (clip, entry))


if __name__ == "__main__":
    main()
