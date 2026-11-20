extends "res://scripts/demos/c_zone_debug/mine_hoist_chain_review.gd"
var extraction_samples:Dictionary={}
var previous_stone:=Vector2.ZERO
var previous_extract:=false
var maximum_extraction_step:=0.0
var saw_depth_clearance:=false
func frames(n:int)->void:
 for i in n:
  await physics_frame
  if hoist==null:continue
  var extracting_now:bool=hoist.task==hoist.Task.PICKUP and hoist.basket_pickup
  if extracting_now:
   if previous_extract:maximum_extraction_step=maxf(maximum_extraction_step,hoist.stone_origin.distance_to(previous_stone))
   for entry in [[.15,"reach"],[.32,"contact"],[.50,"lift"],[.65,"clear"]]:
    if hoist.age>=float(entry[0]) and not extraction_samples.has(entry[1]):
     extraction_samples[entry[1]]=true
     await shot("04-extract-"+str(entry[1]))
   if room.scenery.mechanisms.basket_front.z_index==3:saw_depth_clearance=true
  elif previous_extract:
   maximum_extraction_step=maxf(maximum_extraction_step,hoist.stone_origin.distance_to(previous_stone))
   check(maximum_extraction_step<8.,"basket extraction must be continuous, max step "+str(maximum_extraction_step))
   check(saw_depth_clearance,"stone must clear the rim before passing in front")
   print("BASKET DEPTH CONTINUITY ",maximum_extraction_step)
  previous_extract=extracting_now;previous_stone=hoist.stone_origin
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var directory:="res://artifacts/mine-basket-depth-v30/game"
 DirAccess.make_dir_recursive_absolute(directory)
 var raw=FileAccess.open(directory+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta=FileAccess.open(directory+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func wait_task(wanted:int,limit:int=400)->void:
 for i in limit:
  await frames(1)
  if hoist.location==hoist.Location.AIR:
   saw_airborne_stone=true
   if not extraction_samples.has("flight") and hoist.inside_basket:
    extraction_samples["flight"]=true
    await shot("02a-entering-basket")
  if hoist.task==hoist.Task.PUTDOWN and not hoist.attached:saw_ground_dust=true
  if hoist.task==wanted:return
 check(false,"action failed "+str(hoist.task))

func run()->void:
 if OS.get_environment("INKFALL_BASKET_SIDES")!="1":
  await super.run();return
 root.size=Vector2i(1280,720)
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(30)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;control=room.ladders;hoist=room.hoist
 for upper in [false,true]:
  for side in [-1.,1.]:
   hoist.reset();hoist.rise=room.scenery.mechanisms.basket_travel if upper else 0.
   hoist.target_top=upper;hoist.location=hoist.Location.BASKET;hoist.inside_basket=true
   hoist.load_offset_x=side*8;hoist._present_basket()
   extraction_samples.clear();maximum_extraction_step=0.;saw_depth_clearance=false
   var basket:Vector2=room.scenery.mechanisms.basket.position
   await warp(Vector2(basket.x+side*45,hoist._basket_floor()))
   var rest:Vector2=room.scenery.mechanisms.basket.to_local(hoist.stone_origin)
   await tap()
   for i in 160:
    await frames(1)
    if hoist.task==hoist.Task.PICKUP and hoist.age<hoist.BASKET_REACH:
     check(room.scenery.mechanisms.basket.to_local(hoist.stone_origin).distance_to(rest)<.3,"ungrasped stone must remain supported inside basket")
    if hoist.task==hoist.Task.CARRY:break
   check(hoist.attached and hoist.task==hoist.Task.CARRY,"both sides and both landings must allow extraction")
   check(hoist.stone.z_index<level.actor.z_index,"carried stone must remain behind character")
   print("BASKET SIDE ",{"upper":upper,"side":side,"max_step":maximum_extraction_step,"clear":saw_depth_clearance})
 print("BASKET FOUR APPROACHES ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
