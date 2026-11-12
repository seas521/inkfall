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
	await _frames(3)
	RenderingServer.force_draw()
	var frame_image:Image=root.get_texture().get_image()
	frame_image.save_png("res://artifacts/rope-ladder/"+label+".png")
	if label=="04-lower-hold":
		var solid:=true
		for point in [Vector2(30,200),Vector2(80,400),Vector2(100,600)]:
			var pixel:Color=frame_image.get_pixelv(Vector2i(point*Vector2(frame_image.get_size())/Vector2(1280,720)))
			solid=solid and pixel.get_luminance()<0.12
		print("PASS: solid left cliff interior" if solid else "FAIL: left cliff interior reveals background")
	print("CAPTURE ",label," feet=",level.rope_ladder.feet()," frame=",level.rope_ladder.frame)
func _run():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate()
	root.add_child(level)
	Film.attach(level)
	await _frames(8)
	level.debug_enter_rope_ladder(OS.get_cmdline_user_args().has("--play"))
	await _frames(20)
	if OS.get_cmdline_user_args().has("--play"):
		DisplayServer.window_set_title("Inkfall · 崖间绳梯 · 连续跟随预览")
		print("PLAY READY: D enters the original walk/flock marker; S mounts, W/S climbs, Space jumps; destination stays visible at fixed scale behind the near bank; original grass persists")
		return
	await _snap("01-cliff")
	if OS.get_cmdline_user_args().has("--top-only"):
		quit(0)
		return
	Input.action_press("climb_down")
	await _frames(140)
	await _snap("02-descent")
	await _frames(300)
	await _snap("03-fog")
	for i in 1600:
		await _frames(1)
		if level.rope_ladder.at_bottom: break
	Input.action_release("climb_down")
	await _frames(25)
	await _snap("04-lower-hold")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(24)
	await _snap("05-jump")
	await _frames(100)
	await _snap("06-bank")
	var top:Vector2=level.rope_ladder.anchor()
	level.player.position=Vector2(top.x+68-13,level.log_bridge.LEFT.position.y-54)
	level.player.velocity=Vector2.ZERO
	await _frames(12)
	level.facing=-1
	Input.action_press("climb_up")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(400)
	await _snap("07-return")
	for i in 1800:
		await _frames(1)
		if level.rope_ladder.returned_top>0: break
	Input.action_release("climb_up")
	await _frames(20)
	await _snap("08-top")
	print("COMPLETE returned=",level.rope_ladder.returned_top," jumps=",level.rope_ladder.jumps)
	quit(0)
