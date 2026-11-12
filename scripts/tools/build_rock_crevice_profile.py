"""Derive the collision contour from the authored silhouette; keep source RGBA intact."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'assets/art/rock-crevice/roof-v4.png'
a=np.asarray(Image.open(source).convert('RGBA'))[:,:,3]
top=[];bottom=[]
for x in np.linspace(0,a.shape[1]-1,128):
    ys=np.flatnonzero(a[:,int(x)]>120)
    top.append(float(ys[0]) if len(ys) else 780.)
    # Keep the end masses extending below the shelter datum, into the earth.
    bottom.append(min(float(ys[-1]) if len(ys) else 700.,715.))
data=dict(top=top,bottom=bottom)
(ROOT/'scripts/chapters/rock_crevice_profile.gd').write_text('extends RefCounted\nconst DATA='+json.dumps(data,separators=(',',':'))+'\n')
(ROOT/'assets/art/rock-crevice/roof-profile.json').write_text(json.dumps(data,indent=2)+'\n')
