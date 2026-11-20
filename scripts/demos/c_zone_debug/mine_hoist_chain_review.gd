extends "res://scripts/demos/c_zone_debug/mine_pair_ladders_review.gd"
var hoist
var maximum_hand_gap:=0.0
var loaded_frames:=0
var empty_frames:=0
var saw_airborne_stone:=false
var saw_ground_dust:=false
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 var directory:="res://artifacts/mine-hoist-interaction-v1/game"
 DirAccess.make_dir_recursive_absolute(directory)
 if root.use_hdr_2d:
  var raw=FileAccess.open(directory+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(image.get_data());raw.close()
  var meta=FileAccess.open(directory+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[image.get_width(),image.get_height()],"format":image.get_format()}));meta.close()
 else:image.save_png(directory+"/"+label+".png")
func walk_to(x:float)->void:
 release()
 for i in 1900:
  var dx:float=x-route.feet().x
  if absf(dx)<2.5:break
  Input.action_press("move_right" if dx>0 else "move_left")
  Input.action_release("move_left" if dx>0 else "move_right")
  await frames(1)
  if i>0 and i%500==0:print("HOIST WALK TRACE ",{"feet":route.feet(),"v":level.player.velocity,"task":hoist.task,"input":Input.get_axis("move_left","move_right"),"grounded":level.player.is_on_floor()})
 release();await frames(10)
 check(absf(route.feet().x-x)<8,"continuous walking must reach "+str(x)+": "+str(route.feet()))
 if absf(route.feet().x-x)>=8:
  for j in level.player.get_slide_collision_count():
   var hit=level.player.get_slide_collision(j)
   print("HOIST BLOCKED ",hit.get_position()," ",hit.get_normal()," ",hit.get_collider())
func tap()->void:
 Input.action_press("interact");await frames(1);Input.action_release("interact");await frames(1)
func wait_task(wanted:int,limit:int=400)->void:
 for i in limit:
  await frames(1)
  if hoist.location==hoist.Location.AIR:
   if not saw_airborne_stone and hoist.age>hoist.THROW_DETACH+.15:await shot("02a-ballistic-basket-throw")
   if hoist.age>hoist.THROW_DETACH+.15:saw_airborne_stone=true
  if hoist.task==hoist.Task.PUTDOWN and not hoist.attached and not saw_ground_dust:
   check(not room.pressure.motes.is_empty(),"stone-ground contact must emit dust")
   saw_ground_dust=true
   await frames(5);await shot("05a-ground-contact-dust")
  if hoist.task==wanted:return
 check(false,"hoist action must finish at task "+str(wanted)+", got "+str(hoist.task))
func climb_at(index:int,down:bool)->void:
 var d:Dictionary=control.definitions()[index]
 await walk_to(d.x)
 Input.action_press("climb_down" if down else "climb_up")
 await frames(2)
 check(control.active(),"real approach must engage ladder "+str(index))
 for i in 650:
  await frames(1)
  if not control.active():break
 release();await frames(18)
 check(not control.active() and level.player.is_on_floor(),"ladder must return supported control")
func stroke()->void:
 await walk_to(room.scenery.mechanisms.selector_grip().x-23)
 await tap()
 for i in 220:
  await frames(1)
  if hoist.task==hoist.Task.LEVER:
   var hand:Vector2=level.actor.grip_hand_world()
   var grip:Vector2=room.scenery.mechanisms.selector_grip()
   var point:=Vector2(grip.x,clampf(hand.y,grip.y-8,grip.y+8))
   maximum_hand_gap=maxf(maximum_hand_gap,hand.distance_to(point))
   if i==23:await shot("04-selector-hand-contact")
  if hoist.task==hoist.Task.NONE:break
 check(maximum_hand_gap<.1,"hand must remain on the real selector grip: "+str(maximum_hand_gap))
 check(not Input.is_action_pressed("interact"),"trip must not depend on holding F")
func wait_trip()->int:
 var count:=0
 for i in 1000:
  await frames(1);count+=1
  if not hoist.moving():break
 check(not hoist.moving(),"selected hoist trip must dock automatically")
 var art=room.scenery.mechanisms
 check(art.basket_rope.to_global(art.basket_rope.points[-1]).distance_to(art.basket.to_global(Vector2(0,-84)))<.01,"rope must remain attached to the swinging basket eye")
 if hoist.loaded():check(hoist.stone.global_position.distance_to(hoist._basket_stone_origin())<.01,"stone must ride the actual basket transform")
 return count
func run()->void:
 root.size=Vector2i(1280,720)
 if DisplayServer.get_name()=="headless":
  level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
  await frames(10);level.enter_mine_cart_pair_test();await frames(30)
 else:
  var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
  await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;control=room.ladders;hoist=room.hoist
 await climb_at(1,true)
 print("HOIST STEP lower landing ",route.feet())
 await shot("00-lower-floor")
 await walk_to(hoist.stone_origin.x-40);await tap();await wait_task(hoist.Task.CARRY)
 check(hoist.attached and hoist.location==hoist.Location.ARMS,"real pickup must attach the existing floor stone")
 check(not level.actor.heavy_item.visible,"there must not be a duplicate carried stone")
 print("HOIST STEP carrying ",hoist.stone_origin)
 await shot("01-real-stone-carried")
 await walk_to(room.scenery.mechanisms.basket.position.x-45);await tap();await wait_task(hoist.Task.NONE)
 check(hoist.loaded() and not hoist.attached,"placing must leave the stone inside the basket")
 check(hoist.throws==1 and saw_airborne_stone,"basket loading must use a real detached ballistic throw")
 print("HOIST STEP basket loaded ",hoist.stone_origin)
 await shot("02-basket-loaded")
 await climb_at(1,false);await climb_at(0,false)
 await stroke();check(hoist.target_top,"one pull must select ascent")
 loaded_frames=await wait_trip()
 check(hoist.rise>room.scenery.mechanisms.basket_travel-.1,"loaded hoist must reach main deck")
 print("HOIST STEP raised loaded in ",loaded_frames," frames")
 await shot("03-loaded-upper-dock")
 # Push again -> descend. Tap again during descent -> reverse safely.
 await stroke();check(not hoist.target_top,"next push must select descent")
 await frames(80);check(hoist.speed<0,"released selector must keep lowering")
 await stroke();check(hoist.target_top,"next pull must reverse through braking")
 await wait_trip()
 await climb_at(0,true)
 await walk_to(hoist.stone_origin.x-45);await tap();await wait_task(hoist.Task.CARRY)
 check(hoist.attached and not hoist.loaded(),"main-deck unloading must recover the same stone")
 await shot("05-unloaded-on-main-deck")
 await walk_to(room.pressure.plate_rest.x-38);await tap();await wait_task(hoist.Task.NONE)
 check(hoist.location==hoist.Location.GROUND and not hoist.attached,"placing must end carrying")
 check(saw_ground_dust,"ground placement must have contact dust feedback")
 check(absf((hoist.stone_origin.y+hoist.STONE_BOTTOM)-(room.MID_Y+room.pressure.depression))<2,"visible stone sole must meet the depressed button face")
 await walk_to(room.STAIR_END+38);await frames(75)
 check(room.pressure.released,"real transported stone must hold the plate after the player leaves")
 await shot("06-stone-holds-pressure")
 var old:float=room.bays[0]
 Input.action_press("interact");Input.action_press("move_right");await frames(440)
 Input.action_release("interact");release();await frames(2)
 check(room.bays[0]>old+100,"complete real puzzle must free a cart the player can push")
 check(room.bays[0]>room.relay.STAGE_X,"released second cart must move freely past the former fixed station")
 print("HOIST STEP cart extracted ",room.bays[0])
 await shot("07-cart-extracted")
 if OS.get_environment("INKFALL_HOIST_CAPTURE_ONLY")=="1":
  print("MINE HOIST LIVE CAPTURE ","FAIL" if failed else "PASS")
  quit(1 if failed else 0);return
 # Empty basket return uses the same single selector, with lighter drive.
 await walk_to(270);await climb_at(0,false);await stroke()
 empty_frames=await wait_trip()
 check(empty_frames<loaded_frames,"empty basket must complete its trip faster than a loaded one")
 check(hoist.location==hoist.Location.GROUND and room.pressure.released,"empty return cannot remove the plate's stone")
 route.fail();route.restore_checkpoint();await frames(25)
 check(hoist.task==hoist.Task.NONE and hoist.location==hoist.Location.GROUND and hoist.rise==0,"death must restore the complete hoist attempt")
 check(not hoist.attached and not room.pressure.released and room.bays[0]==523,"reset must not leave phantom load or an unlocked cart")
 var data={"passed":not failed,"loaded_frames":loaded_frames,"empty_frames":empty_frames,"maximum_selector_hand_gap":maximum_hand_gap}
 var file=FileAccess.open("res://artifacts/mine-hoist-interaction-v1/review.json",FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "))
 print("MINE HOIST CHAIN ","FAIL" if failed else "PASS"," ",data)
 quit(1 if failed else 0)
