#!/usr/bin/env python3
"""Cuts the new run video (Seedance 1427: stand -> a weak, upright jog -> stand; first and last frame = the idle) into the start,
the run loop and the stop.

    /tmp/imgenv/bin/python scripts/tools/build_run_set.py RUN_VIDEO

The boy runs upright with his head up (not hunched): short, low steps, arms hanging loose. The video's own cadence is 2.7 steps/s
with a ground speed of about 78 px/s in the game's units (measured from the planted foot: 16.3 source px per frame x 24 fps x
0.1996 game px per source px). The game's run speed is HOOD_RUN_SPEED (78 px/s): the clips are played at the recorded speed (45 frames for the 18 frame loop, the same
ratio for the start and the stop) and the feet do not slide.

  tired_start  source 12-35  idle -> leans into it -> the loop's first frame (ends ON the loop's first frame)
  tired_run    source 35-52  the loop (two steps)
  run_stop     source 92-106 (see build_stop_clip.py) the stride shortens, he straightens and ends on the idle picture
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import build_tired_clips as btc  # noqa: E402

SPEED_UP = 2.5  # output frames per source frame: 60 fps / 24 fps = the recorded speed (the loop is 45 frames: two steps, 2.7 steps/s)
CLIPS = [
    # name, first, last, loop, frames
    ("tired_start", 12, 35, False, int(round(23 * SPEED_UP))),
    ("tired_run", 35, 52, True, 45),
]


def main():
    video = sys.argv[1]
    for name, first, last, loop, frames in CLIPS:
        # rife_upsample --redo starts again from the saved 24 fps frames of the same name: the OLD clip's frames would replace the
        # ones just cut (this is what made the first "new" run look like the old one), so the saved copy goes first
        shutil.rmtree(btc.PROJECT / "artifacts/hood-frames/24fps" / name, ignore_errors=True)
        btc.extract(video, name, first, last, loop, False, False)
        result = subprocess.run([sys.executable, str(btc.RIFE), name, "--redo", "--frames", str(frames)], capture_output=True, text=True)
        print(result.stdout.strip() or result.stderr.strip()[-300:])
        path = btc.OUT / name / "manifest.json"
        manifest = json.loads(path.read_text())
        manifest["fps"] = 60.0
        manifest["loop"] = loop
        path.write_text(json.dumps(manifest, indent=2))
        print("%-12s source %d-%d -> %d frames" % (name, first, last, int(manifest["frames"])))
    subprocess.run([sys.executable, str(TOOLS / "build_stop_clip.py"), video, "92", "106", str(int(round(15 * SPEED_UP)))], check=True)


if __name__ == "__main__":
    main()
