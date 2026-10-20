#!/usr/bin/env python3
"""Cuts the run-to-stand video (Seedance 4459: first frame = the run, last frame = the idle) into the `run_stop` clip.

    /tmp/imgenv/bin/python scripts/tools/build_stop_clip.py STOP_VIDEO

Source frames 42-72: the stride shortens, the body straightens out of the lean and settles into the standing pose (the distance to
the idle picture goes 11761 px -> 409 px). The video's own run (0-41) is not used: the game's body stops at once, so a clip that
starts with running strides would be running on the spot. Frame 36 of the video is exactly the run's first frame; from there
the run-up is not needed. The last frame is replaced by the idle picture itself after a short morph (RIFE) so the idle takes over
without any change on the screen.

Tables in the manifest: `entry_from_run` (a tired_run frame -> the first stop frame to play: the one of the first ENTRY_FRAMES that
looks most like it) and `exit_to_run` (a stop frame -> the tired_run frame to continue from if he sets off again half way).
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
import rife_upsample as ru  # noqa: E402
import tempfile  # noqa: E402

OUT = btc.OUT
FIRST, LAST, FRAMES = 42, 72, 44
MORPH_FRAMES = 5
ENTRY_FRAMES = 12


def alpha(path):
    return np.array(Image.open(path).convert("RGBA"))[..., 3] > 128


def main():
    video = sys.argv[1]
    shutil.rmtree(btc.PROJECT / "artifacts/hood-frames/24fps/run_stop", ignore_errors=True)
    btc.extract(video, "run_stop", FIRST, LAST, False, False, False)
    result = subprocess.run([sys.executable, str(btc.RIFE), "run_stop", "--frames", str(FRAMES)], capture_output=True, text=True)
    print(result.stdout.strip() or result.stderr.strip()[-300:])
    folder = OUT / "run_stop"
    manifest = json.loads((folder / "manifest.json").read_text())
    count = int(manifest["frames"])
    last = np.array(Image.open(folder / ("frame_%03d.png" % (count - 1))).convert("RGBA"))
    idle_manifest = json.loads((OUT / "idle_left/manifest.json").read_text())
    idle_src = np.array(Image.open(OUT / "idle_left/frame_000.png").convert("RGBA"))
    dx, dy = int(manifest["root"][0] - idle_manifest["root"][0]), int(manifest["root"][1] - idle_manifest["root"][1])
    idle = np.zeros_like(last)
    idle[dy:dy + 256, dx:dx + 256] = idle_src
    pair = [last, idle]
    sil = [(255 - f[..., 3]).astype(np.uint8) for f in pair]
    eyes = [(255 - (np.clip(ru.eye_mask(f), 0, 1) * 255).astype(np.uint8)) for f in pair]
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        rife_dir = Path("/tmp/rife/rife-ncnn-vulkan-20221029-macos")
        sil_out = ru.run_rife(rife_dir, sil, MORPH_FRAMES + 1, work, "sil")
        eye_out = ru.run_rife(rife_dir, eyes, MORPH_FRAMES + 1, work, "eye")
    morph = [ru.compose(sil_out[i], eye_out[i]) for i in range(1, MORPH_FRAMES + 1)]
    morph[-1] = idle
    for number, frame in enumerate(morph):
        Image.fromarray(frame, "RGBA").save(folder / ("frame_%03d.png" % (count + number)))
    total = count + MORPH_FRAMES
    manifest["frames"] = total
    manifest["fps"] = 60.0
    manifest["loop"] = False
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2))
    # tables
    run = [alpha(OUT / "tired_run" / ("frame_%03d.png" % i)) for i in range(74)]
    stop = [alpha(folder / ("frame_%03d.png" % i)) for i in range(total)]
    entry = [int(np.argmin([int((run[i] ^ stop[j]).sum()) for j in range(min(ENTRY_FRAMES, total))])) for i in range(len(run))]
    exit_index = [int(np.argmin([int((stop[j] ^ r).sum()) for r in run])) for j in range(total)]
    manifest["entry_from_run"] = entry
    manifest["exit_to_run"] = exit_index
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print("run_stop: %d frames (%d + %d morph into idle_left); entry_from_run %s... exit_to_run %s" % (total, count, MORPH_FRAMES, entry[:10], exit_index[::6]))


if __name__ == "__main__":
    main()
