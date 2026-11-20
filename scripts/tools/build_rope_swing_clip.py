"""Package native Seedance frames using a measured hand root and ONE body scale.
Run with /private/tmp/inkfall-predator-venv/bin/python after native extraction.
Green/blue are tracking aids only; the game supplies its own physical rope.
"""
import json,re,hashlib
from pathlib import Path
import numpy as np
from scipy import ndimage,signal
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
AUDIT=ROOT/'artifacts/rope-swing'
OUT=ROOT/'assets/art/actors/hood_boy/rope_swing/rope_swing'
OUT.mkdir(parents=True,exist_ok=True)
frames=[]; tracks=[]
for path in sorted((AUDIT/'source').glob('*.png')):
 rgb=np.asarray(Image.open(path).convert('RGB'),dtype=float)/255
 r,g,b=rgb.transpose(2,0,1)
 alpha=1-np.clip((np.maximum.reduce([r,g,b])-.11)/.17,0,1)
 orange=(r>g*1.2)&(r>b+.15)&(r>.3)
 alpha=np.maximum(alpha,orange)
 labels,_=ndimage.label(alpha>.45);sizes=np.bincount(labels.ravel());sizes[0]=0
 keep=ndimage.binary_dilation(labels==sizes.argmax(),iterations=2);alpha*=keep
 yy,xx=np.where(alpha>.5)
 ey,ex=np.where(orange&keep)
 eye=np.array([ex.mean(),ey.mean()]) if len(ex) else np.array([xx.mean(),yy.min()+45])
 blue=(b>r+.15)&(b>g+.04)
 near=ndimage.binary_dilation(blue,iterations=6)&(alpha>.6)
 ys,xs=np.indices(near.shape)
 near&=(ys>eye[1]-120)&(ys<eye[1]+45)&(abs(xs-eye[0])<130)
 hy,hx=np.where(near)
 hand=np.array([hx.mean(),hy.mean()]) if len(hx)>2 else np.array([eye[0]-40,eye[1]-35])
 rope=blue&(ys>hand[1]-95)&(ys<hand[1]-15)&(abs(xs-hand[0])<90)
 ry,rx=np.where(rope)
 slope=np.polyfit(ry,rx,1)[0] if len(ry)>40 else 0
 foot=np.array([np.median(xx[yy>yy.max()-5]),yy.max()])
 rgba=np.zeros((*alpha.shape,4),dtype=np.uint8);rgba[:,:,:3]=1;rgba[:,:,3]=(alpha*255).astype('uint8')
 frames.append(Image.fromarray(rgba))
 tracks.append({'hand':hand.tolist(),'eye':eye.tolist(),'feet':foot.tolist(),'angle':float(np.arctan(slope)),'contact_pixels':len(hx)})
# Smooth subpixel tracking noise, not body shape or frame timing.
for key in ['hand','eye','angle','feet']:
 vals=np.array([x[key] for x in tracks]);smooth=signal.savgol_filter(ndimage.median_filter(vals,size=(7,1) if vals.ndim==2 else 7,mode="nearest"),11,2,axis=0)
 for i,v in enumerate(smooth):tracks[i][key]=v.tolist()
idle=Image.open(ROOT/'assets/art/actors/hood_boy/core/idle_left/f_000.png').getchannel('A').getbbox()
box=frames[0].getchannel('A').getbbox();scale=(idle[3]-idle[1])/(box[3]-box[1])
root=np.array([320.,160.]);rects=[];eyes=[];packed=[]
for i,(im,tr) in enumerate(zip(frames,tracks)):
 hand=np.array(tr['hand']);bbox=im.getchannel('A').getbbox()
 # Independent crops retain their measured location relative to the hand, never bbox-centred.
 crop=(max(0,bbox[0]-4),max(0,bbox[1]-4),min(960,bbox[2]+4),min(960,bbox[3]+4))
 sub=im.crop(crop);sub=sub.resize((round(sub.width*scale),round(sub.height*scale)),Image.Resampling.LANCZOS)
 sub.save(OUT/f'f_{i:03d}.png')
 origin=np.array(crop[:2])*scale-hand*scale+root
 rects.append([float(origin[0]),float(origin[1]),sub.width,sub.height])
 eyes.append([*(((np.array(tr['eye'])-hand)*scale).tolist()),0,1])
 tr['feet_local']=((np.array(tr['feet'])-hand)*scale).tolist()
 tr['hand_error_px']=0.0
 if i%12==0:
  bg=Image.new('RGBA',(300,330),(140,140,140,255));small=sub.resize((round(sub.width*.75),round(sub.height*.75)))
  off=(np.array([150,85])+(origin-root)*.75).astype(int);bg.alpha_composite(small,tuple(off));d=ImageDraw.Draw(bg);d.text((8,310),str(i),fill='white');packed.append(bg.convert('RGB'))
entry={'frames':len(frames),'fps':24.,'loop':False,'canvas':640,'root':root.tolist(),'group':'rope_swing','rects':rects}
p=ROOT/'scripts/actors/hood_actor_manifest.gd';s=p.read_text()
for name,updates in [('CLIPS',{'rope_swing':entry}),('GROUPS',{'rope_swing':['rope_swing']})]:
 m=re.search(r'^const '+name+r' := (\{.*\})$',s,re.M);data=json.loads(m.group(1));data.update(updates);s=s[:m.start(1)]+json.dumps(data,separators=(',',':'))+s[m.end(1):]
p.write_text(s)
p=ROOT/'scripts/actors/hood_eye_tracks.gd';s=p.read_text();m=re.search(r'^const DATA := (\{.*\})$',s,re.M);data=json.loads(m.group(1));data['rope_swing']=eyes;p.write_text(s[:m.start(1)]+json.dumps(data,separators=(',',':'))+s[m.end(1):])
data={'scale':scale,'frames':len(frames),'fps':24,'tracks':tracks,'segments':{'catch':[34,60],'hold':[61,83],'swing':[84,192],'release':[193,216],'air':[217,240]}}
(ROOT/'scripts/actors/rope_swing_manifest.gd').write_text('extends RefCounted\n\nconst DATA := '+json.dumps(data,separators=(',',':'))+'\n')
(AUDIT/'audit.json').write_text(json.dumps(data,indent=2))
sheet=Image.new('RGB',(1500,1650),(140,140,140))
for i,im in enumerate(packed):sheet.paste(im,(i%5*300,i//5*330))
sheet.save(AUDIT/'processed-contact.jpg')
print('Packaged',len(frames),'native frames; fixed scale',scale,'standing height',idle[3]-idle[1])
