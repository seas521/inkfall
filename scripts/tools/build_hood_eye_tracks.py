"""Read authored frames and build eye metadata; never repaint source bitmaps."""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

ROOT = Path(__file__).resolve().parents[2]
manifest = (ROOT / "scripts/actors/hood_actor_manifest.gd").read_text()
clips = json.loads(manifest.split("const CLIPS := ", 1)[1].split("\nconst GROUPS", 1)[0])
tracks = {}
audit = {}
seeds = {}
PRESERVE_OCCLUSION = {"fall_impact", "downed", "get_up", "climb", "grab_bridge", "water_plunge"}


def transfer_head(old_outline, new_outline, eye):
    """Register nearby hood edges, rather than guessing a point in empty pixels."""
    eye = np.asarray(eye, dtype=float)
    relative = old_outline - eye
    source = old_outline[(relative[:, 0] > -35) & (relative[:, 0] < 95) & (relative[:, 1] > -80) & (relative[:, 1] < 45)]
    relative = new_outline - eye
    target = new_outline[(relative[:, 0] > -60) & (relative[:, 0] < 120) & (relative[:, 1] > -100) & (relative[:, 1] < 65)]
    if len(source) < 8 or len(target) < 8:
        return eye.copy()
    source = source[::max(1, len(source) // 160)]
    tree = cKDTree(target)
    moved = source.copy()
    result = eye.copy()
    for _ in range(7):
        distance, indices = tree.query(moved)
        keep = distance < min(20, max(4, np.percentile(distance, 78)))
        if keep.sum() < 8:
            break
        p, q = source[keep], target[indices[keep]]
        pc, qc = p.mean(0), q.mean(0)
        u, _, vt = np.linalg.svd((p - pc).T @ (q - qc))
        rotation = vt.T @ u.T
        if np.linalg.det(rotation) < 0:
            vt[-1] *= -1
            rotation = vt.T @ u.T
        scale = np.clip(np.sum((q - qc) * ((p - pc) @ rotation.T)) / max(np.sum((p - pc) ** 2), 1), 0.88, 1.12)
        offset = qc - scale * pc @ rotation.T
        moved = scale * source @ rotation.T + offset
        result = scale * eye @ rotation.T + offset
    return result if np.linalg.norm(result - eye) < 45 else eye.copy()


for name, info in clips.items():
    rows = []
    previous = None
    detected = 0
    multiple = 0
    outlines = []
    alphas = []
    eye_holes = []
    for index, rect in enumerate(info["rects"]):
        path = ROOT / f"assets/art/actors/hood_boy/{info['group']}/{name}/f_{index:03}.png"
        rgba = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)
        r, g, b, a = [rgba[:, :, i] for i in range(4)]
        raw_solid = a > 200
        enclosed = ndimage.binary_fill_holes(raw_solid)
        hole_labels, hole_count = ndimage.label(enclosed & ~raw_solid)
        hole_centers = []
        for hole_id in range(1, hole_count + 1):
            hy, hx = np.where(hole_labels == hole_id)
            if 8 <= len(hx) <= 500:
                hole_centers.append(np.array([hx.mean()+0.5+rect[0]-info["root"][0], hy.mean()+0.5+rect[1]-info["root"][1]]))
        eye_holes.append(hole_centers)
        solid = ndimage.binary_fill_holes(a > 128)
        border = solid & ~ndimage.binary_erosion(solid)
        by, bx = np.where(border)
        outlines.append(np.stack([bx + rect[0] - info["root"][0], by + rect[1] - info["root"][1]], axis=1).astype(float))
        alphas.append(solid)
        mask = (a > 80) & (r > 55) & (r - g > 24) & (g - b > 4)
        # Join fragments within one tiny glowing eye, not widely spaced eyes.
        labels, count = ndimage.label(ndimage.binary_dilation(mask), np.ones((3, 3)))
        candidates = []
        for component in range(1, count + 1):
            ys, xs = np.where(mask & (labels == component))
            if len(xs) < 2:
                continue
            weights = (r[ys, xs] - g[ys, xs]) * a[ys, xs] / 255.0
            cx, cy = np.average(xs + 0.5, weights=weights), np.average(ys + 0.5, weights=weights)
            local = np.array([cx + rect[0] - info["root"][0], cy + rect[1] - info["root"][1]])
            score = np.log1p(weights.sum())
            if previous is not None:
                score -= np.linalg.norm(local - previous) / 25.0
            candidates.append((score, local, xs, ys, weights))
        if candidates:
            _, local, xs, ys, weights = max(candidates, key=lambda item: item[0])
            centered = np.stack([xs - np.average(xs, weights=weights), ys - np.average(ys, weights=weights)])
            covariance = (centered * weights) @ centered.T / max(weights.sum(), 1.0)
            values, vectors = np.linalg.eigh(covariance)
            axis = vectors[:, -1]
            angle = float(np.arctan2(axis[1], axis[0]) - np.pi / 2.0)
            angle = (angle + np.pi / 2.0) % np.pi - np.pi / 2.0
            if values[-1] < max(1.0, values[0]) * 1.4:
                angle = rows[-1][2] if rows else 0.0
            rows.append([round(float(local[0]), 3), round(float(local[1]), 3), round(angle, 4), 1.0])
            previous = local
            detected += 1
            multiple += len(candidates) > 1
        else:
            # No visible source eye means occluded, never a made-up front eye.
            at = previous if previous is not None else np.array([0.0, -150.0])
            rows.append([round(float(at[0]), 3), round(float(at[1]), 3), 0.0, 0.0])
    original_visible = [i for i, row in enumerate(rows) if row[3]]
    recovered = 0
    if name not in PRESERVE_OCCLUSION:
        forward, backward = {}, {}
        if not original_visible and name == "tired_idle" and "tired_stop" in seeds:
            old_outline, old_eye = seeds["tired_stop"]
            first = transfer_head(old_outline, outlines[0], old_eye)
            rows[0] = [*np.round(first, 3), 0.0, 1.0]
            original_visible = [0]
            recovered += 1
        previous_eye = None
        for i in range(len(rows)):
            if rows[i][3]:
                previous_eye = np.array(rows[i][:2])
            elif previous_eye is not None:
                previous_eye = transfer_head(outlines[i-1], outlines[i], previous_eye)
                forward[i] = previous_eye.copy()
        previous_eye = None
        for i in range(len(rows)-1, -1, -1):
            if rows[i][3]:
                previous_eye = np.array(rows[i][:2])
            elif previous_eye is not None:
                previous_eye = transfer_head(outlines[i+1], outlines[i], previous_eye)
                backward[i] = previous_eye.copy()
        for i, row in enumerate(rows):
            if row[3]:
                continue
            if i in forward and i in backward:
                left = max(j for j in original_visible if j < i)
                right = min(j for j in original_visible if j > i)
                t = (i-left) / (right-left)
                point = forward[i]*(1-t) + backward[i]*t
            else:
                point = forward.get(i, backward.get(i))
            if point is None:
                continue
            pixel = point + np.array(info["root"]) - np.array(info["rects"][i][:2])
            x, y = np.round(pixel).astype(int)
            solid = alphas[i]
            if 0 <= y < solid.shape[0] and 0 <= x < solid.shape[1] and solid[y, x]:
                row[:2] = np.round(point, 3).tolist()
                row[3] = 1.0
                recovered += 1
    if rows[-1][3]:
        seeds[name] = (outlines[-1], np.array(rows[-1][:2]))
    # Keep the light core inside the hood, including recovered landmarks.
    for i, row in enumerate(rows):
        if not row[3]:
            continue
        pixel = np.array(row[:2]) + np.array(info["root"]) - np.array(info["rects"][i][:2])
        x, y = np.round(pixel).astype(int)
        distance = ndimage.distance_transform_edt(alphas[i])
        if 0 <= y < distance.shape[0] and 0 <= x < distance.shape[1] and distance[y, x] < 2.8:
            yy, xx = np.where(distance >= 2.8)
            delta = (xx - pixel[0]) ** 2 + (yy - pixel[1]) ** 2
            closest = np.argmin(delta)
            if delta[closest] < 64:
                point = np.array([xx[closest], yy[closest]]) - np.array(info["root"]) + np.array(info["rects"][i][:2])
                row[:2] = np.round(point, 3).tolist()
    if name == "rope_ladder":
        # Matting removed the bright eye interior, leaving an amber crescent.
        # Its centroid flips between opposite rims as the head moves. The
        # enclosed eye socket remains tied to the face in every source frame.
        for i, row in enumerate(rows):
            if not eye_holes[i]:
                continue
            center = min(eye_holes[i], key=lambda point: np.linalg.norm(point-np.array(row[:2])))
            if np.linalg.norm(center-np.array(row[:2])) < 24:
                row[:2] = np.round(center, 3).tolist()
                row[2] = 0.0
    tracks[name] = rows
    audit[name] = {"frames": len(rows), "detected": detected, "recovered": recovered, "occluded": len(rows) - detected - recovered, "multiple_candidates": multiple}

out = ROOT / "scripts/actors/hood_eye_tracks.gd"
out.write_text("# Generated by build_hood_eye_tracks.py; source sprites remain unchanged.\nextends RefCounted\n\nconst DATA := " + json.dumps(tracks, separators=(",", ":")) + "\n")
audit_dir = ROOT / "artifacts/actor-eyes"
audit_dir.mkdir(parents=True, exist_ok=True)
(audit_dir / ".gdignore").touch()
(audit_dir / "source-audit.json").write_text(json.dumps(audit, indent=2))
for name, row in audit.items():
    print(f"{name:24} {row['detected']:3}/{row['frames']:3} source; recovered={row['recovered']:3}; occluded={row['occluded']:3}; ambiguous={row['multiple_candidates']}")
print(f"Wrote {out}; {sum(row['frames'] for row in audit.values())} original frames audited")
