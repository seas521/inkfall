extends Node2D

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const Manifest = preload("res://scripts/actors/seedance_actor_manifest.gd")
const SmallItemRenderer = preload("res://scripts/actors/small_item_renderer.gd")

const DISPLAY_SCALE := 0.42
const RUN_CYCLE_DISTANCE := 116.0
const SMALL_ITEM_COVERAGE_RADIUS := 13.0

var pose
var animated: AnimatedSprite2D
var head_glow: Sprite2D
var small_item: Node2D
var current_clip: StringName = &"idle"
var current_frame_index := 0
var clip_time := 0.0
var travel_distance := 0.0
var takeoff_time := 0.0
var landing_time := 0.0
var previous_grounded := false
var previous_vertical_speed := 0.0
var active_landing_frame_order: Array = []

func _ready() -> void:
	small_item = SmallItemRenderer.new()
	add_child(small_item)
	small_item.hide()
	animated = AnimatedSprite2D.new()
	animated.centered = false
	animated.position = -Manifest.ROOT
	animated.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	animated.sprite_frames = _build_sprite_frames()
	animated.animation = &"idle"
	animated.pause()
	animated.material = _build_small_item_marker_material()
	add_child(animated)
	_build_head_glow()
	hide()

func _build_small_item_marker_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 marker_center = vec2(-100.0, -100.0);
uniform float marker_radius = 5.5;
uniform float fog_blur = 0.0;
uniform bool monochrome = false;

vec4 shape_actor_sample(vec4 color, vec2 sample_uv, vec2 texture_pixel_size) {
	vec2 pixel = sample_uv / texture_pixel_size;
	float marker_mask = 1.0 - step(marker_radius, distance(pixel, marker_center));
	color.rgb = mix(color.rgb, vec3(0.004, 0.008, 0.008), marker_mask * step(0.01, color.a));
	return vec4(color.rgb * color.a, color.a);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * fog_blur;
	vec4 color = shape_actor_sample(texture(TEXTURE, UV), UV, TEXTURE_PIXEL_SIZE) * 0.52;
	color += shape_actor_sample(texture(TEXTURE, UV + vec2(px.x, 0.0)), UV + vec2(px.x, 0.0), TEXTURE_PIXEL_SIZE) * 0.12;
	color += shape_actor_sample(texture(TEXTURE, UV - vec2(px.x, 0.0)), UV - vec2(px.x, 0.0), TEXTURE_PIXEL_SIZE) * 0.12;
	color += shape_actor_sample(texture(TEXTURE, UV + vec2(0.0, px.y)), UV + vec2(0.0, px.y), TEXTURE_PIXEL_SIZE) * 0.12;
	color += shape_actor_sample(texture(TEXTURE, UV - vec2(0.0, px.y)), UV - vec2(0.0, px.y), TEXTURE_PIXEL_SIZE) * 0.12;
	vec3 straight_rgb = color.rgb / max(color.a, 0.0001);
	if (monochrome) {
		float value = dot(straight_rgb, vec3(0.299, 0.587, 0.114));
		straight_rgb = vec3(value);
	}
	COLOR = vec4(straight_rgb, color.a) * COLOR;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _build_sprite_frames() -> SpriteFrames:
	var library := SpriteFrames.new()
	if library.has_animation(&"default"):
		library.remove_animation(&"default")
	for clip_name in Manifest.CLIPS:
		var clip: StringName = clip_name
		var metadata: Dictionary = Manifest.CLIPS[clip]
		library.add_animation(clip)
		library.set_animation_speed(clip, float(metadata["fps"]))
		library.set_animation_loop(clip, bool(metadata["loop"]))
		for frame_index in range(int(metadata["frames"])):
			var frame_path := Manifest.frame_path(clip, frame_index)
			var texture := load(frame_path) as Texture2D
			if texture == null:
				push_error("Missing Seedance actor frame: %s" % frame_path)
				continue
			library.add_frame(clip, texture)
	return library

func _build_head_glow() -> void:
	head_glow = Sprite2D.new()
	head_glow.show_behind_parent = true
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.65, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.58, 0.20, 0.20),
		Color(0.86, 0.34, 0.07, 0.06),
		Color(0.42, 0.12, 0.02, 0.014),
		Color.TRANSPARENT,
	])
	var glow_texture := GradientTexture2D.new()
	glow_texture.width = 112
	glow_texture.height = 112
	glow_texture.gradient = gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	head_glow.texture = glow_texture
	head_glow.position = Vector2(31.0, -146.0)
	head_glow.scale = Vector2(0.74, 0.62)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	head_glow.material = additive
	add_child(head_glow)

func sync_pose(delta: float, next_pose) -> void:
	pose = next_pose
	show()
	if not pose.grounded and previous_grounded:
		landing_time = 0.0
		active_landing_frame_order.clear()
		takeoff_time = (
			0.125
			if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE
			else (
				0.167
				if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD
				else 0.125
			)
		)
	if pose.grounded and not previous_grounded:
		var landing_clip := _landing_clip()
		var landing_metadata: Dictionary = Manifest.CLIPS[landing_clip]
		active_landing_frame_order = _landing_frame_order(
			landing_metadata,
			previous_vertical_speed
		)
		landing_time = (
			float(_playback_frame_count(landing_metadata))
			/ float(landing_metadata["fps"])
		)
	takeoff_time = maxf(0.0, takeoff_time - delta)
	landing_time = maxf(0.0, landing_time - delta)
	if pose.grounded and absf(pose.velocity.x) > 1.0:
		travel_distance += absf(pose.velocity.x) * delta
	var next_clip := _choose_clip()
	if next_clip != current_clip:
		current_clip = next_clip
		clip_time = 0.0
	else:
		clip_time += delta
	_apply_frame()
	position = pose.feet
	var display_scale: float = DISPLAY_SCALE * float(pose.visual_scale)
	scale = Vector2(pose.facing * display_scale, display_scale)
	head_glow.position.x = -31.0 if pose.clip_flip_h else 31.0
	var fade := 1.0
	if pose.failure_time > 0.0:
		fade = 1.0 - smoothstep(
			0.80,
			1.0,
			pose.failure_time / maxf(0.01, pose.failure_duration)
		)
	modulate.a = fade
	animated.modulate = Color(0.0, 0.0, 0.0, 1.0) if pose.monochrome else Color.WHITE
	head_glow.visible = not pose.monochrome
	head_glow.modulate = Color(
		1.0,
		0.49,
		0.13,
		0.0 if pose.monochrome else fade * (0.07 + pose.light_exposure * 0.05)
	)
	(animated.material as ShaderMaterial).set_shader_parameter("fog_blur", pose.fog_blur)
	(animated.material as ShaderMaterial).set_shader_parameter("monochrome", pose.monochrome)
	previous_grounded = pose.grounded
	previous_vertical_speed = pose.velocity.y

func _landing_clip() -> StringName:
	if pose.equipment == ActorPoseState.EQUIPMENT_THROWABLE:
		return &"carry_land"
	if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD:
		return &"shield_land"
	if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE:
		return &"combo_land"
	return &"land"

func _playback_frame_count(metadata: Dictionary) -> int:
	if metadata.has("soft_frame_order") and not active_landing_frame_order.is_empty():
		return active_landing_frame_order.size()
	var frame_order := _frame_order(metadata)
	return frame_order.size() if not frame_order.is_empty() else int(metadata["frames"])

func _landing_frame_order(metadata: Dictionary, impact_speed: float) -> Array:
	if not metadata.has("soft_frame_order"):
		return Array(metadata.get("frame_order", [])).duplicate()
	if impact_speed < 650.0:
		return Array(metadata["soft_frame_order"]).duplicate()
	if impact_speed < 820.0:
		return Array(metadata["medium_frame_order"]).duplicate()
	return Array(metadata["hard_frame_order"]).duplicate()

func _frame_order(metadata: Dictionary) -> Array:
	if current_clip == &"land" and not active_landing_frame_order.is_empty():
		return active_landing_frame_order
	return metadata.get("frame_order", [])

func _choose_clip() -> StringName:
	var semantic_clip := _semantic_clip()
	if animated.sprite_frames.has_animation(semantic_clip):
		return semantic_clip
	var moving := absf(pose.velocity.x) > 25.0
	if pose.equipment == ActorPoseState.EQUIPMENT_THROWABLE:
		return &"carry_run" if moving else &"carry"
	if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD:
		return &"shield_walk" if moving else &"shield_ready"
	if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE:
		return &"blade_run" if moving else &"blade_ready"
	if moving:
		return &"run"
	return &"idle"

func _semantic_clip() -> StringName:
	if pose.failure_time > 0.0:
		return &"failure"
	match pose.action:
		ActorPoseState.ACTION_PICKUP: return &"pickup"
		ActorPoseState.ACTION_PUT_DOWN: return &"put_down"
		ActorPoseState.ACTION_THROW_CHARGE: return &"throw_charge"
		ActorPoseState.ACTION_THROW_RELEASE: return &"throw_release"
		ActorPoseState.ACTION_SHIELD_EQUIP: return &"shield_equip"
		ActorPoseState.ACTION_SHIELD_RAISE: return &"shield_raise"
		ActorPoseState.ACTION_SHIELD_GUARD: return &"shield_guard"
		ActorPoseState.ACTION_SHIELD_LOWER: return &"shield_lower"
		ActorPoseState.ACTION_SHIELD_PARRY:
			return (
				&"combo_shield_parry"
				if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE
				else &"shield_parry"
			)
		ActorPoseState.ACTION_SHIELD_BLOCK: return &"shield_block"
		ActorPoseState.ACTION_BLADE_EQUIP: return &"blade_equip"
		ActorPoseState.ACTION_BLADE_SWING: return &"blade_swing"
		ActorPoseState.ACTION_BLADE_SHEATHE: return &"blade_sheathe"
		ActorPoseState.ACTION_BLADE_DRAW_RUN: return &"blade_draw_run"
		ActorPoseState.ACTION_BLADE_SHEATHE_RUN: return &"blade_sheathe_run"
		ActorPoseState.ACTION_BLADE_SHEATHE_GUARD: return &"blade_sheathe_guard"
		ActorPoseState.ACTION_PUSH_ENGAGE: return &"push_engage"
		ActorPoseState.ACTION_PUSH: return &"push"
		ActorPoseState.ACTION_PUSH_RELEASE: return &"push_release"
		ActorPoseState.ACTION_HIT: return &"hit"
		ActorPoseState.ACTION_KNOCKDOWN: return &"knockdown"
		ActorPoseState.ACTION_DOWNED: return &"downed"
		ActorPoseState.ACTION_GET_UP: return &"get_up"
		ActorPoseState.ACTION_UNCONTROLLED_FALL: return &"uncontrolled_fall"
		ActorPoseState.ACTION_FALL_IMPACT: return &"fall_impact"
		ActorPoseState.ACTION_FALL_DOWNED: return &"fall_downed"
	if pose.equipment == ActorPoseState.EQUIPMENT_THROWABLE:
		if not pose.grounded:
			if takeoff_time > 0.0:
				return &"carry_takeoff"
			if pose.velocity.y < -85.0:
				return &"carry_rise"
			if pose.velocity.y < 95.0:
				return &"carry_apex"
			return &"carry_fall"
		if landing_time > 0.0:
			return &"carry_land"
		if absf(pose.velocity.x) > 25.0:
			return &"carry_run"
		return &"carry"
	if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE and not pose.grounded:
		if takeoff_time > 0.0:
			return &"combo_takeoff"
		if pose.velocity.y < -85.0:
			return &"combo_rise"
		if pose.velocity.y < 95.0:
			return &"combo_apex"
		return &"combo_fall"
	if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD:
		if not pose.grounded:
			if takeoff_time > 0.0:
				return &"shield_takeoff"
			if pose.velocity.y < -85.0:
				return &"shield_rise"
			if pose.velocity.y < 95.0:
				return &"shield_apex"
			return &"shield_fall"
		if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD:
			if landing_time > 0.0:
				return &"shield_land"
			if absf(pose.velocity.x) > 25.0:
				return &"shield_walk"
			return &"shield_ready"
	if (
		pose.equipment == ActorPoseState.EQUIPMENT_BLADE
		or pose.equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE
	) and pose.grounded:
		if (
			pose.equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE
			and landing_time > 0.0
		):
			return &"combo_land"
		if absf(pose.velocity.x) > 25.0:
			return &"blade_run"
		return &"blade_ready"
	if not pose.grounded:
		if takeoff_time > 0.0:
			return &"takeoff"
		if pose.velocity.y < -85.0:
			return &"rise"
		if pose.velocity.y < 95.0:
			return &"apex"
		return &"fall"
	if landing_time > 0.0:
		return &"land"
	return &"run" if absf(pose.velocity.x) > 25.0 else &"idle"

func _apply_frame() -> void:
	var metadata: Dictionary = Manifest.CLIPS[current_clip]
	var frame_scale := float(metadata.get("frame_scale", 1.0))
	animated.scale = Vector2.ONE * frame_scale
	animated.position = -Manifest.ROOT * frame_scale + Vector2(
		float(metadata.get("offset_x", 0.0)),
		0.0
	) + pose.frame_root_offset
	animated.flip_h = pose.clip_flip_h
	var frame_order := _frame_order(metadata)
	var frame_count := _playback_frame_count(metadata)
	var frame_index := 0
	if current_clip in [&"run", &"carry_run", &"shield_walk", &"blade_run"]:
		var cycle_distance: float = (
			float(metadata.get("distance", RUN_CYCLE_DISTANCE))
			* float(pose.visual_scale)
		)
		var distance_per_frame: float = cycle_distance / float(frame_count)
		frame_index = int(floor(travel_distance / distance_per_frame)) % frame_count
	elif pose.action != ActorPoseState.ACTION_NONE and not bool(metadata["loop"]):
		frame_index = mini(
			frame_count - 1,
			int(round(pose.action_progress * float(frame_count - 1)))
		)
	elif bool(metadata["loop"]):
		frame_index = int(floor(clip_time * float(metadata["fps"]))) % frame_count
	else:
		frame_index = mini(
			frame_count - 1,
			int(floor(clip_time * float(metadata["fps"])))
		)
	var source_frame_index := (
		int(frame_order[frame_index])
		if not frame_order.is_empty()
		else frame_index
	)
	current_frame_index = source_frame_index
	animated.animation = current_clip
	animated.frame = source_frame_index
	_apply_small_item(metadata, source_frame_index)

func _apply_small_item(metadata: Dictionary, frame_index: int) -> void:
	var anchor = Manifest.small_item_anchor(current_clip, frame_index)
	var marker_material := animated.material as ShaderMaterial
	if anchor == null or pose.small_item_kind == &"":
		small_item.hide()
		marker_material.set_shader_parameter("marker_center", Vector2(-100.0, -100.0))
		return
	var frame_scale := float(metadata.get("frame_scale", 1.0))
	var offset := Vector2(float(metadata.get("offset_x", 0.0)), 0.0)
	var held_radius: float = float(pose.small_item_radius)
	if pose.small_item_kind != &"orb":
		held_radius = maxf(held_radius, SMALL_ITEM_COVERAGE_RADIUS)
	small_item.position = (Vector2(anchor) - Manifest.ROOT) * frame_scale + offset
	small_item.scale = Vector2.ONE * frame_scale
	small_item.call(
		"configure",
		pose.small_item_kind,
		held_radius / (DISPLAY_SCALE * frame_scale)
	)
	small_item.z_index = -1 if pose.small_item_kind == &"orb" else 1
	small_item.show()
	marker_material.set_shader_parameter(
		"marker_center",
		Vector2(anchor) - Manifest.SMALL_ITEM_CENTER_OFFSET
	)
