extends SceneTree
const SCENE=preload("res://scenes/debug/c_zone_river.tscn")
const Film=preload("res://scripts/effects/film_look.gd")
var level
func _initialize():call_deferred("_run")
func _frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func _snap(name:String):
	await _frames(3)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/rope-ladder/fix-review/"+name+".png")
	print("CAPTURE ",name," cut=",level.scene1.cut," landmark=",level.art.landmark_output.visible," grass=",level.art.grass_art.visible)
func _run():
	DirAccess.make_dir_recursive_absolute("res://artifacts/rope-ladder/fix-review")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_title("Inkfall · 原有崖边演出与目的地验证")
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate()
	root.add_child(level)
	Film.attach(level)
	await _frames(8)
	level.debug_enter_rope_ladder(true)
	await _frames(10)
	Input.action_press("move_right")
	for i in 180:
		await _frames(1)
		if level.scene1.auto_walking(): break
	Input.action_release("move_right")
	await _frames(80)
	await _snap("10-auto-walk-and-grave")
	for i in 1400:
		await _frames(1)
		if level.scene1.flock_clock()>0.25: break
	await _snap("11-flock-at-grave")
	for i in 600:
		await _frames(1)
		if level.scene1.cut==level.scene1.Cut.DONE: break
	print("CONTROLS RESTORED ",not level.scene1.locks_move())
	Input.action_press("move_right")
	for i in 200:
		await _frames(1)
		if level.player.position.x+13>level.scene1.CLIFF_X-45: break
	Input.action_release("move_right")
	await _frames(10)
	await _snap("12-cliff-destination")
	Input.action_press("climb_down")
	await _frames(140)
	Input.action_release("climb_down")
	await _snap("13-ladder-destination")
	Input.action_press("climb_down")
	for i in 1600:
		await _frames(1)
		if level.rope_ladder.at_bottom: break
	Input.action_release("climb_down")
	await _snap("14-lower-destination")
	print("COMPLETE marker and destination continuity")
	quit(0)
