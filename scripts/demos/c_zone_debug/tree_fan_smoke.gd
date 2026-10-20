extends SceneTree

const Scene = preload("res://scenes/debug/c_zone_river.tscn")
const Route = preload("res://scripts/demos/c_zone_debug/tree_fan_route.gd")
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
	level = Scene.instantiate()
	root.add_child(level)
	await Route.frames(level,100)
	_check(level.fan_on_tree and level.art.fan_pickup.visible and not level.fan_owned,"leaf is visible on the tree at the normal empty-handed start")
	await _shot("01-tree-wide",Vector2(640,360),1.0)
	Input.action_press("interact")
	await Route.frames(level,2)
	Input.action_release("interact")
	_check(not level.fan_owned,"ground-level F cannot pick the tree leaf")
	level.crate.position.x=750.0
	level.player.position=Vector2(475,496)
	await Route.frames(level,30)
	Input.action_press("jump")
	var highest_feet := 550.0
	var ground_reachable := false
	for i in 65:
		await physics_frame
		highest_feet=minf(highest_feet,level.player.position.y+54.0)
		ground_reachable=ground_reachable or level.can_pick_up_fan()
	Input.action_release("jump")
	_check(highest_feet>level.RACK_RECT.position.y+10.0 and not ground_reachable,"ground jump alone cannot reach the rack or tree leaf")
	level.reset_all()
	await Route.frames(level,100)
	var climbed := await Route.climb(level)
	_check(climbed,"normal jump inputs climb raft then one-way rack beam")
	if not climbed:
		print("Route stopped at ",level.player.position," feet ",level.player.position.y+54.0," velocity ",level.player.velocity)
		quit(1)
		return
	_check(not level.can_pick_up_fan(),"standing on the beam is still below pickup reach")
	await _shot("02-on-rack",Vector2(425,340),1.5)
	Input.action_press("interact")
	Input.action_press("jump")
	_check(await Route.until(level,func(): return level.can_pick_up_fan(),60),"jump from the rack reaches the leaf grip")
	await Route.frames(level,18)
	_check(not level.fan_owned,"holding F before the jump does not auto-collect")
	Input.action_release("interact")
	Input.action_release("jump")
	await Route.frames(level,60)
	Input.action_press("jump")
	_check(await Route.until(level,func(): return level.can_pick_up_fan(),60),"a second jump can retry the pickup")
	Input.action_press("interact")
	await Route.frames(level,2)
	Input.action_release("interact")
	_check(level.fan_owned and not level.fan_on_tree and level.airborne_pickup,"fresh airborne F detaches and transfers the leaf")
	_check(level.actor.current_clip!=&"pickup" and level.player.velocity.y<0.0,"air pickup preserves upward motion and uses jump rather than crouch frames")
	await _shot("03-air-pickup",Vector2(490,305),2.0)
	Input.action_press("move_right")
	await Route.frames(level,6)
	_check(level.player.velocity.x>50.0,"airborne pickup does not freeze horizontal input")
	_check(level.fan.position.distance_to(level.FAN_SPOT)>2.0,"leaf transfers toward the moving hand during airborne pickup")
	Input.action_release("move_right")
	Input.action_release("jump")
	await Route.frames(level,75)
	_check(level.fan_owned and not level.art.fan_pickup.visible,"landing keeps exactly one held leaf")
	await _shot("04-held-leaf",level.player.position+Vector2(48,0),2.4)
	Input.action_press("interact")
	await Route.frames(level,30)
	Input.action_release("interact")
	_check(not level.fan_owned and absf(level.fan_rest_position().y-level.RACK_RECT.position.y+4.0)<0.01,"the leaf can be put down on the rack, not dropped through to ground")
	await Route.frames(level,2)
	Input.action_press("interact")
	await Route.frames(level,28)
	Input.action_release("interact")
	_check(level.fan_owned,"a leaf placed on the rack can be picked up normally")
	level.restore_checkpoint()
	_check(level.fan_owned and not level.fan_on_tree,"recovery preserves the collected tool, without regrowing a duplicate")
	level.reset_all()
	_check(level.fan_on_tree and not level.fan_owned and level.art.fan_pickup.visible,"full reset returns the leaf to the branch")
	level.crate.position.x+=180.0
	await Route.frames(level,2)
	_check(level.fan_on_tree and level.fan_rest_position()==level.FAN_SPOT,"moving the raft does not reveal or relocate the leaf")
	print("tree_fan_smoke: %s" % ("PASS" if failures==0 else "FAIL (%d)" % failures))
	level.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _shot(label: String, center: Vector2, zoom: float) -> void:
	if not capture: return
	# Take captures only between input edges so just-pressed events are not lost.
	level.set_physics_process(false)
	level.camera.position=center
	level.camera.zoom=Vector2.ONE*zoom
	level.camera.force_update_scroll()
	await process_frame
	RenderingServer.force_draw()
	var frame := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-tree-fan")
	frame.save_png("res://artifacts/c-zone-tree-fan/%s.png" % label)
	level.camera.zoom=Vector2.ONE
	level.set_physics_process(true)

func _check(condition: bool, message: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL",message])
	if not condition: failures+=1
