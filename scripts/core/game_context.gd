extends RefCounted

var player_position := Vector2(170.0, 526.0)
var player_velocity := Vector2.ZERO
var player_facing := 1.0
var on_ground := false
var coyote_time := 0.0
var jump_buffer := 0.0
var regular_jump_active := false
var air_speed_scale := 1.0
var jump_speed_scale := 1.0  # the hooded boy jumps about his own height
var run_speed_scale := 1.0  # the hooded boy runs a little slower: a labouring pace, not a parkour sprint

var camera_axis := 0.0
var failure_flash := 0.0
