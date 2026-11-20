#!/usr/bin/env python3
"""Offline extraction experiment; does not touch runtime sprites or manifests."""
from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/heavy-mime-combined-preview'
def smooth(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def largest(m):
 lab,n=ndi.label(m)
 if not n:return m
 count=np.bincount(lab.ravel());count[0]=0
 return lab==count.argmax()
def run(tag):
 dst=OUT/(tag+'-extracted');dst.mkdir(exist_ok=True)
 reports=[];last=None
 for i,p in enumerate(sorted((OUT/tag).glob('f-*.png'))):
  rgb=np.array(Image.open(p).convert('RGB'),dtype=float);r,g,b=rgb.transpose(2,0,1)
  fg=1-smooth(18,65,g-np.maximum(r,b))
  eye=(r>85)&(r-g>28)&(g-b>5)
  ey,ex=np.where(eye)
  ep=(float(np.median(ex)),float(np.median(ey))) if len(ex) else (320.,200.)
  yy,xx=np.indices(r.shape)
  seed=(b>r+3)&(b>g+4)&(b>18)&(fg>.6)&(xx<ep[0]+8)&(yy>ep[1]+20)
  seed=largest(ndi.binary_closing(seed,iterations=3));sy,sx=np.where(seed)
  circle=None
  if len(sx)>450:
   x0,x1=np.percentile(sx,[.5,99.5]);y0,y1=np.percentile(sy,[.5,99.5]);rad=max(x1-x0,y1-y0)*.5
   cx=(x0+x1)*.5;cy=(y0+y1)*.5
   # Seeds are shaded, with fingers cutting through the bottom half.
   rad=max(rad,46 if tag=='2488' else 60)
   circle=(float(cx),float(cy),float(rad));last=circle
  # Do not extend stale masks into the released hands.
  if circle is not None:
   cx,cy,rad=circle
   zone=((xx-cx)/(rad+4))**2+((yy-cy)/(rad+4))**2<1
   # Preserve the dark foreground fingers/forearms; remove only the
   # blue/gray body of the generated prop in the tracked spatial region.
   object_color=smooth(8,17,b)*smooth(1,5,b-np.maximum(r,g))
   fg*=1-zone*object_color
   # Gray reflections may be neutral. Their brightness still separates
   # them from the black sleeves in 2488.
   if tag=='2488':fg*=1-zone*smooth(13,23,np.maximum.reduce([r,g,b]))
  alpha=np.uint8(np.clip(fg,0,1)*255)
  solid=alpha>120;main=largest(solid);near=ndi.binary_dilation(main,iterations=4)
  # Keep small finger islands attached to the near hand, discard floaters.
  lab,n=ndi.label(solid)
  for k in range(1,n+1):
   mask=lab==k
   if 7<mask.sum()<180 and np.any(mask&ndi.binary_dilation(main,iterations=16)):near|=ndi.binary_dilation(mask,iterations=1)
  alpha*=near
  a=np.zeros((*r.shape,4),np.uint8);a[...,:3]=1;a[...,3]=alpha
  a[eye,:3]=(255,125,16)
  Image.fromarray(a).save(dst/f'f-{i:03}.png')
  reports.append({'frame':i,'eye':ep,'circle':circle})
 (OUT/(tag+'-tracking.json')).write_text(json.dumps(reports))
for tag in ['2488','3968']:run(tag)
# Quick review: source and transparent extraction side by side, flat gray
# makes residual props and accidental gaps visible instead of hiding them.
samples=[('2488',24),('2488',48),('2488',60),('3968',48),('3968',90),('3968',102)]
sheet=Image.new('RGB',(1200,3*360),(62,62,62));draw=ImageDraw.Draw(sheet)
for j,(tag,i) in enumerate(samples):
 x=j%2*600;y=j//2*360
 src=Image.open(OUT/tag/f'f-{i+1:03}.png').convert('RGBA')
 cut=Image.open(OUT/(tag+'-extracted')/f'f-{i:03}.png')
 for k,im in enumerate([src,cut]):
  im.thumbnail((300,320));sheet.paste(im,(x+k*300,y+28),im)
 draw.text((x+8,y+7),f'{tag} {i/24:.2f}s: source / alpha extraction',fill='white')
sheet.save(OUT/'extraction-diagnostic.png')
