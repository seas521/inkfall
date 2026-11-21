extends Node2D
# Complete river environment. Both banks use the same full top profiles as
# collision; water, distant air and near bank are separate spatial layers.
# No bank-photo borders, terrain joins or small patches remain.
const TRUNKS=preload("res://assets/art/c_zone_debug/forest/foreground-trunks-volume-v57.png")
const REEDS=preload("res://assets/art/c_zone_debug/river-v66/reed-sedge-clumps.png")
const INK:=Color("050606")
var art:Node2D
var remote:ColorRect
var material_far:ShaderMaterial
var shores:Node2D
var near_bank:Node2D
var near_views:Array[SubViewport]=[]
var shore_parts:Array[Node2D]=[]
const TREE_SHADER="""shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec4 s=texture(TEXTURE,UV);
 vec2 d=TEXTURE_PIXEL_SIZE*1.1;
 vec3 broad=s.rgb*.5+(texture(TEXTURE,UV+vec2(d.x,0)).rgb+texture(TEXTURE,UV-vec2(d.x,0)).rgb+texture(TEXTURE,UV+vec2(0,d.y)).rgb+texture(TEXTURE,UV-vec2(0,d.y)).rgb)*.125;
 float l=dot(broad,vec3(.299,.587,.114));
 float alpha=smoothstep(.04,.96,s.a);
 COLOR=vec4(vec3(.00035+l*.075),alpha);
}
"""
func setup(host:Node2D,back:Node)->void:
 art=host
 remote=ColorRect.new();remote.size=Vector2(1280,720);remote.mouse_filter=Control.MOUSE_FILTER_IGNORE
 material_far=ShaderMaterial.new();material_far.shader=preload("res://assets/shaders/river_cove_v59.gdshader")
 remote.material=material_far;remote.z_index=20;back.add_child(remote);remote.hide()
 shores=Node2D.new();shores.z_index=-2;shores.draw.connect(_draw_shores)
 var shore_shader:=Shader.new()
 shore_shader.code="""shader_type canvas_item;
render_mode unshaded;
void fragment(){ /* Opaque land; water owns its complete optical response. */ }
"""
 var shore_material:=ShaderMaterial.new();shore_material.shader=shore_shader;shores.material=shore_material
 shores.add_to_group(&"chapter_gameplay_focus");add_child(shores);shore_parts.append(shores)
 var tree_material:=ShaderMaterial.new();tree_material.shader=Shader.new();tree_material.shader.code=TREE_SHADER
 # Trees belong behind the walking bank. Opaque soil hides all below-ground
 # roots; neither the actor nor the ground is clipped to fake this overlap.
 for spec in [Vector4(845,0,990,.55),Vector4(2520,1,930,.49)]:
  var atlas:=AtlasTexture.new();atlas.atlas=TRUNKS;atlas.region=Rect2(spec.y*768.,0,768,1024);atlas.filter_clip=true
  var tree:=Sprite2D.new();tree.texture=atlas;tree.centered=false
  tree.scale=Vector2(spec.w,spec.z/1024.)
  var floor_y:float=art.level.ground_y(spec.x)
  tree.position=Vector2(spec.x-384.*spec.w,floor_y+98.-spec.z)
  tree.material=tree_material;tree.z_index=-4;tree.name="bank_tree_"+str(int(spec.x));add_child(tree)
 near_bank=Node2D.new();near_bank.draw.connect(_draw_near_bank)
 var raw:=SubViewport.new();raw.size=Vector2i(1408,1024);raw.transparent_bg=true;raw.disable_3d=true
 add_child(raw);raw.add_child(near_bank);near_views.append(raw)
 raw.canvas_transform=Transform2D(0.,Vector2(.75,.75),0.,-Vector2(1260,420)*.75)
 var horizontal:=SubViewport.new();horizontal.size=raw.size;horizontal.transparent_bg=true;horizontal.disable_3d=true;add_child(horizontal);near_views.append(horizontal)
 var first:=Sprite2D.new();first.centered=false;first.texture=raw.get_texture();first.material=_near_blur(Vector2.RIGHT);horizontal.add_child(first)
 var output:=Sprite2D.new();output.centered=false;output.texture=horizontal.get_texture();output.material=_near_blur(Vector2.DOWN)
 output.position=Vector2(1260,420);output.scale=Vector2.ONE/.75;output.z_index=12;add_child(output)
 _build_reeds()
 for viewport in near_views:viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 shores.queue_redraw();near_bank.queue_redraw();hide()
func _near_blur(direction:Vector2)->ShaderMaterial:
 var shader:=Shader.new()
 shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform vec2 direction=vec2(1.,0.);
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*direction*2.;
 vec4 c=texture(TEXTURE,UV)*.227027;
 c+=(texture(TEXTURE,UV+d*1.384615)+texture(TEXTURE,UV-d*1.384615))*.316216;
 c+=(texture(TEXTURE,UV+d*3.230769)+texture(TEXTURE,UV-d*3.230769))*.070270;
 COLOR=c;
}
"""
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("direction",direction);return material
func sync(enabled:bool,time:float)->void:
 # World geometry is built/warmed at setup and remains present throughout
 # the valley context, including preview, wide framing and return travel.
 # Do not gate it by the player or camera centre while it is still visible.
 visible=enabled;remote.visible=enabled
 if not enabled:return
 var level=art.level
 var inverse:Transform2D=level.get_canvas_transform().affine_inverse()
 var size:Vector2=level.get_viewport_rect().size
 var origin:=inverse*Vector2.ZERO
 material_far.set_shader_parameter("world_origin",origin-art.position)
 material_far.set_shader_parameter("world_axis_x",inverse*Vector2(size.x,0)-origin)
 material_far.set_shader_parameter("world_axis_y",inverse*Vector2(0,size.y)-origin)
 material_far.set_shader_parameter("clock",time)
func _process(_delta:float)->void:
 if visible and not art.level.is_visible_in_tree():hide();remote.hide()
func _draw_shores()->void:
 for profile in [art.level.LEFT_PROFILE,art.level.RIGHT_PROFILE]:
  var edge:=PackedVector2Array()
  var start:float=profile[0].x
  var end:float=profile[-2].x
  for x in range(int(start),int(end),4):
   edge.append(Vector2(x,art._bank_edge_y(x)))
  edge.append(Vector2(end,art._bank_edge_y(end)))
  var solid:=edge.duplicate()
  solid.append(Vector2(end,1600));solid.append(Vector2(start,1600))
  if start<0.:
   solid.append(Vector2(start-90.,720));solid.append(Vector2(start-35.,310))
  shores.draw_colored_polygon(solid,INK)
  shores.draw_polyline(edge,INK,1.6,true)
func _near_bank_contour()->PackedVector2Array:
 var anchors:=PackedVector2Array([Vector2(1300,1170),Vector2(1490,1090),Vector2(1670,1000),Vector2(1860,915),Vector2(2060,840),Vector2(2250,790),Vector2(2450,735),Vector2(2660,700),Vector2(2920,690)])
 var edge:=PackedVector2Array()
 for j in anchors.size()-1:
  for i in 12:
   var p:Vector2=anchors[j].lerp(anchors[j+1],i/12.)
   p.y+=sin(p.x*.021)*3.8+sin(p.x*.054)*1.3
   edge.append(p)
 edge.append(anchors[-1])
 return edge
func _draw_near_bank()->void:
 var edge:=_near_bank_contour()
 var mass:=edge.duplicate();mass.append(Vector2(3100,1800));mass.append(Vector2(1300,1800))
 near_bank.draw_colored_polygon(mass,INK)
func _build_reeds()->void:
 var edge:=_near_bank_contour()
 var shader:=Shader.new()
 shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform vec4 atlas_region=vec4(0.,0.,1.,1.);
void fragment(){
 vec2 local=(UV-atlas_region.xy)/atlas_region.zw;
 float a=texture(TEXTURE,UV).a;
 a=smoothstep(.005,.15,a);
 a*=smoothstep(0.,.025,local.x)*(1.-smoothstep(.975,1.,local.x));
 COLOR=vec4(vec3(.0005),a);
}
"""
 var rng:=RandomNumberGenerator.new();rng.seed=67043
 var size:Vector2=REEDS.get_size()
 var materials:Array[ShaderMaterial]=[]
 var rows:Array[Node2D]=[]
 for column in 3:
  var mat:=ShaderMaterial.new();mat.shader=shader
  mat.set_shader_parameter("atlas_region",Vector4(column/3.,0.,1./3.,1.))
  materials.append(mat)
  var row:=Node2D.new();near_bank.add_child(row);rows.append(row)
 # A continuous low sedge bed with overlapping tall reeds growing through
 # it. Shared atlas/material groups keep the dense shoreline inexpensive.
 for layer in 2:
  var i:=3+layer*2
  while i<edge.size()-1:
   var column:=1 if layer==0 else (0 if rng.randf()<.5 else 2)
   var region:=Rect2(column*size.x/3.,0,size.x/3.,size.y)
   var atlas:=AtlasTexture.new();atlas.atlas=REEDS;atlas.region=region;atlas.filter_clip=true
   var plant:=Sprite2D.new();plant.texture=atlas;plant.centered=false
   plant.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
   var height:float=rng.randf_range(100.,160.) if layer==0 else rng.randf_range(145.,225.)
   var factor:=height/(size.y*.88)
   plant.scale=Vector2.ONE*factor;plant.flip_h=rng.randf()<.5
   plant.position=edge[i]-Vector2(region.size.x*.5,size.y*.93)*factor+Vector2(rng.randf_range(-7.,7.),rng.randf_range(7.,15.))
   plant.material=materials[column];rows[column].add_child(plant)
   i+=rng.randi_range(1,2) if layer==0 else rng.randi_range(2,4)
