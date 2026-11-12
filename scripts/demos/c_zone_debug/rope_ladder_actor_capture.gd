extends "res://scripts/demos/c_zone_debug/rope_ladder_capture.gd"
var previous_clip:StringName=&""
var handoffs:Array=[]
var recorded:Dictionary={}
var last_sync:=0
var last_physics:=0
var max_pose_ratio:=0.0
func _frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
		if level==null or level.rope_ladder==null: continue
		var actor=level.actor
		var ladder=level.rope_ladder
		var count:int=Engine.get_physics_frames()
		if ladder.active() and previous_clip==&"rope_ladder" and count>last_physics:
			max_pose_ratio=maxf(max_pose_ratio,float(actor.pose_sync_count-last_sync)/float(count-last_physics))
		last_sync=actor.pose_sync_count
		last_physics=count
		var tag:String="top" if level.player.position.y<ladder.anchor().y+100 else "bank"
		if actor.current_clip==&"rope_ladder" and ((ladder.mode==ladder.Mode.EXIT and ladder.frame>=232) or (ladder.mode==ladder.Mode.LAND and ladder.frame>=117)) and not recorded.has(tag):
			recorded[tag]=true
			_record(tag+"-last-recorded")
		if previous_clip==&"rope_ladder" and actor.current_clip!=&"rope_ladder":
			handoffs.append({"tag":tag,"age":0})
		for item in handoffs:
			item.age+=1
			if item.age in [1,8,30,90]: _record(item.tag+"-idle-%02d"%item.age)
		previous_clip=actor.current_clip
func _record(label:String):
	var actor=level.actor
	RenderingServer.force_draw()
	var frame_image:Image=root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://artifacts/rope-ladder/actor-handoff")
	frame_image.save_png("res://artifacts/rope-ladder/actor-handoff/"+label+".png")
	var source:Image=actor.sprite.texture.get_image()
	if source.is_compressed(): source.decompress()
	var total:=0.0
	var eye:=Vector2.ZERO
	for y in source.get_height():
		for x in source.get_width():
			var c:Color=source.get_pixel(x,y)
			if c.a>0.4 and c.r>0.35 and c.r>c.g*1.35:
				var w:float=(c.r-c.g)*c.a
				total+=w
				eye+=Vector2(x+0.5,y+0.5)*w
	var screen:Vector2=actor.sprite.to_global(eye/maxf(total,0.001))-Vector2(level.camera_x,level.camera_y)-level.camera.offset
	if actor.eye_light.visible:
		screen=actor.eye_light.global_position-Vector2(level.camera_x,level.camera_y)-level.camera.offset
	screen*=Vector2(frame_image.get_size())/Vector2(root.content_scale_size)
	var chroma:=0.0
	for dy in range(-4,5):
		for dx in range(-4,5):
			var p:Vector2i=Vector2i(screen)+Vector2i(dx,dy)
			if Rect2i(Vector2i.ZERO,frame_image.get_size()).has_point(p):
				var c:Color=frame_image.get_pixelv(p)
				chroma=maxf(chroma,c.r-maxf(c.g,c.b))
	print("ACTOR REVIEW ",label," clip=",actor.current_clip," frame=",actor.current_frame_index," eye_chroma=",chroma," eye_screen=",screen," root=",actor.position," body=",actor.body.position," landing=",actor.landing_time)
func _snap(label:String):
	await super._snap(label)
	if label=="06-bank":
		await _frames(100)
	if label=="08-top":
		await _frames(100)
		print("ACTOR POSE UPDATES PER PHYSICS FRAME ",max_pose_ratio)
