extends SceneTree

# Draws the part outlines on the master so the cuts can be checked by eye.
const Defs = preload("res://scripts/prototypes/wizard_rig/wizard_rig_defs.gd")

func _init() -> void:
	var master := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/prototypes/wizard_rig/wizard_master.png"))
	var out := Image.create(master.get_width(), master.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.92, 0.92, 0.93))
	out.blend_rect(master, Rect2i(Vector2i.ZERO, master.get_size()), Vector2i.ZERO)
	var palette := [Color.RED, Color.BLUE, Color.GREEN, Color.MAGENTA, Color.CYAN, Color.ORANGE, Color.YELLOW, Color.HOT_PINK]
	var index := 0
	for part in Defs.build():
		if not part.has("poly"):
			continue
		var color: Color = palette[index % palette.size()]
		index += 1
		var poly: PackedVector2Array = part.poly
		for i in range(poly.size()):
			_line(out, poly[i] * Defs.K, poly[(i + 1) % poly.size()] * Defs.K, color)
		var pv: Vector2 = part.pivot * Defs.K
		for d in range(-4, 5):
			out.set_pixelv(Vector2i(pv) + Vector2i(d, 0), color)
			out.set_pixelv(Vector2i(pv) + Vector2i(0, d), color)
	out.save_png("/tmp/overlay.png")
	quit()

func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var steps := int(a.distance_to(b))
	for s in range(steps + 1):
		var p := a.lerp(b, float(s) / maxf(1.0, float(steps)))
		var pi := Vector2i(p)
		if pi.x >= 0 and pi.y >= 0 and pi.x < img.get_width() and pi.y < img.get_height():
			img.set_pixelv(pi, c)
