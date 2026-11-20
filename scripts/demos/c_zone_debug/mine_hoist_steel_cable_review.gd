extends SceneTree
var level
var room
var rig
var failed:=false
var samples:Array=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func shot(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-hoist-steel-cable-v1/game"
 DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+name+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+name+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func run()->void:
 if DisplayServer.get_name()=="headless":
  level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
  await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 else:
  var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
  await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 room=level.bridge_to_c.mine_trial.gap.art.pair_room;rig=room.scenery.mechanisms
 level.set_physics_process(false)
 for fraction in [0.,.5,1.]:
  for sway in [-.03,0.,.03]:
   room.hoist.rise=room.scenery.mechanisms.basket_travel*fraction
   room.hoist.sway=sway;room.hoist._present_basket()
   var cable=rig.basket_rope
   var path:PackedVector2Array=cable.points
   var drum_at:Vector2=room.ORIGIN+rig.DRUM_CENTER
   var crown_at:Vector2=room.ORIGIN+rig.CROWN
   var basket_eye:Vector2=rig.basket.to_global(Vector2(0,-84))
   var inlet:Vector2=(path[1]-path[0]).normalized()
   var outlet:Vector2=(path[-1]-path[-2]).normalized()
   var inlet_error:float=absf(inlet.dot((rig.crown_entry-crown_at).normalized()))
   var outlet_error:float=absf(outlet.dot((rig.crown_exit-crown_at).normalized()))
   check(path[0].distance_to(rig.drum_takeoff)<.001,"steel cable must originate on the drum")
   check(absf(path[0].distance_to(drum_at)-rig.DRUM_RADIUS)<.001,"winch lead must sit on the winding surface")
   check(cable.to_global(path[-1]).distance_to(basket_eye)<.001,"cable terminal must remain attached to the moving basket eye")
   check(inlet_error<.0001 and outlet_error<.0001,"cable must enter and leave the wheel groove tangentially")
   for i in range(1,path.size()-1):check(absf(path[i].distance_to(crown_at)-rig.CROWN_RADIUS)<.001,"continuous wrap must follow the actual sheave radius")
   check(absf(rig.crown_wheel.rotation+room.hoist.rise/rig.CROWN_RADIUS)<.001,"sheave must rotate by cable travel / groove radius")
   var redraws:int=cable.redraws
   rig._sync_ropes();check(cable.redraws==redraws,"an unchanged steel cable must retain its drawing cache")
   samples.append({"rise":room.hoist.rise,"sway":sway,"inlet_error":inlet_error,"outlet_error":outlet_error,"terminal_error":cable.to_global(path[-1]).distance_to(basket_eye)})
  if DisplayServer.get_name()!="headless":
   level.player.position=Vector2(rig.selector_grip().x-36,room.UPPER_Y)-Vector2(13,54)
   level.player.velocity=Vector2.ZERO;level.facing=1
   level.camera_x=-770;level.camera_y=-3620;level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
   level.bridge_to_c._present(0)
   await frames(4);await shot("upper-"+str(int(fraction*100)))
   if fraction==.5:
    level.camera_y=-3220;level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
    await frames(4);await shot("basket-mid-travel")
 var out:=FileAccess.open("res://artifacts/mine-hoist-steel-cable-v1/review.json",FileAccess.WRITE)
 out.store_string(JSON.stringify({"passed":not failed,"samples":samples},"  "))
 print("MINE HOIST STEEL CABLE ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
