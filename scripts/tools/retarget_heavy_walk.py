#!/usr/bin/env python3
"""Keep the hugging torso, reuse the existing actual load-bearing leg cycle.
Returns calibrated ground distance; all processing is offline, not per frame.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

DISPLAY=.42*.90

def full_frame(root,group,name,index,rect):
 im=Image.open(root/f'assets/art/actors/hood_boy/{group}/{name}/f_{index:03}.png').convert('RGBA')
 out=Image.new('RGBA',(384,384));out.paste(im,(rect[0],rect[1]));return out

def sole(alpha):
 y,x=np.where(alpha>0);out=[]
 if not len(x):return out
 for col in range(int(x.min()),int(x.max())+1,3):
  for row in range(int(y.max()),max(int(y.min()),int(y.max())-12)-1,-1):
   if alpha[row,col]>153:out.extend([col+.5,row+1.]);break
 return out

def contacts(alpha):
 y,x=np.where(alpha>153)
 if not len(x):return []
 m=alpha>153;m[:max(0,int(y.max())-3)]=False
 lab,n=ndi.label(m);out=[]
 for k in range(1,n+1):
  yy,xx=np.where(lab==k)
  if len(xx)>5:out.append((float(np.median(xx)-192),len(xx)))
 return out

def calibrate(points):
 # Follow each planted foot through its support interval. New landings are
 # new tracks; they must not be mistaken for a backwards jump of one foot.
 tracks=[];active=[]
 for frame,items in enumerate(points):
  pool=list(items);live=[]
  for track in active:
   prediction=track[-1][1]
   if len(track)>2:prediction+=np.median(np.diff([p[1] for p in track[-4:]]))
   if not pool:continue
   best=min(range(len(pool)),key=lambda k:abs(pool[k][0]-prediction))
   if abs(pool[best][0]-prediction)<6:
    x,n=pool.pop(best);track.append((frame,x,n));live.append(track)
  for x,n in pool:
   track=[(frame,x,n)];tracks.append(track);live.append(track)
  active=live
 runs=[]
 for track in tracks:
  if len(track)<7:continue
  a=np.array(track,float);x=a[:,0];y=a[:,1]
  slope,intercept=np.polyfit(x,y,1)
  err=np.mean((y-(slope*x+intercept))**2)
  variance=np.var(y)
  if slope>.12 and variance>1 and err/variance<.45:
   runs.append(dict(start=int(x[0]),end=int(x[-1]),slope=float(slope),length=len(track),r2=float(1-err/variance)))
 if not runs:raise RuntimeError('no real supporting-foot backstroke found')
 # The longest complete support phase is least biased by heel/toe contact.
 ordered=sorted(runs,key=lambda r:r['length'],reverse=True)
 chosen=ordered[:2]
 speed=float(np.average([r['slope'] for r in chosen],weights=[r['length'] for r in chosen]))*60*DISPLAY
 speed=float(np.clip(speed,20,42))
 return speed,runs

def apply(root:Path,pack:dict):
 old=json.loads((root/'artifacts/mine-cart-gap-v1/heavy-pack.json').read_text())['big_walk']['info']
 original=[]
 for i in range(int(old['frames'])-1):
  a=np.array(full_frame(root,'heavy','big_walk',i,old['rects'][i]))[...,3]
  # The skirt hides the join. Only replace the bare lower limbs.
  a[:299]=0
  im=Image.fromarray(a).transform((384,384),Image.Transform.AFFINE,(1,0,0,0,1.10,348-348*1.10),Image.Resampling.BICUBIC)
  mask=np.array(im)>110
  original.append(ndi.distance_transform_edt(mask)-ndi.distance_transform_edt(~mask))
 cycle=pack['hug_walk']['info']['frames'];points=[];entry_points=[]
 for name in ['hug_walk','hug_walk_enter']:
  e=pack[name];info=e['info'];new_rects=[];new_soles=[]
  for i,r in enumerate(info['rects']):
   body=np.array(full_frame(root,'hug',name,i,r));native=body[...,3].copy()
   # Entry starts at the previous half-step, then hands over to loop frame 0.
   phase=(i/cycle*len(original)) if name=='hug_walk' else (len(original)*.5+(i+1)/info['frames']*len(original)*.5)
   a=int(np.floor(phase))%len(original);b=(a+1)%len(original);t=phase-np.floor(phase)
   field=original[a]*(1-t)+original[b]*t
   legs=np.clip((field+.7)/1.4,0,1)*255
   y=np.indices(native.shape)[0]
   keep=np.clip((310-y)/8.,0,1)
   alpha=np.maximum(native*keep,legs).astype(np.uint8)
   body[...,3]=alpha
   # Preserve source torso/eye colors; only newly retargeted legs need ink.
   body[(alpha>0)&((native==0)|(y>=310)),:3]=1
   yy,xx=np.where(alpha>0);crop=(max(0,int(xx.min())-5),max(0,int(yy.min())-5),min(384,int(xx.max())+6),min(384,int(yy.max())+6))
   Image.fromarray(body).crop(crop).save(root/f'assets/art/actors/hood_boy/hug/{name}/f_{i:03}.png')
   new_rects.append([crop[0],crop[1],crop[2]-crop[0],crop[3]-crop[1]])
   new_soles.append(sole(alpha[crop[1]:crop[3],crop[0]:crop[2]]))
   if name=='hug_walk':points.append(contacts(alpha))
   else:entry_points.append(contacts(alpha))
  info['rects']=new_rects;e['soles']=new_soles
 speed,runs=calibrate(points)
 distance=speed*cycle/60.
 pack['hug_walk']['info'].update(walk_speed=speed,travel_distance=distance,ground_contacts=points)
 entry_travel=0.;anchor=None
 for group in entry_points:
  if not group:continue
  if anchor is None:anchor=max(group,key=lambda p:p[1])[0];continue
  x,n=min(group,key=lambda p:abs(p[0]-anchor))
  if abs(x-anchor)<10:entry_travel+=max(0,x-anchor)*DISPLAY
  anchor=x
 pack['hug_walk_enter']['info'].update(travel_distance=max(3.5,entry_travel))
 report={'walk_speed':speed,'cycle_distance':distance,'cycle_frames':cycle,'support_phases':runs,'ground_contacts':points}
 out=root/'artifacts/mine-heavy-walk-v2';out.mkdir(exist_ok=True)
 (out/'gait-calibration.json').write_text(json.dumps(report,indent=2)+'\n')
 print('HEAVY GAIT calibrated:',round(speed,2),'world px/s;',round(distance,2),'px per cycle',flush=True)
 return pack

if __name__=='__main__':
 root=Path(__file__).resolve().parents[2]
 p=root/'artifacts/mine-heavy-hug-v1/hug-pack.json';data=json.loads(p.read_text())
 data=apply(root,data);p.write_text(json.dumps(data,separators=(',',':')))
