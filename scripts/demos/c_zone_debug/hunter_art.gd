extends Node2D

# The hunter's pictures (the script is hunter_act.gd): a lantern swinging far back in the trees whose glow creeps in from the left as he
# nears, the shadow of the foot (a dark column that thickens), the foot itself (in front, huge), and the arm sweeping through the fog (behind
# everything, soft and grey) with the dark band it throws on the ground. All black silhouettes made from generated images.
const FOOT_IMAGE := preload("res://assets/art/c_zone_debug/forest/hunter_foot.jpg")
const ARM_IMAGE := preload("res://assets/art/c_zone_debug/forest/hunter_arm.jpg")
const SCREEN := Vector2(1280.0, 720.0)
const FOOT_SOLE_LEFT := 137.0  # in the foot picture: the sole's left and right ends, its centre and its bottom
const FOOT_SOLE_RIGHT := 672.0
const FOOT_SOLE_BOTTOM := 1196.0
const ARM_HAND_X := 985.0  # the palm
const ARM_CLAW_BOTTOM := 591.0

const SHADER := """shader_type canvas_item;
uniform vec4 ink : source_color = vec4(0.012, 0.013, 0.013, 1.0);
uniform float soft = 0.0;
uniform float strength = 1.0;
void fragment() {
	float l = dot(textureLod(TEXTURE, UV, soft).rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(ink.rgb, (1.0 - smoothstep(0.20, 0.80, l)) * strength);
}"""

var level: Node2D
var hunter: Node2D
var clock := 0.0
var back_layer: CanvasLayer
var front_layer: CanvasLayer
var arm_sprite: Sprite2D
var hand_sprite: Sprite2D  # the same arm, turned to come down from above (the cliff)
var foot_sprite: Sprite2D
var column_art: Node2D  # behind the world: the shadows
var glow_art: Node2D  # over it: the lantern, the flecks
var column_texture: ImageTexture
var glow_texture: GradientTexture2D
var camera_x := 0.0
var camera_y := 0.0
var shake_offset := Vector2.ZERO

func setup(level_node: Node2D, host: Node) -> void:
	level = level_node
	back_layer = CanvasLayer.new()
	back_layer.layer = -9
	host.add_child(back_layer)
	front_layer = CanvasLayer.new()
	front_layer.layer = 14
	host.add_child(front_layer)
	column_texture = _make_column_texture()
	glow_texture = _make_glow_texture()
	column_art = Node2D.new()
	column_art.draw.connect(_draw_columns)
	back_layer.add_child(column_art)
	arm_sprite = _make_sprite(ARM_IMAGE, Rect2(-4000.0, 0.0, 5280.0, 720.0), 3.0, 0.50, Color(0.06, 0.065, 0.065))
	back_layer.add_child(arm_sprite)
	foot_sprite = _make_sprite(FOOT_IMAGE, Rect2(0.0, -4000.0, 720.0, 5280.0), 0.8, 1.0, Color(0.012, 0.013, 0.013))
	front_layer.add_child(foot_sprite)
	hand_sprite = _make_sprite(ARM_IMAGE, Rect2(-4000.0, 0.0, 5280.0, 720.0), 0.9, 1.0, Color(0.012, 0.013, 0.013))
	hand_sprite.rotation = PI * 0.5
	front_layer.add_child(hand_sprite)
	glow_art = Node2D.new()
	glow_art.draw.connect(_draw_glow)
	front_layer.add_child(glow_art)

func _make_sprite(texture: Texture2D, region: Rect2, soft: float, strength: float, ink: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shader := Shader.new()
	shader.code = SHADER
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("soft", soft)
	material_value.set_shader_parameter("strength", strength)
	material_value.set_shader_parameter("ink", ink)
	sprite.material = material_value
	sprite.visible = false
	return sprite

# a dark column with soft sides, strongest at the bottom (the ground) and thinning upward
func _make_column_texture() -> ImageTexture:
	var image := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		var v := float(y) / 127.0
		for x in 64:
			var u := absf(float(x) / 63.0 * 2.0 - 1.0)
			var side := 1.0 - smoothstep(0.55, 1.0, u)
			var alpha := side * (0.30 + 0.70 * pow(v, 1.2))
			image.set_pixel(x, y, Color(0.0, 0.0, 0.01, alpha))
	return ImageTexture.create_from_image(image)

func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.42))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture

func sync(delta: float, new_camera_x: float, new_camera_y: float, hunter_node: Node2D, active: bool) -> void:
	clock += delta
	hunter = hunter_node
	camera_x = new_camera_x
	camera_y = new_camera_y
	back_layer.visible = active
	front_layer.visible = active
	if not active or hunter == null:
		return
	shake_offset = level.camera.offset if level.camera != null else Vector2.ZERO
	var ground_screen: float = hunter.scene1.GROUND_Y - camera_y - shake_offset.y
	# --- the foot: huge, in front. its sole fills the stretch the shadow lay on
	var down: float = hunter.foot_down()
	var lift: float = hunter.foot_lift()
	foot_sprite.visible = down > 0.0 and lift < 1.0
	if foot_sprite.visible:
		var centre_x: float = (hunter.FOOT_X0 + hunter.FOOT_X1) * 0.5 - camera_x - shake_offset.x
		var scale_value: float = (hunter.FOOT_X1 - hunter.FOOT_X0 + 46.0) / (FOOT_SOLE_RIGHT - FOOT_SOLE_LEFT)
		foot_sprite.scale = Vector2.ONE * scale_value
		# (the sprite's region starts 4000 px above the picture, to carry the leg up out of the frame: its origin is that high)
		var rest_y := ground_screen + 6.0 - (FOOT_SOLE_BOTTOM + 4000.0) * scale_value
		foot_sprite.position = Vector2(centre_x - (FOOT_SOLE_LEFT + FOOT_SOLE_RIGHT) * 0.5 * scale_value, rest_y - (1.0 - down) * 900.0 - lift * 900.0)
	# --- the arm: far back, grey, the hand over the band it throws
	var band = hunter.arm_x()
	arm_sprite.visible = band != null
	if band != null:
		var s := 0.95
		arm_sprite.scale = Vector2.ONE * s
		var fade := smoothstep(-200.0, 200.0, float(band) - camera_x) * (1.0 - smoothstep(1200.0, 1700.0, float(band) - camera_x))
		(arm_sprite.material as ShaderMaterial).set_shader_parameter("strength", 0.55 * fade)
		arm_sprite.position = Vector2(float(band) - camera_x - shake_offset.x - (ARM_HAND_X + 4000.0) * s, ground_screen + 12.0 - ARM_CLAW_BOTTOM * s)
	# --- the hand at the cliff: from above, claws down, on the spot the shadow marks
	var slam: Dictionary = hunter.scene1.slam_info()
	var hand_down: float = slam.down
	var hand_gone: float = slam.lift
	hand_sprite.visible = hand_down > 0.0 and hand_gone < 1.0
	if hand_sprite.visible:
		var hs := 0.85
		hand_sprite.scale = Vector2.ONE * hs
		# the palm is the pivot (so the turn keeps it on the spot); the claws reach about 200 px (picture) below it, to the ground
		hand_sprite.offset = -Vector2(ARM_HAND_X + 4000.0, 300.0)
		var hx: float = float(slam.x) - camera_x - shake_offset.x
		hand_sprite.position = Vector2(hx, ground_screen - 170.0 * hs * 0.85 - (1.0 - hand_down) * 1000.0 - hand_gone * 1000.0)
	column_art.queue_redraw()
	glow_art.queue_redraw()

func _draw_columns() -> void:
	if hunter == null:
		return
	var ground_screen: float = hunter.scene1.GROUND_Y - camera_y - shake_offset.y
	var shadow: float = hunter.foot_shadow()
	if shadow > 0.01 and hunter.foot_lift() < 1.0:
		var x0: float = hunter.FOOT_X0 - 40.0 - camera_x - shake_offset.x
		var width: float = hunter.FOOT_X1 - hunter.FOOT_X0 + 80.0
		var lift_fade: float = 1.0 - hunter.foot_lift()
		var flicker := 0.92 + 0.08 * sin(clock * 23.0)
		column_art.draw_texture_rect(column_texture, Rect2(x0, ground_screen - 520.0, width, 530.0), false, Color(1.0, 1.0, 1.0, shadow * 1.0 * flicker * lift_fade))
	var slam: Dictionary = hunter.scene1.slam_info()
	if float(slam.shadow) > 0.01:
		var sx: float = float(slam.x) - camera_x - shake_offset.x
		column_art.draw_texture_rect(column_texture, Rect2(sx - 210.0, ground_screen - 560.0, 420.0, 572.0), false, Color(1.0, 1.0, 1.0, float(slam.shadow) * (0.92 + 0.08 * sin(clock * 21.0))))
	var band = hunter.arm_x()
	if band != null:
		var half: float = hunter.ARM_WIDTH * 0.5
		var bx: float = float(band) - camera_x - shake_offset.x
		var fade := smoothstep(-300.0, 100.0, bx) * (1.0 - smoothstep(1300.0, 1700.0, bx))
		column_art.draw_texture_rect(column_texture, Rect2(bx - half * 1.5, ground_screen - 260.0, half * 3.0, 272.0), false, Color(1.0, 1.0, 1.0, 0.9 * fade))

func _draw_glow() -> void:
	if hunter == null:
		return
	var pressure: float = hunter.pressure
	var hero_x: float = level.player.position.x + 13.0 - camera_x
	# --- flecks of bark and leaf shaken down on the stretch the foot is coming down on
	if hunter.foot_phase == 1:
		var u: float = clampf(hunter.foot_time / hunter.FOOT_OMEN, 0.0, 1.0)
		var ground_screen: float = hunter.scene1.GROUND_Y - camera_y - shake_offset.y
		for i in 34:
			var seed_value := float(i) * 7.31
			var fx: float = hunter.FOOT_X0 - 20.0 + fposmod(seed_value * 13.7, hunter.FOOT_X1 - hunter.FOOT_X0 + 40.0) - camera_x
			var fall := fposmod(clock * (140.0 + float(i % 5) * 40.0) + seed_value * 41.0, ground_screen + 40.0)
			var a := smoothstep(0.1, 0.5, u) * 0.75
			glow_art.draw_rect(Rect2(fx + sin(clock * 3.0 + seed_value) * 4.0, fall - 20.0, 2.0 + float(i % 3), 3.0 + float(i % 4)), Color(0.03, 0.03, 0.03, a))
	# --- the lantern: a glow that creeps in from the left as he closes; it hangs from a chain out of the dark above and swings
	if pressure < 0.04:
		return
	var swing := sin(clock * 1.35) * 0.5 + sin(clock * 2.1 + 1.0) * 0.25
	var lx := hero_x - 420.0 * (1.15 - pressure) - 180.0 + swing * (30.0 + 40.0 * pressure)
	var ly := 150.0 + 60.0 * (1.0 - pressure) + sin(clock * 1.9) * 10.0
	var radius := 150.0 + 330.0 * pressure
	var flick := 0.9 + 0.1 * sin(clock * 17.0) * sin(clock * 5.3)
	var a := clampf(pow(pressure, 0.85) * 0.62, 0.0, 0.62) * flick
	glow_art.draw_texture_rect(glow_texture, Rect2(lx - radius, ly - radius, radius * 2.0, radius * 2.0), false, Color(1.0, 0.60, 0.26, a))
	glow_art.draw_texture_rect(glow_texture, Rect2(lx - radius * 0.34, ly - radius * 0.34, radius * 0.68, radius * 0.68), false, Color(1.0, 0.82, 0.52, a * 1.1))
	# the lantern's chain, and its cage
	var top := Vector2(lx - swing * 22.0, -40.0)
	glow_art.draw_line(top, Vector2(lx, ly - 12.0), Color(0.02, 0.02, 0.02, 0.5 * clampf(pressure * 2.0, 0.0, 1.0)), 2.0, true)
	glow_art.draw_circle(Vector2(lx, ly), 7.0 + 3.0 * pressure, Color(1.0, 0.92, 0.7, 0.95 * clampf(pressure * 2.0, 0.0, 1.0)))
	glow_art.draw_arc(Vector2(lx, ly), 10.0 + 3.0 * pressure, 0.0, TAU, 18, Color(0.02, 0.02, 0.02, 0.8 * clampf(pressure * 2.0, 0.0, 1.0)), 2.0, true)
