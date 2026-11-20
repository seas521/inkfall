extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
const Physics=preload("res://scripts/chapters/mine_pendulum_dynamics.gd")
var rows:Array=[]
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-directional-pendulum-v5/game"
 DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func pull(side:float,seconds:float=6.5)->void:
 await warp(Vector2(relay.LEVER.x+side*38,room.TRACK_Y))
 print("BEFORE PULL ",side," feet=",route.feet()," floor=",level.player.is_on_floor()," task=",room.hoist.task," state=",relay.state)
 Input.action_press("interact")
 await frames(2)
 print("START PULL ",side," feet=",route.feet()," owner=",relay.charge_owner," task=",room.hoist.task," state=",relay.state," grip=",room.cart_gripped)
 await frames(int(seconds*60)-2)
 check(relay.charge_owner and relay.control_side==side,"operating side must select winding direction")
 check(absf(relay.angle-side*relay.MAX_ANGLE)<.025,"hold must haul to selected maximum")
 check(absf(relay.angular_speed)<.04,"held maximum must settle smoothly")
 check(relay.hand_gap<.15,"either hand pose must contact lever")
 await shot("left-haul" if side<0 else "right-haul")
 var a:float=relay.angle;var w:float=relay.angular_speed
 relay._release_hammer();Input.action_release("interact")
 check(absf(relay.angle-a)<.000001 and absf(relay.angular_speed-w)<.000001,"release must preserve angle and momentum")
 check(relay.state!=relay.State.COUNTDOWN,"release must not insert countdown")
 rows.append({"side":side,"angle":a,"omega":w,"hand_gap":relay.hand_gap,"carts":room.bays.duplicate()})
 print("DIRECTIONAL PULL ",rows[-1])
func solver_checks()->void:
 var a:=Vector2(1.1,0);var b:=-a
 var initial:float=Physics.energy(a,473,980)
 var previous_peak:=a.x;var previous_w:=0.0;var peaks:=0;var speed_peak:=0.0
 for i in 8400:
  a=Physics.step(a,1.0/120,473,980);b=Physics.step(b,1.0/120,473,980)
  check(a.distance_to(-b)<.00001,"free pendulum must be symmetric")
  speed_peak=maxf(speed_peak,absf(a.y))
  if previous_w*a.y<0:
   check(absf(a.x)<previous_peak,"successive turning points must lose amplitude")
   previous_peak=absf(a.x);peaks+=1
  previous_w=a.y
 check(peaks>10 and absf(a.x)<.01,"free pendulum must decay toward its lowest point")
 check(Physics.energy(a,473,980)<initial*.001,"bearing damping must dissipate free energy")
 check(speed_peak>1,"pendulum must accelerate through center instead of uniform tweening")
 # Catch a moving pendulum without teleporting or zeroing its inertia.
 var moving:=Vector2(.3,1.2)
 var caught:Vector2=Physics.step(moving,1.0/120,473,980,-1.28,.1)
 check(absf(caught.y-moving.y)<.1,"re-grip clutch must not instantly reset swing speed")
func run()->void:
 solver_checks()
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 # Park cars outside the lower haul arc for isolated controls verification.
 await setup_pair(1350,1550,false)
 check(relay.angle>0 and relay.brake_amount==1,"initial state must park on upper right with brake")
 await pull(-1)
 for i in 100:
  await frames(1)
  if relay.angle>0:break
 check(relay.angle>0,"left release must swing right across center")
 await shot("free-swing")
 await pull(1)
 await frames(110)
 check(relay.angle<0,"right release must swing left across center")
 var out:=FileAccess.open("res://artifacts/mine-directional-pendulum-v5/control-review.json",FileAccess.WRITE)
 out.store_string(JSON.stringify({"passed":not failed,"pulls":rows},"  "))
 print("MINE DIRECTIONAL PENDULUM ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
