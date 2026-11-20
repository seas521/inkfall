extends "res://scripts/demos/c_zone_debug/mine_pair_ladders_review.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(30)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;control=room.ladders
 var mechanism=room.scenery.mechanisms
 var pressure=room.pressure
 var plate:Node2D=mechanism.parts["pressure_plate"]
 var base:Node2D=mechanism.parts["pressure_plate_base"]
 var base_at:Vector2=base.position
 await warp(Vector2(pressure.plate_rest.x,room.MID_Y))
 await frames(10)
 check(pressure.load_active,"grounded player must depress the pedal without F")
 check(pressure.depression>1.5 and not pressure.motes.is_empty(),"pedal must visibly travel and emit local contact dust")
 await frames(70)
 check(pressure.released and not room.restraint_locked(),"full mechanical lift must release the cart")
 check(not room.restraint_cleared,"player weight alone must not latch permanent release")
 check(plate.position.y>pressure.plate_rest.y+5,"button face must move down")
 check(base.position==base_at,"button base must remain fixed")
 check(mechanism.clamp_rise>41 and absf(mechanism.guide_wheel.rotation)>1,"restraint and physical sheave must travel together")
 var anchor:Marker2D=plate.get_node("rope_anchor")
 check(mechanism.clamp_rope.to_global(mechanism.clamp_rope.points[0]).distance_to(anchor.global_position)<.01,"rope must follow the depressed board eye")
 Input.action_press("jump");await frames(12);Input.action_release("jump")
 check(not level.player.is_on_floor() and not pressure.load_active,"air above the pedal must not count as weight")
 await warp(Vector2(70,room.MID_Y));await frames(90)
 check(not pressure.released and not room.restraint_cleared and room.restraint_locked() and pressure.rise==0,"leaving without ballast must lower the restraint and lock the car again")
 check(pressure.depression<.01,"unloaded pedal must spring back")
 check(not pressure.footprint_contains(Vector2(pressure.plate_rest.x,room.MID_Y+300)),"another storey cannot operate this pressure plate")
 # Later hoist loads use the same supported-weight interface; no puzzle
 # bypass is exposed to the player and carrying alone never supplies load.
 pressure.set_ballast("review_load",Vector2(pressure.plate_rest.x,room.MID_Y),true)
 await frames(80)
 check(pressure.released,"supported ballast must replace the player")
 pressure.set_ballast("review_load",Vector2.ZERO,false);await frames(90)
 await warp(Vector2(room.bays[0]-54,room.TRACK_Y))
 var initial:float=room.bays[0]
 Input.action_press("interact");Input.action_press("move_right");await frames(75)
 check(room.cart_gripped and room.bays[0]>initial+10,"latched cart must move without keeping weight on the pedal")
 Input.action_release("interact");release();await frames(2)
 pressure.set_ballast("review_load",Vector2(pressure.plate_rest.x,room.MID_Y),true);await frames(80)
 Input.action_press("interact");Input.action_press("move_right");await frames(165)
 check(room.bays[0]>initial+95,"released cart must move with the player's real push")
 check(absf(room.cart_bodies[0].position.x-room.bays[0])<.01,"cart collision must move with its drawing")
 var hand:Vector2=level.actor.grip_hand_world()
 var contact:Vector2=room.carts[0].grip_surface(Vector2(room.bays[0],room.TRACK_Y),Vector3.ZERO,hand.y,room.cart_grip_side)
 check(absf(hand.x-contact.x)<.05,"loaded hands must actually contact the cart")
 Input.action_release("interact");release();await frames(2)
 check(not room.cart_gripped,"release F must restore ordinary player movement")
 var fixture=room.lamps[1]
 var old_velocity:float=fixture.angular_velocity
 room.mechanical_impulse(fixture.global_position,.06)
 check(fixture.angular_velocity>old_velocity+.05,"nearby impact must add pendulum momentum")
 fixture.advance_swing(.05);room.scenery.sync()
 var data:PackedVector3Array=room.scenery.far.material.get_shader_parameter("lamps")
 check(data.size()==6 and absf(data[1].z-fixture.light_angle())<.0001,"live illumination must read the actual lamp angle")
 route.fail();route.restore_checkpoint();await frames(20)
 check(not room.cart_gripped and room.bays[0]==523 and pressure.rise==0,"death must restore a coherent closed puzzle")
 print("MINE PRESSURE RELEASE ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
