"""Register native side-view stair descent; no limb warps or live resizing.

The source's slow perspective scale drift is corrected isotropically from
matching standing poses. Only camera/root travel is removed; knee and foot
motion remains native. Blue steps and green screen are not gameplay art.
"""
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from build_back_ladder_clip import PROJECT, table, replace_table, key_frame

UP='--up' in sys.argv
NAME='mine_stair_up' if UP else 'mine_stair_down'
GROUP='mine_stairs'
AUDIT=PROJECT/('artifacts/stair-ascent-1130-integration' if UP else 'artifacts/stair-descent-3285-integration')
OUT=PROJECT/f'assets/art/actors/hood_boy/{GROUP}/{NAME}'
AUDIT.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
native=sorted((PROJECT/('artifacts/stair-ascent-1130-review/native' if UP else 'artifacts/stair-descent-3285-review/native')).glob('*.png'))
assert len(native)==121,'Decode 121 native 24fps images first, without fps conversion'
manifest=PROJECT/'scripts/actors/hood_actor_manifest.gd'
text,clips=table(manifest,'CLIPS');_,groups=table(manifest,'GROUPS')
idle=clips['idle_left'];root=np.array([192.,320.])
idle_image=Image.open(PROJECT/'assets/art/actors/hood_boy/core/idle_left/f_000.png').convert('RGBA')
idle_full=Image.new('RGBA',(384,384))
idle_pos=np.array(idle['rects'][0][:2])-idle['root']+root
idle_full.paste(idle_image,tuple(idle_pos.astype(int)))
idle_array=np.asarray(idle_full)
iy,ix=np.where(idle_array[:,:,3]>153)
idle_height=iy.max()-iy.min()+1
middle=(iy>iy.min()+idle_height*.40)&(iy<iy.min()+idle_height*.67)
torso_offset=np.median(ix[middle])-root[0]

images=[];tracks=[];previous_contact=None
for i,path in enumerate(native):
 rgb=np.asarray(Image.open(path).convert('RGB'))
 image,track=key_frame(rgb)
 rgba=np.asarray(image);mask=rgba[:,:,3]>153
 blue=(rgb[:,:,2].astype(float)>rgb[:,:,0]+25)&(rgb[:,:,2].astype(float)>rgb[:,:,1]+12)&(rgb[:,:,2]>55)
 distance=ndimage.distance_transform_edt(~blue)
 yy,xx=np.where(mask);bottom=yy.max();candidates=[]
 for x in range(xx.min(),xx.max()+1):
  ys=np.flatnonzero(mask[:,x])
  if len(ys)==0:continue
  y=ys[-1]
  if y<bottom-100:continue
  if distance[min(y+2,959),x]<4:candidates.append([x,y+1])
 clusters=[]
 for point in candidates:
  if not clusters or point[0]-clusters[-1][-1][0]>7:clusters.append([])
  clusters[-1].append(point)
 if clusters:
  # Keep the already planted foot until it actually leaves the blue
  # tread. The wider forward shoe can pass over a riser while airborne;
  # choosing the largest patch prematurely transfers body weight to it.
  cluster=max(clusters,key=len)
  if previous_contact is not None:
   nearest=min(clusters,key=lambda c:np.min(np.linalg.norm(np.asarray(c)-previous_contact,axis=1)))
   distance_to_previous=np.min(np.linalg.norm(np.asarray(nearest)-previous_contact,axis=1))
   if distance_to_previous<18:cluster=nearest
  cloud=np.asarray(cluster)
  if previous_contact is not None and np.min(np.linalg.norm(cloud-previous_contact,axis=1))<18:
   contact=cloud[np.argmin(np.linalg.norm(cloud-previous_contact,axis=1))].astype(float)
  else:contact=np.median(cluster,axis=0)
 else:contact=np.array(track['feet'])+np.array([0,1])
 previous_contact=contact
 track['contact']=contact.tolist();track['contact_count']=max([len(c)for c in clusters],default=0)
 images.append(image);tracks.append(track)
initial=float(np.median([t['height']for t in tracks[:10]]))
final=float(tracks[-1]['height']) if UP else float(np.median([t['height']for t in tracks[112:]]))
base=idle_height/initial
torso_x=ndimage.gaussian_filter1d(np.array([t['torso'][0]for t in tracks]),2.,mode='nearest')
contact_xy=np.array([t['contact']for t in tracks])
slope,intercept=np.polyfit(contact_xy[20:101,0],contact_xy[20:101,1],1)
start_x=float(np.median(torso_x[:10]));end_x=float(np.median(torso_x[112:]))

def eye_point(rgba):
 rgb=rgba[:,:,:3].astype(float);mask=(rgb[:,:,0]>55)&(rgb[:,:,0]-rgb[:,:,1]>24)&(rgba[:,:,3]>80)
 yy,xx=np.where(mask)
 return mask,np.array([yy.mean(),xx.mean()])

registered=[];contacts=[];scales=[]
for i,(image,t)in enumerate(zip(images,tracks)):
 fraction=float(np.clip((torso_x[i]-start_x)/(end_x-start_x),0,1))
 scale=base/(1+(final/initial-1)*fraction)
 # Canonical clips face left. Position the torso from its stable source
 # track, not the alternating lowest foot, then mirror the whole image.
 origin=np.array([torso_x[i]+(-torso_offset if UP else torso_offset)/scale,slope*torso_x[i]+intercept])
 affine=(1/scale,0,origin[0]-root[0]/scale,0,1/scale,origin[1]-root[1]/scale)
 canvas=image.transform((384,384),Image.Transform.AFFINE,affine,Image.Resampling.BICUBIC)
 if not UP:canvas=canvas.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 data=np.array(canvas);data[:,:,3][data[:,:,3]<3]=0
 registered.append(data)
 point=(np.array(t['contact'])-origin)*scale
 if not UP:point[0]=-point[0]-1 # Mirror about pixel centres.
 contacts.append(point.tolist());scales.append(scale)

def field(rgba):
 alpha=rgba[:,:,3]/255.;inside=alpha>.5
 return ndimage.distance_transform_edt(inside)-ndimage.distance_transform_edt(~inside)+alpha-.5

def join(a,b,count):
 fa,fb=field(a),field(b);_,pa=eye_point(a);eb,pb=eye_point(b)
 eye=np.zeros_like(b);eye[eb]=b[eb]
 result=[]
 for n in range(count):
  t=n/(count-1);t=t*t*(3-2*t)
  if n==0:rgba=a.copy()
  elif n==count-1:rgba=b.copy()
  else:
   rgba=np.zeros_like(a);rgba[:,:,:3]=[1,2,2]
   rgba[:,:,3]=np.uint8(np.clip((1-t)*fa+t*fb+.5,0,1)*255)
   moved=ndimage.shift(eye.astype(float),(*((1-t)*(pa-pb)),0),order=1,mode='constant')
   valid=moved[:,:,3]>0;rgba[valid,:3]=np.uint8(moved[valid,:3].clip(0,255))
  result.append(rgba)
 return result

first,last=(15,120) if UP else (15,108)
entry=join(idle_array,registered[first],8)
exit_frames=join(registered[last],idle_array,10)
sequence=entry+registered[first+1:last+1]+exit_frames[1:]+[idle_array.copy()for _ in range(4)]
points=[np.array([0,1]).tolist()for _ in range(8)]+contacts[first+1:last+1]+[[0,1]for _ in range(13)]
assert len(sequence)==len(points)
cycle_begin,cycle_end=(69,80) if UP else (90,102)
def mixed_points(a,b,count):
 result=[]
 for i in range(count):
  t=i/(count-1);t=t*t*(3-2*t)
  result.append(((1-t)*np.array(a)+t*np.array(b)).tolist())
 return result
enter_seq=join(idle_array,registered[cycle_begin],8)
step_seq=registered[cycle_begin:cycle_end+1]
exit_seq=join(registered[cycle_end],idle_array,10)+[idle_array.copy()for _ in range(4)]
entries={NAME:(sequence,points),
 NAME+'_enter':(enter_seq,mixed_points([0,1],contacts[cycle_begin],8)),
 NAME+'_step':(step_seq,contacts[cycle_begin:cycle_end+1]),
 NAME+'_exit':(exit_seq,mixed_points(contacts[cycle_end],[0,1],10)+[[0,1]for _ in range(4)])}
all_eyes={};all_soles={};review=[]
for clip_name,(seq,contact_points)in entries.items():
 destination=OUT.parent/clip_name;destination.mkdir(parents=True,exist_ok=True)
 rects=[];eyes=[];soles=[]
 for i,rgba in enumerate(seq):
  im=Image.fromarray(rgba);box=im.getchannel('A').getbbox()
  assert box and min(box[:2])>5 and max(box[2:])<379,'No cropped head/foot pixels allowed'
  box=(box[0]-5,box[1]-5,box[2]+5,box[3]+5)
  crop=im.crop(box);crop.save(destination/f'f_{i:03d}.png')
  imported=destination/f'f_{i:03d}.png.import'
  if imported.exists():
   params=(PROJECT/'assets/art/actors/hood_boy/core/idle_left/f_000.png.import').read_text().split('[params]',1)[1]
   imported.write_text(imported.read_text().split('[params]',1)[0]+'[params]'+params)
  rects.append([box[0],box[1],box[2]-box[0],box[3]-box[1]])
  _,eye=eye_point(rgba);eyes.append([float(eye[1]-root[0]),float(eye[0]-root[1]),-.1492,1.])
  alpha=np.asarray(crop)[:,:,3]/255.;yy,xx=np.where(alpha>0);sole=[]
  for x in range(xx.min(),xx.max()+1,3):
   for y in range(yy.max(),max(yy.min(),yy.max()-12)-1,-1):
    if alpha[y,x]>.6:sole += [x+.5,y+1.];break
  soles.append(sole)
  if clip_name==NAME and i%7==0:review.append((i,im))
 clips[clip_name]={'frames':len(seq),'fps':24.,'loop':False,'canvas':384,'root':root.tolist(),'group':GROUP,'rects':rects}
 all_eyes[clip_name]=eyes;all_soles[clip_name]=soles
groups[GROUP]=list(dict.fromkeys(groups.get(GROUP,[])+list(entries)))
manifest.write_text(replace_table(replace_table(text,'CLIPS',clips),'GROUPS',groups))
p=PROJECT/'scripts/actors/hood_eye_tracks.gd';text,data=table(p,'DATA')
for name,values in all_eyes.items():
 if name.endswith('_enter'):values[0]=data['idle_left'][0]
 elif name.endswith('_exit'):
  for i in range(len(values)-5,len(values)):values[i]=data['idle_left'][0]
 elif name==NAME:
  for i in [0,*range(len(values)-5,len(values))]:values[i]=data['idle_left'][0]
 data[name]=values
p.write_text(replace_table(text,'DATA',data))
p=PROJECT/'scripts/actors/hood_actor_soles.gd';text=p.read_text()
for name,values in all_soles.items():
 text=re.sub(r'\n\s*"'+name+r'": \[[^\n]*\],?','',text)
 at=text.rfind('}');text=text[:at]+'\t"'+name+'": '+json.dumps(values,separators=(',',':'))+',\n'+text[at:]
p.write_text(text)
report={'frames':len(sequence),'contacts':points,'native_range':[first,last],'entry_frames':8,'exit_start':8+last-first,'idle_alias_from':len(sequence)-5,'source_fps':24,'initial_height':initial,'final_height':final,'source_camera_scale':scales,'runtime_scale':.378,'mode':'native descent, motion-distance driven; isotropic source-camera correction only'}
plants=[0,8]
for i in range(9,report['exit_start']):
 if points[i][0]-points[i-1][0]<-7:plants.append(i)
plants.append(report['idle_alias_from'])
report['plants']=plants
report['native_step_range']=[cycle_begin,cycle_end]
report['parts']={}
for part in ['enter','step','exit']:
 clip_name=NAME+'_'+part
 report['parts'][part]={'clip':clip_name,'frames':len(entries[clip_name][0]),'contacts':entries[clip_name][1]}

meta=PROJECT/'scripts/actors/mine_stair_manifest.gd'
old=meta.read_text() if meta.exists() else 'extends RefCounted\n'
key='UP' if UP else 'DATA'
line='const '+key+' := '+json.dumps(report,separators=(',',':'))
if re.search(r'^const '+key+r' := .*$',old,re.M):old=re.sub(r'^const '+key+r' := .*$',lambda _:line,old,flags=re.M)
else:old+='\n'+line+'\n'
meta.write_text(old)
(AUDIT/'registration.json').write_text(json.dumps(report,indent=2))
sheet=Image.new('RGB',(6*192,((len(review)+5)//6)*230),(65,65,65));draw=ImageDraw.Draw(sheet)
for j,(i,im)in enumerate(review):
 im=im.resize((192,192),Image.Resampling.LANCZOS);x=j%6*192;y=j//6*230
 sheet.paste(im,(x,y+20),im);draw.text((x+4,y+4),str(i),fill='white')
sheet.save(AUDIT/'registered-contact.jpg')
print('Packaged',len(sequence),'frames; camera scale drift',final/initial-1,'canonical joins exact; source range',first,last)
