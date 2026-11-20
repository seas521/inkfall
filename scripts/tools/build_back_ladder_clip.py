#!/usr/bin/env python3
"""Import the blue-ladder master with one scale, native timing and separate tracks.

Only the new back_ladder group is changed. The forest's side-view rope ladder
and all existing clips remain intact. Frames stream through memory one at a
time; source pixels are keyed, never inpainted or reshaped.
"""
import argparse
import json
import re
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PROJECT = Path(__file__).resolve().parents[2]


def table(path, name):
    text = path.read_text()
    return text, json.loads(re.search(r'^const ' + name + r' := (.*)$', text, re.M)[1])


def replace_table(text, name, value):
    return re.sub(r'^const ' + name + r' := .*$',
                  lambda _: 'const ' + name + ' := ' + json.dumps(value, separators=(',', ':')),
                  text, flags=re.M)


def smoothstep(lo, hi, value):
    t = np.clip((value-lo)/(hi-lo), 0, 1)
    return t*t*(3-2*t)


def key_frame(rgb):
    r, g, b = rgb.astype(np.float32).transpose(2, 0, 1)/255
    # Both auxiliary colors are brighter/chromatic; retain the balanced
    # dark silhouette and its partial coverage along both screen colors.
    value = np.maximum.reduce([r, g, b])
    alpha = 1-smoothstep(.10, .29, value)
    blue = smoothstep(.035, .16, np.minimum(b-r, b-g))
    green = smoothstep(.045, .20, g-np.maximum(r, b))
    alpha *= (1-blue)*(1-green)
    orange = (r>.25)&(r>g*1.15)&(g>b*1.35)&(r>b+.13)
    alpha[orange] = 1
    labels, count = ndimage.label(alpha>.5)
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    if count == 0:
        raise ValueError('No character in source frame')
    main = labels == sizes.argmax()
    keep = ndimage.binary_dilation(main, iterations=3)
    alpha *= keep
    yy, xx = np.where(main)
    top, bottom = int(yy.min()), int(yy.max())
    foot_band = yy >= bottom-4
    feet = [float(np.median(xx[foot_band])), float(bottom)]
    torso = main.copy()
    torso[:round(top+(bottom-top)*.40)] = False
    torso[round(top+(bottom-top)*.67):] = False
    ty, tx = np.where(torso)
    center = [float(np.median(tx)), float(np.median(ty))]
    eye_mask = orange & keep
    ey, ex = np.where(eye_mask)
    eye = [float(ex.mean()), float(ey.mean())] if len(ex)>3 else None
    rgba = np.empty((*alpha.shape, 4), dtype=np.uint8)
    rgba[:, :, :3] = [1, 2, 2]
    rgba[:, :, :3][eye_mask] = rgb[eye_mask]
    rgba[:, :, 3] = np.uint8(np.clip(alpha, 0, 1)*255)
    return Image.fromarray(rgba), {'feet': feet, 'torso': center, 'top': top,
                                   'height': bottom-top+1, 'eye': eye}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('video', type=Path)
    parser.add_argument('--stabilize-scale', action='store_true', help='undo smooth source scale drift measured from the two matching standing poses')
    args = parser.parse_args()
    audit = PROJECT/'artifacts/back-ladder-3155-review'
    out = PROJECT/'assets/art/actors/hood_boy/back_ladder/back_ladder'
    audit.mkdir(parents=True, exist_ok=True); out.mkdir(parents=True, exist_ok=True)
    (audit/'.gdignore').touch()
    end_correction = 1.0
    if args.stabilize_scale:
        prior = json.loads((audit/'audit.json').read_text())
        (audit/'raw-key-audit.json').write_text(json.dumps(prior, indent=2))
        initial = np.median([t['height'] for t in prior['tracks'] if t['source_time']<=.4])
        final = np.median([t['height'] for t in prior['tracks'] if t['source_time']>=9.2])
        end_correction = float(initial/final)
    probe = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
        'stream=width,height,avg_frame_rate,duration', '-of', 'json', str(args.video)]))['streams'][0]
    width, height = probe['width'], probe['height']
    timestamps = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_frames',
        '-show_entries', 'frame=best_effort_timestamp_time', '-of', 'json', str(args.video)]))['frames']
    source_times = [float(f['best_effort_timestamp_time']) for f in timestamps]
    # Seedance advertises 60 fps while carrying 24 native images per second.
    # Measure actual decoded-frame timestamps rather than that container tag.
    fps = round((len(source_times)-1)/(source_times[-1]-source_times[0]), 6)
    process = subprocess.Popen(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-i',
                                str(args.video), '-an', '-f', 'rawvideo', '-pix_fmt',
                                'rgb24', '-fps_mode', 'passthrough', '-'], stdout=subprocess.PIPE)
    target = Image.open(PROJECT/'assets/art/actors/hood_boy/core/idle_left/f_000.png').getchannel('A').getbbox()
    target_height = target[3]-target[1]
    root = np.array([320., 580.]); scale = None; source_root = None
    rects, tracks, eyes, index, margins = [], [], [], 0, []
    while True:
        data = process.stdout.read(width*height*3)
        if not data:
            break
        if len(data) != width*height*3:
            raise ValueError('Truncated decoded frame')
        rgb = np.frombuffer(data, np.uint8).reshape(height, width, 3)
        image, track = key_frame(rgb)
        track['source_time'] = source_times[index]
        if scale is None:
            scale = target_height/track['height']
            source_root = np.array(track['feet'])
        # One smooth isotropic camera correction, calibrated only from
        # matching standing poses. Never fit a new scale to each bent pose.
        phase = float(smoothstep(0., 9.2, track['source_time']))
        applied_scale = scale*(1+(end_correction-1)*phase)
        track['applied_scale'] = applied_scale
        scaled = image.resize((round(width*applied_scale), round(height*applied_scale)), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (640, 640))
        offset = tuple(np.rint(root-source_root*applied_scale).astype(int))
        canvas.paste(scaled, offset)
        values = np.asarray(canvas).copy(); values[:, :, 3][values[:, :, 3]<3] = 0
        canvas = Image.fromarray(values)
        box = canvas.getchannel('A').getbbox()
        margins.append(min(box[0], box[1], 640-box[2], 640-box[3]))
        crop = (box[0]-5, box[1]-5, box[2]+5, box[3]+5)
        canvas.crop(crop).save(out/f'f_{index:03d}.png')
        rects.append([crop[0], crop[1], crop[2]-crop[0], crop[3]-crop[1]])
        tracks.append(track)
        if track['eye'] is None:
            eyes.append([0., 0., 0., 0.])
        else:
            point = (np.array(track['eye'])-source_root)*applied_scale
            eyes.append([round(float(point[0]), 4), round(float(point[1]), 4), 0., 1.])
        if index % 120 == 0:
            print(f'Processed {index} native frames', flush=True)
        index += 1
    if process.wait() != 0:
        raise RuntimeError('Video decoding failed')
    assert min(margins)>5, 'Character clipped by the actor canvas'
    assert len(tracks)==len(source_times), 'Missing native decoded frames'
    segment_times = {'turn_in':[.4,1.5], 'mount':[1.5,2.25], 'up':[2.25,6.5],
                     'exit_top':[6.5,8.25], 'turn_out':[8.25,9.2], 'stand':[9.2,source_times[-1]]}
    segments = {key:[round(a*fps),min(index-1,round(b*fps))] for key,(a,b) in segment_times.items()}
    entry = {'frames':index, 'fps':fps, 'loop':False, 'canvas':640,
             'root':root.tolist(), 'group':'back_ladder', 'rects':rects}
    manifest = PROJECT/'scripts/actors/hood_actor_manifest.gd'
    text, clips = table(manifest, 'CLIPS'); _, groups = table(manifest, 'GROUPS')
    clips['back_ladder'] = entry; groups['back_ladder'] = ['back_ladder']
    manifest.write_text(replace_table(replace_table(text, 'CLIPS', clips), 'GROUPS', groups))
    eye_file = PROJECT/'scripts/actors/hood_eye_tracks.gd'
    text, eye_data = table(eye_file, 'DATA'); eye_data['back_ladder'] = eyes
    eye_file.write_text(replace_table(text, 'DATA', eye_data))
    report = {'source':str(args.video), 'fps':fps, 'frames':index, 'scale':scale,
              'source_root':source_root.tolist(), 'root':root.tolist(),
              'target_standing_height':target_height, 'minimum_margin':min(margins),
              'segments':segments, 'tracks':tracks,
              'source_end_scale_correction':end_correction,
              'scale_mode':'fixed actor scale; smooth isotropic source camera correction from matching standing poses; no limb or face deformation'}
    (audit/'audit.json').write_text(json.dumps(report, indent=2))
    (PROJECT/'scripts/actors/back_ladder_manifest.gd').write_text(
        'extends RefCounted\n\nconst DATA := '+json.dumps(report, separators=(',', ':'))+'\n')
    print(f'Imported {index} frames @ {fps:g}, scale={scale:.6f}, margin={min(margins)}', flush=True)


if __name__ == '__main__':
    main()
