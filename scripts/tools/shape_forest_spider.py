"""Derive a needle-legged hunter from the official parameter variant.
Keep the original topology/weights, reshape along each leg's actual bone chain,
update bind poses, then let build_forest_spider_model.py retarget native clips.
"""
import json
import struct
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/polyfork/spider-v1'
raw=(OUT/'garden-orb-weaver-long-legs.glb').read_bytes()
length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length]); binary=bytearray(raw[28+length:])

def array(index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    n={'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    dtype=np.dtype({5126:'<f4',5123:'<u2',5121:'u1'}[a['componentType']])
    return np.ndarray((a['count'],n),dtype=dtype,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dtype.itemsize*n),dtype.itemsize))
parents={child:i for i,node in enumerate(doc['nodes']) for child in node.get('children',[])}
def global_position(i):
    p=np.array(doc['nodes'][i].get('translation',[0,0,0]),dtype=float)
    return p+global_position(parents[i]) if i in parents else p
skin=doc['skins'][0]; joints=skin['joints'];names=[doc['nodes'][i]['name'] for i in joints]
old_global=np.array([global_position(i) for i in joints]);new_global=old_global+np.array([0,.60,0])
p=doc['meshes'][0]['primitives'][0];vertices=array(p['attributes']['POSITION']);original=vertices.copy()
weights=array(p['attributes']['WEIGHTS_0']);indices=array(p['attributes']['JOINTS_0']);dominant=indices[np.arange(len(indices)),weights.argmax(axis=1)]
legs=[]
for side in ['Left','Right']:
 for number in range(1,5):
    bone_names=[f'{side}Leg{number}{part}' for part in ['Hip','Knee','Tip']]
    ids=[names.index(n) for n in bone_names]
    h,k,t=old_global[ids]
    tip_cloud=original[dominant==ids[2]]
    foot=tip_cloud[np.argmin(tip_cloud[:,1])].astype(float)
    old=np.array([h,k,t,foot])
    new=old.copy()
    new[:,[0,2]]=h[[0,2]]+(old[:,[0,2]]-h[[0,2]])*1.25
    new[0,1]+=.60;new[1,1]+=.82
    # Tarsi remain on the ground, with elevated hips and knees above them.
    for bone_id,point in zip(ids,new[:3]):new_global[bone_id]=point
    selection=np.flatnonzero(np.isin(dominant,ids))
    for vindex in selection:
        point=original[vindex].astype(float)
        candidates=[]
        for seg in range(3):
            delta=old[seg+1]-old[seg]
            u=np.clip(np.dot(point-old[seg],delta)/np.dot(delta,delta),0,1)
            centre=old[seg]+delta*u
            candidates.append((np.linalg.norm(point-centre),seg,u,centre))
        _,seg,u,centre=min(candidates,key=lambda c:c[0])
        axis=(old[seg+1]-old[seg]);axis/=np.linalg.norm(axis)
        new_axis=(new[seg+1]-new[seg]);new_axis/=np.linalg.norm(new_axis)
        cross=np.cross(axis,new_axis);cos=np.dot(axis,new_axis)
        skew=np.array([[0,-cross[2],cross[1]],[cross[2],0,-cross[0]],[-cross[1],cross[0],0]])
        rotation=np.eye(3)+skew+skew@skew/max(1+cos,1e-6)
        thickness=.34 if seg<2 else .26
        vertices[vindex]=new[seg]+(new[seg+1]-new[seg])*u+rotation@(point-centre)*thickness
    legs.append({'hip':bone_names[0],'knee':bone_names[1],'tip':bone_names[2],'foot_local':(new[3]-new[2]).tolist(),'front':number<=2,'side':1 if side=='Left' else -1,'number':number})
nonlegs=np.array(['Leg' not in names[i] for i in dominant])
vertices[nonlegs]=original[nonlegs]+np.array([0,.60,0])
abdomen=dominant==names.index('Abdomen')
pivot=new_global[names.index('Abdomen')]
vertices[abdomen]=pivot+(vertices[abdomen]-pivot)*np.array([.78,.78,.80])
# Bone local translations and inverse bind transforms follow the new rest pose.
node_positions={node:pos for node,pos in zip(joints,new_global)}
for node,position in node_positions.items():
    parent=parents.get(node)
    parent_pos=node_positions.get(parent,global_position(parent) if parent is not None else np.zeros(3))
    doc['nodes'][node]['translation']=(position-parent_pos).tolist()
binds=array(skin['inverseBindMatrices'])
for i,position in enumerate(new_global):
    matrix=np.eye(4);matrix[:3,3]=-position
    binds[i]=matrix.flatten(order='F')
a=doc['accessors'][p['attributes']['POSITION']];a['min']=vertices.min(axis=0).tolist();a['max']=vertices.max(axis=0).tolist()
# Do not resize binary while NumPy views exist.
encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
(OUT/'garden-orb-weaver-needle-variant.glb').write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(binary))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(binary),b'BIN\0')+binary)
(OUT/'hunter-rig.json').write_text(json.dumps({'legs':legs,'source_params':{'legReach':1.1,'legThickness':.85,'stance':1.08,'fullness':.9},'derivative':{'reach_multiplier':1.25,'tube_radius_multiplier':.34,'tip_radius_multiplier':.26,'hips_lift':.60,'knee_lift':.82,'abdomen_scale':[.78,.78,.80]}},indent=2))
print('Needle geometry: eight extended/tapered legs, elevated body, smaller abdomen, updated bind poses')
