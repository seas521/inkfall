import bpy, random, math, os
from mathutils import Vector
random.seed(318)
out="/Users/xiangxi.li/Documents/inkfall/assets/art/descent/mine-v12"
bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
s=bpy.context.scene
s.render.engine="CYCLES"; s.cycles.samples=24
s.render.film_transparent=True
s.render.image_settings.file_format="PNG";s.render.image_settings.color_mode="RGBA"
s.view_settings.view_transform="Standard"
s.world.color=(0.04,0.04,0.04)
def mat(name,v):
 m=bpy.data.materials.new(name);m.diffuse_color=(v,v,v,1);m.use_nodes=True
 p=next((n for n in m.node_tree.nodes if n.type=="BSDF_PRINCIPLED"),None) or m.node_tree.nodes.new("ShaderNodeBsdfPrincipled");output=next((n for n in m.node_tree.nodes if n.type=="OUTPUT_MATERIAL"),None) or m.node_tree.nodes.new("ShaderNodeOutputMaterial");m.node_tree.links.new(p.outputs[0],output.inputs[0]);p.inputs["Base Color"].default_value=(v,v,v,1);p.inputs["Roughness"].default_value=.9
 return m
rock=mat("Weathered dark stone",.065);wood=mat("Charred wood",.022);iron=mat("Blackened iron",.035);cloth=mat("Wound cloth",.12)
bpy.ops.object.camera_add(location=(0,-8,0));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat("-Z","Y").to_euler();cam.data.type="ORTHO";s.camera=cam
bpy.ops.object.light_add(type="AREA",location=(-2,-4,5));lamp=bpy.context.object;lamp.data.energy=420;lamp.data.size=4
lamp.rotation_euler=(Vector((0,0,0))-lamp.location).to_track_quat("-Z","Y").to_euler()
def clear():
 for o in list(bpy.data.objects):
  if o.type=="MESH":bpy.data.objects.remove(o,do_unlink=True)
def stone(loc,scale):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc);o=bpy.context.object
 for v in o.data.vertices:v.co*=random.uniform(.87,1.10)
 o.scale=scale;o.rotation_euler=(random.random()*.2,random.random()*.2,random.random()*.3);o.data.materials.append(rock)
 b=o.modifiers.new("Soft worn corners","BEVEL");b.width=.03;b.segments=2
 return o
def render(name,w,h,span):
 s.render.resolution_x=w;s.render.resolution_y=h;s.render.resolution_percentage=100;cam.data.ortho_scale=span;s.render.filepath=out+"/"+name+".png";bpy.ops.render.render(write_still=True)
for i in range(4):
 clear()
 bpy.ops.mesh.primitive_cube_add(size=1.5,location=(0,0,0));o=bpy.context.object
 for v in o.data.vertices:
  v.co.x+=random.uniform(-.09,.09);v.co.z+=random.uniform(-.07,.07)
 o.scale=(1,.5,.92);o.data.materials.append(rock)
 b=o.modifiers.new("Chipped masonry corners","BEVEL");b.width=.12;b.segments=2
 render("stone-"+str(i),256,256,1.8)
clear()
# Dense, irregular, transparent-edged track ballast, solid enough under sleepers.
for i in range(200):
 x=random.uniform(-4,4);z=random.uniform(-.31,.05)
 stone((x,random.uniform(-.12,.22),z),(random.uniform(.06,.18),.08,random.uniform(.04,.10)))
render("ballast",1024,128,8.6)
clear()
bpy.ops.mesh.primitive_cylinder_add(vertices=14,radius=.06,depth=1.2,location=(0,0,0));bpy.context.object.data.materials.append(wood)
for i in range(7):
 bpy.ops.mesh.primitive_torus_add(major_radius=.075+i*.002,minor_radius=.023,major_segments=18,minor_segments=6,location=(0,0,.35+i*.028));bpy.context.object.data.materials.append(cloth)
render("torch",128,512,1.55)
clear()

# Hollow iron basin: double-wall profile, an open interior and a chipped rim.
verts=[];faces=[];rings=[(.19,-.13),(.36,.02),(.48,.40),(.445,.40),(.32,.05),(.16,-.08)]
for j,(radius,z) in enumerate(rings):
 for i in range(48):
  a=i*math.tau/48;r=radius*(1+.006*math.sin(i*2.7))
  verts.append((r*math.cos(a),r*math.sin(a),z+(.008*math.sin(i*1.9) if j in [2,3] else 0)))
for j in range(len(rings)-1):
 for i in range(48):
  k=j*48+i;n=j*48+(i+1)%48
  faces.append((k,n,n+48,k+48))
mesh=bpy.data.meshes.new("Hollow riveted basin");mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new("Open fire bowl",mesh);bpy.context.collection.objects.link(o);o.data.materials.append(iron)
bevel=o.modifiers.new("Worn basin edges","BEVEL");bevel.width=.012;bevel.segments=2
def rod(a,b,r):
 mid=(Vector(a)+Vector(b))/2
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=(Vector(b)-Vector(a)).length,location=mid)
 o=bpy.context.object;o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat("Z","Y").to_euler();o.data.materials.append(iron)
for angle in [-math.pi/2,.55,2.6]:
 c=math.cos(angle);d=math.sin(angle)
 rod((.32*c,.32*d,.04),(.42*c,.42*d,-.55),.035)
 rod((.42*c,.42*d,-.55),(.52*c,.52*d,-.73),.035)
 rod((.52*c-.07,.52*d,-.73),(.52*c+.07,.52*d,-.73),.035)
 rod((.35*c,.35*d,.02),(.48*c,.48*d,.38),.025)
 for z,r in [(.08,.38),(.30,.46)]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.027,location=(r*c,r*d,z));bpy.context.object.data.materials.append(iron)
for i in range(9):
 stone((random.uniform(-.25,.25),random.uniform(-.23,.23),.04),(random.uniform(.05,.10),.08,.06))
# A low irregular rock footing rises out of the main earth, rather than hovering.
for i in range(7):
 stone((-.61+i*.20,random.uniform(-.08,.15),-.83),(random.uniform(.17,.25),.28,random.uniform(.10,.16)))
cam.location=(0,-8,1.6);cam.rotation_euler=(Vector((0,0,-.15))-cam.location).to_track_quat("-Z","Y").to_euler()
render("brazier",512,512,1.9)
bpy.ops.wm.save_as_mainfile(filepath=out+"/mine-props.blend")
