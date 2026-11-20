extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var gallery=load("res://scenes/demos/mine_art_gallery.tscn").instantiate()
	root.add_child(gallery)
	for i in 80:await physics_frame
	assert(gallery.ready_for_review)
	for item in [[-2880,"entry"],[-1600,"deep"],[-500,"exit"]]:
		gallery.set_view(float(item[0]))
		for i in 10:await physics_frame
		await RenderingServer.frame_post_draw
		var im:=root.get_texture().get_image()
		im.resize(1280,720,Image.INTERPOLATE_LANCZOS)
		im.save_png("res://artifacts/mine-art-v10/review/gallery-"+item[1]+".png")
	print("MINE ART GALLERY PASS")
	quit()
