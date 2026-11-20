extends "res://scripts/demos/c_zone_debug/mine_basket_depth_v30_review.gd"
var peak_carry_speed:=0.0
var immediate_throws:=0
func frames(n:int)->void:
 for i in n:
  await super.frames(1)
  if hoist!=null and hoist.task==hoist.Task.CARRY:
   peak_carry_speed=maxf(peak_carry_speed,absf(level.player.velocity.x))
func walk_to(x:float)->void:
 var carrying:bool=hoist.task==hoist.Task.CARRY
 var distance:float=absf(x-route.feet().x)
 await super.walk_to(x)
 if carrying and distance>50:
  check(peak_carry_speed>35.8,"heavy carry must reach the faster shared pace")
  print("CARRY PACE ",peak_carry_speed)
func tap()->void:
 var carrying:bool=hoist.task==hoist.Task.CARRY
 var before:Vector2=route.feet()
 var basket:Vector2=room.scenery.mechanisms.basket.position
 var throwing:bool=carrying and absf(before.x-basket.x)<85 and absf(before.y-hoist._basket_floor())<12
 await super.tap()
 if throwing:
  immediate_throws+=1
  check(hoist.task==hoist.Task.THROW,"F must start throwing immediately, without APPROACH")
  check(absf(route.feet().x-before.x)<.1,"F cannot walk the player to an authored throw mark")
  print("DIRECT F THROW ",{"count":immediate_throws,"player_shift":route.feet().x-before.x})
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var directory:="res://artifacts/mine-basket-readability-v31/game"
 DirAccess.make_dir_recursive_absolute(directory)
 var raw=FileAccess.open(directory+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta=FileAccess.open(directory+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
