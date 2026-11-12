extends SceneTree
const MODEL="res://assets/art/polyfork/forest-v1/scorched-grass-tuft-994376.glb"
func _initialize():call_deferred("_run")
func _run():
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(512,512)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	root.add_child(viewport)
	var world:=Node3D.new();viewport.add_child(world)
	var source:Node3D=load(MODEL).instantiate();world.add_child(source)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color.BLACK;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	var bounds:=AABB();var first:=true;var root_position:=Vector3.ZERO
	for node in source.find_children("*","MeshInstance3D",true,false):
		if String(node.name)=="pebbles":
			node.hide()
			continue
		node.material_override=mat
		var b:AABB=node.global_transform*node.get_aabb()
		bounds=b if first else bounds.merge(b);first=false
		if "trunk" in String(node.name):root_position=Vector3(b.get_center().x,b.position.y,b.get_center().z)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=maxf(bounds.size.x,bounds.size.y)/0.88
	camera.position=Vector3(bounds.get_center().x,bounds.get_center().y,40);world.add_child(camera);camera.current=true
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://assets/art/polyfork/forest-v1/scorched-grass-no-soil-v1.png")
	var projected:Vector2=camera.unproject_position(root_position)
	var doc:Dictionary={"root":[projected.x,projected.y],"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"camera_size":camera.size}
	FileAccess.open("res://assets/art/polyfork/forest-v1/render-grass.json",FileAccess.WRITE).store_string(JSON.stringify(doc,"  "))
	print("GRASS BAKED WITHOUT pebbles/soil ",doc)
	quit()
