#!/usr/bin/env python3
"""Takes the thin rod out of the fan video (Seedance 8081) and records where it was.

    ffmpeg -i VIDEO -fps_mode passthrough FRAMES/%04d.png
    /tmp/imgenv/bin/python scripts/tools/remove_thin_rod.py FRAMES CLEAN

The generator drew a thin straight rod (the invisible fan handle) in the boy's hands, black on green like
him. The game draws the fan itself, so the rod has to go, but where it was is exactly what the fan needs:
its direction and where it leaves the hand.

Per frame: the silhouette is opened with a disc a little wider than the rod (the rod, ~8 px thick, vanishes,
the body stays); what the opening removed is split into pieces, and the straight, long, thin pieces are the
rod (fingers, the hood tip and toes are short). Those pixels are painted back to the background colour in
CLEAN/ (same file names; make a video of them with ffmpeg and run seedance_frames.py on it), and
CLEAN/rod.json gets, for each frame the rod is visible: the end that touches the body (`near`), the far end
(`tip`), its length and its angle. Frames where the rod is hidden against the body have no entry.
"""
import glob
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

OPEN_RADIUS = 6
MIN_LENGTH = 45
MIN_ASPECT = 5.0


def disc(radius):
    y, x = np.ogrid[-radius: radius + 1, -radius: radius + 1]
    return x * x + y * y <= radius * radius


def main():
    frames, clean = Path(sys.argv[1]), Path(sys.argv[2])
    only = {int(v) for v in sys.argv[3].split(",")} if len(sys.argv) > 3 else None  # test on a few frames
    clean.mkdir(parents=True, exist_ok=True)
    rod = {}
    structure = disc(OPEN_RADIUS)
    for index, path in enumerate(sorted(glob.glob(str(frames / "*.png")))):
        if only is not None and index not in only:
            continue
        image = np.array(Image.open(path).convert("RGB"))
        a = image.astype(int)
        g = a[..., 1] - np.maximum(a[..., 0], a[..., 2])
        mask = g < 90
        background = np.median(image[:20].reshape(-1, 3), axis=0).astype(np.uint8)
        opened = ndimage.binary_opening(mask, structure=structure)
        thin = mask & ~opened
        labels, count = ndimage.label(thin, structure=np.ones((3, 3)))
        remove = np.zeros_like(mask)
        best = None
        for k in range(1, count + 1):
            ys, xs = np.where(labels == k)
            if len(xs) < 20:
                continue
            points = np.stack([xs, ys], 1).astype(float)
            centre = points.mean(0)
            _, singular, vt = np.linalg.svd(points - centre, full_matrices=False)
            axis = vt[0]
            along = (points - centre) @ axis
            across = (points - centre) @ vt[1]
            length = float(along.max() - along.min())
            thickness = float(across.max() - across.min()) + 1.0
            if length >= MIN_LENGTH and length / thickness >= MIN_ASPECT:
                remove |= labels == k
                if best is None or length > best["length"]:
                    end_a = centre + axis * along.max()
                    end_b = centre + axis * along.min()
                    body_ys, body_xs = np.where(ndimage.binary_dilation(opened, iterations=3))
                    # the end nearer to the body is where the hand holds it
                    def distance_to_body(point):
                        return float(np.min((body_xs - point[0]) ** 2 + (body_ys - point[1]) ** 2)) if len(body_xs) else 0.0
                    near, tip = (end_a, end_b) if distance_to_body(end_a) < distance_to_body(end_b) else (end_b, end_a)
                    best = {"length": length, "near": [float(near[0]), float(near[1])], "tip": [float(tip[0]), float(tip[1])]}
        if best is not None:
            dx = best["tip"][0] - best["near"][0]
            dy = best["tip"][1] - best["near"][1]
            best["angle"] = float(np.degrees(np.arctan2(dy, dx)))
            rod[index] = best
        remove = ndimage.binary_dilation(remove, iterations=3) & ~opened
        out = image.copy()
        out[remove] = background
        Image.fromarray(out).save(clean / Path(path).name)
    (clean / "rod.json").write_text(json.dumps(rod))
    print("rod found in", len(rod), "frames")


if __name__ == "__main__":
    main()
