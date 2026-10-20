extends Node2D

# Flame lab: the old volumetric fire next to the new particle fire, on the game's own dark ground.
#   left   the old flame (inkfall_volume shader plus its soft heat glow), as used in the C zone
#   middle the new flame as a campfire, with a black silhouette standing beside it
#   right  the new flame as a hazard strip that bursts on and off between two ledges
# F10 switches the film look on and off; the film look is attached here so it matches the game.

const InkFlame = preload("res://scripts/effects/ink_flame.gd")
const FilmLook = preload("res://scripts/effects/film_look.gd")
const OLD_SHADER: Shader = preload("res://assets/shaders/inkfall_volume.gdshader")
const GROUND_Y := 540.0
const INK := Color(0.004, 0.005, 0.006)

var clock := 0.0
var old_sprite: Sprite2D
var campfire: Node2D
var hazard: Node2D
var mist: GradientTexture2D

func _ready() -> void:
	FilmLook.attach(self)
	mist = InkFlame._radial([0.0, 0.24, 0.52, 0.78, 1.0], [0.92, 0.68, 0.31, 0.08, 0.0]) as GradientTexture2D
	old_sprite = Sprite2D.new()
	old_sprite.centered = false
	var white := GradientTexture2D.new()
	white.width = 4
	white.height = 4
	old_sprite.texture = white
	var material := ShaderMaterial.new()
	material.shader = OLD_SHADER
	material.set_shader_parameter("smoke", false)
	material.set_shader_parameter("monochrome", false)
	old_sprite.material = material
	old_sprite.z_index = 2
	add_child(old_sprite)
	# The old flame sits on a 64 x 46 hazard: 128 wide and 94 tall, base 4 below the rect.
	old_sprite.position = Vector2(230.0 - 64.0, GROUND_Y + 4.0 - 94.0)
	old_sprite.scale = Vector2(128.0, 94.0) / Vector2(4.0, 4.0)

	campfire = InkFlame.new()
	campfire.width = 50.0
	campfire.height = 86.0
	campfire.seed_value = 2
	campfire.position = Vector2(620.0, GROUND_Y - 6.0)
	campfire.z_index = 2
	add_child(campfire)

	hazard = InkFlame.new()
	hazard.width = 130.0
	hazard.height = 84.0
	hazard.seed_value = 5
	hazard.position = Vector2(1030.0, GROUND_Y + 4.0)
	hazard.z_index = 2
	add_child(hazard)

	for item in [["旧：体积着色器", 230.0], ["新：篝火", 620.0], ["新：危险火条（周期燃灭）", 1030.0]]:
		var label := Label.new()
		label.text = item[0]
		label.position = Vector2(float(item[1]) - 120.0, 60.0)
		label.size = Vector2(240.0, 24.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.6))
		label.add_theme_font_size_override("font_size", 16)
		label.z_index = 20
		add_child(label)

func _process(delta: float) -> void:
	clock += delta
	var material := old_sprite.material as ShaderMaterial
	material.set_shader_parameter("clock", clock)
	var old_strength := 0.5 + 0.5 * smoothstep(-0.2, 0.5, sin(clock * 0.9))
	old_strength = 1.0
	material.set_shader_parameter("intensity", 3.4 * old_strength + 0.5)
	hazard.strength = smoothstep(-0.25, 0.45, sin(clock * 0.9))
	queue_redraw()

func _draw() -> void:
	# Night air: dark above, a band of grey fog in the middle, dark ground.
	var top := Color(0.015, 0.016, 0.018)
	var fog := Color(0.115, 0.118, 0.12)
	var low := Color(0.03, 0.032, 0.034)
	var sky := PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 330), Vector2(0, 330)])
	draw_polygon(sky, PackedColorArray([top, top, fog, fog]))
	var mid := PackedVector2Array([Vector2(0, 330), Vector2(1280, 330), Vector2(1280, 720), Vector2(0, 720)])
	draw_polygon(mid, PackedColorArray([fog, fog, low, low]))
	# Far dark pillars.
	for x in [90.0, 410.0, 800.0, 1210.0]:
		var w := 54.0 + fmod(x, 37.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w, GROUND_Y), Vector2(x - w * 0.8, 170.0), Vector2(x - w * 0.2, 140.0), Vector2(x + w * 0.5, 160.0), Vector2(x + w * 0.8, 190.0), Vector2(x + w, GROUND_Y),
		]), Color(0.012, 0.013, 0.015))
	# Ground, with the old fire's hazard basin and the hazard strip's gap.
	draw_rect(Rect2(0.0, GROUND_Y, 1280.0, 180.0), INK)
	draw_rect(Rect2(198.0, GROUND_Y - 1.0, 64.0, 10.0), INK)
	# Old flame's heat glow, as the C zone draws it.
	var base := Vector2(230.0, GROUND_Y)
	_soft(base + Vector2(0.0, -26.0), Vector2(160.0, 64.0), Color(1.0, 0.46, 0.08, 0.42))
	_soft(base + Vector2(0.0, -14.0), Vector2(96.0, 40.0), Color(1.0, 0.78, 0.35, 0.40))
	_soft(base + Vector2(0.0, -34.0), Vector2(282.0, 150.0), Color(1.0, 0.42, 0.08, 0.20))
	# Campfire: two logs and a ring of stones.
	var c := Vector2(620.0, GROUND_Y)
	draw_line(c + Vector2(-34.0, -2.0), c + Vector2(30.0, -12.0), INK, 8.0, true)
	draw_line(c + Vector2(-30.0, -12.0), c + Vector2(34.0, -3.0), INK, 8.0, true)
	for i in range(7):
		var ang := PI + float(i) * PI / 6.0
		draw_circle(c + Vector2(cos(ang) * 44.0, -2.0 + sin(ang) * 6.0), 6.5 + float(i % 3), INK, true, -1.0, true)
	# A standing silhouette beside it, to see how the fire's light falls on it.
	var f := Vector2(740.0, GROUND_Y)
	draw_colored_polygon(PackedVector2Array([
		f + Vector2(-9, 0), f + Vector2(-11, -44), f + Vector2(-13, -80), f + Vector2(-7, -96), f + Vector2(8, -96), f + Vector2(14, -80), f + Vector2(11, -44), f + Vector2(9, 0),
	]), INK)
	draw_circle(f + Vector2(0, -106), 11.0, INK, true, -1.0, true)
	# Hazard strip: two ledges and a dark basin between them.
	draw_rect(Rect2(880.0, GROUND_Y - 20.0, 85.0, 200.0), INK)
	draw_rect(Rect2(1095.0, GROUND_Y - 20.0, 85.0, 200.0), INK)
	draw_rect(Rect2(960.0, GROUND_Y + 6.0, 140.0, 200.0), INK)

func _soft(center: Vector2, size: Vector2, color: Color) -> void:
	draw_texture_rect(mist, Rect2(center - size * 0.5, size), false, color)
