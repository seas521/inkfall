extends SceneTree

# The climb on the real pushable box (headless): for every frame, the sprite's pixels over the box top are checked column by
# column for a thin sliver of background between the body and the surface (it shows as a thin light line on the box). Uses the
# actor's real transform and the real frame images.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const Manifest = preload("res://scripts/actors/hood_actor_manifest.gd")
var level
var failures := 0
var cache := {}

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _slivers() -> Array:
	var actor = level.actor
	var clip := String(actor.current_clip)
	var key := "%s/%d" % [clip, actor.current_frame_index]
	if not cache.has(key):
		cache[key] = Image.load_from_file(ProjectSettings.globalize_path(Manifest.frame_path(clip, actor.current_frame_index)))
	var image: Image = cache[key]
	var top: float = level.puzzle_box.position.y
	var x0: float = level.puzzle_box.position.x
	var x1: float = x0 + level.PUZZLE_BOX_SIZE.x
	var above := {}
	var below := {}
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				var world: Vector2 = actor.sprite.to_global(Vector2(x + 0.5, y + 0.5))
				if world.x > x0 + 3.0 and world.x < x1 - 3.0:
					var column := int(floor(world.x))
					if world.y < top:
						above[column] = maxf(above.get(column, -1e9), world.y)
					else:
						below[column] = minf(below.get(column, 1e9), world.y)
	var columns := 0
	var widest := 0.0
	for column in above.keys():
		var gap: float = float(below.get(column, top)) - float(above[column])
		if gap > 0.5 and gap <= 3.0:
			columns += 1
			widest = maxf(widest, gap)
	return [columns, widest]

func _run() -> void:
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_marsh_act()
	await _frames(30)
	var ledge_y: float = level.SECOND_ACT_LEDGE.position.y
	level.player.position = Vector2(2870.0, ledge_y - 54.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	Input.action_press("move_right")
	for i in 240:
		await physics_frame
		if level.player.position.x + 26.0 >= 2950.0 - 36.0:
			break
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")
	var worst := 0
	var worst_at := 0.0
	var started := false
	for i in 400:
		await physics_frame
		if level.climb_time >= 0.0:
			started = true
			Input.action_release("move_right")
			var progress: float = level.climb_time / level.climb_total
			if progress > 0.5 and progress < 0.9:
				var result := _slivers()
				if int(result[0]) > worst:
					worst = int(result[0])
					worst_at = progress
		elif started:
			break
	Input.action_release("move_right")
	print("the most columns with a thin sliver under the body: %d (at %.2f of the climb)" % [worst, worst_at])
	if worst > 3:
		failures += 1
		print("FAIL: a thin light line shows between the body and the box top")
	print("climb gap smoke: ", "OK" if failures == 0 else "FAILED")
	quit(1 if failures > 0 else 0)
