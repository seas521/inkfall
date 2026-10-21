#!/usr/bin/env python3
"""Raises the frame rate of the hooded boy's clips with RIFE (rife-ncnn-vulkan, runs on the Mac GPU).

    /tmp/imgenv/bin/python scripts/tools/rife_upsample.py run_left start_left ... [--fps 60]

The clips come from a ~24fps video, and a fast limb moves a long way between two frames; on a 120Hz
screen every pose is held for 5 refreshes while the body glides, which reads as stutter. Interpolating
to 60fps (2 refreshes per frame at 120Hz, 1 at 60Hz) fixes that. ffmpeg's `minterpolate` broke the legs
and cross-fades ghost, but RIFE on a flat black-on-white silhouette keeps the limbs whole.

Each clip folder in assets/art/prototypes/hood_clips is replaced in place; the original frames are kept in
artifacts/hood-frames/24fps/<clip>. The manifest gets `frame_factor` (new frames per old frame) and
`upsampled: true`, so running it twice does nothing.

The silhouette and the orange eye are interpolated as two separate masks (RIFE only does RGB), then put
back together as pure black + orange eye on an alpha channel.

RIFE binary: https://github.com/nihui/rife-ncnn-vulkan/releases (default path ~/tools/rife-ncnn-vulkan-20221029-macos).
"""
import argparse
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PROJECT = Path(__file__).resolve().parents[2]
CLIPS = PROJECT / "assets/art/prototypes/hood_clips"
BACKUP = PROJECT / "artifacts/hood-frames/24fps"
EYE = np.array([255.0, 150.0, 40.0])


def eye_mask(rgba):
    r, g, b, a = (rgba[..., i].astype(float) for i in range(4))
    return ((a > 40) & (r > 110) & (r - b > 40) & (g > b * 1.2)).astype(float) * (a / 255.0)


def run_rife(rife_dir, images, out_count, workdir, tag):
    inp = workdir / ("in_" + tag)
    out = workdir / ("out_" + tag)
    inp.mkdir()
    out.mkdir()
    for i, image in enumerate(images):
        Image.fromarray(image, "L").convert("RGB").save(inp / ("%08d.png" % (i + 1)))
    subprocess.run(
        [str(rife_dir / "rife-ncnn-vulkan"), "-i", str(inp), "-o", str(out), "-m", "rife-v4.6", "-n", str(out_count), "-x", "-z"],
        check=True, capture_output=True, cwd=rife_dir,
    )
    return [np.array(Image.open(p).convert("L")) for p in sorted(out.glob("*.png"))]


def compose(sil_gray, eye_gray):
    """Black silhouette + orange eye on an alpha channel, from the two interpolated greyscale masks."""
    sil = np.clip((200.0 - sil_gray.astype(float)) / 140.0, 0.0, 1.0)
    eye = np.clip((200.0 - eye_gray.astype(float)) / 140.0, 0.0, 1.0)
    # Specks the interpolation can leave behind: keep the largest part and what touches it.
    labels, n = ndimage.label(sil > 0.5)
    if n > 1:
        sizes = ndimage.sum(sil > 0.5, labels, range(1, n + 1))
        main = labels == (int(np.argmax(sizes)) + 1)
        near = ndimage.binary_dilation(main, iterations=3)
        sil = np.where(near, sil, 0.0)
    rgba = np.zeros(sil.shape + (4,), dtype=np.uint8)
    rgba[..., :3] = (EYE[None, None, :] * eye[..., None]).astype(np.uint8)
    rgba[..., 3] = (np.maximum(sil, eye) * 255).astype(np.uint8)
    return rgba


def upsample(name, fps_target, rife_dir, frames_override=0, redo=False):
    folder = CLIPS / name
    if redo and (BACKUP / name).exists():
        shutil.rmtree(folder)
        shutil.copytree(BACKUP / name, folder)
    manifest = json.loads((folder / "manifest.json").read_text())
    if manifest.get("upsampled"):
        print(name, "already upsampled")
        return
    count = int(manifest["frames"])
    fps = float(manifest["fps"])
    loop = bool(manifest["loop"])
    # --frames N retimes the clip to exactly N frames at the target fps (a loop of N frames). Used for the
    # run: it plays at exactly 1.0x at the level-1 run speed, so every frame stays on screen for the
    # same number of refreshes (a 1.075x speed made one frame in seven last one refresh instead of two).
    factor = (frames_override / count) if frames_override > 0 else fps_target / fps
    frames = [np.array(Image.open(folder / ("frame_%03d.png" % i)).convert("RGBA")) for i in range(count)]
    sequence = frames + [frames[0]] if loop else frames
    out_count = int(round((len(sequence) - 1) * factor)) + 1
    keep = frames_override if frames_override > 0 else (int(round(count * factor)) if loop else out_count)
    if not loop:
        keep = min(keep, out_count)  # a short clip cannot be stretched to more frames than the interpolator can make

    silhouettes = [(255 - (f[..., 3]).astype(np.uint8)) for f in sequence]
    eyes = [(255 - (np.clip(eye_mask(f), 0, 1) * 255).astype(np.uint8)) for f in sequence]
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        sil_out = run_rife(rife_dir, silhouettes, out_count, work, "sil")
        eye_out = run_rife(rife_dir, eyes, out_count, work, "eye")

    BACKUP.mkdir(parents=True, exist_ok=True)
    backup = BACKUP / name
    if backup.exists():
        shutil.rmtree(backup)
    shutil.copytree(folder, backup, ignore=shutil.ignore_patterns("*.import"))
    (BACKUP.parent / ".gdignore").touch()
    for old in folder.glob("frame_*"):
        old.unlink()

    # Sanity check: an interpolated frame whose feet are far beyond both neighbours' feet is a glitch.
    def bottom(rgba):
        rows = np.where(rgba[..., 3] > 128)[0]
        return int(rows.max()) if len(rows) else 0
    original_bottoms = [bottom(f) for f in sequence]
    written = 0
    for i in range(keep):
        rgba = compose(sil_out[i], eye_out[i])
        Image.fromarray(rgba, "RGBA").save(folder / ("frame_%03d.png" % i))
        position = i * (len(sequence) - 1) / max(1, out_count - 1)
        lo = original_bottoms[int(np.floor(position))]
        hi = original_bottoms[min(len(sequence) - 1, int(np.floor(position)) + 1)]
        overshoot = max(min(lo, hi) - bottom(rgba), bottom(rgba) - max(lo, hi), 0)
        if overshoot > 8:
            print("  WARNING %s frame %d: feet %d px beyond both neighbours" % (name, i, overshoot))
        written += 1

    manifest["original_frames"] = count
    manifest["original_fps"] = fps
    manifest["frames"] = written
    manifest["fps"] = fps_target
    manifest["frame_factor"] = written / count
    manifest["upsampled"] = True
    manifest.pop("frame_durations", None)
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print("%s: %d -> %d frames @ %g fps" % (name, count, written, fps_target))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("clips", nargs="+")
    parser.add_argument("--fps", type=float, default=60.0)
    parser.add_argument("--frames", type=int, default=0, help="retime to exactly this many frames at --fps (one clip only)")
    parser.add_argument("--redo", action="store_true", help="start again from the saved 24fps frames")
    parser.add_argument("--rife", default=os.path.expanduser("~/tools/rife-ncnn-vulkan-20221029-macos"))
    args = parser.parse_args()
    for clip in args.clips:
        upsample(clip, args.fps, Path(args.rife), args.frames, args.redo)


if __name__ == "__main__":
    main()
