extends CanvasLayer
# Shared receiving light for the continuous chapter. Background paintings
# keep their own light volumes; this joins bodies, props, surfaces and near air.
const SHADER=preload("res://assets/shaders/valley_player_light.gdshader")
const Scene1=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const STEP:=4.0
var level:Node2D
var rect:ColorRect
var light_material:ShaderMaterial
var ground_texture:ImageTexture
var profiles:Dictionary={}
var lighting_region:StringName=&"valley"
var sources:=PackedVector4Array()
var axes:=PackedVector2Array()
var source_canopy:=PackedFloat32Array()
var barriers:=PackedVector4Array()
var source_count:=0
var barrier_count:=0
var canopy:=0.0
var surface_receivers:Dictionary={}
const SURFACE=preload("res://assets/shaders/chapter_surface_receiver.gdshader")
var transport_view:SubViewport
var transport_material:ShaderMaterial
var transport_active:=false

func _build_transport()->void:
 transport_view=SubViewport.new();transport_view.size=Vector2i(320,180)
 transport_view.disable_3d=true;transport_view.use_hdr_2d=true
 transport_view.world_2d=World2D.new()
 transport_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(transport_view)
 var field:=ColorRect.new();field.size=Vector2(transport_view.size)
 transport_material=ShaderMaterial.new()
 transport_material.shader=preload("res://assets/shaders/valley_sun_transport.gdshader")
 field.material=transport_material;transport_view.add_child(field)

func sync_terrain_projection()->void:
 if transport_material==null or level.marsh_art.back_stage.is_empty():return
 var stage:Dictionary=level.marsh_art.back_stage
 transport_material.set_shader_parameter("blocker_texture",stage.view.get_texture())
 var at:Vector2=stage.sprite.global_position
 transport_material.set_shader_parameter("blocker_rect",Vector4(at.x,at.y,float(stage.view.size.x),float(stage.view.size.y)))
 transport_material.set_shader_parameter("blocker_ready",1.0 if lighting_region in [&"forest",&"valley"] and level.marsh_art.visible and stage.sprite.visible else 0.0)
 var route=level.get("bridge_to_c")
 if route!=null and route.mine_trial!=null:
  var room=route.mine_trial.gap.art.pair_room
  if room!=null and room.scenery!=null:
   transport_material.set_shader_parameter("structure_texture",room.scenery.structure.texture)
   transport_material.set_shader_parameter("foreground_texture",room.scenery.foreground.texture)
   transport_material.set_shader_parameter("structure_rect",Vector4(room.ORIGIN.x,room.ORIGIN.y,1672.,941.))
   transport_material.set_shader_parameter("structure_ready",1.0 if room.enabled else 0.0)

func _sync_transport(field:Texture2D,camera:Vector2,time:float,origin:Vector2,axis_x:Vector2,axis_y:Vector2)->void:
 transport_active=true
 transport_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if transport_active else SubViewport.UPDATE_DISABLED
 if transport_active:
  transport_material.set_shader_parameter("source_forest",field)
  transport_material.set_shader_parameter("ground_profile",ground_texture)
  transport_material.set_shader_parameter("ground_sampling",profiles[lighting_region].sampling)
  transport_material.set_shader_parameter("world_origin",origin)
  transport_material.set_shader_parameter("world_axis_x",axis_x)
  transport_material.set_shader_parameter("world_axis_y",axis_y)
  transport_material.set_shader_parameter("forest_light_camera",camera)
  transport_material.set_shader_parameter("forest_light_clock",time)
  transport_material.set_shader_parameter("valley_mode",float(level.actor.sprite.material.get_shader_parameter("forest_received_light")))
  transport_material.set_shader_parameter("chapter_light_count",source_count)
  transport_material.set_shader_parameter("chapter_lights",sources)
  transport_material.set_shader_parameter("chapter_light_axes",axes)
  transport_material.set_shader_parameter("chapter_light_canopy",source_canopy)
  transport_material.set_shader_parameter("chapter_barrier_count",barrier_count)
  transport_material.set_shader_parameter("chapter_barriers",barriers)
  transport_material.set_shader_parameter("chapter_canopy",canopy)
  transport_material.set_shader_parameter("chapter_light_clock",time)
  sync_terrain_projection()
 for material:ShaderMaterial in [light_material,level.actor.sprite.material]:
  material.set_shader_parameter("valley_transport_ready",1.0 if transport_active else 0.0)
  material.set_shader_parameter("valley_transport_texture",transport_view.get_texture())

func _stop_transport()->void:
 transport_active=false
 if transport_view!=null:transport_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for material:ShaderMaterial in [light_material,level.actor.sprite.material]:
  material.set_shader_parameter("valley_transport_ready",0.0)

func _receiver(node:Node2D,top:bool,existing:bool=false)->void:
 if not is_instance_valid(node) or surface_receivers.has(node.get_instance_id()):return
 if not existing and node.material!=null:return
 var material:ShaderMaterial=node.material as ShaderMaterial if existing else ShaderMaterial.new()
 if material==null:return
 if not existing:material.shader=SURFACE;node.material=material
 material.set_shader_parameter("only_exposed_tops",top)
 material.set_shader_parameter("surface_response",.006 if top else .008)
 surface_receivers[node.get_instance_id()]={"node":weakref(node),"material":material}

func _surfaces(field:Texture2D,camera:Vector2,time:float)->void:
 for key in ["terrain","bank_grass","grass_band"]:_receiver(level.art.get(key),true)
 for key in ["crate_art","raft_front"]:_receiver(level.art.get(key),false)
 _receiver(level.art.grass_art,true,true)
 _receiver(level.marsh_art.grass,true,true)
 for source in get_tree().get_nodes_in_group(&"chapter_lit_ground"):
  if level.is_ancestor_of(source):_receiver(source,true,true)
 var canvas:Transform2D=level.get_canvas_transform()
 var size:Vector2=level.get_viewport_rect().size
 var row_x:=Vector3(canvas.x.x,canvas.y.x,canvas.origin.x)*1280./size.x
 var row_y:=Vector3(canvas.x.y,canvas.y.y,canvas.origin.y)*720./size.y
 var outdoor:float=float(level.actor.sprite.material.get_shader_parameter("forest_received_light"))
 for entry in surface_receivers.values():
  var node=entry.node.get_ref()
  if not is_instance_valid(node):continue
  var material:ShaderMaterial=entry.material
  material.set_shader_parameter("chapter_light_count",source_count)
  material.set_shader_parameter("chapter_lights",sources)
  material.set_shader_parameter("chapter_light_axes",axes)
  material.set_shader_parameter("chapter_light_canopy",source_canopy)
  material.set_shader_parameter("chapter_barrier_count",barrier_count)
  material.set_shader_parameter("chapter_barriers",barriers)
  material.set_shader_parameter("chapter_canopy",canopy)
  material.set_shader_parameter("chapter_light_clock",time)
  material.set_shader_parameter("forest_received_light",outdoor)
  material.set_shader_parameter("forest_light_texture",field)
  material.set_shader_parameter("forest_light_camera",camera)
  material.set_shader_parameter("forest_light_clock",time)
  material.set_shader_parameter("valley_transport_ready",1.0 if transport_active else 0.0)
  material.set_shader_parameter("valley_transport_texture",transport_view.get_texture())
  material.set_shader_parameter("light_screen_x",row_x)
  material.set_shader_parameter("light_screen_y",row_y)
  material.set_shader_parameter("ground_profile",ground_texture)
  material.set_shader_parameter("ground_sampling",profiles[lighting_region].sampling)
  if node==level.marsh_art.grass:
   material.set_shader_parameter("source_world_offset",-level.marsh_art.front_stage.root.position+level.marsh_art.global_position)

func _mute_surfaces()->void:
 for entry in surface_receivers.values():
  entry.material.set_shader_parameter("chapter_light_count",0)
  entry.material.set_shader_parameter("forest_received_light",0.)
  entry.material.set_shader_parameter("valley_transport_ready",0.)
func _ready()->void:
 layer=13
 var copy:=BackBufferCopy.new();copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
 add_child(copy)
 rect=ColorRect.new();rect.set_anchors_preset(Control.PRESET_FULL_RECT)
 rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
 light_material=ShaderMaterial.new();light_material.shader=SHADER
 rect.material=light_material;add_child(rect);hide()
func setup(host:Node2D)->void:
 level=host
 sources.resize(12);axes.resize(12);source_canopy.resize(12);barriers.resize(4)
 _build_transport()
 _profile(&"valley")
func _profile(region:StringName)->void:
 if not profiles.has(region):
  var bounds:=Vector2(-640,15200)
  if region==&"forest":bounds=Vector2(-11000,-3200)
  if region==&"mine":bounds=Vector2(-3600,3900)
  if region==&"gorge":bounds=Vector2(-4200,-1000)
  var count:=ceili((bounds.y-bounds.x)/STEP)+1
  var image:=Image.create(count,1,false,Image.FORMAT_RGBAF)
  for i in count:image.set_pixel(i,0,_surface(bounds.x+i*STEP,region))
  profiles[region]={"texture":ImageTexture.create_from_image(image),"sampling":Vector3(bounds.x,STEP,count)}
 ground_texture=profiles[region].texture
 light_material.set_shader_parameter("ground_profile",ground_texture)
 light_material.set_shader_parameter("ground_sampling",profiles[region].sampling)
func _surface(x:float,region:StringName=&"valley")->Color:
 if region==&"forest":return Color(Scene1.ground_top(x),0,1. if x<Scene1.CLIFF_X else 0.,100000.)
 if region==&"gorge":return Color(-3400.,0,0,100000.)
 if region==&"mine":
  var route=level.bridge_to_c
  var room=route.mine_trial.gap.art.pair_room
  var y:float=room.floor_y(x)
  var valid:=x>=-549. and x<1740.
  if x< -1014.:y=route.mine_trial.ground(x);valid=true
  if x>=room.relay.EXIT_X:y=room.relay.exit_scene.ground_y(x);valid=true
  var lower:float=room.lower_floor_y(x) if x> -385. and x<245. else 100000.
  return Color(y,0,1. if valid else 0.,lower)
 if x<2780.:
  var ground:float=level.ground_y(x)
  var water:bool=ground>575. and x>1090. and x<2110.
  return Color(minf(ground,575.),1. if water else 0.,1.,100000.)
 for profile in level.MARSH_LANDS:
  if x<profile[0].x or x>profile[-1].x:continue
  for i in range(profile.size()-1):
   if x<=profile[i+1].x:
    var a:Vector2=profile[i];var b:Vector2=profile[i+1]
    return Color(lerpf(a.y,b.y,(x-a.x)/(b.x-a.x)),0,1,100000.)
 return Color(430.,0,0,100000.)
func _source(at:Vector2,reach:float,power:float,axis:Vector2,leaf:float=0.)->void:
 if source_count>=12 or power<=.001:return
 var half_view:Vector2=Vector2(640,360)/level.camera.zoom
 var view:=Rect2(level.camera.get_screen_center_position()-half_view,half_view*2.)
 if not view.grow(reach*1.1).has_point(at):return
 sources[source_count]=Vector4(at.x,at.y,reach,power)
 axes[source_count]=axis.normalized();source_canopy[source_count]=leaf
 canopy=maxf(canopy,leaf);source_count+=1
func _fixture(fixture:Node2D,power:float=.72)->void:
 if not is_instance_valid(fixture) or not fixture.is_visible_in_tree() or not fixture.has_method("light_position"):return
 var energy:float=float(fixture.get("energy")) if fixture.get("energy")!=null else 1.
 _source(fixture.light_position(),390.,power*energy,Vector2.DOWN.rotated(fixture.light_angle()))
func _lights(_region_hint:StringName)->void:
 source_count=0;barrier_count=0;canopy=0.
 sources.fill(Vector4.ZERO);axes.fill(Vector2.DOWN);source_canopy.fill(0.);barriers.fill(Vector4.ZERO)
 # Stable world lights are culled by their actual reach, not enabled by a
 # region flag. Each sunlight/lamp keeps its own response across handoffs.
 _source(Vector2(-8680,-4700),1150,.35,Vector2(-.5,.866),1.)
 _source(Vector2(-6070,-4780),1100,.90,Vector2(-.5,.866),1.)
 _source(Vector2(-3350,-4810),1100,.45,Vector2(-.5,.866),1.)
 _source(Vector2(-2700,-4450),1200,.45,Vector2(-.5,.866),1.)
 var route=level.get("bridge_to_c")
 if route!=null and route.mine_trial!=null:
  for fixture in [route.art.chamber.lamp,route.art.chase_chamber.lamp,route.mine_trial.escape.chase_lamp,route.mine_trial.escape.end_lamp]:_fixture(fixture)
  var room=route.mine_trial.gap.art.pair_room
  for i in room.lamps.size():_fixture(room.lamps[i],.68 if i<4 else .18)
  _fixture(room.relay.art.fixture,.80)
  # The two decks block overhead sources from shining through solid floors.
  barriers[0]=Vector4(-549,-231,room.UPPER_Y,3.)
  barriers[1]=Vector4(-410,315,room.MID_Y,4.)
  barrier_count=2
func sync(enabled:bool,field:Texture2D,camera:Vector2,time:float)->void:
 visible=enabled
 if not enabled:
  _stop_transport()
  _mute_surfaces()
  level.actor.set_chapter_lights(0,sources,axes,0,barriers,0.,time)
  return
 lighting_region=level.art.valley_player_focus._region()
 _profile(lighting_region);_lights(lighting_region)
 var region_id:int=[&"valley",&"forest",&"mine",&"gorge"].find(lighting_region)
 light_material.set_shader_parameter("lighting_region",region_id)
 light_material.set_shader_parameter("chapter_light_count",source_count)
 light_material.set_shader_parameter("chapter_lights",sources)
 light_material.set_shader_parameter("chapter_light_axes",axes)
 light_material.set_shader_parameter("chapter_light_canopy",source_canopy)
 light_material.set_shader_parameter("chapter_barrier_count",barrier_count)
 light_material.set_shader_parameter("chapter_barriers",barriers)
 light_material.set_shader_parameter("chapter_canopy",canopy)
 light_material.set_shader_parameter("chapter_light_clock",time)
 level.actor.set_chapter_lights(source_count,sources,axes,barrier_count,barriers,canopy,time,source_canopy)
 var canvas:Transform2D=level.get_canvas_transform()
 var inverse:=canvas.affine_inverse()
 var size:Vector2=level.get_viewport_rect().size
 var origin:=inverse*Vector2.ZERO
 _sync_transport(field,camera,time,origin,inverse*Vector2(size.x,0)-origin,inverse*Vector2(0,size.y)-origin)
 light_material.set_shader_parameter("forest_light_texture",field)
 light_material.set_shader_parameter("forest_light_camera",camera)
 light_material.set_shader_parameter("forest_light_clock",time)
 light_material.set_shader_parameter("world_origin",origin)
 light_material.set_shader_parameter("world_axis_x",inverse*Vector2(size.x,0)-origin)
 light_material.set_shader_parameter("world_axis_y",inverse*Vector2(0,size.y)-origin)
 light_material.set_shader_parameter("gameplay_coverage",level.art.valley_player_focus.mask_view.get_texture())
 _surfaces(field,camera,time)
func _process(_delta:float)->void:
 if visible and not level.is_visible_in_tree():
  hide()
  level.actor.set_chapter_lights(0,sources,axes,0,barriers,0.,0.)
  level.actor.set_forest_light(false,null,Vector2.ZERO,0.)
  _stop_transport()
  _mute_surfaces()
