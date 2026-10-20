"""Key the supplied sheet without repainting or per-pose rescaling."""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path('/var/folders/td/45r5thg13cd2j_v235nfw9xh0000gp/T/codex-clipboard-b2f3dffc-ae11-4f3f-aea5-493af5dc4bdc.png')
output = ROOT / 'assets/art/c_zone_debug/drown_v1'
output.mkdir(parents=True, exist_ok=True)
sheet = Image.open(SOURCE).convert('RGB')
assert sheet.size == (1024,1024)
scale = .69
for i in range(8):
    x, y = i % 3, i // 3
    cell = sheet.crop((round(x*1024/3), round(y*1024/3), round((x+1)*1024/3), round((y+1)*1024/3)))
    rgb = np.asarray(cell, dtype=np.float32) / 255
    green = rgb[:,:,1] - np.maximum(rgb[:,:,0],rgb[:,:,2])
    alpha = 1-np.clip((green-.03)/.30,0,1)
    orange = (rgb[:,:,0]>rgb[:,:,1]*1.15) & (rgb[:,:,0]>.35)
    ink = np.broadcast_to(np.array([.004,.006,.006]),rgb.shape).copy()
    ink[orange] = rgb[orange]
    rgba = Image.fromarray(np.uint8(np.clip(np.dstack([ink,alpha])*255,0,255)))
    frame = rgba.transform((256,256),Image.Transform.AFFINE,
                           (1/scale,0,170-128/scale,0,1/scale,290-232/scale),
                           resample=Image.Resampling.BICUBIC)
    bounds = frame.getbbox()
    assert bounds and min(bounds[:2])>=3 and max(bounds[2:])<253,(i,bounds)
    frame.save(output/f'frame_{i:02d}.png')
print('PASS: 8 keyed full frames; one scale/root; back-facing ninth frame excluded')
