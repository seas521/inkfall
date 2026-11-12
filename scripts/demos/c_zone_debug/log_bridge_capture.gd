extends SceneTree
const SCENE=preload("res://scenes/debug/c_zone_river.tscn")
const Bridge=preload("res://scripts/demos/c_zone_debug/log_bridge_act.gd")
const Film=preload("res://scripts/effects/film_look.gd")
var level
func _initialize(): call_deferred("_run")
func _frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func _snap(label:String):
	await _frames(3)
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/log-bridge/"+label+".png")
	print("CAPTURE ",label)
func _run():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate()
	root.add_child(level)
	Film.attach(level)
	await _frames(8)
	level.debug_enter_log_bridge()
	await _frames(25)
	await _snap("01-entry")
	var b=level.log_bridge
	level.player.position=Vector2(b.grip_feet_x()-13,Bridge.LEFT.position.y-55)
	level.player.velocity=Vector2.ZERO
	await _frames(8)
	Input.action_press("interact")
	await _frames(48)
	await _snap("02-grip")
	print("HAND gap=",level.actor.grip_hand_world().distance_to(b.pin_hand())," actor_root_offset=",level.actor.position-(level.player.position+Vector2(13,54)))
	Input.action_press("move_left")
	await _frames(18)
	await _snap("03-pull")
	for i in 80:
		await _frames(1)
		if b.state==Bridge.State.FALLING and b.angle > -0.4:
			break
	Input.action_release("move_left")
	Input.action_release("interact")
	await _snap("04-fall")
	for i in 120:
		await _frames(1)
		if b.state==Bridge.State.SETTLING: break
	await _frames(8)
	await _snap("04-impact")
	if OS.get_cmdline_user_args().has("--impact-only"):
		quit(0)
		return
	await _frames(80)
	await _snap("05-bridge")
	Input.action_press("move_right")
	for i in 350:
		await _frames(1)
		if level.player.position.x+13>Bridge.ORIGIN.x+620:
			break
	await _snap("06-crossing")
	for i in 200:
		await _frames(1)
		if level.player.position.x+13>Bridge.RIGHT.position.x+110:
			break
	Input.action_release("move_right")
	await _frames(50)
	await _snap("07-bank")
	print("COMPLETE reached_bank=",b.reached_bank," deaths=",b.deaths," state=",b.state)
	quit(0)
