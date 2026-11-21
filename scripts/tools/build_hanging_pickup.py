#!/usr/bin/env python3
"""Package the approved hanging-item reach: VIDEO optional; otherwise reuse 24fps candidates.
Fixed shared scale/root; keeps source frames 5..88 continuously. Re-registers only this clip.
Requires Pillow, NumPy, SciPy and ffmpeg. QA remains under ignored artifacts/.
"""
from pathlib import Path
import sys,json
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts/tools'))
from seedance_frames import matte
art=root/'artifacts/rabbit-reach-v79';art.mkdir(parents=True,exist_ok=True);(art/'.gdignore').touch();
if len(sys.argv)>1:
 import subprocess
 source=art/'source-24fps';source.mkdir(exist_ok=True)
 subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',sys.argv[1],'-vf','fps=24','-start_number','0',str(source/'%04d.png')],check=True)
out=root/'assets/art/actors/hood_boy/hanging/hanging_pickup';out.mkdir(parents=True,exist_ok=True)
# A single registration for all frames, based on the initial standing silhouette.
scale=201/699;root_src=np.array([480.,827.]);root_dst=np.array([192.,348.]);size=round(960*scale);offset=np.rint(root_dst-np.array([960-root_src[0],root_src[1]])*scale).astype(int)
keys={5:(554,570),10:(661,504),15:(705,361),20:(680,175),24:(659,93),30:(653,85),47:(650,85),60:(650,86),64:(665,133),68:(695,211),70:(695,253),72:(699,295),74:(695,335),77:(678,386),82:(650,438),88:(630,468)}
rects=[];points=[];eyes=[];soles=[];previews=[];margins=[]
for idx,src in enumerate(range(5,89)):
 rgba,a=matte(art/f'source-24fps/{src:04d}.png','green');yy,xx=np.indices(a.shape)
 # Separate thin generated prop cords from the character before component selection.
 opened=ndimage.binary_opening(a>.5,structure=np.ones((5,5)))
 lab,n=ndimage.label(opened);counts=np.bincount(lab.ravel());counts[0]=0;keep=ndimage.binary_dilation(lab==counts.argmax(),iterations=3)
 rgba[:,:,3]*=keep
 # Raised cord can be attached to the closed fist: remove only above its top.
 if src>=24:
  hx=np.interp(src,list(keys),[v[0] for v in keys.values()]);hy=np.interp(src,list(keys),[v[1] for v in keys.values()])
  rgba[:,:,3][(xx>hx-25)&(yy<hy-32)]=0
 if src>=71:
  rgba[:,:,3][(xx>hx-22)&(yy>hy+26)]=0
 im=Image.fromarray(np.uint8(np.clip(rgba,0,1)*255)).transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize((size,size),Image.Resampling.LANCZOS)
 frame=Image.new('RGBA',(384,384));frame.alpha_composite(im,tuple(offset));data=np.array(frame);data[:,:,3][data[:,:,3]<3]=0;frame=Image.fromarray(data)
 box=frame.getbbox();margins.append(min(box[0],box[1],384-box[2],384-box[3]));box=(box[0]-4,box[1]-4,box[2]+4,box[3]+4)
 cropped=frame.crop(box);cropped.save(out/f'f_{idx:03d}.png');rects.append([box[0],box[1],box[2]-box[0],box[3]-box[1]])
 hx=np.interp(src,list(keys),[v[0] for v in keys.values()]);hy=np.interp(src,list(keys),[v[1] for v in keys.values()]);points.append([round((480-hx)*scale,3),round((hy-827)*scale,3)])
 rgb=np.array(frame);r,g,b=rgb[:,:,:3].transpose(2,0,1);ey,ex=np.where((r.astype(float)>g*1.2)&(r>50)&(rgb[:,:,3]>128))
 if len(ex):eyes.append([float(ex.mean()-192),float(ey.mean()-348),max(1,float(ex.max()-ex.min())/2),max(1,float(ey.max()-ey.min())/2)])
 else:eyes.append([])
 a=np.array(cropped)[:,:,3]/255;y,x=np.where(a>.5);bottom=y.max();pts=[]
 for c in range(int(x.min()),int(x.max())+1,3):
  rows=np.where(a[max(0,bottom-12):bottom+1,c]>.6)[0]
  if len(rows):pts.extend([c+.5,float(max(0,bottom-12)+rows.max()+1)])
 soles.append(pts)
 prev=Image.new('RGBA',(384,384),(85,85,85,255));prev.alpha_composite(frame);previews.append(prev.convert('RGB'))
info={'frames':len(rects),'fps':48.,'loop':False,'canvas':384,'root':[192.,348.],'group':'hanging','rects':rects,'hold_points':points,'source_first':5,'source_last':88,'source_fps':24.,'grasp_frame':20}
manifest=root/'scripts/actors/hood_actor_manifest.gd';lines=manifest.read_text().splitlines()
for i,l in enumerate(lines):
 if l.startswith('const CLIPS := '):
  d=json.loads(l.split(':= ',1)[1]);d['hanging_pickup']=info;lines[i]='const CLIPS := '+json.dumps(d,separators=(',',':'))
 if l.startswith('const GROUPS := '):
  d=json.loads(l.split(':= ',1)[1]);d['hanging']=['hanging_pickup'];lines[i]='const GROUPS := '+json.dumps(d,separators=(',',':'))
manifest.write_text('\n'.join(lines)+'\n')
p=root/'scripts/actors/hood_eye_tracks.gd';prefix,raw=p.read_text().split('const DATA := ',1);d=json.loads(raw);d['hanging_pickup']=eyes;p.write_text(prefix+'const DATA := '+json.dumps(d,separators=(',',':'))+'\n')
p=root/'scripts/actors/hood_actor_soles.gd';s='\n'.join(l for l in p.read_text().splitlines() if not l.lstrip().startswith('"hanging_pickup":'))+'\n';end=s.rfind('}');s=s[:end]+'\t"hanging_pickup": '+json.dumps(soles,separators=(',',':'))+',\n'+s[end:];p.write_text(s)
for page in range(3):
 sheet=Image.new('RGB',(1200,1125),(30,30,30));draw=ImageDraw.Draw(sheet)
 for cell,im in enumerate(previews[page*30:page*30+30]):
  x=cell%6*200;y=cell//6*225;sheet.paste(im.resize((200,200)),(x,y));draw.text((x+4,y+201),str(page*30+cell+5),fill='white')
 sheet.save(art/f'keyed-{page:02d}.jpg')
previews[0].save(art/'keyed-preview.gif',save_all=True,append_images=previews[1:],duration=21,loop=0)
(art/'pack-audit.json').write_text(json.dumps({'scale':scale,'source_root':root_src.tolist(),'minimum_canvas_margin':min(margins),'info':info},indent=2))
print('packaged',len(rects),'frames, margin',min(margins))
