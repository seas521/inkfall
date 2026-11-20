extends CanvasLayer

# The whole game seen through old film: see assets/shaders/film_look.gdshader.
# F10 switches it off and on, for comparison.

const SHADER: Shader = preload("res://assets/shaders/film_look.gdshader")
const GROUP := &"film_look"
const PENDING := &"film_look_attach_pending"
var lens_material:ShaderMaterial
var mine_target:=0.0
var mine_amount:=0.0
var route_owner:WeakRef
var route_softness:=0.0
func set_route_softness(owner:CanvasItem,amount:float=1.0)->void:
	# Tie the stronger lens to the live chapter, so menu-only scenes keep
	# their existing presentation after returning from gameplay.
	if route_owner==null or route_owner.get_ref()!=owner:route_owner=weakref(owner)
	route_softness=clampf(amount,0,1)
func set_mine_environment(amount:float)->void:
	mine_target=clampf(amount,0,1)
func _process(delta:float)->void:
	mine_amount=lerpf(mine_amount,mine_target,1-exp(-delta*5.0))
	if lens_material!=null:
		lens_material.set_shader_parameter("mine_atmosphere",mine_amount)
		var world=route_owner.get_ref() if route_owner!=null else null
		var live:bool=is_instance_valid(world) and world.is_inside_tree() and world.is_visible_in_tree()
		lens_material.set_shader_parameter("route_softness",route_softness if live else 0.0)
		if route_owner!=null and not live:
			mine_target=0.0
			lens_material.set_shader_parameter("environment_softness",0.0)
			lens_material.set_shader_parameter("river_clarity",0.0)

func set_river_clarity(enabled:bool,bank:Texture2D,canvas:Transform2D,viewport_size:Vector2)->void:
	if lens_material==null:return
	lens_material.set_shader_parameter("river_clarity",1.0 if enabled else 0.0)
	if not enabled:return
	var inverse:=canvas.affine_inverse()
	var origin:=inverse*Vector2.ZERO
	lens_material.set_shader_parameter("river_bank",bank)
	lens_material.set_shader_parameter("river_origin",origin)
	lens_material.set_shader_parameter("river_axis_x",inverse*Vector2(viewport_size.x,0)-origin)
	lens_material.set_shader_parameter("river_axis_y",inverse*Vector2(0,viewport_size.y)-origin)

func set_environment_softness(amount:float)->void:
	if lens_material!=null:lens_material.set_shader_parameter("environment_softness",clampf(amount,0,1))

# Add one film layer to the scene tree that contains `host`, unless one is already there.
static func attach(host: Node) -> void:
	var tree := host.get_tree()
	if tree == null or tree.has_meta(PENDING) or not tree.get_nodes_in_group(GROUP).is_empty():
		return
	tree.set_meta(PENDING,true)
	var layer := (load("res://scripts/effects/film_look.gd") as GDScript).new() as CanvasLayer
	tree.root.add_child.call_deferred(layer)

func _ready() -> void:
	add_to_group(GROUP)
	get_tree().remove_meta(PENDING)
	layer = 100
	follow_viewport_enabled = false
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	lens_material=material
	rect.material = material
	add_child(rect)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		visible = not visible
