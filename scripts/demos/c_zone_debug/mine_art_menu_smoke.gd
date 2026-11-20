extends SceneTree
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
	for i in n:await physics_frame
func run()->void:
	change_scene_to_file("res://scenes/main.tscn")
	await frames(8)
	current_scene.debug_selection=12
	current_scene._start_debug_level()
	await frames(90)
	assert(current_scene.ready_for_review)
	current_scene.set_view(-600)
	assert(is_equal_approx(current_scene.view_x,-600))
	Input.action_press("ui_cancel")
	await frames(2)
	Input.action_release("ui_cancel")
	await frames(12)
	assert(current_scene.debug_selector_open)
	assert(current_scene.debug_selection==12)
	print("MINE ART MENU PASS")
	quit()
