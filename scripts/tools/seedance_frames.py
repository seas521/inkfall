#!/usr/bin/env python3
"""Turn a Seedance clip (black silhouette on a light plain background) into game frames.

    python scripts/tools/seedance_frames.py VIDEO --find-loop 44,93 --min-loop 14      # suggest loop points
    python scripts/tools/seedance_frames.py VIDEO --name run_right --start 44 --end 73 --loop \
        --fps-out 48 --scale 0.2736 --root-x 492 --ground-y 833

--start/--end are SOURCE frame numbers (the video's own frames). Pipeline: trim -> uniform timing ->
(optional) motion-interpolate to a higher frame rate ->
chroma/luminance matte into pure black + opaque orange eye -> one shared scale and one shared root for
the whole clip (taken from its first frame, or from --root-x/--root-y/--scale) so the motion inside
the clip is kept exactly as generated -> write 256x256 RGBA frames, a manifest and a preview.

The first clip of a character decides the scale: it prints `scale=...`; pass that number to every
other clip with --scale so that the character has the same size in all of them.
Needs Pillow and numpy (a venv is enough) and ffmpeg on the PATH.
"""
import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
ROOT = np.array([128.0, 232.0])
INK = np.array([0.004, 0.006, 0.006])


def run(*args):
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", *map(str, args)], check=True)


def extract(video, temp, fps_out, src_fps, first, last, interp):
    """Source frames first..last (inclusive) with uniform timing, optionally interpolated to fps_out."""
    vf = [f"trim=start_frame={first}:end_frame={last + 1}", f"setpts=N/({src_fps}*TB)"]
    if fps_out and fps_out > src_fps:
        vf.append(f"minterpolate=fps={fps_out}:mi_mode={interp}:mc_mode=aobmc:me_mode=bidir:vsbmc=1"
                  if interp == "mci" else f"minterpolate=fps={fps_out}:mi_mode=blend")
    run("-i", video, "-an", "-vf", ",".join(vf), "-fps_mode", "passthrough", "-start_number", "0", Path(temp) / "%04d.png")
    return sorted(Path(temp).glob("*.png"))


def probe_fps(video):
    """Real frame rate = unique frames / duration. Seedance files often declare 60 fps but carry
    24 fps content with uneven timestamps, so the declared rate would duplicate frames."""
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames", "-show_entries",
                          "stream=nb_read_frames,duration", "-of", "json", str(video)],
                         capture_output=True, text=True, check=True).stdout
    import json as _json
    stream = _json.loads(out)["streams"][0]
    frames, duration = float(stream["nb_read_frames"]), float(stream["duration"])
    return round(frames / duration, 2)


def drop_specks(alpha, near=6):
    """Keep the character: the biggest connected shape plus anything touching it. Stray pixels, dust,
    compression noise and detached fragments invented by the interpolator all go."""
    from scipy import ndimage
    labels, count = ndimage.label(alpha > 0.5)
    if count <= 1:
        return alpha
    areas = ndimage.sum(np.ones_like(alpha), labels, index=np.arange(1, count + 1))
    main = labels == (1 + int(np.argmax(areas)))
    zone = ndimage.binary_dilation(main, iterations=near)
    return np.where(zone, alpha, 0.0)


def matte(path, key, exclude_blue=False):
    """Returns (rgba, alpha). key: green screen (default), light or dark plain background."""
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    orange = (r - b > 0.15) & (g > b * 1.4) & (r > g * 0.8)
    if key == "green":
        # How green a pixel is relative to the background, measured from the frame border.
        greenness = g - np.maximum(r, b)
        border = np.concatenate([greenness[:6].ravel(), greenness[-6:].ravel(), greenness[:, :6].ravel(), greenness[:, -6:].ravel()])
        bg = max(0.2, float(np.median(border)))
        t = np.clip(greenness / bg, 0.0, 1.5)
        coverage = 1.0 - np.clip((t - 0.10) / 0.80, 0.0, 1.0)
        # Ground shadows and dust wisps are only half-dark: a firm threshold drops them, and the later
        # downscale gives the silhouette its soft edge back.
        x = np.clip((coverage - 0.55) / 0.25, 0.0, 1.0)
        alpha = x * x * (3.0 - 2.0 * x)
    elif key == "light":
        value = rgb.mean(axis=2)
        t = np.clip((value - 0.10) / 0.32, 0.0, 1.0)
        alpha = 1.0 - t * t * (3.0 - 2.0 * t)
    else:
        value = rgb.mean(axis=2)
        t = np.clip((value - 0.55) / 0.30, 0.0, 1.0)
        alpha = t * t * (3.0 - 2.0 * t)
    if exclude_blue:
        # a flat blue block in the picture (the climb): it is not the character. Where the black body edge blends with
        # it, the pixel is only partly the body.
        alpha = alpha * np.clip((0.55 - b) / 0.30, 0.0, 1.0)
    alpha[orange] = 1.0
    alpha = drop_specks(alpha)
    ink = np.broadcast_to(INK, rgb.shape).copy()
    ink[orange] = rgb[orange]
    return np.dstack([ink, alpha]), alpha


def feet_anchor(alpha):
    ys, xs = np.nonzero(alpha > 0.5)
    bottom = ys.max()
    band = ys >= bottom - max(2, int((bottom - ys.min()) * 0.04))
    return float(xs[band].mean()), float(bottom), float(ys.min())


def loop_candidates(masks, lo, hi, min_len, max_len, count=6):
    """Pairs (s, e) where the frame after e looks like frame s and the motion lines up."""
    found = []
    for s_ in range(max(lo, 1), hi - min_len):
        for e_ in range(s_ + min_len - 1, min(hi, s_ + max_len)):
            if e_ + 1 >= len(masks):
                continue
            score = np.abs(masks[e_ + 1] - masks[s_]).mean() + 0.5 * np.abs(masks[e_] - masks[s_ - 1]).mean()
            found.append((float(score) * 1000.0, s_, e_, e_ - s_ + 1))
    found.sort()
    return found[:count]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("video")
    ap.add_argument("--name", default="clip")
    ap.add_argument("--out", default=str(PROJECT / "assets/art/actors/hood_boy"))
    ap.add_argument("--start", type=int, default=0, help="first SOURCE frame of the clip")
    ap.add_argument("--end", type=int, default=-1, help="last SOURCE frame (inclusive)")
    ap.add_argument("--interp", choices=["mci", "blend"], default="mci", help="how --fps-out invents in-between frames")
    ap.add_argument("--fps-out", type=float, default=0.0, help="interpolate the source to this rate first")
    ap.add_argument("--scale", type=float, default=0.0, help="source px -> canvas px; default: standing height 200px")
    ap.add_argument("--root-x", type=float, default=None, help="source x that maps to the canvas root")
    ap.add_argument("--ground-y", type=float, default=None, help="source y of the ground that maps to the canvas root")
    ap.add_argument("--key", choices=["green", "light", "dark"], default="green", help="background to remove")
    ap.add_argument("--flip", action="store_true", help="mirror the frames horizontally")
    ap.add_argument("--loop", action="store_true", help="START..END is a closed loop (the frame after END looks like START)")
    ap.add_argument("--find-loop", metavar="LO,HI", help="only report the best loop points between two source frames")
    ap.add_argument("--exclude-blue", action="store_true", help="a flat blue block is in the picture (it is not part of the character)")
    ap.add_argument("--boomerang", action="store_true", help="play START..END forward then backward as a loop")
    ap.add_argument("--pin-feet", action="store_true", help="keep the feet centre of every frame on the root (for turns in place, where the video drifts sideways)")
    ap.add_argument("--step", type=int, default=1, help="keep every Nth source frame (speeds the motion up N times)")
    ap.add_argument("--min-loop", type=int, default=8)
    ap.add_argument("--max-loop", type=int, default=40)
    ap.add_argument("--pin-hands", type=float, default=None, help="keep the hand tip (front-most point, smoothed over 9 frames) at this many source px left of the root: for shoving / pushing, where the hands stay on the object while the body drifts")
    ap.add_argument("--pin-centroid", action="store_true", help="keep the centre of the silhouette on the root in x and y: for floating / swimming, where the body moves about in the picture")
    ap.add_argument("--pin-top", action="store_true", help="keep the top of the silhouette at the root's height (the root is then the highest point): for sinking, where the body drifts down and out of the picture")
    ap.add_argument("--root-pos", default=None, help="root in canvas px as X,Y instead of the default (e.g. 192,192 so that a centroid-pinned swimmer sits mid-canvas)")
    ap.add_argument("--canvas", type=int, default=256)
    args = ap.parse_args()

    src_fps = probe_fps(args.video)
    if args.find_loop:
        lo, hi = (int(v) for v in args.find_loop.split(","))
        with tempfile.TemporaryDirectory(prefix="seedance-") as temp:
            paths = extract(args.video, temp, 0.0, src_fps, 0, 100000, "blend")
            masks = [matte(p, args.key)[1] for p in paths[:min(len(paths), hi + 2)]]
        for score, first, last, count in loop_candidates(masks, lo, hi, args.min_loop, args.max_loop):
            print(f"score={score:5.1f}  --start {first} --end {last}  ({count} frames, {count / src_fps:.2f}s)")
        return
    out_dir = Path(args.out) / args.name
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("frame_*.png"):
        old.unlink()
    last = args.end if args.end >= 0 else 100000
    with tempfile.TemporaryDirectory(prefix="seedance-") as temp:
        interpolating = args.fps_out > src_fps
        fps = args.fps_out if interpolating else src_fps
        # The interpolator loses a few frames at the end of its input, so feed it a little extra and
        # keep exactly the frames that belong to START..END. For a closed loop the clip stops just
        # before it would repeat its first frame.
        extra = 3 if interpolating else (1 if args.loop else 0)
        paths = extract(args.video, temp, args.fps_out, src_fps, args.start, last + extra, args.interp)
        count = args.end - args.start + 1 if args.end >= 0 else len(paths)
        keep = round(count * fps / src_fps) if args.loop else round((count - 1) * fps / src_fps) + 1
        paths = paths[:keep]
        if args.step > 1:
            paths = paths[::args.step]
        rgbas, alphas = zip(*[matte(p, args.key, args.exclude_blue) for p in paths])
        if args.boomerang:
            order = list(range(len(rgbas))) + list(range(len(rgbas) - 2, 0, -1))
            rgbas, alphas = [rgbas[i] for i in order], [alphas[i] for i in order]
            args.loop = True
        size = alphas[0].shape[::-1]
        x0, y0, top0 = feet_anchor(alphas[0])
        scale = args.scale or 200.0 / max(1.0, y0 - top0)
        root_x = args.root_x if args.root_x is not None else x0
        ground_y = args.ground_y if args.ground_y is not None else y0
        canvas = args.canvas
        root = ROOT * canvas / 256.0
        if args.root_pos:
            root = np.array([float(v) for v in args.root_pos.split(",")])
        warnings = []
        hand_anchor = None
        if args.pin_hands is not None:
            tips = np.array([float(np.nonzero((alpha > 0.5).any(axis=0))[0].min()) for alpha in alphas])
            half = 4
            hand_anchor = [float(np.median(tips[max(0, i - half): i + half + 1])) for i in range(len(tips))]
        for index, rgba in enumerate(rgbas):
            img = Image.fromarray(np.uint8(np.clip(rgba * 255.0, 0, 255)), "RGBA")
            small = img.resize((max(1, round(size[0] * scale)), max(1, round(size[1] * scale))), Image.Resampling.LANCZOS)
            anchor_x = feet_anchor(alphas[index])[0] if args.pin_feet else root_x
            if hand_anchor is not None:
                anchor_x = hand_anchor[index] + args.pin_hands
            anchor_y = ground_y
            if args.pin_centroid:
                ys_c, xs_c = np.nonzero(alphas[index] > 0.5)
                anchor_x, anchor_y = float(xs_c.mean()), float(ys_c.mean())
            elif args.pin_top:
                ys_c, xs_c = np.nonzero(alphas[index] > 0.5)
                anchor_y = float(ys_c.min())
            offset = (round(root[0] - anchor_x * scale), round(root[1] - anchor_y * scale))
            frame = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
            frame.paste(small, offset)
            if args.flip:
                frame = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            box = frame.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
            if box is None or min(box[:2]) < 3 or box[2] > canvas - 3 or box[3] > canvas - 3:
                warnings.append((index, box))
            frame.save(out_dir / f"frame_{index:03d}.png")
        manifest = {
            "name": args.name, "frames": len(rgbas), "fps": fps, "source_fps": src_fps,
            "scale": scale, "root": [float(root[0]), float(root[1])], "canvas": canvas,
            "source_root": [root_x, ground_y], "loop": bool(args.loop),
            "source_frames": [args.start, args.end],
        }
        (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))
        # Preview over the game's grey, looped three times if it is a loop.
        repeats = ["-stream_loop", "2"] if args.loop else []
        run(*repeats, "-framerate", fps, "-i", out_dir / "frame_%03d.png", "-f", "lavfi", "-i",
            f"color=c=0x8a8c8e:s={canvas}x{canvas}:r={fps}", "-filter_complex",
            "[1:v][0:v]overlay=shortest=1,scale=iw*2:ih*2:flags=neighbor", "-pix_fmt", "yuv420p",
            out_dir / "preview.mp4")
    print(f"{args.name}: {len(rgbas)} frames @ {fps:g}fps  scale={scale:.4f}  root_src=({root_x:.1f},{ground_y:.1f})")
    for index, box in warnings:
        print(f"WARNING frame {index}: silhouette {box} touches the {canvas}px canvas border")
    if warnings:
        sys.exit(2)


if __name__ == "__main__":
    main()
