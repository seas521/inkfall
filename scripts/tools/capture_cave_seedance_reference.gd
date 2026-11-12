extends SceneTree
# Canonical in-game actor/shader/eye, rendered directly. No generated redraw.
const Actor=preload("res://scripts/demos/c_zone_debug/hood_river_actor.gd")
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
func _initialize():call_deferred("_run")
func _run():
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1024,1024)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background:=ColorRect.new()
	background.size=Vector2(1024,1024)
	background.color=Color("20cc20")
	viewport.add_child(background)
	var stage:=Node2D.new()
	stage.position=Vector2(560,850)
	stage.scale=Vector2.ONE*6.8 # export-only magnification; in-game scale stays 0.90
	viewport.add_child(stage)
	var actor=Actor.new()
	stage.add_child(actor)
	actor.load_group("core")
	var pose=Pose.new()
	pose.apply({"feet":Vector2.ZERO,"grounded":true,"velocity":Vector2.ZERO,"facing":-1,"visual_scale":Pose.HOOD_VISUAL_SCALE,"action":&"none","fog_blur":0.0})
	actor.sync_pose(0,pose)
	actor.current_clip=&"idle_left"
	actor.current_frame_index=0
	actor.progress=0
	actor.playing=false
	actor._apply()
	actor.ghost.hide()
	for i in 8:await process_frame
	RenderingServer.force_draw()
	var target:="res://artifacts/rock-crevice/seedance-duck-reference-v1.png"
	viewport.get_texture().get_image().save_png(target)
	var info:={"actor_script":"hood_river_actor.gd","clip":"idle_left","frame":0,"facing":-1,"game_visual_scale":Pose.HOOD_VISUAL_SCALE,"reference_magnification":6.8,"canvas":[1024,1024],"foot_origin":[560,850],"background":"#20cc20","redrawn":false}
	FileAccess.open("res://artifacts/rock-crevice/seedance-duck-reference-v1.json",FileAccess.WRITE).store_string(JSON.stringify(info,"  "))
	print("CANONICAL CAVE REFERENCE SAVED ",target)
	quit()
