#!/usr/bin/env python3
"""Package Seedance 9190 without baking its blue marker into the character.
Consumes 640px/60fps MCI frames. Body, foreground hands, item and eyes share
one registered transform; item texture stays behind the visible embracing arms.
"""
from pathlib import Path
import json, math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'artifacts/mine-heavy-hug-v1'
DST=ROOT/'assets/art/actors/hood_boy/hug'
CAN=384; ORIGIN=np.array([192.,348.]); DISPLAY=.42*.90
TARGET=np.array([39.0,31.5])/DISPLAY
OUTLINE=np.array([[-13,6],[-12,-2],[-8,-4],[-9,-7],[-2,-10],[4,-9],[6,-6],[10,-5],[13,1],[12,4],[12,7],[7,9],[3,10],[-3,8],[-8,9]],float)
files=sorted((ART/'interpolated').glob('*.png'))[:303]
assert len(files)>=301

def smooth(a,b,v):
 t=np.clip((v-a)/(b-a),0,1);return t*t*(3-2*t)
def largest(m):
 labels,n=ndi.label(m)
 if not n:return m
 count=np.bincount(labels.ravel());count[0]=0
 return labels==count.argmax()

data=[]
for i,path in enumerate(files):
 rgb=np.array(Image.open(path).convert('RGB'),np.float32)
 r,g,b=rgb.transpose(2,0,1)
 blue=largest((b-r>12)&(b-g>5)&(b>35))
 if blue.sum()<80:blue[:]=False
 eye=(r>85)&(r-g>26)&(g-b>8)
 blue_key=smooth(1,5,b-r)*smooth(1,4,b-g)*smooth(1.10,1.45,(b+1)/(r+1))*smooth(7,16,b)
 if blue.any():
  from scipy.spatial import ConvexHull
  by0,bx0=np.where(blue)
  pts=np.stack([bx0,by0],1);hull=pts[ConvexHull(pts).vertices]
  region=Image.new('L',(rgb.shape[1],rgb.shape[0]));ImageDraw.Draw(region).polygon([tuple(v) for v in hull],fill=255)
  blue_key*=ndi.binary_dilation(np.array(region)>0,iterations=5)
 else:blue_key[:]=0
 body=((1-smooth(20,64,g-np.maximum(r,b)))*(1-blue_key))
 body*=1-smooth(65,105,np.max(rgb,axis=2))
 body=np.maximum(body,eye.astype(float))
 solid=body>.50
 lab,n=ndi.label(solid)
 if n:
  counts=np.bincount(lab.ravel());counts[0]=0;main=counts.argmax()
  keep=(lab==main)
  if blue.any():
   hand_region=ndi.binary_dilation(blue,iterations=12)&ndi.binary_dilation(keep,iterations=14)
   for component in range(1,n+1):
    if component!=main and counts[component]>=5 and np.any((lab==component)&hand_region):keep|=(lab==component)
  near=ndi.binary_dilation(keep,iterations=2);body*=near
  body=ndi.gaussian_filter(ndi.binary_closing(body>.42).astype(float),.42)
 solid=body>.5
 yy,xx=np.where(solid)
 if not len(xx):raise RuntimeError(f'empty actor {i}')
 bottom=np.percentile(yy,99.95)
 grid_y,grid_x=np.indices(solid.shape)
 by,bx=np.where(blue)
 # A dark face of the floor marker is not a foot. Keep registration on the
 # actor's planted feet behind the marker while he squats beside it.
 if len(bx) and by.max()>bottom-30:
  planted=solid&(grid_x>bx.max()+2)
  py,px=np.where(planted)
  if len(py)>30:bottom=np.percentile(py,99.9)
  feet=planted&(grid_y>bottom-25)
 else:feet=solid&(grid_y>bottom-25)
 fy,fx=np.where(feet)
 footx=float(np.median(fx))
 ey,ex=np.where(eye & ndi.binary_dilation(solid,iterations=3))
 by,bx=np.where(blue)
 data.append(dict(rgb=rgb,body=body,blue=blue,eye=eye,eye_xy=np.array([ex.mean(),ey.mean()]) if len(ex) else None,top=float(yy.min()),bottom=float(bottom),footx=footx,blue_box=np.array([bx.min(),by.min(),bx.max()+1,by.max()+1],float) if len(bx) else None))

# Normalize AI camera/scale drift; retain the actual squat and throw lean.
heights=np.array([d['bottom']-d['top'] for d in data])
raw_scales=np.zeros(len(data))
initial=200/np.median(heights[:5]);held=190/np.median(heights[78:85])
for i in range(len(data)):
 if i<85:raw_scales[i]=initial+(held-initial)*smooth(0,85,i)
 elif i<218:raw_scales[i]=190/heights[i]
 else:raw_scales[i]=(190/np.median(heights[210:219]))+(initial-190/np.median(heights[210:219]))*smooth(218,300,i)
scales=ndi.gaussian_filter1d(raw_scales,1.8)
roots=ndi.gaussian_filter1d(np.array([d['footx'] for d in data]),4)
# A planted foot must travel backwards relative to the moving torso. Pinning
# the foot centre every frame erased the stride and produced skating.
hips=[]
for d in data:
 h=d['bottom']-d['top'];y=int(d['bottom']-h*.34)
 band=d['body'][max(0,y-int(h*.018)):y+int(h*.018)]>.55
 hy,hx=np.where(band)
 if d['blue_box'] is not None:
  behind=hx>d['blue_box'][2]-8
  if behind.sum()>10:hx=hx[behind]
 hips.append(float(np.median(hx)) if len(hx) else d['footx'])
hips=ndi.gaussian_filter1d(np.array(hips),1.5)
hip_reference=(hips[90]-roots[90])*scales[90]
hip_roots=hips-hip_reference/scales
for i in range(91,241):
 weight=1.0 if i<216 else 1.0-smooth(216,240,i)
 roots[i]=roots[i]*(1-weight)+hip_roots[i]*weight
floors=ndi.gaussian_filter1d(np.array([d['bottom'] for d in data]),.6)
rock=Image.open(ROOT/'assets/art/descent/mine-cart-gap-v1/chock-natural-rock-v2.png').convert('RGB').crop((160,270,1190,950))
rock=np.array(rock.resize(tuple(np.ceil(TARGET).astype(int)),Image.Resampling.LANCZOS)).astype(float).mean(2)
rock_rgb=np.ones((*rock.shape,3),np.uint8) # same near-black ink as the actor; no baked gray light
frames=[];preview=[]
for i,d in enumerate(data):
 s=scales[i];rx=roots[i];floor=floors[i]
 transform=(1/s,0,rx-ORIGIN[0]/s,0,1/s,floor-ORIGIN[1]/s)
 alpha=np.array(Image.fromarray(np.uint8(np.clip(d['body'],0,1)*255)).transform((CAN,CAN),Image.Transform.AFFINE,transform,Image.Resampling.BICUBIC))
 # Pure black silhouettes; source amber is only a landmark for the shared eye.
 rgba=np.zeros((CAN,CAN,4),np.uint8);rgba[...,0:3]=1;rgba[...,3]=alpha
 eye_point=(d['eye_xy']-np.array([rx,floor]))*s if d['eye_xy'] is not None else np.array([0.,-150.])
 # The source blue marker physically occludes the lower face. Keying it
 # leaves its square boundary in the actor alpha; a smaller rigid stone
 # exposes that boundary. Restore only this occluded jaw, without deleting
 # any actor pixels, replacing the head, or changing the held stone.
 if d['eye_xy'] is not None and d['blue_box'] is not None:
  marker_top=(d['blue_box'][1]-floor)*s
  if marker_top<eye_point[1]+38:
   face=Image.new('RGBA',(CAN,CAN))
   jaw=[(-12,5),(-12,14),(-10,21),(-6,26),(0,30),(7,31),(13,27),(14,5)]
   e=eye_point+ORIGIN
   ImageDraw.Draw(face).polygon([(float(e[0]+x),float(e[1]+y)) for x,y in jaw],fill=(1,1,1,255))
   rgba=np.array(Image.alpha_composite(face,Image.fromarray(rgba)))
 if d['eye_xy'] is not None:
  eye_img=Image.new('RGBA',(CAN,CAN));ed=ImageDraw.Draw(eye_img)
  ep=eye_point+ORIGIN;ed.ellipse((ep[0]-2,ep[1]-3,ep[0]+2,ep[1]+3),fill=(255,125,16,255))
  aimg=Image.alpha_composite(Image.fromarray(rgba),eye_img)
 else:aimg=Image.fromarray(rgba)
 item=Image.new('RGBA',(CAN,CAN));center=None;item_size=TARGET.copy()
 if d['blue_box'] is not None and i<241:
  old=d['blue_box'];p0=(old[:2]-[rx,floor])*s+ORIGIN;p1=(old[2:]-[rx,floor])*s+ORIGIN
  # Grow the free outer/lower volume while retaining the chest contact face.
  extra=np.maximum(0,TARGET-(p1-p0))
  y0=p0[1]-extra[1]*.22
  if d['eye_xy'] is not None and i<233:y0=max(y0,eye_point[1]+ORIGIN[1]+12)
  y0=min(y0,ORIGIN[1]-TARGET[1]+3)
  pos=np.array([p1[0]-TARGET[0],y0])
  shape=((OUTLINE+[13,11])/[26,21])*TARGET+pos
  mask=Image.new('L',(CAN,CAN));ImageDraw.Draw(mask).polygon([tuple(v) for v in shape],fill=255)
  # Fill the original marker's occlusion so there is never a torso/hand gap.
  marker=Image.fromarray(np.uint8(d['blue'])*255).transform((CAN,CAN),Image.Transform.AFFINE,transform,Image.Resampling.BICUBIC)
  union=np.maximum(np.array(mask),np.array(marker))
  texture=Image.fromarray(np.dstack([rock_rgb,np.full(rock.shape,255,np.uint8)]))
  item.paste(texture,(int(round(pos[0])),int(round(pos[1]))))
  # Where the marker exceeds the fractured outline, retain rock, never blue.
  ia=np.array(item);missing=(union>0)&(ia[...,3]==0);ia[missing,:3]=np.uint8(rock_rgb.mean((0,1)))
  ia[...,3]=union;item=Image.fromarray(ia)
  center=pos+TARGET*.5-ORIGIN
 frames.append(dict(body=aimg,item=item,center=center,eye=[round(float(eye_point[0]),3),round(float(eye_point[1]),3),0,1 if d['eye_xy'] is not None else 0]))

# Match a genuine full gait cycle, including the held volume and lower legs.
def loop_cost(a,b):
 aa=np.array(frames[a]['body'])[245:,:,3]>.5;bb=np.array(frames[b]['body'])[245:,:,3]>.5
 v=np.logical_xor(aa,bb).sum()/max(1,np.logical_or(aa,bb).sum())
 ca,cb=frames[a]['center'],frames[b]['center']
 return v+np.linalg.norm(ca-cb)*.008
best=min((loop_cost(a,b),a,b) for a in range(100,154,2) for b in range(a+43,min(217,a+88),2))
print('HUG LOOP',best,flush=True)
_,walk_start,walk_end=best
clips={
 'hug_pickup':list(range(10,91)),
 'hug_hold':[90],
 'hug_walk':list(range(walk_start,walk_end)),
 'hug_walk_enter':list(range(91,walk_start)),
 'hug_throw_charge':list(range(216,233)),
 'hug_throw_release':list(range(233,255)),
 'hug_recover':list(range(255,301)),
}
result={}
for name,indices in clips.items():
 dst=DST/name;dst.mkdir(parents=True,exist_ok=True)
 info={'frames':len(indices),'fps':60.,'root':[192.,348.],'canvas':CAN,'loop':name in ['hug_hold','hug_walk'],'group':'hug','rects':[],'item_rects':[],'hold_points':[],'source_frames':indices}
 eyes=[];soles=[]
 for j,index in enumerate(indices):
  f=frames[index];body=f['body'];item=f['item']
  rect=body.getbbox();rect=(max(0,rect[0]-5),max(0,rect[1]-5),min(CAN,rect[2]+5),min(CAN,rect[3]+5))
  body.crop(rect).save(dst/f'f_{j:03}.png')
  info['rects'].append([rect[0],rect[1],rect[2]-rect[0],rect[3]-rect[1]])
  ir=item.getbbox() or (0,0,1,1)
  item.crop(ir).save(dst/f'item_{j:03}.png')
  info['item_rects'].append([ir[0],ir[1],ir[2]-ir[0],ir[3]-ir[1]])
  info['hold_points'].append([round(float(v),4) for v in (f['center'] if f['center'] is not None else [0,-95])])
  eyes.append(f['eye'])
  alpha=np.array(body.crop(rect))[...,3];yy,xx=np.where(alpha>0);points=[]
  for x in range(int(xx.min()),int(xx.max())+1,3):
   for y in range(int(yy.max()),max(int(yy.min()),int(yy.max())-12)-1,-1):
    if alpha[y,x]>153:points.extend([x+.5,y+1.]);break
  soles.append(points)
 if name=='hug_pickup':info['grasp_frame']=50
 if name=='hug_throw_release':info['release_frame']=7
 result[name]={'info':info,'eyes':eyes,'soles':soles}
 print('PACKED',name,len(indices),flush=True)
(ART/'hug-pack.json').write_text(json.dumps(result,separators=(',',':')))
(ART/'registration.json').write_text(json.dumps({'scales':[round(float(v),5) for v in scales],'roots':[round(float(v),2) for v in roots],'loop':best,'heights':[round(float((d['bottom']-d['top'])*scales[i]),2) for i,d in enumerate(data)]},indent=2))
# Review on a neutral background; source markers must be completely gone.
selected=[10,30,50,60,75,83,110,140,170,210,230,236,242,260,285]
sheet=Image.new('RGB',(5*256,3*256),(76,76,76));draw=ImageDraw.Draw(sheet)
for k,i in enumerate(selected):
 merged=Image.new('RGBA',(CAN,CAN),(76,76,76,255));merged=Image.alpha_composite(merged,frames[i]['item']);merged=Image.alpha_composite(merged,frames[i]['body'])
 sheet.paste(merged.resize((256,256),Image.Resampling.LANCZOS).convert('RGB'),((k%5)*256,(k//5)*256))
 draw.text(((k%5)*256+6,(k//5)*256+5),str(i),fill='white')
sheet.save(ART/'processed-contact-sheet.png')
