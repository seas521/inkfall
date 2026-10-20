extends RefCounted

const Palette = preload("res://scripts/shared/inkfall_palette.gd")

static func update_player(context, delta: float, platform_list: Array[Rect2], horizontal_bounds: Vector2, allow_input: bool) -> void:
	if Input.is_action_just_pressed("jump"):
		context.jump_buffer = 0.13
	context.jump_buffer = maxf(0.0, context.jump_buffer - delta)

	var direction := 0.0
	if allow_input:
		direction = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		context.player_facing = signf(direction)
	var target_speed := direction * Palette.RUN_SPEED * float(context.run_speed_scale if context.on_ground else context.air_speed_scale)
	context.player_velocity.x = move_toward(context.player_velocity.x, target_speed, (2300.0 if direction != 0.0 else 3000.0) * delta)

	if context.on_ground:
		context.coyote_time = 0.12
	else:
		context.coyote_time = maxf(0.0, context.coyote_time - delta)
	if allow_input and context.jump_buffer > 0.0 and context.coyote_time > 0.0:
		context.player_velocity.y = Palette.JUMP_SPEED * context.jump_speed_scale
		context.jump_buffer = 0.0
		context.coyote_time = 0.0
		context.on_ground = false
		context.regular_jump_active = true
	if context.regular_jump_active:
		if not Input.is_action_pressed("jump") and context.player_velocity.y < -185.0 * context.jump_speed_scale:
			context.player_velocity.y = -185.0 * context.jump_speed_scale
			context.regular_jump_active = false
		elif context.player_velocity.y >= 0.0:
			context.regular_jump_active = false

	context.player_velocity.y += Palette.GRAVITY * delta
	context.player_position.x += context.player_velocity.x * delta
	context.player_position.x = clampf(context.player_position.x, horizontal_bounds.x, horizontal_bounds.y - Palette.PLAYER_SIZE.x)

	var previous_bottom: float = context.player_position.y + Palette.PLAYER_SIZE.y
	context.player_position.y += context.player_velocity.y * delta
	context.on_ground = false
	if context.player_velocity.y >= 0.0:
		for platform_rect in platform_list:
			var new_bottom: float = context.player_position.y + Palette.PLAYER_SIZE.y
			var horizontal_overlap: bool = (
				context.player_position.x + Palette.PLAYER_SIZE.x > platform_rect.position.x + 3.0
				and context.player_position.x < platform_rect.end.x - 3.0
			)
			if not horizontal_overlap:
				continue
			if previous_bottom <= platform_rect.position.y + 5.0 and new_bottom >= platform_rect.position.y:
				context.player_position.y = platform_rect.position.y - Palette.PLAYER_SIZE.y
				context.player_velocity.y = 0.0
				context.on_ground = true
				break

static func carry_player_with_dynamic_platform(context, previous_rects: Array[Rect2], current_rects: Array[Rect2]) -> void:
	if not context.on_ground or previous_rects.size() != current_rects.size():
		return
	var player_bottom: float = context.player_position.y + Palette.PLAYER_SIZE.y
	for index in range(previous_rects.size()):
		var old_rect: Rect2 = previous_rects[index]
		var standing_on_top: bool = (
			absf(player_bottom - old_rect.position.y) <= 4.0
			and context.player_position.x + Palette.PLAYER_SIZE.x > old_rect.position.x + 4.0
			and context.player_position.x < old_rect.end.x - 4.0
		)
		if standing_on_top:
			context.player_position += current_rects[index].position - old_rect.position
			return
