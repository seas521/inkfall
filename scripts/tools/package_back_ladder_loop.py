#!/usr/bin/env python3
"""Package the pose-reviewed 3155 climb cycle; translation only, no shape edits."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from build_back_ladder_clip import PROJECT, table, replace_table

audit_dir=PROJECT/'artifacts/back-ladder-3155-review'
audit=json.loads((audit_dir/'audit.json').read_text())
manifest=PROJECT/'scripts/actors/hood_actor_manifest.gd'
text, clips=table(manifest,'CLIPS'); _, groups=table(manifest,'GROUPS')
master=clips['back_ladder']; first,last=97,122
out=PROJECT/'assets/art/actors/hood_boy/back_ladder/back_ladder_up'
out.mkdir(parents=True,exist_ok=True)
root=np.array([192.,348.]); source_root=np.array(audit['source_root'])
rects=[]; removed=[]
for n,index in enumerate(range(first,last+1)):
    image=Image.open(PROJECT/f'assets/art/actors/hood_boy/back_ladder/back_ladder/f_{index:03d}.png').convert('RGBA')
    track=audit['tracks'][index]
    torso=(np.array(track['torso'])-source_root)*track['applied_scale']
    offset=np.rint(np.array(master['rects'][index][:2])-np.array(master['root'])-torso+root-np.array([0,95])).astype(int)
    frame=Image.new('RGBA',(384,384));frame.paste(image,tuple(offset))
    bounds=frame.getchannel('A').getbbox();box=(bounds[0]-5,bounds[1]-5,bounds[2]+5,bounds[3]+5)
    assert min(box[:2])>=0 and max(box[2:])<=384
    frame.crop(box).save(out/f'f_{n:03d}.png')
    rects.append([box[0],box[1],box[2]-box[0],box[3]-box[1]])
    removed.append(torso.tolist())
clips['back_ladder_up']={'frames':last-first+1,'fps':audit['fps'],'loop':True,'canvas':384,
                         'root':root.tolist(),'group':'back_ladder','rects':rects,
                         'source_frames':[first,last],'removed_root_translation':removed}
groups['back_ladder']=['back_ladder','back_ladder_up']
manifest.write_text(replace_table(replace_table(text,'CLIPS',clips),'GROUPS',groups))
eyes_path=PROJECT/'scripts/actors/hood_eye_tracks.gd'
text,eyes=table(eyes_path,'DATA');eyes['back_ladder_up']=[[0.,0.,0.,0.] for _ in rects]
eyes_path.write_text(replace_table(text,'DATA',eyes))
audit['segments']['up_loop']=[first,last]
(audit_dir/'audit.json').write_text(json.dumps(audit,indent=2))
(PROJECT/'scripts/actors/back_ladder_manifest.gd').write_text('extends RefCounted\n\nconst DATA := '+json.dumps(audit,separators=(',',':'))+'\n')
print(f'Packaged {len(rects)} native loop poses, {len(rects)/audit["fps"]:.3f}s; torso translation separated')
