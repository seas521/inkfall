extends ColorRect

# The misty forest backdrop (the look of Limbo's opening forest), meant to be reused wherever the game is in the trees: scene 1 and
# the later misty woodland. It is one full-screen shader and nothing else:
#   - fog light: big soft patches, brightest just behind the ground line, dark canopy at the top with gaps that let light through
#   - a slanted shaft of light (strength set by the caller)
#   - two planes of huge, soft, out-of-focus trunks (far: pale grey, mid: dark grey), each with its own parallax; they flare at the foot
#   - nothing is drawn sharp: depth is blur and value, the crisp things (the boy, the ground, the obstacles) are drawn elsewhere
# The caller drives it with `sync()` every frame; `near_trunks()` draws the big black trunks that pass in front (into a blurred layer).

# Restore the original atmospheric light field; tree silhouettes are separate
# existing image plates. Rejected broadleaf panoramas are not used.
const SHADER=preload("res://assets/shaders/forest_original_atmosphere.gdshader")

func _init() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SHADER

# horizon: the screen y of the ground line; level: how bright the fog is (0.3 dark .. 1 bright); shaft: 0..1 and shaft_x: where on the
# screen the shaft of light stands; density: 1 = trunks everywhere, 0 = none; reveal_edge: 2 = whole picture, below 0 = cut away.
func sync(camera_x: float, clock: float, horizon: float, level_value: float, shaft_value: float, shaft_screen_x: float, _density: float, reveal_edge: float) -> void:
	var m := material as ShaderMaterial
	m.set_shader_parameter("scroll", camera_x)
	m.set_shader_parameter("clock", clock)
	m.set_shader_parameter("horizon", horizon)
	m.set_shader_parameter("level", level_value)
	m.set_shader_parameter("shaft", shaft_value)
	m.set_shader_parameter("shaft_x", shaft_screen_x)
	m.set_shader_parameter("reveal_edge", reveal_edge)

# Linear interpolation through keys (Vector2: x = position 0..1, y = value).
static func keyed(keys: Array, t: float) -> float:
	if t <= (keys[0] as Vector2).x:
		return (keys[0] as Vector2).y
	for i in range(1, keys.size()):
		var a: Vector2 = keys[i - 1]
		var b: Vector2 = keys[i]
		if t <= b.x:
			return lerpf(a.y, b.y, smoothstep(0.0, 1.0, (t - a.x) / maxf(b.x - a.x, 0.0001)))
	return (keys[keys.size() - 1] as Vector2).y
