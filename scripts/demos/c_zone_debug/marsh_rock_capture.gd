extends SceneTree

# Live capture of the falling-stone trap: tremor, the limb breaking, the stone rolling, the shove.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var level

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_marsh_act()
	level.checkpoint = 2
	level.restore_checkpoint()
	level.player.position = Vector2(3780.0, 360.0)
	level.rock_first_delay = 0.12
	await _frames(4)
	var taken := {}
	Input.action_press("move_right")
	for step in range(1500):
		await physics_frame
		await process_frame
		var first: Dictionary = level.marsh_rock_state(0)
		if level.rock_lock_time > 0.0:
			Input.action_release("move_right")
		if level.rock_lock_time > 0.7 and not taken.has("0-lock"):
			await _snap("0-lock", taken)
		elif first.mode == level.ROCK_WARN and not taken.has("a-warn") and first.shake > 0.7:
			await _snap("a-warn", taken)
		elif level.limb_broken and level.limb_time > 0.16 and not taken.has("b-break"):
			await _snap("b-break", taken)
		elif level.limb_broken and level.limb_time > 0.6 and not taken.has("c-limb-falls"):
			await _snap("c-limb-falls", taken)
		elif first.mode == level.ROCK_ROLL and first.impact_time > 0.18 and not taken.has("d-landing"):
			await _snap("d-landing", taken)
		elif level.rock_shove_index == 0 and not taken.has("e-shove"):
			await _snap("e-shove", taken)
			quit(0)
			return
		if level.marsh_hit_time > 0.0:
			break
	quit(0)

func _snap(name: String, taken: Dictionary) -> void:
	taken[name] = true
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-marsh")
	root.get_texture().get_image().save_png("res://artifacts/c-zone-marsh/rock-%s.png" % name)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
