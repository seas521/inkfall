extends SceneTree
const Actor=preload("res://scripts/demos/c_zone_debug/hood_river_actor.gd")
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 for settings:Dictionary in [{"name":"standing"},{"name":"small hold","held":0,"equipment":Pose.EQUIPMENT_THROWABLE},{"name":"large hold","held":0,"equipment":Pose.EQUIPMENT_THROWABLE,"small_item_kind":&"mine_heavy"},{"name":"crouching","action":&"low_idle"},{"name":"resting after exertion","action":Pose.ACTION_PANT},{"name":"grip hold","action":&"grip_hold"}]:
  var actor=Actor.new();root.add_child(actor);await process_frame
  actor.load_group("hug");actor.load_group("low_stance")
  var pose=Pose.new();var base={"feet":Vector2(250,350),"grounded":true,"visual_scale":Pose.HOOD_VISUAL_SCALE,"velocity":Vector2.ZERO}
  base.merge(settings,true);pose.apply(base)
  for i in 120:actor.sync_pose(1.0/60,pose)
  var scale:Vector2=actor.body.scale;var transform:Transform2D=actor.body.transform
  var clip=actor.current_clip;var index:int=actor.current_frame_index;var texture=actor.sprite.texture
  for i in 480:
   pose.action_progress=fposmod(float(i)/60,1.0)
   actor.sync_pose(1.0/60,pose)
   assert(actor.body.scale.is_equal_approx(scale),"idle body scale cannot breathe")
   assert(actor.body.transform.is_equal_approx(transform),"settled rest transform must remain fixed")
   assert(actor.current_clip==clip and actor.current_frame_index==index and actor.sprite.texture==texture,"rest frames must not cycle")
  print("STATIC IDLE PASS ",settings.name," clip ",clip," scale ",scale)
  actor.queue_free();await process_frame
 print("GLOBAL STATIC REST PASS")
 quit()
