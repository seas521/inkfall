extends SceneTree
const SCENE=preload("res://scenes/debug/c_zone_river.tscn")
const Film=preload("res://scripts/effects/film_look.gd")
var level
func _initialize(): call_deferred("_run")
func _frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func _snap(label:String):
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/log-bridge/feedback-"+label+".png")
	print("FEEDBACK CAPTURE ",label," offset=",level.camera.offset," angle=",level.log_bridge.angle)
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
	var b=level.log_bridge
	if OS.get_cmdline_user_args().has("--play"):
		DisplayServer.window_set_title("Inkfall · 断木斜桥 · 受力与镜头反馈")
		print("PLAY READY: Space jumps; F + left extracts the chock; partial movement loads the bridge; impact shakes the ground view")
		return
	var landings:int=b.landing_impulses
	Input.action_press("jump")
	await _frames(18)
	Input.action_release("jump")
	for i in 100:
		await _frames(1)
		if b.landing_impulses>landings:
			await _frames(4)
			await _snap("01-jump-landing")
			break
	await _frames(35)
	level.player.position=Vector2(b.grip_feet_x()-13,b.LEFT.position.y-55)
	level.player.velocity=Vector2.ZERO
	await _frames(8)
	Input.action_press("interact")
	await _frames(48)
	Input.action_press("move_left")
	await _frames(22)
	await _snap("02-partial-pull")
	Input.action_release("move_left")
	await _frames(22)
	Input.action_press("move_left")
	for i in 100:
		await _frames(1)
		if b.state!=b.State.PROPPED: break
	Input.action_release("move_left")
	Input.action_release("interact")
	await _frames(10)
	await _snap("03-release")
	for i in 150:
		await _frames(1)
		if b.state==b.State.SETTLING: break
	await _frames(5)
	await _snap("04-impact")
	if OS.get_cmdline_user_args().has("--impact-only"):
		await _frames(45)
		print("FEEDBACK COMPLETE scrapes=",b.art.scrape_count," impacts=",b.impact_impulses," landings=",b.landing_impulses)
		quit(0)
		return
	await _frames(90)
	Input.action_press("move_right")
	for i in 260:
		await _frames(1)
		if b._on_log() and b.log_body.to_local(level.player.position+Vector2(13,54)).x>150: break
	Input.action_release("move_right")
	await _frames(5)
	Input.action_press("jump")
	await _frames(18)
	Input.action_release("jump")
	await _frames(65)
	Input.action_press("move_right")
	await _frames(130)
	Input.action_release("move_right")
	await _frames(30)
	print("FEEDBACK COMPLETE pin=",b.extraction," scrapes=",b.art.scrape_count," releases=",b.art.release_count," impacts=",b.impact_impulses," landings=",b.landing_impulses," bank=",b.reached_bank)
	quit(0)
