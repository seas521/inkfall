extends SceneTree
const SCENE=preload("res://scenes/debug/c_zone_river.tscn")
var level
var failures:=0
func _initialize(): call_deferred("_run")
func _check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures+=1
func _camera()->Vector2: return Vector2(level.camera_x,level.camera_y)
func _set_camera(at:Vector2):
	level.camera_x=at.x
	level.camera_y=at.y
	level.camera.position=at+Vector2(640,360)
func _run():
	level=SCENE.instantiate()
	root.add_child(level)
	for i in 8: await physics_frame
	level.debug_enter_rope_ladder()
	level.set_physics_process(false)
	var ladder=level.rope_ladder
	var bridge=level.log_bridge
	ladder.set_process(false)
	var top:Vector2=ladder.anchor()
	for feet in [top+Vector2(-18,0),top+Vector2(0,260),Vector2(top.x,bridge.LEFT.position.y-82),Vector2(top.x+45,bridge.LEFT.position.y)]:
		level.player.position=feet-Vector2(13,54)
		ladder.frame=82.0
		ladder.source_origin=feet-ladder._track(82.0,"feet")
		var initial:Vector2=feet-Vector2(600,620)
		_set_camera(initial)
		level._update_camera(1.0/60.0)
		var expected:Vector2=_camera()
		_set_camera(initial)
		bridge._update_camera(1.0/60.0)
		_check(_camera().distance_to(expected)<0.001,"bank camera matches original forest follow at %s"%feet)
		for mode in [ladder.Mode.MOUNT,ladder.Mode.HOLD,ladder.Mode.CATCH,ladder.Mode.AIR,ladder.Mode.LAND,ladder.Mode.EXIT]:
			_set_camera(initial)
			ladder.mode=mode
			ladder._present(1.0/60.0)
			_check(_camera().distance_to(expected)<0.001,"ladder mode %s keeps the same follow target"%mode)
	var before:Vector2=_camera()
	bridge.enter(false)
	_check(_camera()==before,"mount and catch entry never relocate the camera")
	level.player.position=top-Vector2(18+13,54)
	before=_camera()
	ladder._finish_top()
	_check(_camera()==before,"returning onto the cliff does not relocate the camera")
	print("traversal camera smoke OK" if failures==0 else "traversal camera smoke FAILED")
	quit(0 if failures==0 else 1)
