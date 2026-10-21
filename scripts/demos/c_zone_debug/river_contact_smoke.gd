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
	await _frames(90)
	_check((level.player.get_child(0) as CollisionShape2D).shape is CapsuleShape2D, "player uses a rounded sole collider")
	_check_contact("flat bank")
	await _shot("00-bank", level.player.position.x)
	level.intro_time = 0.0
	level.player.position = Vector2(460, 330)
	level.player.velocity = Vector2.ZERO
	await _frames(60)
	_check_contact("rack top")
	await _shot("00-rack", level.player.position.x)
	level.player.position = Vector2(level.crate.position.x + level.CRATE_SIZE.x + 18.5,496)
	level.intro_time = 0.0
	await _frames(20)
	Input.action_press("interact")
	Input.action_press("move_right")
	await _frames(100)
	_check(level.dragging and level.actor.current_clip == &"pull", "right tow grip retains the backward pull animation")
	await _shot("00-right-pull", level.player.position.x)
	Input.action_release("move_right")
	Input.action_release("interact")
	level.intro_time = 0.0
	level.player.position = Vector2(100, 345)
	level.player.velocity = Vector2.ZERO
	await _frames(100)
	_check_contact("opening slope")
	await _shot("01-slope-contact", level.player.position.x + 13.0)
	level.player.position = Vector2(2005, level.ground_y(2018) - 94.0)
	level.crate.position = Vector2(2370, level.CRATE_START.y)
	await _frames(100)
	_check_contact("right-bank uphill slope")
	await _shot("01-right-slope", level.player.position.x + 13.0)
	# Test both orientations of the same rocking platform.
	for side in [1.0, -1.0]:
		level.reset_all()
		level.intro_time = 0.0
		level.crate.position = Vector2(1490, level._unloaded_float_y())
		level.float_direction = side
		level.floating = true
		level.crate_tilt = side * deg_to_rad(3.0)
		level.crate_shape.rotation = level.crate_tilt
		level.player.position = Vector2(1490 + level.CRATE_SIZE.x * 0.5 - 13, 360)
		level.player.velocity = Vector2.ZERO
		await _frames(150)
		_check(level.is_riding(), "player remains supported on tilted crate %s" % side)
		_check_contact("tilted crate %s" % side)
		_check(level.load_sink > 6.0, "raft retains sustained rider displacement")
		_check(level.art.raft_front.z_index > level.actor.z_index and level.art.raft_front.z_index < level.art.water_volume.z_index, "front rim occludes feet but is submerged by water")
		_check(level.art.raft_front.transform == level.art.crate_art.transform, "front rim follows physical raft translation and rocking")
		_check(level.art.bank_grass.z_index > level.actor.z_index, "shore grass occludes lower shins")
		await _shot("02-box-contact-%s" % ("left" if side > 0 else "right"), 1500.0)
		var event_count: int = level.art.water_impact_count
		await _frames(120)
		_check(level.art.water_impact_count == event_count, "floating bob does not repeatedly emit entry splashes")
	Input.action_press("jump")
	await _frames(10)
	_check(not level.actor.support_valid and absf(level.actor.support_offset) < 0.01, "jump clears grounded visual correction without ground attraction")
	Input.action_release("jump")
	# Replay first entry, before buoyancy starts, on both shores.
	for side in [1.0, -1.0]:
		level.reset_all()
		level.intro_time = 0.0
		level.crate.position = Vector2(990,level.CRATE_START.y) if side > 0 else Vector2(2120,level.CRATE_START.y)
		level.player.position = Vector2(945,496) if side > 0 else Vector2(2120+level.CRATE_SIZE.x+13,496)
		await _frames(30)
		Input.action_press("interact")
		var input: StringName = &"move_right" if side > 0 else &"move_left"
		Input.action_press(input)
		for i in 800:
			await physics_frame
			if level.art.water_impact_count > 0:
				break
		_check(level.crate_wet and level.art.water_impact_count > 0, "first water contact emits splash on bank %s" % side)
		_check(not level.floating, "entry splash starts before the buoyancy state")
		await _frames(7)
		await _shot("03-entry-%s" % ("left" if side > 0 else "right"), level.crate.position.x)
		await _shot("04-shore-wide-%s" % ("left" if side > 0 else "right"), level.crate.position.x + level.CRATE_SIZE.x * 0.5, 1.0)
		Input.action_release(input)
		Input.action_release("interact")
		await _frames(170)
		_check(level.art.water_impacts.is_empty(), "impact spray and rings expire")
	level.reset_all()
	_check(level.art.water_impacts.is_empty() and not level.crate_wet and not level.player_wet, "reset clears all water contact history")
	print("river_contact_smoke: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	level.queue_free()
	await _frames(2)
	quit(0 if failures == 0 else 1)

func _check_contact(label: String) -> void:
	var measured: Dictionary = level.actor.surface_contact.solve(level.actor.animated, level.player)
	_check(level.actor.support_valid and measured.valid and absf(measured.offset) < 1.0, "%s visible sole touches actual surface (gap %.3f)" % [label, measured.offset])
	_check(is_equal_approx(absf(level.actor.scale.x), 0.378) and level.actor.rotation == 0.0, "%s keeps original proportions and upright body" % label)

func _shot(label: String, center_x: float, zoom := 1.8) -> void:
	if not capture:
		return
	var saved_camera: Vector2 = level.camera.position
	level.set_physics_process(false)
	level.camera.position = Vector2(center_x, level.player.position.y + 45.0 if zoom > 1.0 else 360.0)
	level.camera.zoom = Vector2.ONE * zoom
	level.camera.force_update_scroll()
	await process_frame
	RenderingServer.force_draw()
	var frame := root.get_texture().get_image()
	if label.begins_with("04-shore"):
		var transform: Transform2D = level.art.get_global_transform_with_canvas()
		var bank_x := 1230.0 if label.ends_with("left") else 1990.0
		var soil_point := Vector2(bank_x,level.art._bank_edge_y(bank_x)+22.0)
		var wet_point := Vector2(bank_x,level.art._bank_edge_y(bank_x)-18.0)
		var dry_before := _sample(frame,transform*soil_point)
		var wet_before := _sample(frame,transform*wet_point)
		level.art.water_volume.hide()
		await process_frame
		RenderingServer.force_draw()
		var no_water := root.get_texture().get_image()
		var dry_after := _sample(no_water,transform*soil_point)
		var wet_after := _sample(no_water,transform*wet_point)
		_check(absf(dry_after.r-dry_before.r)<0.008 and dry_before.r<0.05,"water does not paint fog inside the solid bank (%s)" % label)
		_check(absf(wet_after.r-wet_before.r)>0.025,"water remains visible immediately outside the sloping bank (%s)" % label)
		level.art.water_volume.show()
	if label.begins_with("02-box"):
		var canvas: Transform2D = level.art.crate_art.get_global_transform_with_canvas()
		var above := _sample(frame, canvas * Vector2(0,-21))
		var below := _sample(frame, canvas * Vector2(0,8))
		_check(below.r > above.r + 0.16 and below.r < 0.38, "rendered submerged wood is visibly gray rather than near-black (%.3f -> %.3f)" % [above.r, below.r])
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-raft")
	frame.save_png("res://artifacts/c-zone-raft/%s.png" % label)
	level.camera.position = saved_camera
	level.camera.zoom = Vector2.ONE
	level.camera.force_update_scroll()
	level.set_physics_process(true)

func _sample(frame: Image, pixel: Vector2) -> Color:
	var result := Color(0,0,0,0)
	for x in range(-1,2):
		for y in range(-1,2):
			result += frame.get_pixel(clampi(int(pixel.x)+x,0,frame.get_width()-1), clampi(int(pixel.y)+y,0,frame.get_height()-1)) / 9.0
	return result

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(condition: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		failures += 1
