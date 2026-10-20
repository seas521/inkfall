#!/usr/bin/env python3
"""Makes `tired_rise` (Seedance 1205): bent over, panting -> straightens up -> ends ON the idle picture.

    /tmp/imgenv/bin/python scripts/tools/build_rise_clip.py [VIDEO]      (default /tmp/dv/f.mp4)

Part A is the video itself from the moment he starts to lift (source frame 44) to 68, where he is back to his full height but
still bowed; retimed to RISE_FRAMES. The rest of the video (a stretch taller than he stands, then settling) read as the body
stretching and shrinking, so it is not used. He also ends the video standing straighter than the game's idle picture (idle_left):
hood and head are bigger and held higher, the cloak is the same. Cutting from one to the other showed as a jump. So part B is a morph made with
RIFE between the last frame of part A and the idle picture itself (both feet-aligned), MORPH_FRAMES long: the last frame of the
clip IS idle_left's frame, and the game can switch to the idle without any change on the screen.
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import build_tired_clips as btc  # noqa: E402
import rife_upsample as ru  # noqa: E402

OUT = btc.OUT
PROJECT = btc.PROJECT
VIDEO = sys.argv[1] if len(sys.argv) > 1 else "/tmp/dv/f.mp4"
FIRST, LAST = 44, 68
RISE_FRAMES = 36
MORPH_FRAMES = 20

shutil.rmtree(btc.PROJECT / "artifacts/hood-frames/24fps/tired_rise_a", ignore_errors=True)
count = btc.extract(VIDEO, "tired_rise_a", FIRST, LAST, False, False, False)
# Seedance 1205 was generated at 12 poses per second: every pose is on two frames of the 24 fps video. Interpolating between
# the doubles holds the motion every other step and shows as stutter, so only the first of each pair is kept and RIFE
# makes the in-between frames from the distinct poses.
folder_a = OUT / "tired_rise_a"
kept = []
for path in sorted(folder_a.glob("frame_*.png")):
    mask_now = np.array(Image.open(path).convert("RGBA"))[..., 3] > 128
    if kept and int((mask_now ^ kept[-1][1]).sum()) < 120:
        path.unlink()
        continue
    kept.append((path, mask_now))
for number, (path, _mask) in enumerate(kept):
    path.rename(folder_a / ("tmp_%03d.png" % number))
for number in range(len(kept)):
    (folder_a / ("tmp_%03d.png" % number)).rename(folder_a / ("frame_%03d.png" % number))
manifest_a = json.loads((folder_a / "manifest.json").read_text())
manifest_a["frames"] = len(kept)
manifest_a["fps"] = 12.0
(folder_a / "manifest.json").write_text(json.dumps(manifest_a, indent=2))
print("distinct poses: %d of %d source frames" % (len(kept), count))
result = subprocess.run([sys.executable, str(btc.RIFE), "tired_rise_a", "--frames", str(RISE_FRAMES)], capture_output=True, text=True)
print(result.stdout.strip() or result.stderr.strip()[-400:])
manifest = json.loads((folder_a / "manifest.json").read_text())
frames_a = int(manifest["frames"])
last_a = np.array(Image.open(folder_a / ("frame_%03d.png" % (frames_a - 1))).convert("RGBA"))

# the idle picture on the same canvas: idle_left is 256 px with its root at (128, 232); the rise is 384 px with the root at (192, 348)
idle_manifest = json.loads((OUT / "idle_left/manifest.json").read_text())
idle_src = Image.open(OUT / "idle_left/frame_000.png").convert("RGBA")
dx, dy = int(manifest["root"][0] - idle_manifest["root"][0]), int(manifest["root"][1] - idle_manifest["root"][1])
idle = Image.new("RGBA", (384, 384), (0, 0, 0, 0))
idle.paste(idle_src, (dx, dy))
idle_a = np.array(idle)


def feet_x(rgba):
    ys, xs = np.where(rgba[..., 3] > 128)
    bottom = int(ys.max())
    return float(xs[ys >= bottom - 4].mean()), bottom


print("feet of the last rise frame %s, of the idle %s" % (feet_x(last_a), feet_x(idle_a)))

pair = [last_a, idle_a]
sil = [(255 - f[..., 3]).astype(np.uint8) for f in pair]
eyes = [(255 - (np.clip(ru.eye_mask(f), 0, 1) * 255).astype(np.uint8)) for f in pair]
with tempfile.TemporaryDirectory() as tmp:
    work = Path(tmp)
    rife_dir = Path("/tmp/rife/rife-ncnn-vulkan-20221029-macos")
    sil_out = ru.run_rife(rife_dir, sil, MORPH_FRAMES + 1, work, "sil")
    eye_out = ru.run_rife(rife_dir, eyes, MORPH_FRAMES + 1, work, "eye")
morph = [ru.compose(sil_out[i], eye_out[i]) for i in range(1, MORPH_FRAMES + 1)]
morph[-1] = idle_a  # exactly the idle picture

folder = OUT / "tired_rise"
if folder.exists():
    shutil.rmtree(folder)
folder.mkdir(parents=True)
index = 0
for i in range(frames_a):
    shutil.copy(folder_a / ("frame_%03d.png" % i), folder / ("frame_%03d.png" % index))
    index += 1
for frame in morph:
    Image.fromarray(frame, "RGBA").save(folder / ("frame_%03d.png" % index))
    index += 1
shutil.rmtree(folder_a)
manifest["name"] = "tired_rise"
manifest["frames"] = index
manifest["fps"] = 60.0
manifest["loop"] = False
manifest["rise_frames"] = frames_a
(folder / "manifest.json").write_text(json.dumps(manifest, indent=2))
print("tired_rise: %d frames (%d rise + %d morph into idle_left)" % (index, frames_a, MORPH_FRAMES))
