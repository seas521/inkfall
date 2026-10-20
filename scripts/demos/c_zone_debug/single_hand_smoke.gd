extends SceneTree

const Scene = preload("res://scenes/debug/c_zone_river.tscn")
const Source = preload("res://scripts/actors/seedance_actor_manifest.gd")
const Hand = preload("res://scripts/demos/c_zone_debug/single_hand_manifest.gd")
const OUTPUT := "res://artifacts/c-zone-fan/single-hand-grip"
var level
var failures := 0
var capture := false
var shot_index := 0

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	if capture:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
	_audit_frames()
	level = Scene.instantiate()
	root.add_child(level)
	var empty := await _trace(false)
	var held := await _trace(true)
	var max_error := 0.0
	for i in empty.size():
		max_error = maxf(max_error,Vector2(empty[i]).distance_to(held[i]))
	_check(max_error<0.01,"empty/held movement trajectories match (max %.4f)" % max_error)
	print("single_hand_smoke: %s" % ("PASS" if failures==0 else "FAIL (%d)" % failures))
	level.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _audit_frames() -> void:
	var total := 0
	var sockets_ok := true
	var feet_ok := true
	var heads_ok := true
	var markers_clear := true
	var canvases_ok := true
	for clip in Hand.CLIPS:
		for index in int(Source.CLIPS[clip].frames):
			var source := (load(Source.frame_path(clip,index)) as Texture2D).get_image()
			var frame := (load(Hand.frame_path(clip,index)) as Texture2D).get_image()
			if source.is_compressed(): source.decompress()
			if frame.is_compressed(): frame.decompress()
			canvases_ok = canvases_ok and frame.get_size()==Vector2i(256,256)
			var socket := Vector2i(Hand.hand_anchor(clip,index).round())
			if frame.get_pixelv(socket).a<0.5:
				print("Socket outside grip: ",clip,"/",index," ",socket)
				sockets_ok = false
			var marker: Vector2 = Source.small_item_anchor(clip,index)-Source.SMALL_ITEM_CENTER_OFFSET
			for y in 256:
				for x in 256:
					var before := source.get_pixel(x,y)
					var after := frame.get_pixel(x,y)
					if y<130 and (before.a>0.5 or after.a>0.5) and before!=after:
						if heads_ok: print("Head delta: ",clip,"/",index," ",Vector2i(x,y)," ",before," ",after)
						heads_ok=false
					if y>=218 and x<140 and (before.a>0.5 or after.a>0.5) and before!=after:
						if feet_ok: print("Foot delta: ",clip,"/",index," ",Vector2i(x,y)," ",before," ",after)
						feet_ok=false
					if Vector2(x,y).distance_to(marker)<6.0 and after.a>0.5 and after.r>0.3 and after.r>after.g*1.25:
						markers_clear = false
			total+=1
	_check(canvases_ok and total==53,"53 fixed 256x256 full frames, unchanged frame counts")
	_check(sockets_ok,"all per-frame hand sockets lie inside the new fist")
	_check(heads_ok and feet_ok,"original upper head and supporting feet remain pixel-identical")
	_check(markers_clear,"no source orb glow remains in the hand region")

func _trace(holding: bool) -> Array[Vector2]:
	for action in [&"move_left",&"move_right",&"jump",&"blade_toggle"]:
		Input.action_release(action)
	level.reset_all()
	level.intro_time = 0.0
	level.crate.position = Vector2(2200,518)
	level.player.position = Vector2(540,496)
	level.fan_owned = holding
	level.fan_revealed = holding
	for i in 60: await physics_frame
	var positions: Array[Vector2] = []
	var clips := {}
	var walk_frames := {}
	var root_ok := true
	var attachment_ok := true
	var scale_ok := true
	for i in 240:
		match i:
			24: Input.action_press("move_right")
			66: Input.action_press("jump")
			100: Input.action_release("jump")
			117:
				Input.action_release("move_right")
				Input.action_press("move_left")
			150: Input.action_press("jump")
			158: Input.action_press("blade_toggle")
			170:
				Input.action_release("jump")
				Input.action_release("blade_toggle")
			206: Input.action_release("move_left")
		await physics_frame
		await process_frame
		positions.append(level.player.position)
		if holding:
			clips[level.actor.current_clip]=true
			if level.actor.current_clip==&"carry_run": walk_frames[level.actor.current_frame_index]=true
			root_ok = root_ok and level.actor.animated.position==-Source.ROOT
			scale_ok = scale_ok and level.actor.animated.scale==Vector2.ONE and absf(absf(level.actor.scale.x)-0.378)<0.0001
			attachment_ok = attachment_ok and level.fan.position.distance_to(level.actor.fan_hand_position())<0.01
			if capture and i%2==0: _capture()
	if holding:
		_check(root_ok and scale_ok,"walk/jump/turn retain the same root and scale")
		_check(attachment_ok,"fan stays attached to the single hand through movement and jumping")
		_check(walk_frames.size()>=12,"distance-driven walking retains its continuous frames (%d observed)" % walk_frames.size())
		var all_jumps := true
		for clip in [&"carry_takeoff",&"carry_rise",&"carry_apex",&"carry_fall",&"carry_land"]: all_jumps=all_jumps and clips.has(clip)
		_check(all_jumps,"takeoff/rise/apex/fall/land remain distinct during two jumps")
		_check(level.player.is_on_floor() and level.actor.current_clip==&"carry","landing returns to the single-hand idle")
	return positions

func _capture() -> void:
	level.camera.position = level.player.position+Vector2(38,-4)
	level.camera.zoom = Vector2.ONE*2.2
	level.camera.force_update_scroll()
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.resize(1280,720,Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(OUTPUT+"/motion")
	image.save_png(OUTPUT+"/motion/frame_%04d.png" % shot_index)
	if shot_index in [0,20,38,80]: image.save_png(OUTPUT+"/game-%03d.png" % shot_index)
	shot_index+=1

func _check(condition: bool, message: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL",message])
	if not condition: failures+=1
