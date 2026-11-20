extends Node2D
# Registered 2D layers derived from the approved chiaroscuro v3 concept.
# Rear illumination remains luminous; near ink never lifts into gray faces.
const DEPTH=preload("res://assets/art/descent/mine-pair-v3/cavern-wall.png")
const GALLERY=preload("res://assets/art/descent/mine-pair-v3/far-gallery.png")
const BACK_SUPPORTS=preload("res://assets/art/descent/mine-pair-v3/back-supports.png")
const STRUCTURE=preload("res://assets/art/descent/mine-pair-v3/structure.png")
const FRONT=preload("res://assets/art/descent/mine-pair-v3/foreground.png")
const INK=preload("res://assets/shaders/mine_pair_layer.gdshader")
const SOURCE=preload("res://assets/art/descent/mine-pair-v3/environment-registered.png")
const REGISTERED=preload("res://assets/shaders/mine_pair_registered.gdshader")
const KIT=preload("res://assets/art/descent/mine-pair-v3/props.png")
const Parts=preload("res://scripts/chapters/mine_pair_parts.gd")
const LIGHT_RESPONSE=preload("res://assets/shaders/mine_pair_light_response.gdshader")
const Softness=preload("res://scripts/chapters/mine_cached_softness.gd")
const SIZE:=Vector2(1672,941)
var room
var far:Sprite2D
var far_gallery:Sprite2D
var back_supports:Sprite2D
var structure:Sprite2D
var foreground:Sprite2D
var mechanisms:Node2D
var layers:Array[Sprite2D]=[]
var cached_views:Array[SubViewport]=[]
func ink(value:float,softness:float,near:bool=false)->ShaderMaterial:
 var m:=ShaderMaterial.new();m.shader=INK
 m.set_shader_parameter("value_scale",value);m.set_shader_parameter("softness",softness)
 m.set_shader_parameter("near_ink",near);return m
func registered(role:int)->ShaderMaterial:
 var material:=ShaderMaterial.new();material.shader=REGISTERED
 material.set_shader_parameter("approved_tex",SOURCE);material.set_shader_parameter("clean_tex",DEPTH)
 material.set_shader_parameter("structure_mask",STRUCTURE);material.set_shader_parameter("foreground_mask",FRONT)
 material.set_shader_parameter("gallery_mask",GALLERY);material.set_shader_parameter("supports_mask",BACK_SUPPORTS)
 material.set_shader_parameter("props_mask",KIT);material.set_shader_parameter("layer_role",role)
 return material
func _ready()->void:
 _mass(Rect2(room.ORIGIN+Vector2(0,941),Vector2(3600,2600)))
 _mass(Rect2(room.ORIGIN-Vector2(0,800),Vector2(3600,800)))
 var wall_material:=registered(0);wall_material.set_shader_parameter("left_feather",.065)
 far=_plate(SOURCE,0,wall_material)
 back_supports=_plate(SOURCE,1,registered(4))
 far_gallery=_plate(SOURCE,2,registered(3))
 structure=_plate(SOURCE,3,registered(2))
 mechanisms=Parts.new();mechanisms.room=room;add_child(mechanisms)
 foreground=_plate(SOURCE,7,registered(1))
 _extension(far,0);_extension(foreground,7)
 var below:=Sprite2D.new();below.texture=foreground.texture;below.centered=false
 below.region_enabled=true;below.region_rect=Rect2(0,940,1672,1)
 below.position=room.ORIGIN+Vector2(0,941);below.scale=Vector2(1,2600)
 below.z_as_relative=false;below.z_index=7;below.material=foreground.material
 below.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(below)
 # A narrow near handrail, never an entire duplicated staircase in front
 # of the actor. The stringer belongs behind the character, not over him.
 var rail:=Line2D.new();rail.width=3;rail.antialiased=true;rail.default_color=Color(.003,.003,.003)
 rail.points=PackedVector2Array([room.ORIGIN+Vector2(970,480),room.ORIGIN+Vector2(1094,590)])
 rail.z_as_relative=false;rail.z_index=6;add_child(rail)
func _mass(bounds:Rect2)->void:
 var polygon:=Polygon2D.new();polygon.color=Color(.001,.001,.001)
 polygon.z_as_relative=false;polygon.z_index=0
 polygon.polygon=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
 add_child(polygon)
func _plate(texture:Texture2D,depth:int,material_value:Material)->Sprite2D:
 var view:=SubViewport.new();view.size=Vector2i(1672,941)
 view.transparent_bg=true;view.use_hdr_2d=true;view.disable_3d=true;view.world_2d=World2D.new()
 view.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(view);cached_views.append(view)
 var source:=Sprite2D.new();source.texture=texture;source.centered=false
 source.scale=SIZE/texture.get_size();source.material=material_value
 source.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;view.add_child(source)
 var sprite:=Sprite2D.new();sprite.texture=view.get_texture();sprite.centered=false;sprite.position=room.ORIGIN
 if depth==7:
  sprite.texture=Softness.texture(self,sprite.texture,1.5,true)
 sprite.z_as_relative=false;sprite.z_index=depth;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 var material:=ShaderMaterial.new();material.shader=LIGHT_RESPONSE
 material.set_shader_parameter("receives_light",depth<=2)
 sprite.material=material;add_child(sprite);layers.append(sprite)
 return sprite
func _extension(source:Sprite2D,depth:int)->void:
 var sprite:=Sprite2D.new();sprite.texture=source.texture;sprite.centered=false
 sprite.region_enabled=true;sprite.region_rect=Rect2(SIZE.x-256,0,256,941);sprite.flip_h=true
 sprite.position=room.ORIGIN+Vector2(SIZE.x,0);sprite.scale=Vector2(.24,1)
 sprite.z_as_relative=false;sprite.z_index=depth;sprite.material=source.material
 sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(sprite)
func sync()->void:
 # Keep the approved composition registered while the final layer mattes
 # are reviewed. Optical depth comes from original values/edge diffusion;
 # collision-bearing art never acquires camera-relative drift.
 if room.lamps.size()!=6:return
 var lights:=PackedVector3Array()
 for fixture in room.lamps:
  var at:Vector2=fixture.light_position()-room.ORIGIN
  lights.append(Vector3(at.x,at.y,fixture.light_angle()))
 for layer in layers:
  if layer.z_index<=2:(layer.material as ShaderMaterial).set_shader_parameter("lamps",lights)
