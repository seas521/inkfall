extends Node2D
# Approved v41 composition: photographed far light, quiet hills, independent
# middle trunks and sparse close silhouettes. Never populate the playable path.
const FAR=preload("res://assets/art/c_zone_debug/valley-v42/far-light-forest.png")
const ATLAS=preload("res://assets/art/c_zone_debug/valley-v42/mid-trunk-atlas.png")
const INK=preload("res://assets/shaders/valley_trunk_v42.gdshader")
const FAR_SHADER=preload("res://assets/shaders/valley_far_v42.gdshader")
const REGIONS=[Rect2(0,0,512,960),Rect2(512,0,512,960),Rect2(1024,0,512,960)]
var trees:Array=[]
var light:ColorRect
var clock:=0.
var banks:Node2D
var camera_x:=0.
var camera_y:=0.
var framing_zoom:=1.0
func _ready()->void:
 light=ColorRect.new();light.size=Vector2(1280,720);light.mouse_filter=Control.MOUSE_FILTER_IGNORE
 light.material=ShaderMaterial.new();light.material.shader=FAR_SHADER;light.material.set_shader_parameter("forest",FAR);add_child(light)
 banks=Node2D.new();banks.draw.connect(_draw_banks);add_child(banks)
 # Unequal authored gaps keep the boy, rock pile and mechanism silhouettes open.
 var stations=[[-320.,480.,1320.,2210.,3100.,3970.],[300.,1070.,1920.,2700.,3710.,4500.,5300.,6210.],[1120.,2360.,4200.,5560.,7050.,8500.]]
 for depth in 3:
  for i in stations[depth].size():
   var x:float=stations[depth][i]
   # Leave the river vista open. Omit these authored trunks permanently,
   # rather than fading trees as the boat passes; inland placements stay intact.
   if (depth==1 and i==1) or (depth==2 and i==0):continue
   var atlas=AtlasTexture.new();atlas.atlas=ATLAS;atlas.region=REGIONS[(i+depth)%3];atlas.filter_clip=true
   var tree=Sprite2D.new();tree.texture=atlas;tree.flip_h=(i%3==1)
   var height:float=[850.,1090.,1290.][depth]+sin(i*3.1+depth)*95.
   tree.scale=Vector2([.40,.51,.56][depth],1.)*height/960.
   tree.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
   var mat=ShaderMaterial.new();mat.shader=INK
   mat.set_shader_parameter("tone",[.042,.019,.009][depth]);mat.set_shader_parameter("strength",[.24,.54,.77][depth])
   mat.set_shader_parameter("softness",[9.,4.5,2.][depth]);mat.set_shader_parameter("root_haze",1.0)
   tree.material=mat;add_child(tree)
   trees.append({"sprite":tree,"x":x,"height":height,"root":[525.,590.,650.][depth]+sin(i*1.7)*30.,"ratio":[.15,.30,.48][depth],"scale":tree.scale})
func sync(cx:float,cy:float,enabled:bool,lens_zoom:float=1.0)->void:
 visible=enabled
 if not enabled:return
 camera_x=cx;camera_y=cy;framing_zoom=lens_zoom;clock+=get_process_delta_time()
 light.material.set_shader_parameter("framing_zoom",lens_zoom)
 banks.scale=Vector2.ONE*lens_zoom;banks.position=Vector2(640,360)*(1.-lens_zoom)
 light.material.set_shader_parameter("scroll",cx);light.material.set_shader_parameter("camera_y",cy);light.material.set_shader_parameter("clock",clock)
 for item in trees:
  var tree:Sprite2D=item.sprite
  tree.position=Vector2(640,360)+(Vector2(item.x-cx*item.ratio,item.root-cy*item.ratio-item.height*.5)-Vector2(640,360))*lens_zoom
  tree.scale=item.scale*lens_zoom
  tree.visible=tree.position.x> -500 and tree.position.x<1780
 banks.queue_redraw()
func _draw_banks()->void:
 # A separate, broad rear bank drifts between the distant light and middle trees.
 # Its low contrast never reads as a new playable platform or horizontal fog strip.
 var poly=PackedVector2Array()
 for sx in range(-400,1681,32):
  var wx=float(sx)+camera_x*.19
  var y=595.+sin(wx*.0021)*49.+sin(wx*.0047+.8)*20.-camera_y*.19
  poly.append(Vector2(sx,y))
 var bottom:=1200.
 for point in poly:bottom=maxf(bottom,point.y+300.)
 poly.append(Vector2(1680,bottom));poly.append(Vector2(-400,bottom))
 banks.draw_colored_polygon(poly,Color(.008,.008,.008,.18))
