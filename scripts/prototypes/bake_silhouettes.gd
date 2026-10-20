extends SceneTree

# Bakes the first level's black silhouettes into plain RGBA pictures: the colour is exactly black
# everywhere and only the alpha carries the shape, so they are the same black in every renderer and
# need no keying shader.  Run: godot --headless --path . --script res://scripts/prototypes/bake_silhouettes.gd
const DIR := "res://assets/art/level01/cinematic_surface/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Left foreground: a generated black tree on magenta. Magenta is bright in red, black is not.
	_bake(DIR + "foreground-left-rich.jpg", DIR + "foreground-left-tree.png", Rect2i(), 0)
	# Right foreground: already has an alpha channel; keep it, make it black.
	_bake(DIR + "foreground-frame-v3-transparent.png", DIR + "foreground-right-black.png", Rect2i(1132, 0, 540, 941), 1)
	# The yard tree on a magenta plate.
	_bake(DIR + "yard-tree-v2-magenta.png", DIR + "yard-tree-black.png", Rect2i(), 2)
	quit(0)

# mode 0: key by red; 1: keep the source alpha; 2: key magenta by (min(r, b) - g)
func _bake(source_path: String, target_path: String, crop: Rect2i, mode: int) -> void:
	var image := Image.load_from_file(source_path)
	if image == null:
		push_error("cannot load " + source_path)
		return
	image.convert(Image.FORMAT_RGBA8)
	if crop.size != Vector2i.ZERO:
		image = image.get_region(crop)
	var width := image.get_width()
	var height := image.get_height()
	var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var opaque := 0
	for y in range(height):
		for x in range(width):
			var c := image.get_pixel(x, y)
			var alpha := 0.0
			match mode:
				0:
					alpha = 1.0 - smoothstep(0.06, 0.40, c.r)
				1:
					alpha = c.a
				2:
					var excess := minf(c.r, c.b) - c.g
					alpha = c.a * (1.0 - smoothstep(0.006, 0.075, excess))
			if alpha < 0.03:
				alpha = 0.0
			if alpha > 0.0:
				opaque += 1
			out.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	out.save_png(target_path)
	print("baked ", target_path, " ", width, "x", height, " opaque px ", opaque)
