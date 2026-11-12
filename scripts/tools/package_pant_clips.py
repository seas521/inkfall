#!/usr/bin/env python3
"""Adds the bent-over panting clips (tired_stop, tired_idle) to the packaged hooded boy without repackaging everything.

    /tmp/imgenv/bin/python scripts/tools/package_pant_clips.py

package_hood_actor.py wipes and rewrites the whole actor folder (and with it every .import file); this does the same
cropping for just these two clips, into their own group `tired`, and patches hood_actor_manifest.gd in place (CLIPS, GROUPS).
The group is loaded on request (hood_river_actor.gd: load_group("tired")). The clips are made by build_tired_clips.py; they
come from the same video as tired_run, so the panting stands exactly where the run left off.

Safe to run again: the group folder is rebuilt and the manifest entries are replaced.
"""
import json
import re
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
SRC = PROJECT / "assets/art/prototypes/hood_clips"
DST = PROJECT / "assets/art/actors/hood_boy"
MANIFEST = PROJECT / "scripts/actors/hood_actor_manifest.gd"
GROUP = "tired"
NAMES = ["tired_stop", "tired_idle"]
PAD = 5
DROP = ("name", "preview", "note", "source_fps", "scale", "source_root", "source_frames", "pinned_to_ground", "mode", "upsampled",
        "entry_from_run", "exit_to_run")  # (the phase tables are for the old run; nothing uses them here)


def main():
    out_group = DST / GROUP
    if out_group.exists():
        shutil.rmtree(out_group)
    entries = {}
    for name in NAMES:
        manifest = json.loads((SRC / name / "manifest.json").read_text())
        count = int(manifest["frames"])
        out = out_group / name
        out.mkdir(parents=True)
        rects = []
        for i in range(count):
            image = Image.open(SRC / name / ("frame_%03d.png" % i)).convert("RGBA")
            alpha = np.array(image)[..., 3]
            ys, xs = np.where(alpha > 0)
            if len(xs) == 0:
                box = (0, 0, 1, 1)
            else:
                box = (max(0, int(xs.min()) - PAD), max(0, int(ys.min()) - PAD), min(image.width, int(xs.max()) + PAD + 1), min(image.height, int(ys.max()) + PAD + 1))
            image.crop(box).save(out / ("f_%03d.png" % i))
            rects.append([box[0], box[1], box[2] - box[0], box[3] - box[1]])
        entry = {k: v for k, v in manifest.items() if k not in DROP}
        entry["group"] = GROUP
        entry["rects"] = rects
        entries[name] = entry
    text = MANIFEST.read_text()
    clips = json.loads(re.search(r"^const CLIPS := (\{.*\})$", text, re.M).group(1))
    groups = json.loads(re.search(r"^const GROUPS := (\{.*\})$", text, re.M).group(1))
    clips.update(entries)
    groups[GROUP] = NAMES
    text = re.sub(r"^const CLIPS := .*$", lambda m: "const CLIPS := " + json.dumps(clips, separators=(",", ":")), text, flags=re.M)
    text = re.sub(r"^const GROUPS := .*$", lambda m: "const GROUPS := " + json.dumps(groups), text, flags=re.M)
    MANIFEST.write_text(text)
    print("packaged", {n: entries[n]["frames"] for n in NAMES})


if __name__ == "__main__":
    main()
