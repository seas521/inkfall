extends CanvasLayer

# A full-screen iris, drawn above everything: black outside a circle that closes towards a point of the picture
# (amount 0 = open, 1 = black). The failure fade of the hooded boy uses it: the picture closes on him and opens on
# where he starts again. A layer of its own, so no scene layer can show through (a plain rectangle in a level's own
# canvas is drawn under its child layers and only greys the picture).

var rect: ColorRect
var material: ShaderMaterial

func _init() -> void:
	layer = 90

func _ready() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float amount = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.7778;
void fragment() {
	vec2 d = (UV - center) * vec2(aspect, 1.0);
	float dist = length(d);
	float open_radius = length(vec2(aspect, 1.0)) * 1.05;
	float radius = mix(open_radius, 0.0, smoothstep(0.0, 1.0, amount));
	float edge = 0.10 + 0.25 * amount;
	float iris = smoothstep(radius - edge, radius, dist);
	float all_black = smoothstep(0.88, 1.0, amount);
	COLOR = vec4(0.0, 0.0, 0.0, max(iris, all_black) * step(0.001, amount));
}
"""
	material = ShaderMaterial.new()
	material.shader = shader
	rect = ColorRect.new()
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	rect.hide()

# center_px: a point of the 1280 x 720 picture.
func set_state(amount: float, center_px: Vector2) -> void:
	if rect == null:
		return
	rect.visible = amount > 0.001
	material.set_shader_parameter("amount", clampf(amount, 0.0, 1.0))
	material.set_shader_parameter("center", Vector2(center_px.x / 1280.0, center_px.y / 720.0))
