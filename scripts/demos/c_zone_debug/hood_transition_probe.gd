extends SceneTree

# Headless probe: run at the pushable box, jump, take hold, climb, and measure how much the drawn silhouette (in world space, with the
# real transform of the sprite) changes from one physics frame to the next. A cut shows as a spike against the normal step.
# Prints one line per frame: the clip, its frame, the change in px (2x2 sub-pixels), and a mark where it is far above the normal step.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const Manifest = preload("res://scripts/actors/hood_actor_manifest.gd")
var level
var cache := {}
var last_centroid := Vector2.ZERO
var previous_centroid := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _mask() -> Dictionary:
	var actor = level.actor
	var clip := String(actor.current_clip)
	var key := "%s/%d" % [clip, actor.current_frame_index]
	if not cache.has(key):
		cache[key] = Image.load_from_file(ProjectSettings.globalize_path(Manifest.frame_path(clip, actor.current_frame_index)))
	var image: Image = cache[key]
	var cells := {}
	var sum := Vector2.ZERO
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).a > 0.5:
				var world: Vector2 = actor.sprite.to_global(Vector2(x + 1.0, y + 1.0))
				cells[Vector2i(int(floor(world.x * 2.0)), int(floor(world.y * 2.0)))] = true
				sum += world
	last_centroid = sum / maxf(1.0, float(cells.size()))
	return cells

func _diff(a: Dictionary, b: Dictionary) -> int:
	var n := 0
	for k in a.keys():
		if not b.has(k):
			n += 1
	for k in b.keys():
		if not a.has(k):
			n += 1
	return n

func _run() -> void:
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	level = SCENE.instantiate()
	root.add_child(level)
	for i in 10: await physics_frame
	level.debug_enter_marsh_act()
	for i in 30: await physics_frame
	var ledge_y: float = level.SECOND_ACT_LEDGE.position.y
	level.player.position = Vector2(2790.0, ledge_y - 54.0)
	level.player.velocity = Vector2.ZERO
	for i in 20: await physics_frame
	Input.action_press("move_right")
	for i in 400:
		await physics_frame
		if level.player.position.x + 26.0 >= 2950.0 - 55.0:
			break
	var previous := _mask()
	Input.action_press("jump")
	var steps: Array = []
	var started := false
	for i in 140:
		await physics_frame
		if i == 14:
			Input.action_release("jump")
		if level.climb_time >= 0.0:
			Input.action_release("move_right")
			started = true
		var now := _mask()
		var d := _diff(previous, now)
		var motion := last_centroid - previous_centroid
		previous_centroid = last_centroid
		steps.append([i, String(level.actor.current_clip), level.actor.current_frame_index, d, level.climb_time, motion])
		previous = now
		if started and level.climb_time < 0.0:
			break
	var normal: Array = []
	for s in steps:
		if String(s[1]) in ["tired_run", "idle_left"]:
			normal.append(int(s[3]))
	normal.sort()
	var base := 1
	if not normal.is_empty():
		base = maxi(1, int(normal[normal.size() / 2]))
	print("normal step (the run, median): %d" % base)
	var last_clip := ""
	var in_climb_start := 0
	for s in steps:
		var spike := int(s[3]) > base * 3
		if String(s[1]) != last_clip or spike:
			print("f%-3d %-22s frame %-3d change %-5d %s" % [s[0], s[1], s[2], s[3], "<<< SPIKE" if spike else ""])
		last_clip = String(s[1])
	# the speed of the picture (the silhouette's centre, px per physics frame) from the last frames of the air into the climb
	for index in range(steps.size()):
		if String(steps[index][1]) == "climb":
			in_climb_start = index
			break
	var line := ""
	for index in range(maxi(1, in_climb_start - 4), mini(steps.size(), in_climb_start + 12)):
		var motion: Vector2 = steps[index][5]
		line += " %s(%.1f,%.1f)" % [String(steps[index][1]).replace("clumsy_", "")[0], motion.x, motion.y]
	print("centre speed px/frame around the grab:", line)
	quit()
