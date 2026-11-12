extends SceneTree
const M=preload("res://scripts/actors/hood_actor_manifest.gd")
const Eyes=preload("res://scripts/actors/hood_eye_tracks.gd")
const Light=preload("res://scripts/actors/hood_eye_light.gd")
const Actor=preload("res://scripts/actors/hood_frame_actor.gd")
const Repair=preload("res://scripts/actors/hood_eye_repair_mask.gd")
func _initialize(): call_deferred("_run")
func _run():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1560,1150))
	root.content_scale_size=Vector2i(1560,1150)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var background:=ColorRect.new()
	background.size=Vector2(1560,1150)
	background.color=Color(0.45,0.45,0.45)
	root.add_child(background)
	var examples:Array=[
		["tired_stop",0],["tired_stop",17],["tired_stop",34],["tired_idle",0],["tired_idle",30],["tired_idle",59],
		["shoved",0],["shoved",27],["shoved",54],["shoved_out",0],["shoved_out",45],["shoved_out",90],
		["climb",0],["climb",30],["climb",60],["climb",91],["clumsy_run_fall",7],["water_tread",15],
		["idle_left",0],["tired_run",22],["fall_impact",20],["downed",50],["get_up",30],["get_up",100],
		["rope_ladder",0],["rope_ladder",60],["rope_ladder",117],["rope_ladder",160],["rope_ladder",210],["rope_ladder",234]]
	var unified:bool=OS.get_cmdline_user_args().has("--unified")
	var repair_checks:Array=[]
	var helper=Actor.new()
	var body_material:ShaderMaterial=helper._build_material()
	helper.free()
	for index in examples.size():
		var name:String=examples[index][0]
		var frame:int=examples[index][1]
		var texture:Texture2D=load(M.frame_path(name,frame))
		var cell:=Vector2(index%6*260,index/6*230)
		var label:=Label.new()
		label.text="%s / %d"%[name,frame]
		label.position=cell+Vector2(8,4)
		label.add_theme_font_size_override("font_size",16)
		root.add_child(label)
		var sprite:=Sprite2D.new()
		sprite.texture=texture
		var factor:float=minf(235.0/texture.get_width(),195.0/texture.get_height())
		sprite.scale=Vector2.ONE*factor
		sprite.position=cell+Vector2(130,126)
		root.add_child(sprite)
		if unified:
			sprite.material=body_material.duplicate()
			var eye=Light.new()
			sprite.add_child(eye)
			var row:Array=Eyes.DATA[name][frame].duplicate()
			var rect:Array=M.CLIPS[name].rects[frame]
			var clip_root:Array=M.CLIPS[name].root
			row[0]+=float(clip_root[0])-float(rect[0])-texture.get_width()*0.5
			row[1]+=float(clip_root[1])-float(rect[1])-texture.get_height()*0.5
			eye.sync_eye(row,false,0.0)
			var mat:=sprite.material as ShaderMaterial
			mat.set_shader_parameter("eye_repair",Repair.texture_for(name,frame,Vector2i(texture.get_size())))
			mat.set_shader_parameter("source_eye_visible",float(row[3])>0.0)
			mat.set_shader_parameter("source_eye",(Vector2(float(row[0]),float(row[1]))+Vector2(texture.get_size())*0.5)/Vector2(texture.get_size()))
			if name=="rope_ladder":
				for span in Repair.Repairs.DATA.get(name,{}).get(str(frame),[]):
					if int(span[2])-int(span[1])<3:continue
					var point:=Vector2((float(span[1])+float(span[2]))*0.5,float(span[0])+0.5)
					repair_checks.append(sprite.position+(point-Vector2(texture.get_size())*0.5)*factor)
	for i in 5: await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/actor-eyes")
	var rendered:=root.get_texture().get_image()
	rendered.save_png("res://artifacts/actor-eyes/unified-contact-sheet.png" if unified else "res://artifacts/actor-eyes/source-contact-sheet.png")
	var failures:=0
	if unified:
		for point in repair_checks:
			var pixel:=rendered.get_pixelv(Vector2i(point))
			if minf(pixel.r,minf(pixel.g,pixel.b))>0.11 and pixel.r-minf(pixel.g,pixel.b)<0.06:
				failures+=1
		var rope_row:=rendered.get_region(Rect2i(0,920,1560,230))
		rope_row.save_png("res://artifacts/actor-eyes/unified-rope-eyes-fixed.png")
		print("PASS: no gray-white eye holes in six rendered ladder poses" if failures==0 else "FAIL: remaining eye-hole pixels "+str(failures))
	print("EYE SOURCE SHEET READY")
	quit(0 if failures==0 else 1)
