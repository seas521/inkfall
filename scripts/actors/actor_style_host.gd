extends Node2D

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const LegacyActor = preload("res://scripts/inkfall_actor_art.gd")
const VelvetDollActor = preload("res://scripts/actors/velvet_doll_actor.gd")
const ShadowFrameActor = preload("res://scripts/actors/shadow_frame_actor.gd")
const SeedanceFrameActor = preload("res://scripts/actors/seedance_frame_actor.gd")
const HoodFrameActor = preload("res://scripts/actors/hood_frame_actor.gd")

# Which actor replaces the crooked-tower knight everywhere the controllers ask for it (they are not changed).
# Empty = leave it. F9 toggles at run time; `-- --hood` on the command line or the project setting
# inkfall/actor_style_override starts with the hooded boy.
# The game starts with the hooded boy. Test scripts (run with --script) keep the previous actor unless they ask for him,
# and `-- --legacy` starts the game with the previous character. F9 switches at any time (no on-screen message).
static var style_override: StringName = ActorPoseState.STYLE_HOOD if not _running_a_script() else &""

static func _running_a_script() -> bool:
	var args := OS.get_cmdline_args()
	return "--script" in args or "-s" in args
static var override_loaded := false

var pose = ActorPoseState.new()
var legacy_actor: Sprite2D
var velvet_actor: Node2D
var shadow_actor: Sprite2D
var crooked_tower_actor: Node2D
var hood_actor: Node2D
var style_toast: Label
var style_toast_time := 0.0
var hood_zone := "level1"

func _ready() -> void:
	legacy_actor = LegacyActor.new()
	add_child(legacy_actor)
	velvet_actor = VelvetDollActor.new()
	add_child(velvet_actor)
	shadow_actor = ShadowFrameActor.new()
	add_child(shadow_actor)
	crooked_tower_actor = SeedanceFrameActor.new()
	add_child(crooked_tower_actor)
	hood_actor = HoodFrameActor.new()
	add_child(hood_actor)
	legacy_actor.hide()
	velvet_actor.hide()
	shadow_actor.hide()
	crooked_tower_actor.hide()
	hood_actor.hide()
	if not override_loaded:
		override_loaded = true
		if "--legacy" in OS.get_cmdline_user_args() or String(ProjectSettings.get_setting("inkfall/actor_style_override", "")) == "legacy":
			style_override = &""
		elif "--hood" in OS.get_cmdline_user_args() or String(ProjectSettings.get_setting("inkfall/actor_style_override", "")) == "hood":
			style_override = ActorPoseState.STYLE_HOOD
	style_toast = Label.new()
	style_toast.position = Vector2(24.0, 24.0)
	style_toast.z_index = 4000
	style_toast.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	style_toast.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	style_toast.add_theme_constant_override("outline_size", 6)
	style_toast.hide()
	add_child(style_toast)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F9:
		# switches silently: no message on the screen
		style_override = &"" if style_override == ActorPoseState.STYLE_HOOD else ActorPoseState.STYLE_HOOD

func present(delta: float, state: Dictionary) -> void:
	pose.apply(state)
	if style_override != &"" and pose.style_id == ActorPoseState.STYLE_CROOKED_TOWER:
		pose.style_id = style_override
	if style_toast_time > 0.0:
		style_toast_time -= delta
		if style_toast_time <= 0.0:
			style_toast.hide()
	visible = pose.active
	if not pose.active:
		legacy_actor.hide()
		velvet_actor.hide()
		shadow_actor.hide()
		crooked_tower_actor.hide()
		hood_actor.hide()
		return
	if pose.style_id == ActorPoseState.STYLE_HOOD:
		legacy_actor.hide()
		velvet_actor.hide()
		shadow_actor.hide()
		crooked_tower_actor.hide()
		hood_actor.call("load_zone", hood_zone)
		hood_actor.call("sync_pose", delta, pose)
		return
	hood_actor.hide()
	if pose.style_id == ActorPoseState.STYLE_CROOKED_TOWER:
		legacy_actor.hide()
		velvet_actor.hide()
		shadow_actor.hide()
		crooked_tower_actor.call("sync_pose", delta, pose)
		return
	if pose.style_id == ActorPoseState.STYLE_SHADOW:
		legacy_actor.hide()
		velvet_actor.hide()
		crooked_tower_actor.hide()
		shadow_actor.call("sync_pose", delta, pose)
		return
	if pose.style_id == ActorPoseState.STYLE_VELVET:
		legacy_actor.hide()
		shadow_actor.hide()
		crooked_tower_actor.hide()
		velvet_actor.call("sync_pose", delta, pose)
		return
	velvet_actor.hide()
	shadow_actor.hide()
	crooked_tower_actor.hide()
	legacy_actor.call(
		"sync_pose",
		delta,
		pose.feet,
		pose.velocity,
		pose.grounded,
		pose.facing,
		pose.held,
		pose.aiming,
		pose.room,
		true,
		pose.failure_time,
		pose.failure_duration
	)
