extends Node
# A static, world-anchored 2D visibility atlas. Sources are the actual river
# tree drawings and bank profiles, copied as render-only silhouettes. No
# player/camera coverage is used to infer light, and no physics is cloned.
const BOUNDS:=Rect2(-900,-1500,4700,3300)
const SIZE:=Vector2i(768,540)
var art:Node2D
var blockers:SubViewport
var field:SubViewport
var source:Node2D
var consumers:Array[ShaderMaterial]=[]
func setup(host:Node2D)->void:
 art=host
 blockers=SubViewport.new();blockers.size=SIZE;blockers.transparent_bg=true
 blockers.disable_3d=true;blockers.world_2d=World2D.new();add_child(blockers)
 var scale_value:=Vector2(SIZE)/BOUNDS.size
 blockers.canvas_transform=Transform2D(Vector2(scale_value.x,0),Vector2(0,scale_value.y),-BOUNDS.position*scale_value)
 source=Node2D.new();source.draw.connect(_draw_banks);blockers.add_child(source)
 # The bank sprites have no physics or behavior; cloning them keeps exact
 # texture alpha, root placement and authored shape in the visibility test.
 for child in art.water_cove.get_children():
  if child is Sprite2D and String(child.name).begins_with("bank_tree_"):
   var copy:Sprite2D=child.duplicate();blockers.add_child(copy)
 var crooked=preload("res://scripts/demos/c_zone_debug/crooked_tree_art.gd").new()
 crooked.position=Vector2(190,520);blockers.add_child(crooked)
 field=SubViewport.new();field.size=SIZE;field.disable_3d=true;field.use_hdr_2d=true
 field.world_2d=World2D.new();add_child(field)
 var rect:=ColorRect.new();rect.size=Vector2(SIZE);rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/river_daylight.gdshader")
 material.set_shader_parameter("blockers",blockers.get_texture())
 material.set_shader_parameter("bounds",Vector4(BOUNDS.position.x,BOUNDS.position.y,BOUNDS.size.x,BOUNDS.size.y))
 rect.material=material;field.add_child(rect)
 source.queue_redraw()
 blockers.render_target_update_mode=SubViewport.UPDATE_ONCE
 field.render_target_update_mode=SubViewport.UPDATE_DISABLED
 # Every consumer reads the same fixed local valley atlas, including in
 # the +3600,-3050 exit preview. Screen transforms never enter the field.
 for target:ShaderMaterial in [art.valley_depth.light.material,art.forest_integration.material_value,art.water_volume.material]:
  target.set_shader_parameter("river_daylight",field.get_texture())
  target.set_shader_parameter("river_daylight_rect",Vector4(BOUNDS.position.x,BOUNDS.position.y,BOUNDS.size.x,BOUNDS.size.y))
  target.set_shader_parameter("river_daylight_ready",0.)
  consumers.append(target)
 call_deferred("_warm")
func _warm()->void:
 # Render dependency explicitly: finish the actual silhouettes before the
 # one-off light tracing pass, then freeze both world textures.
 await RenderingServer.frame_post_draw
 blockers.render_target_update_mode=SubViewport.UPDATE_DISABLED
 field.render_target_update_mode=SubViewport.UPDATE_ONCE
 await RenderingServer.frame_post_draw
 field.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for target in consumers:target.set_shader_parameter("river_daylight_ready",1.)
func _draw_banks()->void:
 for profile in [art.level.LEFT_PROFILE,art.level.RIGHT_PROFILE]:
  var edge:=PackedVector2Array()
  var start:float=profile[0].x;var end:float=profile[-2].x
  for x in range(int(start),int(end)+1,8):edge.append(Vector2(x,art._bank_edge_y(x)))
  edge.append(Vector2(end,art._bank_edge_y(end)));edge.append(Vector2(end,2000));edge.append(Vector2(start,2000))
  source.draw_colored_polygon(edge,Color.BLACK)
