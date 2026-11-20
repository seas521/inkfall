"""Join the mine ladder's standing tail to the exact gameplay idle.

Only adds a mine-specific clip; source ladder/forest frames stay untouched.
The transition has one interpolated contour, not two fading silhouettes.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, shift

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_back_ladder_clip import PROJECT, table, replace_table

NAME = 'mine_ladder_settle'
manifest = PROJECT/'scripts/actors/hood_actor_manifest.gd'
text, clips = table(manifest, 'CLIPS')
_, groups = table(manifest, 'GROUPS')
master = clips['back_ladder']
idle = clips['idle_left']
audit = json.loads((PROJECT/'artifacts/back-ladder-3155-review/audit.json').read_text())
root = np.array([192, 320])
track = audit['tracks'][221]
offset = (np.array([track['torso'][0], track['feet'][1]])-audit['source_root'])*track['applied_scale']

def placed(info, frame, correction):
    src = Image.open(PROJECT/f"assets/art/actors/hood_boy/{info['group']}/{('back_ladder' if info is master else 'idle_left')}/f_{frame:03d}.png").convert('RGBA')
    pos = np.array(info['rects'][frame][:2])-info['root']-correction+root
    return np.array(src.transform((384,384), Image.Transform.AFFINE,
                    (1,0,-pos[0],0,1,-pos[1]), Image.Resampling.BICUBIC))

a = placed(master,221,offset)
b = placed(idle,0,np.zeros(2))
def field(image):
    alpha=image[:,:,3]/255.
    inside=alpha>.5
    return distance_transform_edt(inside)-distance_transform_edt(~inside)+alpha-.5
fa,fb=field(a),field(b)
def eye(image):
    rgb=image[:,:,:3].astype(float)
    mask=(rgb[:,:,0]>55)&(rgb[:,:,0]-rgb[:,:,1]>24)&(image[:,:,3]>80)
    yy,xx=np.where(mask)
    return mask,np.array([yy.mean(),xx.mean()])
ea,pa=eye(a); eb,pb=eye(b)
out=PROJECT/f'assets/art/actors/hood_boy/back_ladder/{NAME}'
out.mkdir(parents=True,exist_ok=True)
rects=[];eyes=[];soles=[]
for i in range(20):
    # Reach identical idle before ownership changes; final 4 frames hold it.
    t=min(1,i/15);t=t*t*(3-2*t)
    if i==0:rgba=a.copy()
    elif t>=1:rgba=b.copy()
    else:
        rgba=np.zeros_like(a)
        rgba[:,:,:3]=[1,2,2]
        rgba[:,:,3]=np.uint8(np.clip((1-t)*fa+t*fb+.5,0,1)*255)
        eye_layer=np.zeros_like(b);eye_layer[eb]=b[eb]
        moved=shift(eye_layer.astype(float),(*( (1-t)*(pa-pb) ),0),order=1,mode='constant')
        mask=moved[:,:,3]>0
        rgba[mask,:3]=np.uint8(np.clip(moved[mask,:3],0,255))
    image=Image.fromarray(rgba)
    box=image.getchannel('A').getbbox();box=(box[0]-5,box[1]-5,box[2]+5,box[3]+5)
    crop=image.crop(box);crop.save(out/f'f_{i:03d}.png')
    imported=out/f'f_{i:03d}.png.import'
    if imported.exists():
        params=(PROJECT/'assets/art/actors/hood_boy/core/idle_left/f_000.png.import').read_text().split('[params]',1)[1]
        imported.write_text(imported.read_text().split('[params]',1)[0]+'[params]'+params)
    rects.append([box[0],box[1],box[2]-box[0],box[3]-box[1]])
    # Same eye metadata endpoints as the existing clips.
    pos=(1-t)*pa+t*pb-root[::-1]
    eyes.append([float(pos[1]),float(pos[0]),-.1492,1.])
    alpha=np.asarray(crop)[:,:,3]/255.;yy,xx=np.where(alpha>0)
    points=[]
    for x in range(xx.min(),xx.max()+1,3):
        for y in range(yy.max(),max(yy.min(),yy.max()-12)-1,-1):
            if alpha[y,x]>.6:points += [x+.5,y+1.];break
    soles.append(points)
clips[NAME]={'frames':20,'fps':60.,'loop':False,'canvas':384,'root':root.tolist(),'group':'back_ladder','rects':rects}
if NAME not in groups['back_ladder']:groups['back_ladder'].append(NAME)
manifest.write_text(replace_table(replace_table(text,'CLIPS',clips),'GROUPS',groups))
p=PROJECT/'scripts/actors/hood_eye_tracks.gd';text,data=table(p,'DATA')
for i in range(15,20):eyes[i]=data['idle_left'][0]
data[NAME]=eyes;p.write_text(replace_table(text,'DATA',data))
p=PROJECT/'scripts/actors/hood_actor_soles.gd';text=p.read_text()
import re
text=re.sub(r'\n\s*"'+NAME+r'": \[[^\n]*\],?','',text)
at=text.rfind('}');text=text[:at]+'\t"'+NAME+'": '+json.dumps(soles,separators=(',',':'))+',\n'+text[at:];p.write_text(text)
print('Added exact-idle settle: 20 frames; last 5 equal canonical idle pixels.')
