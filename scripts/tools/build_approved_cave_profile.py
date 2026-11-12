"""Measure the approved transparent wall's solid edge; do not alter its pixels."""
from pathlib import Path
import numpy as np,json
from scipy.ndimage import uniform_filter1d, median_filter
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'assets/art/rock-crevice/approved-wall-layer.png'
a=np.asarray(Image.open(p).convert('RGBA'))
solid=(a[:,:,3]>220)&(a[:,:,:3].max(axis=2)<28)
wide=uniform_filter1d(solid.astype(float),size=15,axis=1)>.72
bottom=[]
for x in range(a.shape[1]):
 ys=np.flatnonzero(wide[:,x]);bottom.append(float(ys[-1]) if len(ys) else 780.)
bottom=median_filter(np.asarray(bottom),size=19)
# Thin dangling roots/foliage remain in the RGBA layer, not in the roof datum.
for x in range(930,a.shape[1]):
 ys=np.flatnonzero(wide[:,x])
 if len(ys):
  gaps=np.where(np.diff(ys)>3)[0]
  if len(gaps):
   groups=np.split(ys,gaps+1);big=max(groups,key=len);bottom[x]=big[-1]
data={'width':a.shape[1],'height':a.shape[0],'bottom':[round(float(bottom[min(int(x),len(bottom)-1)]),2) for x in np.linspace(0,a.shape[1]-1,256)]}
(ROOT/'scripts/chapters/approved_cave_profile.gd').write_text('extends RefCounted\nconst DATA='+json.dumps(data,separators=(',',':'))+'\n')
(ROOT/'assets/art/rock-crevice/approved-wall-profile.json').write_text(json.dumps(data,indent=2)+'\n')
print('profile',data['width'],data['height'],'samples',[(x,round(float(bottom[x]),1)) for x in [800,900,1000,1200,1400,1600]])
