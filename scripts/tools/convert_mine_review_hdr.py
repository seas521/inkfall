"""Convert native HDR screenshot readback to display PNG, before quantization.
No art grading, gamma look, exposure, resizing or enhancement is applied.
"""
from pathlib import Path
import json, sys, numpy as np
from PIL import Image
folder=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[2]/'artifacts/mine-pair-volume-v1/main-entry'
for path in folder.glob('*.linear'):
 meta=json.loads(path.with_suffix('.json').read_text());w,h=meta['size']
 # Godot Image FORMAT_RGBF/RGBAF/RGBH/RGBAH enum values.
 formats={10:('<f4',3),11:('<f4',4),14:('<f2',3),15:('<f2',4)}
 assert meta['format'] in formats,meta
 dtype,channels=formats[meta['format']]
 raw=np.fromfile(path,dtype=dtype).reshape(h,w,channels).astype(np.float32)
 rgb=np.clip(raw[:,:,:3],0,1)
 display=np.where(rgb<=.0031308,12.92*rgb,1.055*np.power(rgb,1/2.4)-.055)
 im=Image.fromarray(np.rint(display*255).astype(np.uint8),'RGB');im.save(path.with_suffix('.png'))
 im.thumbnail((1280,720),Image.Resampling.LANCZOS);im.save(path.with_name(path.stem+'-preview.png'))
 print('HDR readback converted:',path.stem,w,h)
