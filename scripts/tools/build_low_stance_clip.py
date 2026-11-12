"""Package all 121 native low-stance frames with fixed root/scale and unified eyes."""
import json,re,hashlib
from pathlib import Path
import numpy as np
from scipy import ndimage
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'artifacts/low-stance/source'
OUT=ROOT/'assets/art/actors/hood_boy/low_stance'
AUDIT=ROOT/'artifacts/low-stance'
SCALE=.53
SOURCE_ROOT=np.array([454.1,758.5]);PIVOT=np.array([288.,500.]);CANVAS=576
# All source frames are retained. The loop closes at 64, matching 38 (96.7% IoU).
SEGMENTS={'low_enter':(0,24,False),'low_idle':(24,34,True),'low_walk':(38,63,True),'low_exit':(96,120,False)}
frames=[];tracks=[];margins=[];boxes=[]
for path in sorted(SRC.glob('*.png')):
 rgb=np.array(Image.open(path).convert('RGB'),dtype=np.float32)/255
 alpha=np.clip(1-(rgb[:,:,1]-np.maximum(rgb[:,:,0],rgb[:,:,2])-.025)/.13,0,1)
 labels,_=ndimage.label(alpha>.45);sizes=np.bincount(labels.ravel());sizes[0]=0
 keep=ndimage.binary_dilation(labels==sizes.argmax(),iterations=2);alpha*=keep
 eyemask=(rgb[:,:,0]>rgb[:,:,1]*1.3)&(rgb[:,:,0]>rgb[:,:,2]*1.6)&(rgb[:,:,0]>.3)&(alpha>.6)
 yy,xx=np.where(eyemask)
 if len(xx):
  w=rgb[yy,xx,0];eye=np.array([(xx*w).sum()/w.sum(),(yy*w).sum()/w.sum()]);eye=(eye-SOURCE_ROOT)*SCALE;track=[round(eye[0],3),round(eye[1],3),0,1]
 else:track=[0,0,0,0]
 tracks.append(track)
 rgba=np.zeros((*alpha.shape,4),dtype=np.uint8);rgba[:,:,:3]=1;rgba[:,:,3]=(alpha*255).astype(np.uint8)
 image=Image.fromarray(rgba).resize((509,509),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(CANVAS,CANVAS));origin=np.rint(PIVOT-SOURCE_ROOT*SCALE).astype(int);canvas.paste(image,tuple(origin))
 a=np.array(canvas);a[:,:,3][a[:,:,3]<3]=0;canvas=Image.fromarray(a)
 bbox=canvas.getchannel('A').getbbox();margins.append(min(bbox[0],bbox[1],CANVAS-bbox[2],CANVAS-bbox[3]));frames.append(canvas);boxes.append(bbox)
entries={};eye_entries={}
for name,(start,end,loop) in SEGMENTS.items():
 dst=OUT/name;dst.mkdir(parents=True,exist_ok=True);rects=[]
 for i,source_index in enumerate(range(start,end+1)):
  b=boxes[source_index];crop=(b[0]-4,b[1]-4,b[2]+4,b[3]+4);frames[source_index].crop(crop).save(dst/f'f_{i:03d}.png');rects.append([crop[0],crop[1],crop[2]-crop[0],crop[3]-crop[1]])
 entries[name]={'frames':end-start+1,'fps':24.0,'root':PIVOT.tolist(),'canvas':CANVAS,'loop':loop,'group':'low_stance','source_frames':[start,end],'rects':rects,'cycle_distance':64.0 if name=='low_walk' else 0}
 eye_entries[name]=tracks[start:end+1]
manifest=ROOT/'scripts/actors/hood_actor_manifest.gd';text=manifest.read_text()
for key,updates in [('CLIPS',entries),('GROUPS',{'low_stance':list(SEGMENTS)})]:
 match=re.search(r'^const '+key+r' := (\{.*\})$',text,re.M);data=json.loads(match.group(1));data.update(updates);text=text[:match.start(1)]+json.dumps(data,separators=(',',':'))+text[match.end(1):]
manifest.write_text(text)
eye=ROOT/'scripts/actors/hood_eye_tracks.gd';text=eye.read_text();m=re.search(r'^const DATA := (\{.*\})$',text,re.M);data=json.loads(m.group(1));data.update(eye_entries);eye.write_text(text[:m.start(1)]+json.dumps(data,separators=(',',':'))+text[m.end(1):])
preview=[]
for i,canvas in enumerate(frames):
 bg=Image.new('RGBA',(CANVAS,CANVAS),(185,185,185,255));bg.alpha_composite(canvas)
 tr=tracks[i]
 if tr[3]:
  d=ImageDraw.Draw(bg);x=tr[0]+PIVOT[0];y=tr[1]+PIVOT[1];d.ellipse((x-2.6,y-3.6,x+2.6,y+3.6),fill=(255,125,17,255))
 preview.append(bg.convert('RGB'))
preview[0].save(AUDIT/'all-processed.gif',save_all=True,append_images=preview[1:],duration=42,loop=0)
sheet=Image.new('RGB',(6*192,21*208),(185,185,185));d=ImageDraw.Draw(sheet)
for i,im in enumerate(preview):
 x=i%6*192;y=i//6*208;sheet.paste(im.resize((192,192)),(x,y));d.text((x+3,y+192),str(i),fill=(0,0,0))
sheet.save(AUDIT/'all-processed.jpg')
source=next(Path('/Users/xiangxi.li/Downloads').glob('jimeng-2026-11-10-7261-*.mp4'))
info={'source':source.name,'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'native_frames':len(frames),'pack_scale':SCALE,'source_root':SOURCE_ROOT.tolist(),'root':PIVOT.tolist(),'minimum_margin':min(margins),'entries':entries,'eye_tracks':tracks,'all_rects':boxes}
(AUDIT/'audit.json').write_text(json.dumps(info,indent=2));assert min(margins)>=3
print('PACKAGED',len(frames),'native frames; minimum margin',min(margins),'entries',list(entries))
