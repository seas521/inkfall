extends SceneTree

const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const FilmLook = preload("res://scripts/effects/film_look.gd")
const Layout = preload("res://scripts/demos/c_zone_debug/descent_layout.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level = SCENE.instantiate()
	root.add_child(level)
	FilmLook.attach(level)
	await _frames(8)
	level.debug_enter_descent()
	assert(level.descent.enabled,"Art review must be entered")
	for i in range(Layout.SHOTS.size()):
		level.descent.enter(i)
		level.descent.entry_time = 3.0
		await _frames(12)
		level.descent.hud.hide()
		await _frames(4)
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://artifacts/descent/%02d.png" % (i+1))
		print("CAPTURE ",i+1," ",Layout.SHOTS[i].name," camera=",level.camera.position)
		assert(level.camera.position.distance_to(Vector2(Layout.SHOTS[i].camera)+Vector2(640,360)) < 0.1,"Review camera must reach the selected space")
	# Hold a set for several seconds to exercise the actual atmosphere update.
	level.descent.enter(2)
	await _frames(120)
	# Inspect a slow passage through the actual cave/C handoff and a second hold for air motion.
	for t in [4.5,5.25,5.75]:
		level.descent.rail = t
		level.descent.target = t
		await _frames(6)
		level.descent.hud.hide()
		await _frames(2)
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://artifacts/descent/seam-%.2f.png" % t)
	level.descent.leave_to_river()
	await _frames(8)
	assert(not level.descent.enabled,"C gameplay must resume")
	assert(level.descent.art.weight == 0.0,"New matte must not cover C")
	assert(is_equal_approx(level.marsh_art.modulate.a,1.0),"Original C ink must be fully restored")
	print("PASS: all five sets and C mouth load; C gameplay resumes, preview=",level.descent.enabled)
	quit(0)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
