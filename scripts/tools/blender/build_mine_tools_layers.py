import bpy, math
from mathutils import Vector
out="/Users/xiangxi.li/Documents/inkfall/assets/art/descent/mine-cart-escape-v1/props"
import os
os.makedirs(out,exist_ok=True)
bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine="CYCLES";s.cycles.samples=32;s.render.film_transparent=True
s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100
s.render.image_settings.file_format="PNG";s.render.image_settings.color_mode="RGBA";s.view_settings.view_transform="Standard";s.world.color=(.03,.03,.03)
def material(name,c):
 m=bpy.data.materials.new(name);m.diffuse_color=(c,c,c,1);m.use_nodes=True
 p=next((n for n in m.node_tree.nodes if n.type=="BSDF_PRINCIPLED"),None) or m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
 o=next((n for n in m.node_tree.nodes if n.type=="OUTPUT_MATERIAL"),None) or m.node_tree.nodes.new("ShaderNodeOutputMaterial")
 m.node_tree.links.new(p.outputs[0],o.inputs[0]);p.inputs["Base Color"].default_value=(c,c,c,1);p.inputs["Roughness"].default_value=.9
 return m
wood=material("Dark worn ash handles",.045);iron=material("Dull forged iron",.085)
def rod(a,b,r,mat):
 a,b=Vector(a),Vector(b)
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=(b-a).length,location=(a+b)/2)
 o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat("Z","Y").to_euler();o.data.materials.append(mat)
def plate(name,points,depth,mat):
 v=[(x,y,z) for y in [-depth,depth] for x,z in points];n=len(points)
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
 for i in range(n):j=(i+1)%n;faces.append((i,j,j+n,i+n))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(v,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
 b=o.modifiers.new("Worn edges","BEVEL");b.width=.012;b.segments=2
groups={}
assigned=set()
def capture(name):
 items=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name not in assigned]
 groups[name]=items
 assigned.update(o.name for o in items)
# Capture construction groups before the original static render.
rod((-.32,0,0),(-.52,0,1.28),.027,wood)
plate("Forged pick head",[(-1.00,1.19),(-.80,1.29),(-.56,1.34),(-.33,1.32),(-.07,1.21),(-.32,1.25),(-.55,1.26),(-.80,1.24)],.035,iron)
capture("pick")
rod((.34,.05,0),(.51,.05,1.12),.025,wood)
plate("Worn hoe blade",[(.43,1.15),(.73,1.10),(.80,.84),(.54,.88),(.48,1.04)],.026,iron)
rod((.46,-.01,1.05),(.53,-.01,1.16),.046,iron)

capture("hoe")
# One compact working corner: a battered ground-supported rack behind the
# leaning tools, spare support boards, a bucket and a small coil at its foot.
def timber(name,loc,scale,angle=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name
 o.scale=scale;o.rotation_euler.y=angle;o.data.materials.append(wood)
 b=o.modifiers.new("Soft worn corners","BEVEL");b.width=.025;b.segments=2
 return o
timber("Left rack upright",(-.70,.16,.72),(.13,.15,1.44),-.035)
timber("Right rack upright",(.65,.16,.66),(.12,.15,1.32),.045)
timber("Tool resting crosspiece",(-.02,.12,.94),(1.52,.14,.12),.025)
timber("Low brace",(-.02,.20,.25),(1.45,.10,.08),-.03)
for x in [-.70,.65]:
 rod((x,-.02,.94),(x,.12,.94),.021,iron)
capture("rack")
timber("Spare short board",(-.91,.22,.37),(.16,.12,.74),-.15)
timber("Spare long board",(-1.03,.25,.44),(.15,.10,.88),-.18)
capture("boards")
# Hollow tapered bucket with band and a bent handle; neither a solid cylinder
# nor a separate item in a display row.
v=[];f=[];rings=[(.16,.015),(.20,.34),(.18,.34),(.14,.04)]
for j,(r,z) in enumerate(rings):
 for i in range(24):
  angle=math.tau*i/24
  v.append((-.05+r*math.cos(angle),-.12+r*math.sin(angle),z))
for j in range(3):
 for i in range(24):
  k=j*24+i;n=j*24+(i+1)%24;f.append((k,n,n+24,k+24))
mesh=bpy.data.meshes.new("Bucket");mesh.from_pydata(v,[],f);mesh.update()
o=bpy.data.objects.new("Old empty bucket",mesh);bpy.context.collection.objects.link(o);o.data.materials.append(iron)
for i in range(12):
 a=math.pi*i/12;b=math.pi*(i+1)/12
 rod((-.05+.19*math.cos(a),-.12,.29+.23*math.sin(a)),(-.05+.19*math.cos(b),-.12,.29+.23*math.sin(b)),.011,iron)
capture("bucket")
for i in range(4):
 bpy.ops.mesh.primitive_torus_add(major_radius=.14-i*.025,minor_radius=.017,major_segments=28,minor_segments=8,location=(.76,-.10,.16),rotation=(math.pi/2,0,-.18))
 bpy.context.object.data.materials.append(wood)
capture("coil")
bpy.ops.object.camera_add(location=(0,-6,.83));cam=bpy.context.object
cam.rotation_euler=(Vector((-.10,0,.70))-cam.location).to_track_quat("-Z","Y").to_euler()
cam.data.type="ORTHO";cam.data.ortho_scale=2.45;s.camera=cam
bpy.ops.object.light_add(type="AREA",location=(-1,-3,4));lamp=bpy.context.object;lamp.data.energy=250;lamp.data.size=3
lamp.rotation_euler=(Vector((0,0,.5))-lamp.location).to_track_quat("-Z","Y").to_euler()
for name,objects in groups.items():
 for o in bpy.context.scene.objects:
  if o.type=='MESH':o.hide_render=o not in objects
 s.render.filepath=out+'/'+name+'.png'
 bpy.ops.render.render(write_still=True)
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=out+'/tools-layered.blend')
