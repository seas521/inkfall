extends SceneTree

# Flattens a concept sheet to pure black + the orange eye on a flat light background.
# Usage: godot --headless --path . --script res://artifacts/character-concepts/flatten.gd -- in.jpg out.png
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var img := Image.load_from_file(args[0])
	img.convert(Image.FORMAT_RGBA8)
	var bg := Color(0.90, 0.90, 0.91)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var eye := c.r > 0.55 and c.r - c.b > 0.30 and c.g > 0.25
			if eye:
				img.set_pixel(x, y, Color(1.0, 0.62, 0.12))
			elif lum < 0.30:
				img.set_pixel(x, y, Color(0, 0, 0))
			elif lum < 0.50:
				var t := (lum - 0.30) / 0.20
				img.set_pixel(x, y, Color(0, 0, 0).lerp(bg, t))
			else:
				img.set_pixel(x, y, bg)
	img.save_png(args[1])
	quit()
