extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
var rows:Array=[]
func simulate(index:int,side:float,x:float)->Dictionary:
 var at:float=relay.PIVOT.x+side*(x-relay.PIVOT.x)
 await setup_pair(at if index==0 else 1600,at if index==1 else 1600,false)
 room.restraint_cleared=true
 level.set_physics_process(false)
 relay.angle=side*1.1;relay.angular_speed=0;relay.pendulum_live=true;relay.state=relay.State.SWINGING
 for i in 240:
  relay._integrate(1./120)
  if relay.last_hammer_contact.get("cart",-1)==index or relay.angle*side<.1:break
 var row:Dictionary={"index":index,"side":side,"x":at,"cart_speed":relay.velocities[index],"omega":relay.angular_speed,"angle":relay.angle,"event":relay.last_hammer_contact.duplicate()}
 rows.append(row);print("UNIFIED MATRIX ",row)
 level.set_physics_process(true)
 return row
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 for x in [920.,980.,1000.]:
  var results:Array=[]
  for index in 2:
   for side in [-1.,1.]:results.append(await simulate(index,side,x))
  for i in [0,2]:
   check(absf(float(results[i].cart_speed)+float(results[i+1].cart_speed))<.15,"left/right contact response must mirror")
   check(absf(float(results[i].omega)+float(results[i+1].omega))<.001,"head angular response must mirror")
  check(absf(float(results[0].cart_speed)-float(results[2].cart_speed))<.01,"vehicle number cannot change the collision")
  check(absf(float(results[1].omega)-float(results[3].omega))<.0001,"vehicle number cannot change hammer response")
  if x<1000:
   for row in results:check(not row.event.is_empty(),"actual side and roof contact must be detected")
  else:
   for row in results:check(row.event.is_empty() and absf(float(row.cart_speed))<.01,"clear arc miss cannot accelerate a remote car")
 var file:=FileAccess.open("res://artifacts/mine-contact-unified-v17/matrix.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":not failed,"cases":rows},"  "))
 print("MINE CONTACT MATRIX V17 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
