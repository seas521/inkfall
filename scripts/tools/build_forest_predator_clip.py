#!/usr/bin/env python3
"""Package all native Seedance frames with one scale/root; requires Pillow/NumPy/SciPy."""
import json, subprocess, sys, hashlib
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[2]
AUDIT=ROOT/'artifacts/forest-predator/video-v1'
OUT=ROOT/'assets/art/c_zone_debug/forest/predator-seedance-v1'
SOURCE_ROOT=np.array([480.,880.])
PACK_SCALE=.4
CANVAS=384
CANVAS_ROOT=np.array([192.,354.])
DISPLAY_SCALE=.82
# Tracked oral contact point in original source coordinates (not a per-frame root).
KEYS={0:[400,430],12:[410,435],24:[600,415],34:[575,435],36:[550,430],38:[470,405],39:[370,395],40:[270,405],41:[220,410],42:[215,415],43:[255,440],48:[295,435],60:[290,415],84:[285,425],88:[280,440],90:[260,450],96:[290,450],108:[390,430],120:[400,430]}

def main():
    source=Path(sys.argv[1]); raw=AUDIT/'source'
    raw.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
    subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',str(source),'-an','-fps_mode','passthrough','-start_number','0',str(raw/'%04d.png')],check=True)
    paths=sorted(raw.glob('*.png')); frames=[]; rects=[]; margins=[]; mouth=[]
    for i,path in enumerate(paths):
        rgb=np.asarray(Image.open(path).convert('RGB'),dtype=np.float32)/255
        luma=rgb.max(axis=2)
        alpha=np.clip((.90-luma)/.78,0,1)
        labels,_=ndimage.label(alpha>.45)
        sizes=np.bincount(labels.ravel());sizes[0]=0
        # Keep real detached fine foliage, reject compression specks.
        keep=ndimage.binary_dilation(np.isin(labels,np.where(sizes>=20)[0]),iterations=2)
        alpha*=keep
        rgba=np.zeros((*alpha.shape,4),dtype=np.uint8)
        rgba[:,:,:3]=1;rgba[:,:,3]=np.uint8(alpha*255)
        im=Image.fromarray(rgba).resize((384,384),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(CANVAS,CANVAS))
        origin=np.rint(CANVAS_ROOT-SOURCE_ROOT*PACK_SCALE).astype(int)
        canvas.paste(im,tuple(origin))
        data=np.asarray(canvas).copy();data[:,:,3][data[:,:,3]<3]=0
        canvas=Image.fromarray(data)
        box=canvas.getchannel('A').getbbox()
        margins.append(min(box[0],box[1],CANVAS-box[2],CANVAS-box[3]))
        crop=(box[0]-4,box[1]-4,box[2]+4,box[3]+4)
        canvas.crop(crop).save(OUT/f'f_{i:03d}.png')
        rects.append([crop[0],crop[1],crop[2]-crop[0],crop[3]-crop[1]])
        ks=sorted(KEYS); a=max(k for k in ks if k<=i); b=min(k for k in ks if k>=i)
        point=np.array(KEYS[a]) if a==b else np.array(KEYS[a])+(np.array(KEYS[b])-KEYS[a])*(i-a)/(b-a)
        mouth.append([round(float(v),3) for v in point])
        bg=Image.new('RGBA',canvas.size,(220,220,220,255));bg.alpha_composite(canvas)
        frames.append(bg.convert('RGB'))
    assert len(paths)==121 and min(margins)>=3,(len(paths),min(margins))
    data={'source':source.name,'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'frames':len(paths),'fps':24.0,'source_root':SOURCE_ROOT.tolist(),'pack_scale':PACK_SCALE,'canvas':CANVAS,'root':CANVAS_ROOT.tolist(),'display_scale':DISPLAY_SCALE,'minimum_canvas_margin':min(margins),'rects':rects,'mouth':mouth,'segments':{'idle':[0,12],'windup':[13,39],'snap':[40,49],'eat':[50,88],'eat_intro':[50,64],'eat_loop':[65,88],'recover':[89,120]},'windup_fps':60.0,'feed_windup_fps':60.0}
    (OUT/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
    (ROOT/'scripts/chapters/forest_predator_clip.gd').write_text('extends RefCounted\n\nconst DATA := '+json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    frames[0].save(AUDIT/'processed-motion.gif',save_all=True,append_images=frames[1:],duration=42,loop=0)
    for start in range(0,len(frames),24):
        sheet=Image.new('RGB',(6*192,4*216),(220,220,220));draw=ImageDraw.Draw(sheet)
        for slot,i in enumerate(range(start,min(start+24,len(frames)))):
            im=frames[i].resize((192,192),Image.Resampling.LANCZOS);x=slot%6*192;y=slot//6*216
            sheet.paste(im,(x,y));draw.text((x+4,y+195),f'{i:03d}',fill=(0,0,0))
        sheet.save(AUDIT/f'processed-{start:03d}.jpg')
    (AUDIT/'audit.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
    print(f'PACKAGED {len(frames)} continuous frames, minimum fixed-canvas margin {min(margins)}px; crop coordinates retained')
if __name__=='__main__':main()
