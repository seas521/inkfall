#!/usr/bin/env python3
"""Build an isolated two-source preview, never updates game actor resources."""
from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy import ndimage as ndi
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'artifacts/heavy-mime-combined-preview'
N=384;SOLE=350
tracked={tag:json.loads((OUT/(tag+'-tracking.json')).read_text()) for tag in ['2488','3968']}
clips={};anchors={};eyes={}
for tag in tracked:
 files=sorted((OUT/(tag+'-extracted')).glob('f-*.png'))
 base=np.array(Image.open(files[0]))[...,3];ys,xs=np.where(base>128);factor=210/(ys.max()-ys.min())
 clips[tag]=[];anchors[tag]=[];eyes[tag]=[];lastx=320
 for i,p in enumerate(files):
  im=Image.open(p);a=np.array(im)[...,3];ys,xs=np.where(a>128);floor=np.percentile(ys,99.95)
  eyex,eyey=tracked[tag][i]['eye'];yy,xx=np.indices(a.shape)
  band=(a>128)&(yy>floor-150)&(yy<floor-90)&(xx>eyex+12)
  bx=np.where(band)[1];hip=np.median(bx) if len(bx)>15 else lastx;lastx=hip
  tx=192-factor*hip;ty=SOLE-factor*floor
  # Keep the source character pixels and full head. Only register the root.
  norm=im.transform((N,N),Image.Transform.AFFINE,(1/factor,0,-tx/factor,0,1/factor,-ty/factor),Image.Resampling.BICUBIC)
  clips[tag].append(norm)
  circle=tracked[tag][i]['circle'];anchors[tag].append([circle[0]*factor+tx,circle[1]*factor+ty] if circle else None)
  eyes[tag].append([eyex*factor+tx,eyey*factor+ty])
# Match released-arm poses; 3968 is used only after the unwanted sphere has
# left the hands, so its difficult dark spherical outline never enters export.
best=None
for a in range(99,119):
 for b in range(101,119):
  aa=np.array(clips['2488'][a])[...,3]>128;bb=np.array(clips['3968'][b])[...,3]>128
  yy,xx=np.indices(aa.shape);region=yy<305
  loss=np.logical_xor(aa&region,bb&region).sum()/max(1,np.logical_or(aa&region,bb&region).sum())
  loss+=np.linalg.norm(np.array(eyes['2488'][a])-eyes['3968'][b])*.01
  if best is None or loss<best[0]:best=(float(loss),a,b)
_,a,b=best
sequence=[('2488',i) for i in range(a+1)]+[('3968',i) for i in range(b+1,121)]
(OUT/'alpha').mkdir(exist_ok=True);(OUT/'preview').mkdir(exist_ok=True)
for j,(tag,i) in enumerate(sequence):
 body=clips[tag][i];body.save(OUT/'alpha'/f'f-{j:03}.png')
 frame=Image.new('RGB',(1152,420),(64,64,64));d=ImageDraw.Draw(frame)
 center=anchors[tag][i]
 for k,label in enumerate(['EXTRACTED ACTOR','SAME ACTOR + ROCK','SAME ACTOR + CRATE']):
  tile=Image.new('RGBA',(384,384),(83,83,83,255));td=ImageDraw.Draw(tile)
  if k and center:
   x,y=center
   if k==1:
    pts=[(-38,-15),(-29,-31),(-2,-36),(24,-28),(37,-5),(28,25),(4,34),(-28,27)]
    td.polygon([(x+u,y+v) for u,v in pts],fill=(3,3,3,255))
   else:
    td.rounded_rectangle((x-35,y-31,x+35,y+31),radius=2,fill=(3,3,3,255))
  tile.alpha_composite(body);frame.paste(tile.convert('RGB'),(k*384,30));d.text((k*384+12,9),label,fill='white')
 d.text((12,402),f'Preview only  |  {j/24:.2f}s  |  source {tag} / {i}',fill='white')
 frame.save(OUT/'preview'/f'f-{j:03}.png')
report={'fps':24,'frames':len(sequence),'duration':len(sequence)/24,'transition':{'2488_last':a,'3968_first':b+1,'pose_cost':best[0]},'game_assets_modified':False,'notes':['The dark 3968 sphere cannot be cleanly keyed without a residual rim; do not use those carrying frames.','2488 supplies pickup/hold/walk/release; 3968 supplies the closest matching empty-hand recovery.','This is an isolated feasibility preview, with source occlusions retained rather than invented body parts.']}
(OUT/'combination-report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
# Selected frames, without requiring video playback.
sel=[12,28,44,61,83,min(101,len(sequence)-1)]
sheet=Image.new('RGB',(1152,6*210))
for n,j in enumerate(sel):
 im=Image.open(OUT/'preview'/f'f-{j:03}.png');im=im.resize((576,210));sheet.paste(im,((n%2)*576,(n//2)*210))
sheet=sheet.crop((0,0,1152,630));sheet.save(OUT/'combined-review.png')
