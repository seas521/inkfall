"""Build the approved mine-room contact layout as textureless, lit volumes.
Independent camera-visible passes retain shadows from every other collection.
Coordinates match the game's 1671x941 design canvas; no gameplay changes.
"""
import bpy, bmesh, math, os, random, json
from mathutils import Vector
from mathutils.geometry import tessellate_polygon
ROOT='/Users/xiangxi.li/Documents/inkfall'
OUT=ROOT+'/assets/art/descent/mine-pair-v2'
os.makedirs(OUT,exist_ok=True)
random.seed(2704)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=20;s.cycles.use_denoising=True
s.cycles.max_bounces=5;s.cycles.diffuse_bounces=1;s.cycles.glossy_bounces=1
s.render.resolution_x=3342;s.render.resolution_y=1882;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8'
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
s.world.use_nodes=True;s.world.node_tree.nodes.get('Background').inputs[0].default_value=(.001,.001,.001,1)
s.world.node_tree.nodes.get('Background').inputs[1].default_value=.12
COL={}
for key in ['depth','structure','foreground']:
 c=bpy.data.collections.new(key);s.collection.children.link(c);COL[key]=c
layer='structure';theta=.10;scale=.01

def P(x,v,d=0):return Vector((x*scale,d*scale,(-v/math.cos(theta)-d*math.tan(theta))*scale))
def register(o,name,material):
 o.name=name
 for c in list(o.users_collection):c.objects.unlink(o)
 COL[layer].objects.link(o)
 if material:o.data.materials.append(material)
 return o

def material(name,value):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(value,value,value,1)
 p.inputs['Roughness'].default_value=1.0;p.inputs['Specular IOR Level'].default_value=0.0
 return m
wood=material('Unpainted dark timber - no grain',.026)
endwood=material('Cut timber end',.018)
iron=material('Dull forged iron - no rim paint',.018)
rock=material('Broad stone planes - no texture',.028)
farrock=material('Recessed stone',.085)
farwood=material('Receding gallery wood',.052)
soil=material('Compacted earth',.035)

def box(name,at,size,mat=wood,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=P(*at));o=register(bpy.context.object,name,mat)
 o.scale=Vector(size)*scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 # No bevel or weighted smoothing: long rounded edge highlights read as plastic.
 return o

def beam(name,a,b,width=14,depth=20,mat=wood):
 # Hewn structural timber: large quiet facets, restrained taper, a few
 # compressed/chipped corners. No grain map and no repeated wavy outline.
 A=P(*a);B=P(*b);axis=(B-A).normalized()
 basis=axis.to_track_quat('Z','Y').to_matrix()
 u=basis@Vector((1,0,0));v=basis@Vector((0,1,0))
 local=random.Random(name+str(a)+str(b))
 sections=[0,.19,.57,.83,1]
 verts=[]
 for j,t in enumerate(sections):
  centre=A.lerp(B,t)
  # Preserve end joints; the small bow is individual, not sinusoidal noise.
  if j not in [0,len(sections)-1]:centre+=u*(local.uniform(-.038,.038)*width*scale)
  halfw=width*.5*scale*local.uniform(.93,1.03)
  halfd=depth*.5*scale*local.uniform(.91,1.02)
  corner=.12
  ring=[(-1,-1+corner),(-1+corner,-1),(1-corner,-1),(1,-1+corner),(1,1-corner),(1-corner,1),(-1+corner,1),(-1,1-corner)]
  for x,y in ring:verts.append(centre+u*x*halfw+v*y*halfd)
 faces=[tuple(reversed(range(8))),tuple(range(32,40))]
 for j in range(4):
  for i in range(8):faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 o=bpy.data.objects.new(name,mesh);COL[layer].objects.link(o);o.data.materials.append(mat)
 return o

def rod(name,a,b,r=1.5,mat=iron):
 A=P(*a);B=P(*b);bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r*scale,depth=(A-B).length,location=(A+B)/2)
 o=register(bpy.context.object,name,mat);o.rotation_euler=(B-A).to_track_quat('Z','Y').to_euler();return o

def profile(name,points,d0,d1,mat=rock,bevel=3):
 verts=[P(x,v,d) for d in [d0,d1] for x,v in points];n=len(points)
 front=[Vector((x,v,0)) for x,v in points];tri=tessellate_polygon([front])
 index={tuple(v):i for i,v in enumerate(front)}
 faces=[]
 for t in tri:
  ids=[v if isinstance(v,int) else index[tuple(v)] for v in t];faces.append(tuple(ids));faces.append(tuple(i+n for i in reversed(ids)))
 for i in range(n):j=(i+1)%n;faces.append((i,j,j+n,i+n))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 o=bpy.data.objects.new(name,mesh);COL[layer].objects.link(o);o.data.materials.append(mat)
 # The broad natural contour is authoritative; do not bevel it into a tube.
 return o

def curved_bar(name,points,r=1.2,mat=iron):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=16;c.bevel_depth=r*scale;c.bevel_resolution=3
 spl=c.splines.new('BEZIER');spl.bezier_points.add(len(points)-1)
 for bp,p in zip(spl.bezier_points,points):bp.co=P(*p);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,c);COL[layer].objects.link(o);o.data.materials.append(mat);return o

def deck(name,x0,x1,v,depth=92):
 # The physical top crosses the character's contact line at depth zero.
 # Far and front edges are genuinely separated in depth, not bright strokes.
 for i in range(math.ceil((x1-x0)/19)):
  a=x0+i*19;b=min(x1,a+18.3)
  box(name+' plank',((a+b)/2,v+4,0),(b-a,depth,8),wood,.65)
 for d in [-depth/2+6,depth/2-6]:beam(name+' bearer',(x0,v+15,d),(x1,v+15,d),19,14)

# FAR: enclosed geology, shadow-receiving rear surfaces and rooted galleries.
layer='depth'
box('Solid distant cavern wall',(835,465,470),(2150,22,1400),farrock,4)
# Broad irregular buttresses frame the void, without rock-grain speckles.
profile('Back left geological shoulder',[(-250,-200),(230,-200),(200,60),(105,230),(180,420),(140,620),(280,850),(210,1110),(-250,1200)],300,440,farrock,14)
profile('Back right geological shoulder',[(1400,-200),(1900,-200),(1900,1200),(1290,1200),(1430,900),(1460,730),(1540,590),(1460,350)],340,450,farrock,14)
# A real black adit is recessed behind a low stone header and separate sides.
black=material('Unlit recess',.001)
box('Lower adit black inner wall',(790,765,425),(180,10,200),black,0)
for x in [690,890]:beam('Far adit jamb',(x,650,370),(x,850,370),19,24,farwood)
beam('Far adit lintel',(675,650,370),(905,650,370),22,28,farwood)
box('Rear ground',(780,861,350),(1400,420,22),farrock,3)
# One long diagonal rear gallery, one cropped secondary landing. No grid.
for d in [210,255]:
 beam('Rear gallery girder',(300,205,d),(1390,450,d),17,12,farwood)
 beam('Rear gallery hand rail',(300,161,d),(1390,406,d),4,5,farwood)
 for i in range(12):
  x=310+i*92;v=205+(x-300)*245/1090
  beam('Rear railing upright',(x,v,d),(x,v-44,d),3,4,farwood)
for x,v,bottom in [(820,322,852),(1120,389,900)]:
 beam('Rear load column',(x,v,240),(x,bottom,240),26,30,farwood)
 beam('Rear corbel',(x,v+95,240),(x+110,v+25,240),14,16,farwood)
beam('Cropped rear service shelf',(1360,330,300),(1820,210,300),25,70,farwood)
# Small grounded stacked supply shapes, deliberately quiet.
for x,v,w,h in [(650,830,27,31),(930,830,31,34),(957,818,26,45)]:box('Distant grounded stores',(x,v-h/2,360),(w,25,h),farwood,1)

# PLAY PLANE: actual volumes, grouped supports and a clear path.
layer='structure'
deck('Main unloading deck',280,980,495,100)
deck('Upper hand-winch service deck',140,440,300,86)
# Rear supports: substantial depth, fewer repeated picture-frame shapes.
for x,bottom in [(344,851),(640,849),(945,767)]:
 beam('Rear service pier',(x,520,68),(x,bottom,68),22,26)
beam('Lower left knee brace',(346,750,68),(495,520,68),19,24)
beam('Lower right knee brace',(939,752,68),(760,520,68),19,24)
beam('Back lower tie',(344,608,72),(945,608,72),16,22)
for x in [160,414]:
 beam('Upper platform post',(x,316,44),(x,491,44),18,24)
beam('Upper deck knee',(165,433,44),(275,316,44),15,18)
# Accepted headframe location, paired front/back legs show stance and width.
for d in [60,-12]:
 beam('Headframe left splayed leg',(380,489,d),(465,132,d),30,30)
 beam('Headframe right splayed leg',(693,489,d),(598,132,d),32,32)
for d in [-25,36]:beam('Joined headframe crown',(449,136,d),(620,136,d),15,19)
beam('Headframe left mortise brace',(420,301,20),(525,145,20),13,16)
beam('Headframe right mortise brace',(665,379,42),(555,150,42),12,16)
for x in [379,693]:
 box('Embedded iron foot shoe',(x,484,-12),(35,35,12),iron,0)
 # Foot stones are broad slabs rooted in rock, never free-floating pads.
 profile('Embedded footing stone',[(x-27,495),(x-25,491),(x-6,489),(x+19,490),(x+26,494),(x+24,500),(x-28,500)],-18,38,rock,0)
# A few iron collars have real surfaces but no white decorative rivet dots.
for x,v in [(450,223),(644,302),(688,470)]:box('Headframe flat iron collar',(x,v,-30),(35,3,19),iron,.5)
# Fixed hoist portal: columns recessed outside future vehicle travel lane.
for x in [1100,1340]:beam('Capture rig guide support',(x,425,58),(x,658,58),19,22)
beam('Capture rig crown',(1090,425,58),(1350,425,58),25,34)
beam('Capture rig brace left',(1100,475,58),(1154,425,58),12,15)
beam('Capture rig brace right',(1340,475,58),(1286,425,58),12,15)
# Short descending stair, same takeoff/landing as the accepted collision.
for d in [-34,38]:
 beam('Stair stringer',(975,504,d),(1100,663,d),16,14)
 for i in range(3):
  t=i/2;x=975+125*t;v=495+163*t
  beam('Stair balustrade',(x,v,d),(x,v-47,d),4,5)
 beam('Stair handrail',(975,448,d),(1100,611,d),5,6)
for i in range(9):
 t=(i+.5)/9;x=975+125*t;v=495+163*t
 box('Individual solid stair tread',(x,v,0),(21,88,7),wood,.7)
# Fixed ladders: actual empty rung gaps, no opaque image rectangles.
def ladder(name,x,top,bottom,d=-52):
 for side in [-14,14]:beam(name+' rail',(x+side,top,d),(x+side,bottom,d),4.4,6)
 for i in range(math.floor((bottom-top)/19)+1):
  v=top+i*19+5;beam(name+' rung',(x-14,v,d-1),(x+14,v,d-1),3.6,5)
ladder('Upper fixed ladder',244,302,492)
ladder('Pit wall ladder',295,503,846)
# Anchored, grouped maintenance props. Empty plank top is reserved for winch.
for x in [225,270]:
 rod('Tool wall peg',(x,193,50),(x,193,28),1.8)
 rod('Hung pick handle',(x,194,30),(x+1,253,30),2,wood)
 curved_bar('Forged pick head',[(x-18,201,30),(x-9,194,30),(x,193,30),(x+13,197,30),(x+20,204,30)],1.8)
for j in range(4):
 a=j*.7
 pts=[(319+12*math.cos(t),225+27*math.sin(t),30+j) for t in [i*math.tau/12 for i in range(13)]]
 curved_bar('Coiled spare line',pts,1.05,wood)
rod('Rope hook',(319,195,55),(319,195,25),2)
# Lower tools lean on a rack that has four feet on the lower earth.
for x in [365,447]:
 for d in [2,33]:beam('Lower tool rack grounded leg',(x,849,d),(x-5,779,d),6,7)
for v in [784,823]:beam('Lower rack cross rail',(358,v,2),(449,v,2),8,12)
for i in range(3):
 x=376+i*25
 rod('Leaning shovel handle',(x,757,-2),(x+9,829,-10),1.8,wood)
 box('Broad shovel blade',(x+11,835,-10),(12,3,21),iron,2)
# Two crate silhouettes stay behind the walking lane, not in the player's feet.
def crate(x,bottom,size,d=38):
 box('Grounded supply crate',(x,bottom-size/2,d),(size,size*.7,size),endwood,1)
 for side in [-1,1]:beam('Crate corner',(x+side*(size/2-3),bottom,d-size*.37),(x+side*(size/2-3),bottom-size,d-size*.37),4,4)
 beam('Crate diagonal',(x-size/2+4,bottom-3,d-size*.37),(x+size/2-4,bottom-size+3,d-size*.37),4,4)
crate(612,490,40,50);crate(603,448,33,52);crate(209,298,31,40)
# Sign fixed into the entry rock, deliberately without pictogram decals.
beam('Warning sign rooted post',(141,489,-6),(150,436,-6),6,8)
box('Worn warning sign',(150,438,-10),(43,7,22),wood,1)

# FRONT: geology and deck fascias have real thickness, no painted grain.
layer='foreground'
profile('Left bank rooted rock',[(-120,510),(65,494),(195,492),(269,497),(272,576),(249,652),(262,730),(252,811),(285,852),(213,920),(-120,1080)],-70,90,rock,7)
profile('Lower solid mine floor',[(215,856),(356,851),(530,855),(700,853),(880,848),(950,831),(1070,986),(1700,1180),(-120,1180),(-120,950)],-100,180,soil,5)
profile('Right rooted rail rock',[(979,665),(1100,659),(1300,658),(1510,658),(1780,661),(1800,1200),(795,1200),(877,894),(930,820),(949,742)],-80,130,rock,6)
profile('Continuous cavern overburden',[(-120,-200),(1800,-200),(1800,493),(1671,407),(1530,264),(1295,151),(1070,118),(856,54),(707,24),(470,5),(285,45),(182,116),(86,227),(-120,480)],-80,130,rock,9)
# The visible ground plane is split at actor depth zero: its rear half
# receives light BEHIND the actor; the front half can only cover the soles.
layer='structure'
box('Rear half lower earth',(587,860,65),(714,130,10),soil,1.5)
box('Rear half rail earth',(1380,663,55),(800,110,10),soil,1.5)
layer='foreground'
box('Front half lower earth',(587,860,-35),(714,70,10),soil,1.5)
box('Front half rail earth',(1380,663,-35),(800,70,10),soil,1.5)
# Near-facing fascia occludes only below the actor's feet. No duplicate texture.
beam('Front middle deck fascia',(280,509,-49),(979,509,-49),18,12)
beam('Front upper deck fascia',(140,314,-43),(440,314,-43),17,12)
# A cropped foreground footing supplies a near plane without another black grid.
beam('Near lower pier',(910,591,-52),(910,831,-52),23,25)
beam('Near upper corbel',(910,643,-52),(823,529,-52),16,20)

# Practical light placement corresponds to the four independent game fixtures.
def light(name,x,v,power,size_px,target,depth=-68):
 bpy.ops.object.light_add(type='SPOT',location=P(x,v,depth));o=bpy.context.object;o.name=name
 o.data.energy=power*.65;o.data.spot_size=math.radians(96);o.data.spot_blend=.65;o.data.shadow_soft_size=.085;o.data.color=(1,1,1)
 o.rotation_euler=(P(*target)-o.location).to_track_quat('-Z','Y').to_euler()
light('Upper service lamp',290,135,160,28,(288,308,40))
light('Middle working lamp',755,325,125,24,(735,525,80))
light('Lower loading lamp',525,665,115,28,(550,865,120))
light('Receiving rail lamp',1475,555,140,26,(1460,675,45))
# Very broad rear bounce: separates masses without a bright silhouette outline.
# No studio/rim fill: practical shaded lamps alone illuminate timber.
center=P(835.5,470.5,0)
bpy.ops.object.camera_add(location=center+Vector((0,-math.cos(theta)*25,math.sin(theta)*25)))
cam=bpy.context.object;cam.name='Locked game side camera';cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=16.71
cam.data.lens=50;s.camera=cam
s.render.film_transparent=True
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/artifacts/mine-pair-volume-v1/source/mine-pair-volume.blend')
meshes=[o for o in s.objects if o.type in ['MESH','CURVE']]
for key in ['depth','structure','foreground']:
 selected=set(COL[key].objects)
 for o in meshes:o.visible_camera=o in selected
 s.render.film_transparent=key!='depth'
 s.render.filepath=OUT+'/'+key+'.png';bpy.ops.render.render(write_still=True)
with open(OUT+'/layout.json','w') as f:json.dump({'design_size':[1671,941],'origin':[-665,-3545],'render_size':[3342,1882],'camera_elevation_radians':theta,'layers':list(COL),'material_policy':'No color textures; geometry, shadows, diffuse light and subtle face separation'},f,indent=2)
print('MINE PAIR VOLUME RENDER COMPLETE')
