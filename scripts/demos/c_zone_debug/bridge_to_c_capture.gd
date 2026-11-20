extends SceneTree

const CHAPTER=preload("res://scenes/chapters/chapter_01_route.tscn")
var level
var route

func _initialize()->void:call_deferred("_run")

func frames(n:int)->void:
	for _i in n:
		await physics_frame
		await process_frame

func snap(label:String)->void:
	await frames(3)
	RenderingServer.force_draw()
	var shot:=root.get_texture().get_image()
	shot.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	shot.save_png("res://artifacts/post-bridge/direct-c/%s.png"%label)
	print("BRIDGE TO C CAPTURE ",label," feet=",route.feet()," cover=",route.cover," swapped=",route.swapped)

func place_feet(p:Vector2)->void:
	level.player.position=p-Vector2(13,54)
	level.player.velocity=Vector2.ZERO
	level.camera_x=level.player.position.x-525.0
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640.0,level.camera_y+360.0)

func _run()->void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/post-bridge/direct-c")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=CHAPTER.instantiate()
	root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8)
	route=level.bridge_to_c
	level.scene1.cut=level.scene1.Cut.DONE
	level.scene1.intro_time=99.0
	level.log_bridge.enter(false)
	level.log_bridge.state=level.log_bridge.State.BRIDGED
	level.log_bridge.angle=level.log_bridge.END_ANGLE
	level.log_bridge.extraction=level.log_bridge.PIN_TRAVEL
	level.log_bridge.reached_bank=true
	place_feet(Vector2(-2260,-3715))
	await snap("01-right-bank")
	route._begin()
	place_feet(Vector2(-2100,-3707))
	route.cover=0.58
	route.art.sync(0.0)
	await snap("02-foreground-cover")
	route.cover=1.0
	route._swap_worlds()
	route.art.sync(0.0)
	await snap("03-hidden-swap")
	place_feet(Vector2(-35,level.ground_y(-35)))
	route.cover=0.55
	route.art.sync(0.0)
	level._present(0.0)
	await snap("04-c-bank-emerge")
	place_feet(Vector2(90,level.ground_y(90)))
	route._finish()
	level._present(0.0)
	await snap("05-c-zone")
	quit(0)
