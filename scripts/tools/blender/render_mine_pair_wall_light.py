"""Received practical light and occlusion on the far wall, registered to art.
Only receiver surfaces appear to camera; every timber continues casting.
"""
import bpy
ROOT='/Users/xiangxi.li/Documents/inkfall'
bpy.ops.wm.open_mainfile(filepath=ROOT+'/artifacts/mine-pair-volume-v1/source/mine-pair-volume.blend')
s=bpy.context.scene
for o in s.objects:
 if o.type in ['MESH','CURVE']:
  o.visible_camera=o.name.startswith(('Solid distant cavern wall','Back left geological','Back right geological','Rear ground'))
s.render.film_transparent=False
s.render.filepath=ROOT+'/assets/art/descent/mine-pair-v2/wall-light.png'
bpy.ops.render.render(write_still=True)
print('RECEIVED WALL LIGHT COMPLETE')
