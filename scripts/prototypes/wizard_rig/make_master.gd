extends SceneTree

# Turns the AI rig-pose sheet into a pure black RGBA master (alpha carries the shape) with an opaque
# orange eye. Run: godot --headless --path . --script res://scripts/prototypes/wizard_rig/make_master.gd
const SRC := "res://artifacts/character-concepts/wizard_rig_pose.jpg"
const DST := "res://assets/art/prototypes/wizard_rig/wizard_master.png"

func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			if c.r > 0.55 and c.r - c.b > 0.30 and c.g > 0.25:
				img.set_pixel(x, y, Color(1.0, 0.62, 0.12, 1.0))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, clampf((0.62 - lum) / 0.35, 0.0, 1.0)))
	img.save_png(ProjectSettings.globalize_path(DST))
	print("master ", img.get_size())
	quit()
