extends CanvasLayer

# The whole game seen through old film: see assets/shaders/film_look.gdshader.
# F10 switches it off and on, for comparison.

const SHADER: Shader = preload("res://assets/shaders/film_look.gdshader")
const GROUP := &"film_look"

# Add one film layer to the scene tree that contains `host`, unless one is already there.
static func attach(host: Node) -> void:
	var tree := host.get_tree()
	if tree == null or not tree.get_nodes_in_group(GROUP).is_empty():
		return
	var layer := (load("res://scripts/effects/film_look.gd") as GDScript).new() as CanvasLayer
	tree.root.add_child.call_deferred(layer)

func _ready() -> void:
	add_to_group(GROUP)
	layer = 100
	follow_viewport_enabled = false
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	rect.material = material
	add_child(rect)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		visible = not visible
