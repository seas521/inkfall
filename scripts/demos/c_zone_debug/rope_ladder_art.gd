extends Node2D

const Marsh = preload("res://scripts/demos/c_zone_debug/marsh_art.gd")
const INK := Color("050606")
const Scene1Ink = preload("res://scripts/demos/c_zone_debug/scene1_ink.gd")
var ladder
var viewport: SubViewport
var ink: Node2D
var output: Sprite2D
var fog_layer: CanvasLayer
var fog: ColorRect

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1328,768)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.msaa_2d = Viewport.MSAA_4X
	add_child(viewport)
	ink = Node2D.new()
	ink.draw.connect(_draw_ladder)
	viewport.add_child(ink)
	output = Sprite2D.new()
	output.centered = false
	output.z_index = 4
	output.texture = viewport.get_texture()
	var shader := Shader.new()
	shader.code = Marsh.INK_SHADER
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("ink",INK)
	material_value.set_shader_parameter("soften",1.1)
	output.material = material_value
	add_child(output)
	fog_layer = CanvasLayer.new()
	fog_layer.layer = 9
	add_child(fog_layer)
	fog = ColorRect.new()
	fog.size = Vector2(1280,720)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_material := ShaderMaterial.new()
	fog_material.shader = preload("res://assets/shaders/rope_ladder_fog.gdshader")
	fog.material = fog_material
	fog_layer.add_child(fog)
	fog_layer.hide()

func sync(origin: Vector2, enabled: bool) -> void:
	visible = enabled
	# Keep the naturally misted distant plate; remove the overlaid fog veil.
	fog_layer.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	if not enabled:
		return
	ink.position = -origin.round()+Vector2(24,24)
	output.position = origin.round()-Vector2(24,24)
	(fog.material as ShaderMaterial).set_shader_parameter("clock",ladder.clock)
	(fog.material as ShaderMaterial).set_shader_parameter("camera_y",origin.y)
	(fog.material as ShaderMaterial).set_shader_parameter("strength",ladder.entry_mix())
	ink.queue_redraw()

func _draw_ladder() -> void:
	var top: Vector2 = ladder.anchor()
	var length: float = ladder.length()
	var pitch: float = ladder.rung_pitch()
	if ladder.level.log_bridge.active:
		Scene1Ink.draw_cliff_world(ink)
	# Source-video rail spacing and rung rhythm, kept separate from character art.
	for side in [-1.0,1.0]:
		var rail := PackedVector2Array()
		for i in range(34):
			var y := length*float(i)/33.0
			rail.append(top+Vector2(side*4.4+ladder.bend(y),y))
		ink.draw_polyline(rail,INK,1.75,true)
		ink.draw_arc(top+Vector2(side*4.4,-1),2.9,0,TAU,12,INK,1.6,true)
	var y: float = 100.0*ladder.source_scale()
	while y < length-4:
		var dx: float = ladder.bend(y)
		var slope := sin(y*0.09)*0.65
		var a := top+Vector2(dx-6.0,y+1.5+slope)
		var b := top+Vector2(dx+6.1,y-1.5+slope)
		var normal := (b-a).orthogonal().normalized()
		ink.draw_colored_polygon(PackedVector2Array([a-normal*1.6,b-normal*1.3,b+normal*1.65,a+normal*1.5]),INK)
		for side in [-1.0,1.0]:
			ink.draw_circle(top+Vector2(dx+side*4.4,y-side*1.1),2.0,INK,true,-1,true)
		y += pitch
	# Unequal short frayed tails, not repeated spikes.
	for side in [-1.0,1.0]:
		var end := top+Vector2(ladder.bend(length)+side*4.4,length)
		ink.draw_polyline(PackedVector2Array([end,end+Vector2(-1.1,5.0),end+Vector2(side*1.5,8.0)]),INK,0.9,true)
