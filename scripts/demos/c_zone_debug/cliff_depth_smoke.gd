extends SceneTree

const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var failures := 0
func _initialize(): call_deferred("_run")
func _check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures+=1
func _run():
	var level=SCENE.instantiate()
	root.add_child(level)
	for i in 8: await physics_frame
	level.debug_enter_rope_ladder()
	level.set_physics_process(false)
	level.rope_ladder.set_process(false)
	var art=level.art
	var destination:int=art.surface_art.far_group.get_instance_id()
	var camera_top:float=level.scene1.ground_top(level.scene1.CLIFF_X)-350.0
	var previous_y:=INF
	for depth in [0.0,80.0,150.0,240.0,320.0,390.0,450.0,500.0,620.0]:
		level.camera_y=camera_top+depth
		art.sync(0.0,-4050.0,true)
		var scale_x:float=art.surface_art.far_group.scale.x
		var cabin_ground:float=art.surface_art.far_group.position.y+378.0*0.78
		var mountain_ground:float=art.DESTINATION_FIRE_UV.y*720.0-30.0-(float(level.camera_y)-level.log_bridge.ORIGIN.y)*0.10
		_check(absf(cabin_ground-mountain_ground)<0.1,"live fire stays grounded on the unified destination at depth %s"%depth)
		var flame_base:Vector2=art.surface_art.far_group.position+art.surface_art.fire_flame.position*0.78
		_check(absf(flame_base.y-mountain_ground)<0.1 and not art.surface_art.fire_sprite.visible,"particle fire is grounded without a baked decal at depth %s"%depth)
		_check(is_equal_approx(scale_x,0.78),"destination keeps fixed scale at depth %s"%depth)
		_check(art.landmark_output.visible and art.surface_art.far_group.position.y<=previous_y,"destination remains visible and follows vertical parallax at depth %s"%depth)
		_check(art.surface_art.gameplay_sprite.visible and art.surface_art.tree_sprite.visible and bool(art.surface_art.gameplay_sprite.material.get_shader_parameter("original_destination")),"authored cabin/window/yard and tree remain restored at depth %s"%depth)
		previous_y=art.surface_art.far_group.position.y
		if depth==0.0:
			_check(art.landmark_output.visible and is_equal_approx(scale_x,0.78),"cliff-top destination retains its original size")
	var distant_ledge:float=art.surface_art.far_group.position.y+378.0*0.78
	var near_bank_top:float=level.log_bridge.RIGHT.position.y-float(level.camera_y)
	_check(art.landmark_output.visible and distant_ledge<near_bank_top-180.0,"destination terrace remains vertically separated from the playable bank")
	_check(art.surface_art.gameplay_sprite.region_rect.position==Vector2(1130,220) and art.surface_art.gameplay_sprite.region_rect.size.x==542,"original roof, porch and full workbench yard are retained without the projecting old cliff tip")
	_check(is_equal_approx(float(art.surface_art.tree_material.get_shader_parameter("ink")),art.DESTINATION_INK) and art.surface_art.fire_flame.monochrome,"tree matches the ridge and fire is gray-white as in the reference")
	_check(level.log_bridge.art.back.layer < -10 and not level.log_bridge.art.mid_stage.output.visible,"continuous valley is behind the forest without a detached middle rock")
	_check(level.log_bridge.art.depth.get_parent()==art.landmark_view and art.surface_art.far_group.get_parent()==art.landmark_view,"mountain and original destination share one render and lens pass")
	level.camera_y=camera_top
	art.sync(0.0,-4050.0,true)
	_check(art.landmark_output.visible and art.surface_art.far_group.get_instance_id()==destination,"ascent keeps the same destination")
	for plane in [art.plates_near]:
		_check(is_equal_approx(plane.ground_limit,level.scene1.edge_x()+4050.0),"forest tree coverage ends at the actual cliff")
	art.plates_near.set_fade(0.0)
	_check(is_zero_approx(float(art.plates_near.sprites[0].material.get_shader_parameter("strength"))),"near tree shader honors exit fade")
	for camera_x in [-4800.0,-4300.0,-4100.0,-3900.0]:
		art.sync(0.0,camera_x,true)
		level.log_bridge.art.sync(0.0,Vector2(camera_x,level.camera_y),true)
		_check(art.forest_back.visible and level.log_bridge.art.back.visible and is_equal_approx(float(level.log_bridge.art.depth.material.get_shader_parameter("opacity")),1.0),"forest and valley coexist without a backdrop toggle at %s"%camera_x)
	print("cliff depth smoke OK" if failures==0 else "cliff depth smoke FAILED")
	quit(0 if failures==0 else 1)
