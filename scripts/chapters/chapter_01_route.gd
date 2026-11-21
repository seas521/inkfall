extends "res://scripts/demos/c_zone_debug/river_controller.gd"

# A standalone chapter entry over the shared world/controller. Forest,
# cliff, ladder and mine descent keep the same actor and world coordinates.
# The existing C-zone entrances remain separate DEBUG entries.
signal bridge_unlocked
var bridge_unlocked_once:=false
const DescentRoute=preload("res://scripts/chapters/descent_route_act.gd")
const BridgeToC=preload("res://scripts/chapters/mine_descent_act.gd")
var post_bridge:Node2D
var bridge_to_c:Node2D
var chapter_framing=preload("res://scripts/art/chapter_camera_framing.gd").new()

func sync_chapter_camera(delta:float)->void:
	chapter_framing.sync(self,delta)

func reset_all() -> void:
	chapter_framing.reset()
	if bridge_to_c!=null:bridge_to_c.reset()
	if post_bridge!=null:post_bridge.reset()
	super.reset_all()
	log_bridge.reset_chapter()
	if post_bridge==null:
		post_bridge=DescentRoute.new()
		post_bridge.level=self
		add_child(post_bridge)
	if bridge_to_c==null:
		bridge_to_c=BridgeToC.new()
		bridge_to_c.level=self
		add_child(bridge_to_c)
	post_bridge.reset()
	bridge_to_c.reset()
	log_bridge.set_exit_open(true)
	bridge_unlocked_once=false
	debug_enter_scene1()
	debug_return_index=4

func enter_cliff_test() -> void:
	# Include the original walk, grave/flock and get-up sequence, rather
	# than spawning halfway through its cinematic or directly on the ladder.
	debug_enter_rope_ladder(true)
	debug_return_index=8

func enter_valley_test()->void:
	# Reuse the real exit/handoff so the return bank, boat, checkpoints and
	# coordinate ownership agree with a completed mine traversal.
	enter_mine_cart_pair_test()
	var room=bridge_to_c.mine_trial.gap.art.pair_room
	var relay=room.relay
	relay.state=relay.State.LANDED
	relay.cart_landed=true;relay.completed=true
	room.bays[1]=relay.CART_STOP_X
	relay.positions[1]=Vector2(relay.CART_STOP_X,relay.EXIT_Y)
	room.cart_bodies[1].position=relay.positions[1]
	relay.velocities[1]=0.0
	var foot:=Vector2(3490.,relay.exit_scene.ground_y(3490.))
	player.position=foot-Vector2(13,54);player.velocity=Vector2.ZERO
	camera_x=foot.x-525.;camera_y=bridge_to_c.camera_target_y()
	camera.position=Vector2(camera_x+640.,camera_y+360.)
	relay._begin_handoff()
	intro_time=0.;debug_return_index=17
	_present(0.)

func _physics_process(delta:float) -> void:
	if paused:return
	if bridge_to_c!=null and bridge_to_c.tick(delta):return
	if post_bridge!=null and post_bridge.tick(delta):return
	super._physics_process(delta)
	if not bridge_unlocked_once and log_bridge.state==log_bridge.State.BRIDGED:
		bridge_unlocked_once=true
		bridge_unlocked.emit()

func restore_checkpoint() -> void:
	if bridge_to_c!=null and bridge_to_c.active:
		bridge_to_c.restore_checkpoint()
		return
	if post_bridge!=null and post_bridge.active:
		post_bridge.restore_checkpoint()
		return
	super.restore_checkpoint()

func enter_station_test()->void:
	bridge_to_c.set_enabled(false)
	post_bridge.enter(0,true)
	debug_return_index=9

func enter_scree_test()->void:
	bridge_to_c.set_enabled(false)
	post_bridge.enter(1,true)
	debug_return_index=10

func _camera_target_y()->float:
	if bridge_to_c!=null and bridge_to_c.active:
		return bridge_to_c.camera_target_y()
	if post_bridge!=null and post_bridge.active:
		return minf(0.0,player.position.y-500.0)
	if post_bridge!=null and post_bridge.in_c_zone and player.position.x<500:
		var u:float=smoothstep(-120,500,player.position.x+13)
		return lerpf(minf(0.0,player.position.y-500.0),super._camera_target_y(),u)
	return super._camera_target_y()

func _act_finished() -> void:
	# New rooms join the existing C bank physically; only C's own completed
	# act may invoke its original completion behavior after that handoff.
	if (bridge_to_c!=null and bridge_to_c.in_c_zone) or (post_bridge!=null and post_bridge.in_c_zone):super._act_finished()

func enter_root_cliff_test()->void:
	log_bridge.left_bank_reached=true
	log_bridge.active=true
	post_bridge.active=false
	bridge_to_c.set_enabled(true)
	bridge_to_c.checkpoint_step=-1
	bridge_to_c.enter(true)
	debug_return_index=11

func enter_mine_shaft_test()->void:
	enter_root_cliff_test()
	bridge_to_c.set_shaft_preview(true)
	bridge_to_c.checkpoint_step=3
	bridge_to_c.restore_checkpoint()
	bridge_to_c.mine_trial.break_wall()
	bridge_to_c.mine_trial.launched=true
	bridge_to_c.mine_trial.cart_x=bridge_to_c.mine_trial.PARK_X
	bridge_to_c.mine_trial.cart_speed=0
	player.position=Vector2(-1850-13,-3170-55)
	player.velocity=Vector2.ZERO
	bridge_to_c.fall_origin=-3170
	bridge_to_c.shaft.fall_y=-3170
	camera_x=player.position.x-525
	camera_y=_camera_target_y()
	camera.position=Vector2(camera_x+640,camera_y+360)
	debug_return_index=14

func enter_mine_cart_gap_test()->void:
	enter_root_cliff_test()
	bridge_to_c.checkpoint_step=3
	bridge_to_c.restore_checkpoint()
	var trial=bridge_to_c.mine_trial
	trial.break_wall();trial.launched=true;trial.cart_x=trial.PARK_X;trial.cart_speed=0
	var escape=trial.escape
	escape.started=true;escape.launch_age=20;escape.saved=true;escape.stopped_once=true;escape.stop_age=20
	trial.impact_age=20;escape.rubble_front=-1470
	for piece in escape.roof:
		piece.age=20;piece.landed=true;piece.p.y=trial.ground(piece.p.x)+45
	# Advance the fall chronologically. Sampling the airborne equation first
	# at t=20 teleports timber sideways into the otherwise empty parking bay.
	for frame in 600:
		trial.impact_age=float(frame)/60.0
		for support in escape.timber_supports:support.tick(1.0/60.0)
	trial.impact_age=20
	escape._set_chock_x(trial.PARK_X+escape.CHOCK_OFFSET)
	bridge_to_c.restore_checkpoint()
	trial.sync_visual(0)
	debug_return_index=15

func enter_mine_cart_pair_test()->void:
	enter_mine_cart_gap_test()
	bridge_to_c.mine_trial.gap.bank_reached=true
	bridge_to_c.restore_checkpoint()
	var room=bridge_to_c.mine_trial.gap.art.pair_room
	player.position=Vector2(70-13,room.floor_y(70)-55)
	player.velocity=Vector2.ZERO
	bridge_to_c.fall_origin=room.floor_y(-80)
	camera_x=player.position.x-525;camera_y=_camera_target_y()
	camera.position=Vector2(camera_x+640,camera_y+360)
	debug_return_index=16
