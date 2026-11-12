extends SceneTree
# Earlier static baseline only; runtime uses forest_spider_view.gd for native Run and foot IK.
const MODEL="res://assets/art/polyfork/spider-v1/garden-orb-weaver-animated.glb"
const OUT="res://assets/art/polyfork/spider-v1/frames/"
func _initialize():call_deferred("_run")
func _run():
	DirAccess.make_dir_recursive_absolute(OUT)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(768,512)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var source:Node3D=load(MODEL).instantiate()
	viewport.add_child(source)
	var ink:=StandardMaterial3D.new()
	ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color=Color(0.003,0.003,0.003)
	ink.cull_mode=BaseMaterial3D.CULL_DISABLED
	for node in source.find_children("*","MeshInstance3D",true,false):node.material_override=ink
	var animation:AnimationPlayer=source.find_child("AnimationPlayer",true,false)
	print("SPIDER CLIPS ",animation.get_animation_list())
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=4.7
	camera.position=Vector3(12,0.8,1.8)
	viewport.add_child(camera)
	camera.look_at(Vector3(0,0.8,0))
	camera.current=true
	var doc:Dictionary={"canvas":[768,512],"root":[],"clips":{},"camera_size":camera.size}
	var pivot:=camera.unproject_position(Vector3.ZERO)
	doc.root=[pivot.x,pivot.y]
	for clip_name in ["Walk","Idle"]:
		var selected:StringName
		for name in animation.get_animation_list():
			if String(name).get_file().to_lower()==clip_name.to_lower():selected=name
		assert(not selected.is_empty(),"Missing authored spider clip")
		var duration:float=animation.get_animation(selected).length
		var count:=36 if clip_name=="Walk" else 24
		doc.clips[clip_name.to_lower()]={"frames":count,"duration":duration,"rects":[]}
		animation.play(selected)
		animation.pause()
		for i in count:
			animation.seek(duration*float(i)/float(count),true)
			for wait_frame in 2:await process_frame
			RenderingServer.force_draw()
			var picture:=viewport.get_texture().get_image()
			var crop:=picture.get_used_rect().grow(4).intersection(Rect2i(0,0,768,512))
			picture.get_region(crop).save_png(OUT+"%s_%03d.png"%[clip_name.to_lower(),i])
			doc.clips[clip_name.to_lower()].rects.append([crop.position.x,crop.position.y,crop.size.x,crop.size.y])
		print("BAKED ",clip_name," ",duration,"s / ",count," frames")
	FileAccess.open(OUT+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(doc,"  "))
	print("SPIDER ROOT ",pivot)
	quit()
