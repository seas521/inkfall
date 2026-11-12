#!/usr/bin/env python3
"""Package every native frame of the rope-ladder master without repacking other clips.

Usage: python build_rope_ladder_clip.py VIDEO
Requires ffmpeg, Pillow, NumPy and SciPy. All source coordinates share one scale
and one ladder-top root. Root/contact tracks are separate metadata, never a
per-frame bounding-box recenter or a scale change.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PROJECT = Path(__file__).resolve().parents[2]
AUDIT = PROJECT / "artifacts/rope-ladder"
OUT = PROJECT / "assets/art/actors/hood_boy/rope_ladder/rope_ladder"
MANIFEST = PROJECT / "scripts/actors/hood_actor_manifest.gd"


def main():
    AUDIT.mkdir(parents=True, exist_ok=True)
    (AUDIT / ".gdignore").touch()
    source = AUDIT / "source-frames"
    source.mkdir(exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", sys.argv[1],
                    "-an", "-fps_mode", "passthrough", "-start_number", "0", str(source / "%04d.png")], check=True)
    paths = sorted(source.glob("*.png"))
    idle = Image.open(PROJECT / "assets/art/actors/hood_boy/core/idle_left/f_000.png").getchannel("A").getbbox()
    target_height = idle[3]-idle[1]
    rgba_frames, tracks = [], []
    for path in paths:
        rgb = np.asarray(Image.open(path).convert("RGB"), dtype=float)/255
        r, g, b = rgb.transpose(2, 0, 1)
        alpha = 1-np.clip((np.maximum.reduce([r, g, b])-.12)/.18, 0, 1)
        orange = (r>b+.15)&(r>g*1.15)&(g>b*1.4)&(r>.3)
        alpha = np.maximum(alpha, orange)
        labels, _ = ndimage.label(alpha>.45)
        sizes = np.bincount(labels.ravel()); sizes[0] = 0
        main_mask = labels == sizes.argmax()
        keep = ndimage.binary_dilation(main_mask, iterations=2)
        alpha *= keep
        rgba = np.zeros((*alpha.shape, 4), dtype=np.uint8)
        rgba[:, :, :3] = [1, 2, 2]
        rgba[:, :, :3][orange] = np.uint8(rgb[orange]*255)
        rgba[:, :, 3] = np.uint8(alpha*255)
        yy, xx = np.where(alpha>.5)
        ey, ex = np.where(orange&keep)
        eye = [float(ex.mean()), float(ey.mean())]
        foot_y = float(yy.max()); foot_x = float(np.median(xx[yy>=foot_y-4]))
        blue = (b>r+.12)&(b>g+.04)
        near = ndimage.binary_dilation(blue, iterations=4)&main_mask
        ys, xs = np.indices(near.shape)
        near &= (ys>eye[1]-90)&(ys<eye[1]+110)&(xs<eye[0]+5)
        contact_labels, _ = ndimage.label(near)
        contact_sizes = np.bincount(contact_labels.ravel()); contact_sizes[0] = 0
        if contact_sizes.max()>4:
            hy, hx = np.where(contact_labels==contact_sizes.argmax())
            hand = [float(hx.mean()), float(hy.mean())]
        else:
            hand = [eye[0]-45, eye[1]+25]
        tracks.append({"feet":[foot_x,foot_y],"eye":eye,"hand":hand})
        rgba_frames.append(Image.fromarray(rgba))
    first_box = rgba_frames[0].getchannel("A").getbbox()
    scale = target_height/(first_box[3]-first_box[1])
    size = round(960*scale)
    root = [384*scale, 365*scale]
    OUT.mkdir(parents=True, exist_ok=True)
    rects, margins = [], []
    for i, im in enumerate(rgba_frames):
        frame = Image.new("RGBA", (640,640))
        frame.paste(im.resize((size,size),Image.Resampling.LANCZOS),(0,0))
        # Downsampling ringing is below the useful silhouette threshold.
        data = np.asarray(frame).copy();data[:,:,3][data[:,:,3]<3]=0
        frame = Image.fromarray(data)
        x0,y0,x1,y1 = frame.getchannel("A").getbbox()
        margins.append(min(x0,y0,640-x1,640-y1))
        box = (x0-5,y0-5,x1+5,y1+5)
        frame.crop(box).save(OUT/f"f_{i:03d}.png")
        rects.append([box[0],box[1],box[2]-box[0],box[3]-box[1]])
    entry = {"frames":len(paths),"fps":24.0,"loop":False,"canvas":640,"root":root,
             "group":"rope_ladder","rects":rects}
    # Pose-based direction changes choose the closest actual recorded pose.
    masks = []
    for im, track in zip(rgba_frames,tracks):
        ex,ey = track["eye"]
        masks.append(np.asarray(im.getchannel("A").crop((int(ex-140),int(ey-130),int(ex+260),int(ey+290))).resize((100,105)))>100)
    def nearest(a, candidates):
        def score(b):
            inter = (masks[a]&masks[b]).sum();union = max(1,(masks[a]|masks[b]).sum())
            return 1-inter/union
        return min(candidates,key=score)
    audit = {"source":str(Path(sys.argv[1]).name),"frames":len(paths),"fps":24,
             "scale":scale,"root_source":[384,365],"tracks":tracks,"minimum_canvas_margin":min(margins),
             "segments":{"mount":[10,42],"down":[42,67],"hold":[78,90],"jump":[91,119],
                         "catch":[128,159],"up":[159,183],"exit":[194,234]},
             "down_cycles":1,"up_cycles":1,
             "up_from_down":[nearest(i,range(159,184)) for i in range(42,68)],
             "down_from_up":[nearest(i,range(42,68)) for i in range(159,184)]}
    # Runtime tracks remain in SOURCE coordinates; keep the only calibration here.
    gd = "extends RefCounted\n\nconst DATA := "+json.dumps(audit,separators=(",",":"))+"\n"
    (PROJECT/"scripts/actors/rope_ladder_manifest.gd").write_text(gd)
    (AUDIT/"audit.json").write_text(json.dumps(audit,indent=2))
    text = MANIFEST.read_text()
    clips = json.loads(re.search(r"^const CLIPS := (\{.*\})$",text,re.M).group(1))
    groups = json.loads(re.search(r"^const GROUPS := (\{.*\})$",text,re.M).group(1))
    clips["rope_ladder"] = entry;groups["rope_ladder"] = ["rope_ladder"]
    text = re.sub(r"^const CLIPS := .*$",lambda _:"const CLIPS := "+json.dumps(clips,separators=(",",":")),text,flags=re.M)
    text = re.sub(r"^const GROUPS := .*$",lambda _:"const GROUPS := "+json.dumps(groups),text,flags=re.M)
    MANIFEST.write_text(text)
    print(f"Packaged {len(paths)} consecutive frames, shared scale={scale:.6f}, visible standing height={target_height}px, margin={min(margins)}px")


if __name__ == "__main__":
    main()
