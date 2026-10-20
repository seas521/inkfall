extends Node

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const HoodFrameActor = preload("res://scripts/actors/hood_frame_actor.gd")

const AMBIENCE_WIND: AudioStream = preload("res://assets/audio/level01/ambience_wind.mp3")
const AMBIENCE_RAIN: AudioStream = preload("res://assets/audio/level01/ambience_rain.mp3")
const CLIFF_WIND: AudioStream = preload("res://assets/audio/level01/cliff_wind.mp3")
const FOOTSTEPS: Array[AudioStream] = [
	preload("res://assets/audio/level01/footstep_01.mp3"),
	preload("res://assets/audio/level01/footstep_02.mp3"),
	preload("res://assets/audio/level01/footstep_03.mp3"),
	preload("res://assets/audio/level01/footstep_04.mp3"),
]
const TREE_CREAKS: Array[AudioStream] = [
	preload("res://assets/audio/level01/tree_creak_01.mp3"),
	preload("res://assets/audio/level01/tree_creak_02.mp3"),
	preload("res://assets/audio/level01/tree_creak_03.mp3"),
]
const JUMP_CLOTH: AudioStream = preload("res://assets/audio/level01/jump_cloth.mp3")
const LANDING: AudioStream = preload("res://assets/audio/level01/landing.mp3")
const GET_UP_CLOTH: AudioStream = preload("res://assets/audio/level01/get_up_cloth.mp3")
const GRASS_RUSTLE: AudioStream = preload("res://assets/audio/level01/grass_rustle.mp3")
const BAT_WINGS: AudioStream = preload("res://assets/audio/level01/bat_wings.mp3")
const BAT_COLONY: AudioStream = preload("res://assets/audio/level01/bat_colony.mp3")
const BAT_WHOOSH: AudioStream = preload("res://assets/audio/level01/bat_whoosh.mp3")
const BODY_IMPACT: AudioStream = preload("res://assets/audio/level01/body_impact.mp3")
const DISTANT_WOLF_HOWL: AudioStream = preload("res://assets/audio/level01/distant_wolf_howl.mp3")

const SURFACE_LEFT_CLIFF_X := 482.0
const TREE_X := 1060.0

var ambience_wind: AudioStreamPlayer
var ambience_rain: AudioStreamPlayer
var cliff_wind: AudioStreamPlayer
var footstep_players: Array[AudioStreamPlayer] = []
var tree_creak: AudioStreamPlayer
var distant_wolf_howl: AudioStreamPlayer
var jump_cloth: AudioStreamPlayer
var landing: AudioStreamPlayer
var get_up_cloth: AudioStreamPlayer
var grass_rustle: AudioStreamPlayer
var bat_wings: AudioStreamPlayer
var bat_colony: AudioStreamPlayer
var bat_whoosh: AudioStreamPlayer
var body_impact: AudioStreamPlayer

var active := false
var previous_grounded := false
var previous_velocity_y := 0.0
var previous_actor_action: StringName = ActorPoseState.ACTION_NONE
var previous_bat_triggered := false
var previous_bat_impact_started := false
var previous_bat_time := 0.0
var footstep_time := 0.0
var seen_hood_footsteps := 0
var footstep_index := 0
var footstep_voice := 0
var tree_time := 8.0
var wolf_time := 16.0
var entry_landing_suppression := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 10101
	ambience_wind = _make_player("AmbienceWind", AMBIENCE_WIND, &"Ambience", -80.0, true)
	ambience_rain = _make_player("AmbienceRain", AMBIENCE_RAIN, &"Ambience", -80.0, true)
	cliff_wind = _make_player("CliffWind", CLIFF_WIND, &"Ambience", -80.0, true)
	for voice_index in range(2):
		footstep_players.append(
			_make_player("Footstep%d" % voice_index, FOOTSTEPS[voice_index], &"Character", -11.5)
		)
	tree_creak = _make_player("TreeCreak", TREE_CREAKS[0], &"World", -15.0)
	distant_wolf_howl = _make_player("DistantWolfHowl", DISTANT_WOLF_HOWL, &"World", -16.5)
	jump_cloth = _make_player("JumpCloth", JUMP_CLOTH, &"Character", -9.5)
	landing = _make_player("Landing", LANDING, &"Character", -7.0)
	get_up_cloth = _make_player("GetUpCloth", GET_UP_CLOTH, &"Character", -8.5)
	grass_rustle = _make_player("GrassRustle", GRASS_RUSTLE, &"World", -8.0)
	bat_wings = _make_player("BatWings", BAT_WINGS, &"Event", -4.5)
	bat_colony = _make_player("BatColony", BAT_COLONY, &"Event", -8.0)
	bat_whoosh = _make_player("BatWhoosh", BAT_WHOOSH, &"Event", -4.0)
	body_impact = _make_player("BodyImpact", BODY_IMPACT, &"Event", -3.5)


func sync(
	delta: float,
	room_active: bool,
	player_position: Vector2,
	player_velocity: Vector2,
	grounded: bool,
	actor_action: StringName,
	bat_triggered: bool,
	bat_impact_started: bool,
	bat_event_time: float
) -> void:
	if room_active != active:
		_set_active(room_active)
	_sync_loops(delta, player_position.x)
	if not active:
		_store_state(grounded, player_velocity.y, actor_action, bat_triggered, bat_impact_started, bat_event_time)
		return

	entry_landing_suppression = maxf(0.0, entry_landing_suppression - delta)
	_sync_character(delta, player_velocity, grounded, actor_action)
	_sync_world(delta, player_position.x)
	_sync_bat_event(bat_triggered, bat_impact_started, bat_event_time, actor_action)
	_store_state(grounded, player_velocity.y, actor_action, bat_triggered, bat_impact_started, bat_event_time)


func reset_state() -> void:
	previous_grounded = false
	previous_velocity_y = 0.0
	previous_actor_action = ActorPoseState.ACTION_NONE
	previous_bat_triggered = false
	previous_bat_impact_started = false
	previous_bat_time = 0.0
	footstep_time = 0.0
	tree_time = rng.randf_range(7.0, 11.0)
	wolf_time = rng.randf_range(4.0, 8.0)
	entry_landing_suppression = 0.40
	_stop_one_shots()


func deactivate() -> void:
	active = false
	for player in [ambience_wind, ambience_rain, cliff_wind]:
		if player != null:
			player.volume_db = -80.0
	_stop_one_shots()


func _make_player(
	player_name: String,
	source: AudioStream,
	bus_name: StringName,
	volume_db: float,
	looping := false
) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus_name
	player.volume_db = volume_db
	var playback_stream := source.duplicate() as AudioStream
	if looping and playback_stream is AudioStreamMP3:
		playback_stream.loop = true
	player.stream = playback_stream
	add_child(player)
	if looping:
		player.play()
	return player


func _set_active(next_active: bool) -> void:
	active = next_active
	if active:
		reset_state()
	else:
		_stop_one_shots()


func _sync_loops(delta: float, player_x: float) -> void:
	var cliff_distance := maxf(0.0, SURFACE_LEFT_CLIFF_X - (player_x + 26.0))
	var cliff_proximity := 1.0 - clampf(cliff_distance / 300.0, 0.0, 1.0)
	var wind_target := -6.5 if active else -80.0
	var rain_target := -13.5 if active else -80.0
	var cliff_target := lerpf(-46.0, -10.5, cliff_proximity) if active else -80.0
	ambience_wind.volume_db = _smooth_db(ambience_wind.volume_db, wind_target, delta, 2.2)
	ambience_rain.volume_db = _smooth_db(ambience_rain.volume_db, rain_target, delta, 2.5)
	cliff_wind.volume_db = _smooth_db(cliff_wind.volume_db, cliff_target, delta, 4.0)


func _sync_character(
	delta: float,
	player_velocity: Vector2,
	grounded: bool,
	actor_action: StringName
) -> void:
	var free_to_move := actor_action == ActorPoseState.ACTION_NONE
	var speed_ratio := clampf(absf(player_velocity.x) / 285.0, 0.0, 1.0)
	var hood_steps: int = HoodFrameActor.footstep_serial
	if ActorStyleHost.style_override == ActorPoseState.STYLE_HOOD:
		# the hooded boy's feet come down every 0.167 s at a full run: the steps follow the animation
		if grounded and free_to_move and speed_ratio > 0.16 and hood_steps != seen_hood_footsteps:
			_play_footstep(speed_ratio)
		footstep_time = 0.08
	elif grounded and free_to_move and speed_ratio > 0.16:
		footstep_time -= delta
		if footstep_time <= 0.0:
			_play_footstep(speed_ratio)
			footstep_time = lerpf(0.49, 0.305, speed_ratio)
	else:
		footstep_time = minf(footstep_time, 0.08)

	seen_hood_footsteps = hood_steps

	if previous_grounded and not grounded and player_velocity.y < -80.0 and free_to_move:
		jump_cloth.pitch_scale = rng.randf_range(0.96, 1.04)
		jump_cloth.play()
	if (
		not previous_grounded
		and grounded
		and entry_landing_suppression <= 0.0
		and previous_velocity_y > 120.0
	):
		var landing_strength := clampf(inverse_lerp(120.0, 720.0, previous_velocity_y), 0.0, 1.0)
		landing.volume_db = lerpf(-13.0, -7.0, landing_strength)
		landing.pitch_scale = rng.randf_range(0.98, 1.02)
		landing.play()


func _play_footstep(speed_ratio: float) -> void:
	var player := footstep_players[footstep_voice]
	footstep_voice = (footstep_voice + 1) % footstep_players.size()
	player.stream = FOOTSTEPS[footstep_index]
	footstep_index = (footstep_index + 1) % FOOTSTEPS.size()
	player.volume_db = lerpf(-16.0, -9.0, speed_ratio)
	player.pitch_scale = rng.randf_range(0.95, 1.055)
	player.play()


func _sync_world(delta: float, player_x: float) -> void:
	tree_time -= delta
	wolf_time -= delta
	if tree_time <= 0.0:
		var tree_distance := absf(player_x - TREE_X)
		var proximity := 1.0 - smoothstep(180.0, 980.0, tree_distance)
		tree_creak.stream = TREE_CREAKS[rng.randi_range(0, TREE_CREAKS.size() - 1)]
		tree_creak.volume_db = lerpf(-22.0, -10.0, proximity)
		tree_creak.pitch_scale = rng.randf_range(0.94, 1.04)
		tree_creak.play()
		tree_time = rng.randf_range(9.0, 16.0)
	if wolf_time <= 0.0 and not distant_wolf_howl.playing:
		distant_wolf_howl.volume_db = rng.randf_range(-12.5, -9.5)
		distant_wolf_howl.pitch_scale = rng.randf_range(0.97, 1.02)
		distant_wolf_howl.play()
		wolf_time = rng.randf_range(28.0, 55.0)


func _sync_bat_event(
	bat_triggered: bool,
	bat_impact_started: bool,
	bat_event_time: float,
	actor_action: StringName
) -> void:
	if bat_triggered and not previous_bat_triggered:
		bat_wings.play()
		bat_colony.play()
		grass_rustle.play()
	if (
		bat_triggered
		and previous_bat_time < 0.28
		and bat_event_time >= 0.28
	):
		bat_whoosh.play()
	if bat_impact_started and not previous_bat_impact_started:
		body_impact.play()
	if (
		actor_action == ActorPoseState.ACTION_GET_UP
		and previous_actor_action != ActorPoseState.ACTION_GET_UP
	):
		get_up_cloth.play()


func _store_state(
	grounded: bool,
	velocity_y: float,
	actor_action: StringName,
	bat_triggered: bool,
	bat_impact_started: bool,
	bat_event_time: float
) -> void:
	previous_grounded = grounded
	previous_velocity_y = velocity_y
	previous_actor_action = actor_action
	previous_bat_triggered = bat_triggered
	previous_bat_impact_started = bat_impact_started
	previous_bat_time = bat_event_time


func _stop_one_shots() -> void:
	var players: Array[AudioStreamPlayer] = [
		tree_creak,
		distant_wolf_howl,
		jump_cloth,
		landing,
		get_up_cloth,
		grass_rustle,
		bat_wings,
		bat_colony,
		bat_whoosh,
		body_impact,
	]
	players.append_array(footstep_players)
	for player in players:
		if player != null:
			player.stop()


func _smooth_db(current: float, target: float, delta: float, speed: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))
