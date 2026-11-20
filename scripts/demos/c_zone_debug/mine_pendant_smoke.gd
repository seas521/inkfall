extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var chamber=load("res://scripts/chapters/mine_chamber_art.gd").new()
	root.add_child(chamber)
	chamber.build(0,-3060,1086,func(_x:float)->float:return -3250.0)
	chamber.set_process(false)
	var anchor:Vector2=chamber.lamp.global_position
	var first:Vector2=chamber.lamp.light_position()
	var min_x:=first.x;var max_x:=first.x
	for i in 480:
		chamber._process(1.0/60)
		var bulb:Vector2=chamber.lamp.light_position()
		assert(chamber.lamp.global_position.is_equal_approx(anchor))
		assert(absf(bulb.distance_to(anchor)-76)<0.01)
		assert(absf(chamber.lamp.light_angle())<0.10)
		assert((chamber.ink.get_shader_parameter("lamp") as Vector2).is_equal_approx(bulb))
		assert(is_equal_approx(chamber.ink.get_shader_parameter("angle"),chamber.lamp.light_angle()))
		min_x=minf(min_x,bulb.x);max_x=maxf(max_x,bulb.x)
	assert(max_x-min_x>5.0)
	print("MINE PENDANT PASS fixed anchor, continuous swing, coupled light; travel=",max_x-min_x)
	quit()
