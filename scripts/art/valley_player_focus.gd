extends Node
# Share the live world in a small alpha-only coverage view. Only gameplay
# sources are tagged; distant forest and foreground framing stay out of focus.
const MASK:=1<<19
var level:Node2D
var mask_view:SubViewport
var tagged_actor_id:=0
var enabled:=false
func setup(host:Node2D)->void:
 level=host
 mask_view=SubViewport.new();mask_view.size=Vector2i(640,360)
 mask_view.transparent_bg=true;mask_view.disable_3d=true
 mask_view.world_2d=host.get_viewport().world_2d
 mask_view.canvas_cull_mask=MASK
 mask_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(mask_view)
func _tag_branch(node:Node)->void:
 if node is CanvasItem:
  var item:CanvasItem=node
  while item!=null:
   item.visibility_layer|=MASK
   var parent:Node=item.get_parent()
   item=parent as CanvasItem
 for child in node.get_children():
  if child is Viewport or child is CanvasLayer:continue
  _tag_branch(child)
func _tag_sources()->void:
 for source in [level.actor,level.fan,level.art.terrain,level.art.props,level.art.crate_art,level.art.raft_front,level.art.bank_grass,level.art.fan_pickup]:
  if is_instance_valid(source):_tag_branch(source)
 for stage in [level.marsh_art.back_stage,level.marsh_art.front_stage]:
  _tag_branch(stage.sprite)
 tagged_actor_id=level.actor.get_instance_id()
func sync(active:bool)->void:
 enabled=active
 if active:
  if tagged_actor_id!=level.actor.get_instance_id():_tag_sources()
  var size:Vector2=level.get_viewport_rect().size
  var ratio:=Vector2(mask_view.size)/size
  mask_view.canvas_transform=Transform2D(Vector2(ratio.x,0),Vector2(0,ratio.y),Vector2.ZERO)*level.get_canvas_transform()
 mask_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
 var centre:=Vector2(.5,.65)
 if active:
  centre=(level.get_canvas_transform()*(level.player.position+Vector2(13,24)))/level.get_viewport_rect().size
 for film in get_tree().get_nodes_in_group("film_look"):
  film.set_player_plane_focus(active,mask_view.get_texture(),centre)

func _exit_tree()->void:
 for film in get_tree().get_nodes_in_group("film_look"):
  if film.route_owner!=null and film.route_owner.get_ref()==level:
   film.set_player_plane_focus(false,null,Vector2.ZERO)
