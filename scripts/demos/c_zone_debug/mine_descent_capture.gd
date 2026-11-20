extends SceneTree

const DIR := "res://artifacts/mine-descent-v4/review"
var level
var route

func _initialize() -> void:
	call_deferred("run")

func frames(count:int) -> void:
	for i in count: await physics_frame

func snap(label:String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	picture.save_png(DIR + "/" + label + ".png")
	print("SNAP ",label," player=",level.player.position," camera=",Vector2(level.camera_x,level.camera_y))

func focus_ride(t:float) -> void:
	route.ride_t = t
	var car:Vector2 = route.cart_position(t)
	level.player.position = car - Vector2(13,88)
	level.camera_x = car.x - 640.0
	level.camera_y = car.y - 360.0
	level.camera.position = Vector2(car.x,car.y)

func run() -> void:
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	DirAccess.make_dir_recursive_absolute(DIR)
	level = load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
	root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8)
	route = level.bridge_to_c
	level.debug_enter_rope_ladder(false)
	await snap("ladder")
	level.enter_root_cliff_test()
	await snap("stones-start")
	route.checkpoint_step = 3
	route.restore_checkpoint()
	await snap("stones-late")
	route.checkpoint_step = route.MOUTH_STEP
	route.restore_checkpoint()
	route.stop_set = true
	route.rock_progress = 1.0
	route.brake_open = true
	level.player.position.x=-3035
	await snap("mine-mouth")
	quit()
