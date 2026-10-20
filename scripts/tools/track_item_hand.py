#!/usr/bin/env python3
"""Finds where the carried item is in the hand, frame by frame, for video A (Seedance 2968, single hand).

    ffmpeg -i VIDEO -fps_mode passthrough FRAMES/%04d.png
    /tmp/imgenv/bin/python scripts/tools/track_item_hand.py FRAMES            (after build_small_clips.py + rife_upsample.py)

The video has no object, only a hand shaped around one, and in a silhouette the two hands cannot be told
apart by shape. The hand that holds the item has a small closed hole in its curled fingers (about 90 px
once the eye's own hole is excluded), so:

  frames 13-39   (pick up)   the silhouette's extreme point, tracked by continuity from the held pose
  frames 40-197  (holding)   the centre of the finger hole; while the hand is hidden (behind the head in the
                             wind-up, behind the fan that was drawn) the path is interpolated
  frames 198-202 (release)   interpolated to the forward-most point of the throwing arm

Writes `hold_points` (canvas px from the root, as the other clips) into the manifests of the small clips,
and `grasp_orig_frame` (the hand is on the item and starts to rise) and `release_orig_frame`.
"""
import glob
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import ConvexHull

PROJECT = Path(__file__).resolve().parents[2]
CLIPS = PROJECT / "assets/art/prototypes/hood_clips"
SCALE = 0.528
ROOT_SRC = (456.8, 759.0)


def load_masks(frames):
    files = sorted(glob.glob(str(Path(frames) / "*.png")))
    return files


def silhouette(path):
    a = np.array(Image.open(path).convert("RGB")).astype(int)
    g = a[..., 1] - np.maximum(a[..., 0], a[..., 2])
    m = (g < 60) & (a.sum(2) < 260)
    lab, n = ndimage.label(m)
    if n > 1:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = lab == (int(np.argmax(sizes)) + 1)
    return a, m


def hull_vertices(m):
    edge = m & ~ndimage.binary_erosion(m)
    ys, xs = np.where(edge)
    pts = np.stack([xs, ys], 1)
    return pts[ConvexHull(pts).vertices].astype(float)


def front_point(m):
    ys, xs = np.where(m)
    sel = xs <= xs.min() + 6
    return np.array([xs[sel].mean(), ys[sel].mean()])


def main():
    files = load_masks(sys.argv[1])
    cache = {}

    def get(i):
        if i not in cache:
            cache[i] = silhouette(files[i])
        return cache[i]

    # 1. pick up: nearest hull vertex, backwards from the held pose (frame 50 -> 13)
    pos = front_point(get(50)[1])
    pick = {}
    for i in range(49, 11, -1):
        hv = hull_vertices(get(i)[1])
        d = np.linalg.norm(hv - pos, axis=1)
        if d.min() <= 90:
            pos = hv[int(np.argmin(d))]
        pick[i] = pos.copy()

    # 2. holding: the small closed hole in the curled fingers (not the eye's hole)
    ring = {}
    prev = None
    last = None
    for i in range(40, 198):
        a, m = get(i)
        holes = ndimage.binary_fill_holes(m) & ~m
        lab, n = ndimage.label(holes)
        eye_mask = (a[..., 0] > 150) & (a[..., 0] - a[..., 2] > 60) & (a[..., 1] > a[..., 2] * 1.2)
        ey, ex = np.where(eye_mask)
        eye = np.array([ex.mean(), ey.mean()]) if len(ex) >= 10 else None
        cands = []
        for k in range(1, n + 1):
            ys, xs = np.where(lab == k)
            if 55 <= len(xs) <= 150:
                c = np.array([xs.mean(), ys.mean()])
                if eye is None or np.hypot(*(c - eye)) > 22:
                    cands.append(c)
        if not cands:
            continue
        if prev is None:
            ring[i] = cands[0]
        else:
            cands.sort(key=lambda c: np.hypot(*(c - prev)))
            if np.hypot(*(cands[0] - prev)) < 160 + 90 * (i - last - 1):
                ring[i] = cands[0]
            else:
                continue
        prev, last = ring[i], i

    known = sorted(ring)
    path = {i: pick[i] + np.array([10.0, 0.0]) for i in range(13, 40)}  # the item sits a little behind the finger tips
    for i in range(40, 198):
        if i in ring:
            path[i] = ring[i]
            continue
        lows = [k for k in known if k < i]
        highs = [k for k in known if k > i]
        if lows and highs:
            t = (i - lows[-1]) / (highs[0] - lows[-1])
            path[i] = ring[lows[-1]] * (1 - t) + ring[highs[0]] * t
        else:
            path[i] = ring[lows[-1]] if lows else ring[highs[0]]
    # 3. release: from the hand behind the head to the forward-most point of the throw
    forward = front_point(get(203)[1])
    for i in range(198, 203):
        t = (i - 197) / 6.0
        path[i] = path[197] * (1 - t) + forward * t
    for i in range(203, 232):
        path[i] = forward

    def to_canvas(i):
        x = (path[i][0] - ROOT_SRC[0]) * SCALE
        y = (path[i][1] - ROOT_SRC[1]) * SCALE
        return [float(x), float(y)]

    clips = {
        "small_pickup": (13, 39, False), "small_hold": (50, 50, False), "small_run": (103, 115, False),
        "small_jump_takeoff": (144, 146, True), "small_jump_rise": (147, 149, True), "small_jump_apex": (150, 153, True),
        "small_jump_fall": (154, 157, True), "small_jump_land": (158, 171, False),
        "small_throw_charge": (172, 188, False), "small_throw_release": (192, 214, False), "small_throw_recover": (214, 230, False),
    }
    for name, (first, last_frame, pinned) in clips.items():
        manifest_path = CLIPS / name / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        points = []
        for i in range(first, last_frame + 1):
            x, y = to_canvas(i)
            if pinned:
                # build_small_clips.py put the airborne frames on the ground line: lower the hand by the same amount
                _, m = get(i)
                ys, _ = np.where(m)
                body_lift = (759.0 - ys.max()) * SCALE
                y += body_lift if body_lift > 3.0 else 0.0
            points.append([x, y])
        manifest["hold_points"] = points
        if name == "small_pickup":
            manifest["grasp_orig_frame"] = 29 - first
        if name == "small_throw_release":
            manifest["release_orig_frame"] = 199 - first
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print(name, len(points), "hold points; first", [round(v, 1) for v in points[0]], "last", [round(v, 1) for v in points[-1]])


if __name__ == "__main__":
    main()
