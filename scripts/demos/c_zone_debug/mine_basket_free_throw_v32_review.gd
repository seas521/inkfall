extends "res://scripts/demos/c_zone_debug/mine_basket_readability_v31_review.gd"
func walk_to(x:float)->void:
 # A test player must aim the free throw too. Stand at its physical range,
 # not at the old scripted putdown mark.
 if absf(x-(room.pressure.plate_rest.x-38))<.1:x=room.pressure.plate_rest.x-70
 await super.walk_to(x)
func tap()->void:
 var carrying:bool=hoist.task==hoist.Task.CARRY
 if carrying and absf(route.feet().x-room.scenery.mechanisms.basket.position.x)<85 and absf(route.feet().y-hoist._basket_floor())<12:
  # Approach from the right leaves this test player facing left. Aim back
  # at the basket using real input; production must never auto-turn a throw.
  var aim:="move_right" if route.feet().x<room.scenery.mechanisms.basket.position.x else "move_left"
  Input.action_press(aim);await frames(2);Input.action_release(aim);await frames(14)
 var before:Vector2=route.feet()
 await super.tap()
 if carrying:
  check(hoist.task==hoist.Task.THROW,"every carrying F press must throw directly")
  check(absf(route.feet().x-before.x)<.1,"pressure throws cannot reposition the player")
func wait_task(wanted:int,limit:int=400)->void:
 await super.wait_task(wanted,limit)
 if wanted==hoist.Task.NONE:
  for i in 120:
   if hoist.location!=hoist.Location.AIR:break
   await frames(1)
  if hoist.plate_locked():
   saw_ground_dust=true
   check(not room.pressure.motes.is_empty(),"free throw must emit dust on the actual pressure contact")
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var directory:="res://artifacts/mine-basket-free-throw-v32/game"
 DirAccess.make_dir_recursive_absolute(directory)
 var raw=FileAccess.open(directory+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta=FileAccess.open(directory+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
