"""Split the existing authored far collection by distance; never flatten it."""
import bpy,os,json
ROOT='/Users/xiangxi.li/Documents/inkfall';OUT=ROOT+'/assets/art/descent/mine-pair-v2'
bpy.ops.wm.open_mainfile(filepath=ROOT+'/artifacts/mine-pair-volume-v1/source/mine-pair-volume.blend')
s=bpy.context.scene
# Preserve the exact same geometry, camera, lights and received shadows.
original=list(bpy.data.collections['depth'].objects)
groups={
 'far-gallery':[o for o in original if o.name.startswith(('Rear gallery','Rear railing','Cropped rear service'))],
 'back-supports':[o for o in original if o.name.startswith(('Rear load column','Rear corbel','Far adit','Lower adit','Distant grounded stores'))]
}
meshes=[o for o in s.objects if o.type in ['MESH','CURVE']]
for key,objects in groups.items():
 selected=set(objects)
 for o in meshes:o.visible_camera=o in selected
 s.render.film_transparent=True;s.render.filepath=OUT+'/'+key+'.png'
 bpy.ops.render.render(write_still=True)
with open(OUT+'/depth-layers.json','w') as f:json.dump({k:[o.name for o in v] for k,v in groups.items()},f,indent=2)
print('MINE PAIR DEPTH LAYERS COMPLETE')
