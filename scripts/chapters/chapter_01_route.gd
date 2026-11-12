extends "res://scripts/demos/c_zone_debug/river_controller.gd"

# A standalone chapter entry over the shared world/controller. Forest,
# cliff, ladder and bridge keep the same actor, camera and puzzle state.
# The existing C-zone entrances remain separate DEBUG entries.
signal bridge_unlocked
var bridge_unlocked_once:=false
const DescentRoute=preload("res://scripts/chapters/descent_route_act.gd")
var post_bridge:Node2D

func reset_all() -> void:
	if post_bridge!=null:post_bridge.reset()
	super.reset_all()
	log_bridge.reset_chapter()
	if post_bridge==null:
		post_bridge=DescentRoute.new()
		post_bridge.level=self
		add_child(post_bridge)
	post_bridge.reset()
	log_bridge.set_exit_open(true)
	bridge_unlocked_once=false
	debug_enter_scene1()
	debug_return_index=4

func enter_cliff_test() -> void:
	# Include the original walk, grave/flock and get-up sequence, rather
	# than spawning halfway through its cinematic or directly on the ladder.
	debug_enter_rope_ladder(true)
	debug_return_index=8

func _physics_process(delta:float) -> void:
	if paused:return
	if post_bridge!=null and post_bridge.tick(delta):return
	super._physics_process(delta)
	if not bridge_unlocked_once and log_bridge.state==log_bridge.State.BRIDGED:
		bridge_unlocked_once=true
		bridge_unlocked.emit()

func restore_checkpoint() -> void:
	if post_bridge!=null and post_bridge.active:
		post_bridge.restore_checkpoint()
		return
	super.restore_checkpoint()

func enter_station_test()->void:
	post_bridge.enter(0,true)
	debug_return_index=9

func enter_scree_test()->void:
	post_bridge.enter(1,true)
	debug_return_index=10

func _camera_target_y()->float:
	if post_bridge!=null and post_bridge.active:
		return minf(0.0,player.position.y-500.0)
	if post_bridge!=null and post_bridge.in_c_zone and player.position.x<500:
		var u:float=smoothstep(-120,500,player.position.x+13)
		return lerpf(minf(0.0,player.position.y-500.0),super._camera_target_y(),u)
	return super._camera_target_y()

func _act_finished() -> void:
	# New rooms join the existing C bank physically; only C's own completed
	# act may invoke its original completion behavior after that handoff.
	if post_bridge!=null and post_bridge.in_c_zone:super._act_finished()
