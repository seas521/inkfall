extends Node
# Shared-world coverage for the whole chapter's playing plane. Distant plates
# and near-camera framing keep their authored diffusion; no radial autofocus.
const MASK:=1<<19
var level:Node2D
var mask_view:SubViewport
var tagged_actor_id:=0
var enabled:=false
var registered:Dictionary={}
var tagged:Dictionary={}
var discovery_frame:=-100
var discovery_region:StringName=&""
var focus_anchor:=Vector2.ZERO
var focus_extent:=Vector2(620,380)
var focus_seeded:=false
var focus_frame:=-1

func setup(host:Node2D)->void:
 level=host
 # Thin ropes and ribs must survive the coverage pass instead of crossing
 # an alpha threshold as a half-resolution raster slides under them.
 mask_view=SubViewport.new();mask_view.size=Vector2i(960,540)
 mask_view.transparent_bg=true;mask_view.disable_3d=true
 mask_view.world_2d=host.get_viewport().world_2d
 mask_view.canvas_cull_mask=MASK
 mask_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(mask_view)

func _tag_item(item:CanvasItem)->void:
 while item!=null:
  var id:=item.get_instance_id()
  if not tagged.has(id):tagged[id]={"node":weakref(item),"owned":(item.visibility_layer&MASK)==0}
  item.visibility_layer|=MASK
  item=item.get_parent() as CanvasItem

func _tag_branch(node:Node)->void:
 if node is CanvasItem:_tag_item(node)
 for child in node.get_children():
  if child is Viewport or child is CanvasLayer:continue
  _tag_branch(child)

func _register(node:Node)->void:
 if not is_instance_valid(node):return
 var id:=node.get_instance_id()
 if registered.get(id,-1)==node.get_child_count():return
 _tag_branch(node)
 registered[id]=node.get_child_count()

func _members(object:Object,keys:Array)->void:
 if not is_instance_valid(object):return
 for key in keys:
  var source=object.get(key)
  if source is Node:_register(source)

func _region()->StringName:
 var route=level.get("bridge_to_c")
 if route!=null and route.active and not route.in_c_zone:
  var feet:Vector2=level.player.position+Vector2(13,54)
  return &"gorge" if feet.x< -3100.0 or feet.y< -3510.0 else &"mine"
 if route!=null and route.in_c_zone:return &"valley"
 return &"forest" if level.checkpoint==6 else &"valley"

func _release_tags()->void:
 for entry in tagged.values():
  var node=entry.node.get_ref()
  if is_instance_valid(node) and entry.owned:node.visibility_layer&=~MASK
 tagged.clear();registered.clear()

func _tag_sources(_region_hint:StringName)->void:
 _tag_branch(level.actor)
 tagged_actor_id=level.actor.get_instance_id()
 _register(level.fan)
 if level.log_bridge!=null and level.log_bridge.art!=null:
  var bridge_art=level.log_bridge.art
  if not bridge_art.ink_stage.is_empty():_register(bridge_art.ink_stage.output)
 # Authored depth is chapter-wide. Register eligible world receivers ahead
 # of time, not when the player crosses a region or reaches an object.
 _members(level.art,["terrain","props","crate_art","raft_front","bank_grass","fan_pickup","grass_art","grass_band"])
 for stage in [level.marsh_art.back_stage,level.marsh_art.front_stage]:_register(stage.sprite)
 for stone in level.stone_nodes:_register(stone)
 _register(level.rope_art)
 for source in get_tree().get_nodes_in_group(&"chapter_gameplay_focus"):
  if level.is_ancestor_of(source):_register(source)
 _members(level.art,["spider_art","predator_art","crevice_art"])
 if level.rope_ladder!=null:_members(level.rope_ladder.art,["output"])
 var route=level.get("bridge_to_c")
 if route==null or route.art==null:return
 var art=route.art
 _members(art,["grass","cliff","mechanism"])
 # The exterior mountain lies behind the opaque mine paintings. Including
 # its solid alpha here would incorrectly focus the ENTIRE background.
 _members(art,["rail","mechanism","supports","cart_visual"])
 for chamber in [art.chamber,art.chase_chamber]:_members(chamber,["earth","front"])
 var trial=route.mine_trial
 if trial==null:return
 _members(trial,["masonry"])
 _members(trial.escape,["collapse_draw"])
 if trial.gap==null or trial.gap.art==null:return
 var gap_art=trial.gap.art
 _members(gap_art,["shore","dynamic","front"])
 var room=gap_art.pair_room
 if room==null or room.scenery==null:return
 # Only the registered structure/terrain mattes, not SOURCE or the far wall.
 _members(room.scenery,["structure","foreground","mechanisms"])
 for cart in room.carts:_register(cart)
 _members(room.hoist,["stone"])
 if room.relay==null or room.relay.art==null:return
 var relay_art=room.relay.art
 _members(relay_art,["static_layer","dynamic","hammer_sprite","slider_sprite","buffer_layer"])
 _register(relay_art.get_node_or_null("soft_launch_bank"))
 # Only rooted ground cover is tagged via its group. The same exit owns
 # near-camera understory, which must retain independent defocus.
 _tag_item(room.relay.exit_scene)
 _register(room.relay.exit_scene.get_node_or_null("soft_rooted_valley_bank"))

func _tag_transition_sources()->void:
 # Visible landmarks straddle gameplay ownership boundaries. Their depth
 # must not depend on whether the ladder/descent/mine controller owns input.
 var route=level.get("bridge_to_c")
 if route==null:return
 for tree in route.trees:_register(tree)
 _register(route.swing_rope)
 _members(route.mine_trial,["miner","rear_tools"])

func _source_focus(active:bool)->void:
 if is_instance_valid(level.actor):level.actor.set_gameplay_focus(active)
 if is_instance_valid(level.marsh_art) and not level.marsh_art.back_stage.is_empty():
  level.marsh_art.set_gameplay_focus(active)

func _update_focus(_region_hint:StringName,force:bool)->void:
 var frame:=Engine.get_process_frames()
 if frame==focus_frame and not force:return
 focus_frame=frame
 var feet:Vector2=level.player.position+Vector2(13,54)
 var goal:=feet+Vector2(float(level.facing)*55.,-120.)
 var extent:=Vector2(620,380)
 # Continuous spatial volumes, independent of input/scene ownership. The
 # same view must not refocus because a controller changed its region flag.
 var gorge:=smoothstep(-4300.,-3950.,feet.y)*(1.-smoothstep(-3350.,-3050.,feet.y))*(1.-smoothstep(-3120.,-2900.,feet.x))
 extent=extent.lerp(Vector2(650,540),gorge)
 var underground:=smoothstep(-3650.,-3450.,feet.y)*(1.-smoothstep(-2300.,-1800.,feet.y))
 var hoist:=smoothstep(-950.,-650.,feet.x)*(1.-smoothstep(450.,800.,feet.x))*underground
 var relay:=smoothstep(450.,800.,feet.x)*(1.-smoothstep(1800.,2100.,feet.x))*underground
 goal=goal.lerp(Vector2(-80,-3010),hoist).lerp(Vector2(1110,-3040),relay)
 extent=extent.lerp(Vector2(850,620),hoist).lerp(Vector2(900,450),relay)
 if not focus_seeded or force or focus_anchor.distance_to(goal)>1300.:
  focus_anchor=goal;focus_extent=extent;focus_seeded=true
 else:
  # Ordinary steps and jumps do not pump focus vertically. Large elevation
  # changes/climbing move the focal space gradually after leaving a deadband.
  if absf(goal.y-focus_anchor.y)<115.:goal.y=focus_anchor.y
  var weight:=1.-exp(-clampf(get_process_delta_time(),0,.05)*3.0)
  focus_anchor=focus_anchor.lerp(goal,weight)
  focus_extent=focus_extent.lerp(extent,weight)

func sync(active:bool)->void:
 var changed:=enabled!=active
 enabled=active
 if changed:_source_focus(active)
 if active:
  _tag_transition_sources()
  var frame:=Engine.get_process_frames()
  var region:=_region()
  if frame-discovery_frame>=30 or region!=discovery_region or tagged_actor_id!=level.actor.get_instance_id():
   # Keep already discovered world-space receivers registered. Visibility
   # still belongs to the scene; changing a region is not a depth cut.
   _tag_sources(region);discovery_frame=frame;discovery_region=region
   _source_focus(true)
  _update_focus(region,false)
  var size:Vector2=level.get_viewport_rect().size
  var ratio:=Vector2(mask_view.size)/size
  mask_view.canvas_transform=Transform2D(Vector2(ratio.x,0),Vector2(0,ratio.y),Vector2.ZERO)*level.get_canvas_transform()
 mask_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
 for film in get_tree().get_nodes_in_group("film_look"):
  var size:Vector2=level.get_viewport_rect().size
  var canvas:Transform2D=level.get_canvas_transform()
  var centre:Vector2=canvas*focus_anchor/size
  var span:=Vector2(canvas.basis_xform(Vector2(focus_extent.x,0)).length()/size.x,canvas.basis_xform(Vector2(0,focus_extent.y)).length()/size.y)
  film.set_player_plane_focus(active,mask_view.get_texture(),centre,span)

func _process(_delta:float)->void:
 # Public launch scenes are hidden before being freed on return to menu.
 if enabled and not level.is_visible_in_tree():sync(false)

func _exit_tree()->void:
 _source_focus(false)
 _release_tags()
 for film in get_tree().get_nodes_in_group("film_look"):
  if film.route_owner!=null and film.route_owner.get_ref()==level:
   film.set_player_plane_focus(false,null,Vector2.ZERO)
