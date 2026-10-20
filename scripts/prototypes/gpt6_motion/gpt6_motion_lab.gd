extends Node3D

const HoodRig = preload("res://scripts/prototypes/gpt6_motion/gpt6_hood_rig.gd")
const DEMO_LENGTH := 25.5
const RUN_SPEED := 2.7
const WALK_SPEED := 0.92
const GRAVITY := 12.8
const JUMP_SPEED := 5.0

var body: CharacterBody3D
var rig: Node3D
var camera: Camera3D
var shadow: MeshInstance3D
var state_label: Label
var phase_label: Label
var time_label: Label
var mode_auto: Button
var mode_manual: Button
var pause_button: Button
var timeline: ProgressBar
var slow_select: OptionButton
var auto_mode := true
var paused := false
var playback_speed := 1.0
var demo_time := 0.0
var elapsed := 0.0
var jump_buffer := 0.0
var coyote_time := 0.0
var last_jump_segment := -1
var impact_speed := 0.0
var last_vx := 0.0
var pending_jump := false
var manual_override: Dictionary = {}
var test_mode := false
var ready_for_test := false
var observed_states: Dictionary = {}
var simulated_frames := 0


func _ready() -> void:
	test_mode = OS.get_environment("GPT6_TEST") == "1"
	if not test_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		get_window().title = "INKFALL | GPT6 Hood Motion Lab"
	_build_stage()
	_build_player()
	_build_ui()
	reset_demo()
	ready_for_test = true


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.69, 0.71, 0.70)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var backdrop := MeshInstance3D.new()
	var backdrop_mesh := QuadMesh.new()
	backdrop_mesh.size = Vector2(100.0, 20.0)
	backdrop.mesh = backdrop_mesh
	backdrop.position = Vector3(0, 6, -3)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	float grain = hash(FRAGCOORD.xy) - 0.5;
	float low = sin(world_pos.x * 1.6 + sin(world_pos.y * 2.7)) * 0.009;
	float haze = smoothstep(-0.2, 3.6, world_pos.y);
	vec3 base = mix(vec3(0.53, 0.56, 0.55), vec3(0.76, 0.77, 0.75), haze);
	ALBEDO = base + grain * 0.022 + low;
}
"""
	material.shader = shader
	backdrop.material_override = material
	add_child(backdrop)

	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60, 0.4, 4)
	collision.shape = shape
	collision.position.y = -0.2
	floor_body.add_child(collision)
	add_child(floor_body)
	var floor_visual := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(60, 3, 4)
	floor_visual.mesh = floor_mesh
	floor_visual.position = Vector3(0, -1.505, 0)
	floor_visual.material_override = _flat_material(Color(0.125, 0.15, 0.145))
	add_child(floor_visual)
	for x in range(-28, 29):
		var tick := MeshInstance3D.new()
		var tick_mesh := BoxMesh.new()
		tick_mesh.size = Vector3(0.012, 0.035 if x % 5 else 0.075, 0.01)
		tick.mesh = tick_mesh
		tick.position = Vector3(x, -0.10, 2.01)
		tick.material_override = _flat_material(Color(0.30, 0.34, 0.32))
		add_child(tick)
	for side in [-1, 1]:
		var wall := StaticBody3D.new()
		var wall_shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(0.5, 6, 4)
		wall_shape.shape = wall_box
		wall.position = Vector3(side * 12.5, 2, 0)
		wall.add_child(wall_shape)
		add_child(wall)
		var marker := MeshInstance3D.new()
		var marker_mesh := BoxMesh.new()
		marker_mesh.size = Vector3(0.08, 0.8, 0.08)
		marker.mesh = marker_mesh
		marker.position = Vector3(side * 12.1, 0.4, -0.4)
		marker.material_override = _flat_material(Color(0.25, 0.28, 0.27))
		add_child(marker)

	shadow = MeshInstance3D.new()
	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(0.95, 0.12)
	shadow.mesh = shadow_mesh
	var shadow_material := ShaderMaterial.new()
	var shadow_shader := Shader.new()
	shadow_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float d = length((UV - 0.5) * 2.0);
	ALBEDO = vec3(0.02, 0.03, 0.025);
	ALPHA = (1.0 - smoothstep(0.0, 1.0, d)) * 0.22;
}
"""
	shadow_material.shader = shadow_shader
	shadow.material_override = shadow_material
	shadow.position = Vector3(0, 0.025, -0.28)
	add_child(shadow)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 4.6
	camera.position = Vector3(0, 1.43, 10)
	camera.current = true
	add_child(camera)
	get_viewport().msaa_3d = Viewport.MSAA_4X


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _build_player() -> void:
	body = CharacterBody3D.new()
	body.name = "GPT6Player"
	body.floor_snap_length = 0.12
	body.floor_stop_on_slope = true
	body.axis_lock_linear_z = true
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.17
	shape.height = 1.45
	collision.shape = shape
	collision.position.y = shape.height * 0.5
	body.add_child(collision)
	add_child(body)
	rig = HoodRig.new()
	rig.name = "GPT6Hood"
	body.add_child(rig)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 36)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	var title := Label.new()
	title.text = "INKFALL"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.08, 0.10, 0.09))
	identity.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "GPT6 / HOOD STUDY 01"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.26, 0.30, 0.28))
	identity.add_child(subtitle)
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_END
	modes.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(modes)
	var group := ButtonGroup.new()
	mode_auto = _button("AUTO", "Automatic sequence (Tab)")
	mode_auto.toggle_mode = true
	mode_auto.button_group = group
	mode_auto.pressed.connect(func(): set_auto_mode(true))
	modes.add_child(mode_auto)
	mode_manual = _button("MANUAL", "A/D or arrows: walk. Shift: run. Space/W: jump.")
	mode_manual.toggle_mode = true
	mode_manual.button_group = group
	mode_manual.pressed.connect(func(): set_auto_mode(false))
	modes.add_child(mode_manual)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	column.add_child(footer)
	var status := VBoxContainer.new()
	status.custom_minimum_size.x = 155
	footer.add_child(status)
	state_label = Label.new()
	state_label.text = "IDLE"
	state_label.add_theme_font_size_override("font_size", 18)
	state_label.add_theme_color_override("font_color", Color(0.91, 0.93, 0.90))
	status.add_child(state_label)
	phase_label = Label.new()
	phase_label.text = "01 / STILLNESS"
	phase_label.add_theme_font_size_override("font_size", 11)
	phase_label.add_theme_color_override("font_color", Color(0.58, 0.65, 0.60))
	status.add_child(phase_label)
	var transport := VBoxContainer.new()
	transport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transport.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(transport)
	timeline = ProgressBar.new()
	timeline.custom_minimum_size.y = 3
	timeline.max_value = DEMO_LENGTH
	timeline.show_percentage = false
	timeline.add_theme_stylebox_override("background", _style(Color(0.25, 0.30, 0.27)))
	timeline.add_theme_stylebox_override("fill", _style(Color(0.80, 0.85, 0.78)))
	transport.add_child(timeline)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 11)
	time_label.add_theme_color_override("font_color", Color(0.58, 0.65, 0.60))
	transport.add_child(time_label)
	var tools := HBoxContainer.new()
	tools.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(tools)
	pause_button = _button("II", "Pause / resume (P)", true)
	pause_button.pressed.connect(_toggle_pause)
	tools.add_child(pause_button)
	var reset_button := _button("R", "Reset (R)", true)
	reset_button.pressed.connect(reset_demo)
	tools.add_child(reset_button)
	slow_select = OptionButton.new()
	slow_select.custom_minimum_size = Vector2(85, 36)
	for text in ["0.25x", "0.50x", "1.00x"]:
		slow_select.add_item(text)
	slow_select.select(2)
	slow_select.tooltip_text = "Playback speed"
	slow_select.item_selected.connect(func(index: int): playback_speed = [0.25, 0.5, 1.0][index])
	slow_select.add_theme_color_override("font_color", Color(0.86, 0.90, 0.85))
	for state in ["normal", "hover", "pressed", "focus"]:
		slow_select.add_theme_stylebox_override(state, _style(Color(0.20, 0.25, 0.22)))
	tools.add_child(slow_select)


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style


func _button(text: String, tooltip: String, dark := false) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(38 if dark else 82, 36)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	var foreground := Color(0.86, 0.90, 0.85) if dark else Color(0.12, 0.16, 0.13)
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_color_override("font_pressed_color", Color(0.95, 0.96, 0.93))
	button.add_theme_stylebox_override("normal", _style(Color(0.20, 0.25, 0.22) if dark else Color(0.8, 0.83, 0.79, 0.3)))
	button.add_theme_stylebox_override("hover", _style(Color(0.35, 0.40, 0.36, 0.5)))
	button.add_theme_stylebox_override("pressed", _style(Color(0.14, 0.19, 0.16)))
	return button


func reset_demo() -> void:
	body.position = Vector3(-3.0, 0.002, 0)
	body.velocity = Vector3.ZERO
	camera.position.x = body.position.x
	demo_time = 0.0
	elapsed = 0.0
	jump_buffer = 0.0
	coyote_time = 0.0
	last_jump_segment = -1
	last_vx = 0.0
	pending_jump = false
	impact_speed = 0.0
	paused = false
	observed_states.clear()
	rig.reset_motion()
	mode_auto.button_pressed = auto_mode
	mode_manual.button_pressed = not auto_mode
	pause_button.text = "II"


func set_auto_mode(enabled: bool) -> void:
	auto_mode = enabled
	mode_auto.button_pressed = enabled
	mode_manual.button_pressed = not enabled
	if enabled:
		reset_demo()


func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = ">" if paused else "II"


func _unhandled_key_input(event: InputEvent) -> void:
	if not ready_for_test:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_TAB:
			set_auto_mode(not auto_mode)
			get_viewport().set_input_as_handled()
		KEY_R:
			reset_demo()
		KEY_P:
			_toggle_pause()
		KEY_SPACE, KEY_W:
			if auto_mode:
				set_auto_mode(false)
			pending_jump = true
		KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT:
			if auto_mode:
				set_auto_mode(false)


func _demo_input() -> Dictionary:
	var direction := 0.0
	var walk := false
	var jump := false
	var section := "01 / STILLNESS"
	if demo_time >= 1.6 and demo_time < 3.8:
		direction = 1.0
		walk = true
		section = "02 / FIRST STEPS"
	elif demo_time >= 3.8 and demo_time < 5.8:
		direction = 1.0
		section = "03 / RUN"
	elif demo_time >= 5.8 and demo_time < 6.7:
		section = "04 / BRAKE"
	elif demo_time >= 6.7 and demo_time < 10.2:
		direction = -1.0
		section = "05 / TURN + JUMP"
		jump = _demo_jump(0, 8.5)
	elif demo_time >= 10.2 and demo_time < 12.0:
		section = "06 / RECOVER"
	elif demo_time >= 12.0 and demo_time < 14.0:
		direction = 1.0
		walk = true
		section = "07 / WALK"
	elif demo_time >= 14.0 and demo_time < 17.0:
		direction = 1.0
		section = "08 / RUN + JUMP"
		jump = _demo_jump(1, 15.3)
	elif demo_time >= 17.0 and demo_time < 18.0:
		direction = -1.0
		section = "09 / REVERSE"
	elif demo_time >= 18.0 and demo_time < 19.4:
		section = "10 / SETTLE"
	elif demo_time >= 19.4 and demo_time < 22.3:
		direction = -1.0
		section = "11 / FINAL LEAP"
		jump = _demo_jump(2, 20.6)
	elif demo_time >= 22.3:
		section = "12 / REST"
	phase_label.text = section
	return {"direction": direction, "walk": walk, "jump": jump, "held": true}


func _demo_jump(segment: int, at: float) -> bool:
	if demo_time >= at and last_jump_segment < segment:
		last_jump_segment = segment
		return true
	return false


func _manual_input() -> Dictionary:
	if not manual_override.is_empty():
		return manual_override
	var direction := Input.get_axis("move_left", "move_right")
	var jump := pending_jump
	pending_jump = false
	return {
		"direction": direction, "walk": not Input.is_physical_key_pressed(KEY_SHIFT),
		"jump": jump, "held": Input.is_action_pressed("jump"),
	}


func _physics_process(delta: float) -> void:
	if not ready_for_test or paused:
		return
	# Keep the physics timestep fixed. Time scaling also scales Godot's motion
	# integration, so slow playback does not change the jump trajectory.
	Engine.time_scale = playback_speed
	step_simulation(delta)


func step_simulation(delta: float) -> void:
	elapsed += delta
	if auto_mode:
		demo_time += delta
		if demo_time >= DEMO_LENGTH:
			reset_demo()
	var commands := _demo_input() if auto_mode else _manual_input()
	if not auto_mode:
		phase_label.text = "MANUAL"
	var direction: float = commands.direction
	var grounded_before := body.is_on_floor()
	if commands.jump:
		jump_buffer = 0.13
	else:
		jump_buffer = maxf(0.0, jump_buffer - delta)
	coyote_time = 0.11 if grounded_before else maxf(0.0, coyote_time - delta)
	var top_speed := WALK_SPEED if commands.walk else RUN_SPEED
	var target := direction * top_speed
	var rate := 8.5 if direction != 0 and signf(target) == signf(body.velocity.x) else 12.0
	if not grounded_before:
		rate = 4.5
	body.velocity.x = move_toward(body.velocity.x, target, rate * delta)
	if jump_buffer > 0.0 and coyote_time > 0.0:
		body.velocity.y = JUMP_SPEED
		jump_buffer = 0.0
		coyote_time = 0.0
	if not commands.held and body.velocity.y > 2.2:
		body.velocity.y = 2.2
	body.velocity.y -= GRAVITY * delta
	var previous_vy := body.velocity.y
	body.move_and_slide()
	body.position.z = 0.0
	var grounded := body.is_on_floor()
	impact_speed = absf(previous_vy) if grounded and not grounded_before else 0.0
	var acceleration := (body.velocity.x - last_vx) / maxf(delta, 0.0001)
	last_vx = body.velocity.x
	rig.animate(delta, {
		"velocity": body.velocity, "grounded": grounded,
		"direction": direction, "acceleration": acceleration, "impact": impact_speed,
	})
	observed_states[rig.state_name] = true
	simulated_frames += 1
	shadow.position.x = body.position.x
	shadow.scale.x = 1.0 + maxf(0, body.position.y) * 0.25
	shadow.transparency = clampf(body.position.y * 0.5, 0.0, 0.8)
	camera.position.x = lerpf(camera.position.x, body.position.x + body.velocity.x * 0.10, 1.0 - exp(-delta * 4.0))
	state_label.text = rig.state_name
	timeline.value = demo_time if auto_mode else fmod(elapsed, DEMO_LENGTH)
	time_label.text = "%05.2f / %05.2f" % [demo_time, DEMO_LENGTH] if auto_mode else "%04.1f m/s" % absf(body.velocity.x)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
