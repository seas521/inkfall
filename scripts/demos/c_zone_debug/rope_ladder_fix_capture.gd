extends SceneTree
const SCENE=preload("res://scenes/debug/c_zone_river.tscn")
const Film=preload("res://scripts/effects/film_look.gd")
var level
var ladder
func _initialize(): call_deferred("_run")
func _frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func _snap(label:String):
	await _frames(3)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/rope-ladder/fix-review/"+label+".png")
	print("CAPTURE ",label," feet=",ladder.feet()," grass=",level.art.grass_art.visible," mode=",ladder.mode," deaths=",level.log_bridge.deaths)
func _run():
	DirAccess.make_dir_recursive_absolute("res://artifacts/rope-ladder/fix-review")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_title("Inkfall · 地面衔接与绳梯流程验证")
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate()
	root.add_child(level)
	Film.attach(level)
	await _frames(8)
	level.debug_enter_rope_ladder()
	ladder=level.rope_ladder
	var x:float=level.scene1.CLIFF_X-480
	level.player.position=Vector2(x-13,level.scene1.ground_top(x)-54)
	level.player.velocity=Vector2.ZERO
	level.camera_x=x-525
	level.camera_y=level.scene1.ground_top(x)-350
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	await _frames(20)
	await _snap("01-original-ground")
	Input.action_press("move_right")
	for i in 400:
		await _frames(1)
		if ladder.feet().x>level.scene1.CLIFF_X-50: break
	Input.action_release("move_right")
	await _frames(12)
	await _snap("02-same-ground-at-edge")
	Input.action_press("climb_down")
	await _frames(140)
	Input.action_release("climb_down")
	await _snap("03-ground-during-mount")
	Input.action_press("climb_down")
	for i in 1600:
		await _frames(1)
		if ladder.at_bottom: break
	Input.action_release("climb_down")
	await _snap("04-suspended-end")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(130)
	Input.action_press("move_left")
	for i in 120:
		await _frames(1)
		if ladder.feet().x<ladder.anchor().x+25: break
	Input.action_release("move_left")
	await _frames(15)
	await _snap("05-directly-under-ladder")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(24)
	await _snap("06-near-jump-catch")
	Input.action_press("climb_up")
	for i in 1800:
		await _frames(1)
		if ladder.returned_top>0: break
	Input.action_release("climb_up")
	await _frames(15)
	await _snap("07-returned-ground")
	Input.action_press("climb_down")
	for i in 700:
		await _frames(1)
		if ladder.feet().y>ladder.anchor().y+310: break
	Input.action_release("climb_down")
	await _frames(5)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	for i in 120:
		await _frames(1)
		if level.log_bridge.failure_time>0: break
	await _frames(6)
	await _snap("08-lethal-impact")
	await _frames(100)
	await _snap("09-checkpoint")
	print("COMPLETE catches=",ladder.caught," returned=",ladder.returned_top," deaths=",level.log_bridge.deaths)
	quit(0)
