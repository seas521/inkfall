#!/usr/bin/env python3
"""Package two extracted mime sources; standalone rigid items stay in game code."""
from pathlib import Path
import runpy,json,importlib.util
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'artifacts/heavy-mime-integration-v2'
ns=runpy.run_path(str(ROOT/'scripts/tools/build_heavy_mime_preview.py'))
clips=ns['clips'];eyes=ns['eyes'];anchors=ns['anchors']
# The source walks in place. Register the gait to one stable waist root,
# not the moving cloak silhouette (which otherwise cancels planted-foot travel).
raw_files=sorted((ns['OUT']/'2488-extracted').glob('f-*.png'))
a0=np.array(Image.open(raw_files[0]))[...,3];yy0,xx0=np.where(a0>128);scale=210/(yy0.max()-yy0.min())
hips=[]
for i,p in enumerate(raw_files):
 a=np.array(Image.open(p))[...,3];yy,xx=np.indices(a.shape);floor=np.percentile(np.where(a>128)[0],99.95)
 ex=ns['tracked']['2488'][i]['eye'][0]
 xs=np.where((a>128)&(yy>floor-150)&(yy<floor-90)&(xx>ex+12))[1]
 hips.append(float(np.median(xs)) if len(xs)>15 else (hips[-1] if hips else 320.))
target=float(np.median(hips[35:68]))
for i in range(30,74):
 w=min(1.,max(0.,(i-30)/5),max(0.,(74-i)/7))
 dx=(hips[i]-target)*scale*w
 clips['2488'][i]=clips['2488'][i].transform((384,384),Image.Transform.AFFINE,(1,0,-dx,0,1,0),Image.Resampling.BICUBIC)
 eyes['2488'][i]=[eyes['2488'][i][0]+dx,eyes['2488'][i][1]]
 if anchors['2488'][i] is not None:anchors['2488'][i][0]+=dx
spec=importlib.util.spec_from_file_location('gait',ROOT/'scripts/tools/retarget_heavy_walk.py');gait=importlib.util.module_from_spec(spec);spec.loader.exec_module(gait)
# Only the whole connected actor is retained. Prop-colored scraps/floating
# finger-like fragments are not allowed to become part of the export.
def clean(im):
 a=np.array(im);mask=a[...,3]>60
 joined=ndi.binary_closing(mask,iterations=1)
 lab,n=ndi.label(joined);sizes=np.bincount(lab.ravel());sizes[0]=0
 main=lab==sizes.argmax();near=ndi.binary_dilation(main,iterations=1)
 a[...,3]=np.uint8(a[...,3]*near)
 return Image.fromarray(a)
for tag in clips:clips[tag]=[clean(im) for im in clips[tag]]
def array_pose(tag,i):
 im=np.array(clips[tag][i]);alpha=im[...,3]/255
 field=ndi.distance_transform_edt(alpha>.5)-ndi.distance_transform_edt(alpha<=.5)
 eye=np.array(eyes[tag][i])-np.array([192,350])
 c=anchors[tag][i]
 point=np.array(c)-[192,350] if c is not None else np.array([-55,-135.])
 return (field,eye,point,tag,i)
cache={}
def pose(tag,i):
 key=(tag,i)
 if key not in cache:cache[key]=array_pose(tag,i)
 return cache[key]
def mix(a,b,t):
 return (a[0]*(1-t)+b[0]*t,a[1]*(1-t)+b[1]*t,a[2]*(1-t)+b[2]*t,a[3],a[4]+(b[4]-a[4])*t)
def native(tag,start,end):return [pose(tag,i) for i in range(start,end+1)]
def resample(seq,frames=None):
 n=frames or round((len(seq)-1)*60/24)+1
 result=[]
 for t in np.linspace(0,len(seq)-1,n):
  lo=int(t);hi=min(len(seq)-1,lo+1);result.append(mix(seq[lo],seq[hi],t-lo))
 return result
# Select a real complete stepping cycle, not the still frames at 2.8--3.2s.
best=None
for start in range(35,43):
 for end in range(start+16,min(68,start+29)):
  a=np.array(clips['2488'][start])[290:,:,3]>128;b=np.array(clips['2488'][end])[290:,:,3]>128
  cost=np.logical_xor(a,b).sum()/max(1,np.logical_or(a,b).sum())
  cost+=np.linalg.norm(pose('2488',start)[2]-pose('2488',end)[2])*.015
  if best is None or cost<best[0]:best=(float(cost),start,end)
_,start,end=best
walk=resample(native('2488',start,end))[:-1]
# Keep native upper body and native articulated legs. No head replacement.
pickup=resample(native('2488',0,29))
hold=[pose('2488',30)]
entry=resample(native('2488',30,start))
charge=resample(native('2488',84,95))
release=resample(native('2488',95,102))
# Six continuous full-frame inbetweens bridge the empty-handed recovery;
# neither source head nor face is cut out or pasted onto another body.
bridge=[mix(pose('2488',102),pose('3968',103),t) for t in np.linspace(0,1,7)]
recover=bridge+resample(native('3968',104,120))
sequences={'hug_pickup':pickup,'hug_hold':hold,'hug_walk':walk,'hug_walk_enter':entry,'hug_throw_charge':charge,'hug_throw_release':release,'hug_recover':recover}
pack={};contact=round(14/29*(len(pickup)-1))
for name,seq in sequences.items():
 dst=ROOT/f'assets/art/actors/hood_boy/hug_mime_v2/{name}';dst.mkdir(parents=True,exist_ok=True)
 info={'frames':len(seq),'fps':60.,'root':[192.,348.],'canvas':384,'loop':name in ['hug_hold','hug_walk'],'group':'hug_mime_v2','rects':[],'hold_points':[],'source_frames':[]}
 eye_rows=[];soles=[];contacts=[]
 for i,(field,eye,point,tag,frame) in enumerate(seq):
  alpha=np.uint8(np.clip((field+.6)/1.2,0,1)*255)
  # Normalized preview root is 350, actor root is 348.
  alpha=np.roll(alpha,-2,axis=0);alpha[-2:]=0
  rgba=np.ones((384,384,4),np.uint8);rgba[...,3]=alpha
  ep=eye+np.array([192,348]);im=Image.fromarray(rgba)
  ImageDraw.Draw(im).ellipse((ep[0]-1.5,ep[1]-2.2,ep[0]+1.5,ep[1]+2.2),fill=(255,125,16,255))
  r=im.getbbox();r=(max(0,r[0]-5),max(0,r[1]-5),min(384,r[2]+5),min(384,r[3]+5))
  im.crop(r).save(dst/f'f_{i:03}.png')
  info['rects'].append([r[0],r[1],r[2]-r[0],r[3]-r[1]])
  info['hold_points'].append([round(float(x),4) for x in point]);info['source_frames'].append([tag,round(float(frame),3)])
  eye_rows.append([round(float(eye[0]),3),round(float(eye[1]),3),0.,1.])
  soles.append(gait.sole(alpha[r[1]:r[3],r[0]:r[2]]));contacts.append(gait.contacts(alpha))
 if name=='hug_pickup':info['grasp_frame']=contact
 if name=='hug_walk':
  speed,runs=gait.calibrate(contacts);info.update(walk_speed=speed,travel_distance=speed*len(seq)/60,ground_contacts=contacts)
  calibration={'speed':speed,'support_phases':runs,'loop_source':[start,end],'loop_cost':best[0]}
  # Root motion from the supporting foot: preserve the filmed gait while
  # compensating source toe/heel timing, without swapping or reshaping legs.
  points=[max(p,key=lambda v:v[1])[0] if p else 0. for p in contacts]
  offsets=[0.]
  for j in range(1,len(points)):
   delta=points[j]-points[j-1]
   offsets.append(offsets[-1]+(speed/60/.378-delta if abs(delta)<8 else 0))
  offsets=np.array(offsets);offsets-=np.linspace(0,offsets[-1],len(offsets))
  info['gait_root_offsets']=[round(float(v),4) for v in offsets]
  calibration['max_root_correction']=float(np.max(np.abs(offsets))*.378)

 pack[name]={'info':info,'eyes':eye_rows,'soles':soles}
pack['hug_walk_enter']['info']['travel_distance']=max(3.5,pack['hug_walk']['info']['walk_speed']*len(entry)/60)
# Store source-specific action events, so runtime does not retain 9190 timings.
pack['hug_throw_release']['info']['detach_frame']=round((99-95)/(102-95)*(len(release)-1))
(OUT/'mime-pack.json').write_text(json.dumps(pack,separators=(',',':')))
(OUT/'gait-calibration.json').write_text(json.dumps(calibration,indent=2))
(OUT/'events.json').write_text(json.dumps({'pickup_frames':len(pickup),'grasp_frame':contact,'charge_frames':len(charge),'release_frames':len(release),'detach_frame':pack['hug_throw_release']['info']['detach_frame'],'recover_frames':len(recover)},indent=2))
print('MIME PACK',[(k,v['info']['frames']) for k,v in pack.items()],calibration)
