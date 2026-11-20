extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(400,1600,false)
 level.set_physics_process(false)
 # No real car occupies the lower arc. It must exactly follow the same
 # gravity/bearing integrator, independent of the old staging markers.
 relay.angle=1.1;relay.angular_speed=0;relay.pendulum_live=true;relay.state=relay.State.SWINGING
 relay.charge_owner=false;relay.clutch_release=0
 var expected:=Vector2(1.1,0)
 var error:=0.0
 for i in 700:
  expected=relay.Pendulum.step(expected,1./120,relay.LENGTH+relay.HEAD_CENTER.y,relay.GRAVITY)
  relay._integrate(1./120)
  error=maxf(error,Vector2(relay.angle,relay.angular_speed).distance_to(expected))
 check(error<.00001,"empty sweep must have no hidden location-dependent braking")
 check(relay.last_hammer_contact.is_empty(),"empty arc must not produce a cart impact")
 print("EMPTY SWEEP solver_error=",error)
 # Move the actual donor into the arc and repeat. It must now receive
 # impulse, and its rendered location follows the very same cart state.
 room.bays=[740.,1600.];relay.reset();relay.angle=-.5;relay.angular_speed=1.0;relay.pendulum_live=true;relay.state=relay.State.SWINGING
 for i in 120:
  relay._integrate(1./120)
  if not relay.last_hammer_contact.is_empty():break
 check(not relay.last_hammer_contact.is_empty(),"real cart in the arc must receive an impact")
 check(absf(relay.velocities[0])>1 or not relay.hammer_impulses.is_empty(),"real impact must transfer momentum")
 print("VISIBLE CONTACT ",relay.last_hammer_contact)
 print("MINE HAMMER EMPTY SWEEP ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
