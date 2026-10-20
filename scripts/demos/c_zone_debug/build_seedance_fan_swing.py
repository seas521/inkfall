"""Extract the complete 8496 action with a common canvas and timed holds."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
SOURCE = Path("/Users/xiangxi.li/Downloads/jimeng-2026-10-13-8496-根据上传的角色图片，生成一段5秒的横版2D游戏角色动画。 任务：同一个角色保持侧....mp4")
OUTPUT = PROJECT / "assets/art/c_zone_debug/fan_swing_seedance_8496"
REPORT = PROJECT / "artifacts/c-zone-fan/seedance-8496"
FIRST, LAST = 12, 100
ROOT = np.array([128., 232.])
SOURCE_ROOT = np.array([480., 851.25])
SCALE = 196. / 765.
# Annotated in a 256px full-canvas view, never in per-frame cropped coordinates.
HAND_KEYS = [
    (12, 85, 181), (13, 78, 173), (14, 64, 162), (15, 62, 150),
    (16, 60, 143), (18, 61, 137), (20, 60, 136), (36, 60, 136),
    (38, 66, 136), (39, 77, 139), (40, 100, 148), (41, 153, 164),
    (42, 193, 175), (44, 191, 175), (55, 187, 178), (80, 183, 177),
    (83, 184, 177), (84, 182, 175), (85, 176, 172), (86, 165, 168),
    (87, 160, 169), (88, 155, 173), (89, 150, 178), (90, 142, 182),
    (91, 133, 185), (92, 126, 187), (94, 111, 186), (96, 98, 186),
    (98, 88, 184), (100, 86, 182),
]
ANGLE_KEYS = [(12, -38), (20, -55), (37, -55), (39, -32), (40, -8),
              (41, 32), (42, 65), (44, 94), (83, 94), (89, 64),
              (94, 8), (100, -38)]
# Preserve every frame; only shorten the video's long stationary holds.
PHASES = [(12, 19, .20), (20, 37, .08), (38, 44, .24),
          (45, 83, .08), (84, 100, .24)]


def key_at(keys, index, column):
    return float(np.interp(index, [k[0] for k in keys], [k[column] for k in keys]))


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    REPORT.mkdir(parents=True, exist_ok=True)
    rows, elapsed = [], 0.
    all_frames = []
    with tempfile.TemporaryDirectory(prefix="fan8496-") as temp:
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(SOURCE),
                        "-an", "-vf", "fps=24", "-start_number", "0", str(Path(temp) / "%03d.png")], check=True)
        for index in range(FIRST, LAST + 1):
            rgb = np.asarray(Image.open(Path(temp) / f"{index:03d}.png").convert("RGB"), dtype=np.float32) / 255.
            assert rgb.shape == (960, 960, 3)
            orange = (rgb[:, :, 0] - rgb[:, :, 2] > .15) & (rgb[:, :, 1] > rgb[:, :, 2] * 1.4)
            value = rgb.mean(axis=2)
            t = np.clip((value - .10) / .32, 0, 1)
            alpha = 1 - t * t * (3 - 2 * t)
            alpha[orange] = 1
            ink = np.broadcast_to(np.array([.004, .006, .006]), rgb.shape).copy()
            ink[orange] = rgb[orange]
            rgba = np.dstack([ink, alpha])
            full = Image.fromarray(np.uint8(np.clip(rgba * 255, 0, 255)))
            transform = (1 / SCALE, 0, SOURCE_ROOT[0] - ROOT[0] / SCALE,
                         0, 1 / SCALE, SOURCE_ROOT[1] - ROOT[1] / SCALE)
            frame = full.transform((256, 256), Image.Transform.AFFINE, transform,
                                   resample=Image.Resampling.BICUBIC)
            bbox = frame.getbbox()
            assert bbox and min(bbox[:2]) >= 3 and max(bbox[2:]) < 253, (index, bbox)
            socket = ROOT + (np.array([key_at(HAND_KEYS, index, 1), key_at(HAND_KEYS, index, 2)]) * 3.75 - SOURCE_ROOT) * SCALE
            # Refine the annotated socket onto the local silhouette, not an arbitrary extremity.
            a = np.asarray(frame)[:, :, 3]
            yy, xx = np.nonzero(a > 230)
            nearest = np.argmin((xx - socket[0]) ** 2 + (yy - socket[1]) ** 2)
            error = float(np.hypot(xx[nearest] - socket[0], yy[nearest] - socket[1]))
            assert error < 10, (index, socket, error)
            socket = [float(xx[nearest]), float(yy[nearest])]
            duration = next(seconds / (end - start + 1) for start, end, seconds in PHASES if start <= index <= end)
            elapsed += duration
            local_index = index - FIRST
            frame.save(OUTPUT / f"frame_{local_index:03d}.png")
            all_frames.append(frame)
            rows.append(dict(source_frame=index, hand=socket, angle=key_at(ANGLE_KEYS, index, 1),
                             end_time=elapsed, duration=duration, bounds=bbox, socket_snap=error))

    lines = ["extends RefCounted", "", "# Generated from consecutive 24fps source frames 12..100; no internal cuts.",
             f"const COUNT := {len(rows)}", f"const DURATION := {elapsed:.6f}", "const HANDS := ["]
    lines += [f"\tVector2({r['hand'][0]:.3f}, {r['hand'][1]:.3f})," for r in rows]
    lines += ["]", "const ANGLES := [" + ",".join(f"{r['angle']:.4f}" for r in rows) + "]",
              "const ENDS := [" + ",".join(f"{r['end_time']:.6f}" for r in rows) + "]", ""]
    (PROJECT / "scripts/demos/c_zone_debug/fan_swing_seedance_data.gd").write_text("\n".join(lines))
    report = dict(source=str(SOURCE), sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                  source_fps=24, first=FIRST, last=LAST, count=len(rows), root=ROOT.tolist(),
                  source_root=SOURCE_ROOT.tolist(), common_scale=SCALE, duration=elapsed, frames=rows)
    (REPORT / "extraction.json").write_text(json.dumps(report, indent=2))
    # Internal full-frame audit; no extra game scene or user preview workflow.
    contact = Image.new("RGB", (256 * 10, 256 * 9), "#9b9b9b")
    for i, frame in enumerate(all_frames):
        contact.paste(frame, (i % 10 * 256, i // 10 * 256), frame)
    contact.save(REPORT / "all-frames.png")
    print(f"PASS: {len(rows)} consecutive frames, common scale/root, margins and sockets; duration {elapsed:.2f}s")


if __name__ == "__main__":
    main()
