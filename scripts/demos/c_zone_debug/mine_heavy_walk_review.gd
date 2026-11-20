extends SceneTree
var level
var route
var gap
var samples:Array=[]
var loops:Array=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func snap(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image()
 img.save_png("res://artifacts/mine-heavy-walk-v2/"+label+".png")
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8);level.enter_mine_cart_pair_test();route=level.bridge_to_c;gap=route.mine_trial.gap
 # Isolate locomotion on the long, grounded mine floor; pickup has its own
 # real-input regression. Keep the actual actor/controller and solid carts.
 gap.rock_state=2;gap.rock_attached=true;gap.rock_grip_offset=Vector2.ZERO
 gap.escape.chock_present=false;gap.escape.chock_body.collision_layer=0
 level.player.position=Vector2(-120-13,gap.art.pair_room.floor_y(-120)-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=gap.art.pair_room.floor_y(-120)
 await frames(20)
 var data:Dictionary=level.HoodManifest.CLIPS["hug_walk"]
 var last_index:=-1;var last_wrap_x:=INF;var previous_feet:Array=[]
 Input.action_press("move_right")
 for i in 1050:
  await frames(1)
  if i in [60,73,86,99]:await snap("carry-%03d"%i)
  if level.actor.current_clip!=&"hug_walk":
   last_index=-1;previous_feet=[];continue
  var index:int=level.actor.current_frame_index
  var current:Array=[]
  for point:Array in data["ground_contacts"][index]:
   current.append(level.actor.body.to_global(Vector2(float(point[0]),0)).x)
  if last_index>=0 and index>=last_index and not previous_feet.is_empty():
   for old:float in previous_feet:
    var closest:=INF
    for x:float in current:closest=minf(closest,absf(x-old))
    if closest<2.0:samples.append(closest)
  if last_index>=0 and index<last_index:
   if is_finite(last_wrap_x):loops.append(absf(route.feet().x-last_wrap_x))
   last_wrap_x=route.feet().x
  last_index=index;previous_feet=current
  if route.feet().x>175 and level.actor.current_clip==&"hug_hold":break
 assert(loops.size()>=4,"long carry must traverse multiple full gait cycles")
 var distance:float=data["travel_distance"]
 for travelled:float in loops:assert(absf(travelled-distance)<1.0,"step phase must follow actual distance")
 # Holding into a solid cart cannot keep cycling feet on the spot.
 await frames(15)
 print("BLOCK CHECK ",route.feet()," vel ",level.player.velocity," clip ",level.actor.current_clip)
 assert(level.actor.current_clip==&"hug_hold")
 Input.action_release("move_right");await frames(12)
 var still:float=route.feet().x;await frames(20)
 assert(absf(route.feet().x-still)<.02 and level.actor.current_clip==&"hug_hold")
 Input.action_press("move_left");var distinct:Dictionary={}
 for i in 190:
  await frames(1)
  if level.actor.current_clip==&"hug_walk":distinct[level.actor.current_frame_index]=true
 Input.action_release("move_left");await frames(20)
 assert(distinct.size()>25,"reverse carry must articulate the feet, not slide a hold pose")
 samples.sort();var median:float=samples[samples.size()/2]
 assert(median<.32,"planted-foot drift must be substantially below the old sliding root")
 var report:Dictionary={"native_speed":data["walk_speed"],"stride_distance":distance,"observed_cycle_distances":loops,"median_planted_foot_step":median,"samples":samples.size(),"reverse_frames":distinct.size()}
 print("HEAVY WALK PASS ",JSON.stringify(report))
 var f:=FileAccess.open("res://artifacts/mine-heavy-walk-v2/verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report));f.close()
 quit()
