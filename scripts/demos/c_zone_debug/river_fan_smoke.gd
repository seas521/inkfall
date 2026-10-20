extends SceneTree

const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var level
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	if capture:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
	level = SCENE.instantiate()
	root.add_child(level)
	await _setup(Vector2(540,496))
	_check(not level.pose.monochrome and level.actor.animated.modulate == Color.WHITE and level.actor.head_glow.visible,"C actor preserves source orange facial details")
	_check(level.actor.current_clip == &"carry" and not level.actor.small_item.visible,"fan uses existing carry pose without a spawned stone")
	_check(level.fan.position.distance_to(level.actor.fan_hand_position())<0.01,"held fan follows the reviewed hand anchor")
	await _shot("01-carry")
	Input.action_press("interact")
	await _frames(7)
	_check(level.put_down_time>0.0 and level.actor.current_clip == &"put_down","F plays the eight-frame put-down clip")
	_check(not level.swing_fan(),"fan cannot activate during handoff")
	await _shot("02-put-down")
	await _frames(30)
	_check(not level.fan_owned and level.art.fan_pickup.visible and not level.fan.visible,"put-down transfers the only visible tool to the ground")
	var resting: Vector2 = level.fan_rest_position()
	await _frames(30)
	_check(not level.fan_owned and resting == level.fan_rest_position(),"holding F does not immediately pick the tool back up")
	Input.action_release("interact")
	await _frames(2)
	Input.action_press("interact")
	await _frames(7)
	_check(level.pickup_time>0.0 and level.actor.current_clip == &"pickup","a fresh F press reuses the pickup clip at the new location")
	await _shot("03-pickup")
	Input.action_release("interact")
	await _frames(24)
	_check(level.fan_owned and not level.art.fan_pickup.visible,"re-pickup hides the resting tool")
	Input.action_press("move_right")
	await _frames(10)
	_check(level.actor.current_clip == &"carry_run" and level.fan.position.distance_to(level.actor.fan_hand_position())<0.01,"walking uses carry frames and matching frame anchors")
	Input.action_release("move_right")
	Input.action_press("jump")
	await _frames(10)
	_check(String(level.actor.current_clip).begins_with("carry_"),"jumping retains the existing carry action family")
	Input.action_press("interact")
	await _frames(2)
	_check(level.fan_owned and level.put_down_time==0.0,"airborne put-down cannot strand the tool in midair")
	Input.action_release("jump")
	Input.action_release("interact")
	await _frames(60)
	for side in [-1.0,1.0]:
		await _setup(Vector2(714,496) if side<0 else Vector2(750+level.CRATE_SIZE.x+18,496))
		var start_x: float = level.crate.position.x
		var move: StringName = &"move_right" if side<0 else &"move_left"
		Input.action_press("interact")
		Input.action_press(move)
		await _frames(7)
		_check(level.put_down_time>0.0 and not level.dragging and absf(level.crate.position.x-start_x)<0.1,"raft waits for put-down before push on side %s" % side)
		await _frames(24)
		_check(level.dragging and not level.fan_owned and level.art.fan_pickup.visible,"held F continues to empty-handed grip on side %s" % side)
		var dropped: Vector2 = level.fan_rest_position()
		_check(absf(dropped.y-level.ground_y(dropped.x)+4.0)<0.01,"automatic put-down is supported by nearby ground")
		await _frames(70)
		_check(level.dragging and absf(level.crate.position.x-start_x)>20.0 and dropped==level.fan_rest_position(),"pushing moves the raft but leaves the fan behind")
		await _shot("04-push-%s" % side)
		Input.action_release("interact")
		Input.action_release(move)
	await _setup(Vector2(714,496))
	Input.action_press("interact")
	await _frames(6)
	Input.action_release("interact")
	await _frames(30)
	_check(not level.dragging and not level.pending_grab and not level.fan_owned,"releasing F during put-down cancels queued grip")
	level.restore_checkpoint()
	_check(level.fan_owned and not level.art.fan_pickup.visible,"recovery restores one acquired tool, not a duplicate floor copy")
	level.reset_all()
	level.intro_time = 0.0
	level.crate.position = Vector2(1490,level._unloaded_float_y())
	level.floating = true
	level.player.position = Vector2(1549,400)
	level.fan_owned = true
	level.checkpoint_fan = true
	await _frames(120)
	Input.action_press("interact")
	await _frames(30)
	Input.action_release("interact")
	_check(level.fan_on_raft and not level.fan_owned and level.art.fan_pickup.visible,"F on the raft puts the fan on its deck")
	var local: Vector2 = level.fan_raft_local
	level.crate.velocity.x = 90.0
	await _frames(25)
	var expected: Vector2 = level.crate.position+level.CRATE_SIZE*0.5+local.rotated(level.crate_tilt)
	_check(level.fan_rest_position().distance_to(expected)<0.01 and level.art.fan_pickup.position.distance_to(expected)<0.01,"resting fan follows raft translation and rocking")
	Input.action_press("interact")
	await _frames(25)
	Input.action_release("interact")
	_check(level.fan_owned,"fan can be retrieved from the rocking deck")
	await _shot("05-on-raft")
	level.reset_all()
	_check(not level.fan_owned and not level.fan_on_raft and level.put_down_time==0.0 and not level.pending_grab,"restart clears handoff and deck attachment state")
	print("river_fan_smoke: %s" % ("PASS" if failures==0 else "FAIL (%d)" % failures))
	level.queue_free()
	await _frames(2)
	quit(0 if failures==0 else 1)

func _setup(player_position: Vector2) -> void:
	level.reset_all()
	level.intro_time = 0.0
	level.crate.position = Vector2(750,level.CRATE_START.y)
	level.player.position = player_position
	level.fan_owned = true
	level.fan_revealed = true
	level.checkpoint_fan = true
	await _frames(60)

func _shot(label: String) -> void:
	if not capture:
		return
	var previous: Vector2 = level.camera.position
	level.set_physics_process(false)
	level.camera.position = level.player.position+Vector2(13,0)
	level.camera.zoom = Vector2.ONE*2.4
	level.camera.force_update_scroll()
	await process_frame
	RenderingServer.force_draw()
	var frame := root.get_texture().get_image()
	if label=="01-carry":
		var orange := 0
		for x in range(550,760):
			for y in range(250,410):
				var pixel := frame.get_pixel(x,y)
				if pixel.r>0.35 and pixel.r>pixel.g*1.25 and pixel.g>pixel.b*1.25:
					orange += 1
		_check(orange>5,"rendered face retains orange pixels (%d)" % orange)
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-fan")
	frame.save_png("res://artifacts/c-zone-fan/%s.png" % label)
	level.camera.position = previous
	level.camera.zoom = Vector2.ONE
	level.camera.force_update_scroll()
	level.set_physics_process(true)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(condition: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL",label])
	if not condition:
		failures += 1
