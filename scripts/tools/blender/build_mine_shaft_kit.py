import bpy, math, os
from mathutils import Vector
OUT='/Users/xiangxi.li/Documents/inkfall/assets/art/descent/mine-shaft-v1'
os.makedirs(OUT,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=16;s.render.film_transparent=True
s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.view_settings.view_transform='Standard'
s.world.color=(.07,.07,.07)
def mat(name,value):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None) or m.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
 o=next((n for n in m.node_tree.nodes if n.type=='OUTPUT_MATERIAL'),None) or m.node_tree.nodes.new('ShaderNodeOutputMaterial')
 m.node_tree.links.new(p.outputs[0],o.inputs[0]);p.inputs['Base Color'].default_value=(value,value,value,1);p.inputs['Roughness'].default_value=.84
 return m
wood=mat('Weathered pit timber',.07);iron=mat('Blackened forged iron',.13);rope=mat('Dark twisted cable',.065)
def box(name,at,size,material=wood):
 bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.name=name;o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(material);b=o.modifiers.new('Worn irregular corners','BEVEL');b.width=.014;b.segments=3
 return o
def rod(name,a,b,r,material=iron):
 a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=(b-a).length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(material)
 return o
def brace(a,b,width=.08):
 a,b=Vector(a),Vector(b);o=box('Diagonal bracing',(a+b)/2,(width,.09,(b-a).length));o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
def wheel(at,r):
 x,y,z=at
 bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=.025,major_segments=48,minor_segments=8,location=at,rotation=(math.pi/2,0,0));bpy.context.object.data.materials.append(iron)
 for i in range(8):
  a=i*math.tau/8;rod('Wheel spokes',at,(x+math.sin(a)*r,y,z+math.cos(a)*r),.012)
 rod('Axle',(x,y-.12,z),(x,y+.12,z),.05)
def clear():
 for o in list(bpy.data.objects):
  if o.type not in ['CAMERA','LIGHT']:bpy.data.objects.remove(o,do_unlink=True)
def render(name,center,scale):
 cam.location=Vector(center)+Vector((.22,-8,.15));cam.rotation_euler=(Vector(center)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 s.render.filepath=OUT+'/'+name+'.png';bpy.ops.render.render(write_still=True)
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';s.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-2,-4,6));lamp=bpy.context.object;lamp.data.energy=420;lamp.data.size=3
lamp.rotation_euler=(Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
# Open cage with an unmistakable load-bearing head and undercarriage.
for y in [-.25,.25]:
 for x in [-.83,.83]:
  box('Bent iron upright',(x,y,.82),(.055,.07,1.65),iron)
 box('Top rail',(0,y,1.65),(1.85,.09,.11),iron)
 box('Bottom bearer',(0,y,-.035),(1.9,.12,.15),iron)
for i in range(12):box('Individual deck plank',(-.82+i*.15,0,.045),(.145,.65,.065))
for x in [-.78,.78]:
 rod('Suspension stay',(x,0,1.65),(0,0,2.03),.022)
 wheel((x,0,-.16),.12)
for i in [-1,1]:brace((i*.84,.26,.1),(i*.68,.26,.70),.05)
box('Brake stand',(-.55,-.28,.28),(.09,.09,.5),iron);rod('Brake grip',(-.55,-.28,.53),(-.72,-.28,.68),.028)
render('cage',(0,0,.91),2.45);clear()
# A distinct headframe, with uneven solid posts and mortised angled braces.
for x in [-1,1]:
 o=box('Shaft upright',(x,.05,1.65),(.20,.24,3.3));o.rotation_euler.y=-x*.025
box('Crown timber',(0,.05,3.27),(2.5,.32,.24));box('Cross rail',(0,.13,2.61),(2.15,.17,.12))
brace((-1,0,2.38),(-.35,0,3.22),.16);brace((1,0,2.38),(.35,0,3.22),.16)
for x in [-1,1]:
 for z in [.1,2.57,3.28]:
  rod('Bolt',(x,-.14,z),(x,-.19,z),.035)
render('headframe',(0,0,1.62),3.65);clear()
wheel((0,0,0),.48);box('Bearing block',(0,.12,-.08),(.18,.15,.4),iron)
render('pulley',(0,0,0),1.12);clear()
for i in range(5):
 box('Stacked ballast',(0,0,.13+i*.22),(1.0-(i%2)*.03,.36,.21),iron)
for x in [-.4,.4]:box('Counterweight strap',(x,-.22,.57),(.055,.07,1.23),iron)
rod('Weight shackle',(-.2,0,1.12),(0,0,1.35),.035);rod('Weight shackle',(0,0,1.35),(.2,0,1.12),.035)
render('counterweight',(0,0,.64),1.6);clear()
box('Latch bracket',(0,0,0),(.32,.17,.55),iron)
rod('Sliding locking pin',(-.4,-.13,.1),(.34,-.13,.1),.055)
wheel((-.39,-.13,.1),.12)
for x in [-.10,.10]:rod('Mounting bolts',(x,-.09,-.18),(x,-.13,-.18),.025)
render('lock-pin',(-.04,0,0),.94);clear()
