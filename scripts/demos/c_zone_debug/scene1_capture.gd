extends SceneTree

# Windowed capture of scene 1: frozen frames along it.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Scene1 = preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
var TAG := OS.get_environment("S1_TAG") if OS.has_environment("S1_TAG") else ""

func _initialize() -> void:
	call_deferred("_run")

# `offset`: along the route (px from where he lies); the camera is centred 200 px ahead of him
func _shot(shot_name: String, offset: float, intro: float, lead := 200.0) -> void:
	var px: float = Scene1.START_X + offset
	var gy: float = Scene1.ground_top(px)
	level.player.position = Vector2(px - 13.0, gy - 56.0)
	level.player.velocity = Vector2.ZERO
	level.scene1.intro_time = intro
	for i in 3:
		await physics_frame
	level.set_physics_process(false)
	level.camera_x = px + lead - 640.0
	level.camera_y = level._camera_target_y()
	level.camera.position = Vector2(px + lead, 360.0 + level.camera_y)
	level._present(0.0)
	for i in 4:
		await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/scene1")
	var shot: Image = root.get_texture().get_image()
	shot.save_png("res://artifacts/scene1/%s%s.png" % [TAG, shot_name])
	var zoom := shot.get_region(Rect2i(250, 470, 700, 190))
	zoom.resize(1400, 380, Image.INTERPOLATE_LANCZOS)
	zoom.save_png("res://artifacts/scene1/%s%s_zoom.png" % [TAG, shot_name])
	level.set_physics_process(true)

# Whatever is happening now (he keeps walking): the camera follows him
func _snap(shot_name: String) -> void:
	level.set_physics_process(false)
	var px: float = level.player.position.x + 13.0
	level.camera_x = px + 200.0 - 640.0
	level.camera_y = level._camera_target_y()
	level.camera.position = Vector2(px + 200.0, 360.0 + level.camera_y)
	level._present(0.0)
	for i in 4:
		await process_frame
	RenderingServer.force_draw()
	var shot: Image = root.get_texture().get_image()
	shot.save_png("res://artifacts/scene1/%s%s.png" % [TAG, shot_name])
	var zoom := shot.get_region(Rect2i(250, 470, 700, 190))
	zoom.resize(1400, 380, Image.INTERPOLATE_LANCZOS)
	zoom.save_png("res://artifacts/scene1/%s%s_zoom.png" % [TAG, shot_name])
	level.set_physics_process(true)

# Whatever is happening now, with the camera where the game has it
func _snap_here(shot_name: String) -> void:
	level.set_physics_process(false)
	level._present(0.0)
	var flock = level.art.bat_flock
	if flock.visible:
		print("FLOCK %s visible, seq %.2f target %s shift %s bat0 %s bat9 %s" % [shot_name, flock.sequence_time, flock.target, flock.start_shift, flock._bat_position(0, flock.sequence_time), flock._bat_position(9, flock.sequence_time - 0.2)])
	for i in 4:
		await process_frame
	RenderingServer.force_draw()
	var shot: Image = root.get_texture().get_image()
	shot.save_png("res://artifacts/scene1/%s%s.png" % [TAG, shot_name])
	var px: float = level.player.position.x + 13.0 - level.camera_x
	var zoom := shot.get_region(Rect2i(maxi(0, int(px) - 260), 300, 520, 330))
	zoom.resize(1040, 660, Image.INTERPOLATE_LANCZOS)
	zoom.save_png("res://artifacts/scene1/%s%s_zoom.png" % [TAG, shot_name])
	level.set_physics_process(true)

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = SCENE.instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	level.debug_enter_scene1()
	for i in 30:
		await physics_frame
	var shots: Array = [["a_lying", 0.0, 0.3], ["b_wake", 450.0, 9.0], ["c_forest", 750.0, 9.0], ["d_log", 1000.0, 9.0], ["e_forest", 1450.0, 9.0], ["f_pit", 1880.0, 9.0], ["g_clear", 2400.0, 9.0], ["h_pond", 2700.0, 9.0], ["i_bramble", Scene1.BRAMBLE_OFFSET, 9.0], ["j_slope", 3800.0, 9.0], ["k_boulder", 4080.0, 9.0], ["l_edge1", 4350.0, 9.0], ["m_edge2", 4600.0, 9.0]]
	var only := OS.get_environment("S1_ONLY") if OS.has_environment("S1_ONLY") else ""
	for entry in shots:
		if only == "" or only.split(",").has(entry[0]):
			await _shot(entry[0], entry[1], entry[2])
	if only.split(",").has("wade"):
		var px: float = Scene1.START_X + 2680.0 - 60.0
		level.player.position = Vector2(px - 13.0, Scene1.ground_top(px) - 56.0)
		level.scene1.intro_time = 9.0
		Input.action_press("move_right")
		for i in 170:
			await physics_frame
			if i == 62 or i == 78 or i == 96 or i == 130:
				await _snap("w_%d" % i)
		Input.action_release("move_right")
	if only.split(",").has("cliff"):
		# the cliff sequence, as it plays: no keys pressed; a frame at each of these moments {phase, seconds into it}
		var pxs: float = Scene1.AUTO_X - 90.0
		level.scene1.cp = 3  # (past the foot and the arm)
		level.scene1.reset()
		level.player.position = Vector2(pxs - 13.0, Scene1.ground_top(pxs) - 56.0)
		level.player.velocity = Vector2.ZERO
		level.scene1.intro_time = 99.0
		for i in 20:
			await physics_frame
		var marks: Array = [[1, 0.1, "k0_auto"], [1, 1.6, "k1_slow"], [1, 3.2, "k2_slower"], [2, 0.2, "k3_stop"], [2, 0.42, "k4_bent"], [3, 0.5, "k5_pant"], [3, 2.0, "k6_pant"],
				[4, 0.3, "k7_flock"], [4, 0.7, "k8_flock"], [5, 0.15, "k9_hit"], [5, 0.9, "ka_down"], [6, 0.6, "kb_downed"], [7, 1.2, "kc_getup"], [8, 0.5, "kd_control"], [9, 0.8, "ke_omen"], [9, 1.6, "kf_hand_coming"], [10, 0.12, "kg_slam"], [10, 0.7, "kh_fall"]]
		var done: Array = []
		var last_cut := -1
		Input.action_press("move_right")  # (he walks up to the line by himself, with the keys; then the computer has him)
		for i in 3000:
			await physics_frame
			var sc = level.scene1
			if sc.cut == 1 and Input.is_action_pressed("move_right"):
				Input.action_release("move_right")
			if sc.cut != last_cut:
				print("CLIFF t=%d cut %d at x %.0f vx %.0f" % [i, sc.cut, level.player.position.x + 13.0, level.player.velocity.x])
				last_cut = sc.cut
			for m in marks:
				if not done.has(m[2]) and sc.cut == m[0] and sc.cut_time >= m[1]:
					done.append(m[2])
					await _snap_here(m[2])
			if sc.cut == 10 and sc.cut_time > 1.0:
				break
		print("CLIFF done: %s" % [done])
	if only.split(",").has("chase"):
		# the hunter: run from the pond on (keys held) and take a frame at each moment of the foot and the arm
		var pxh: float = Scene1.CP_X[1]
		level.scene1.cp = 1
		level.player.position = Vector2(pxh - 13.0, Scene1.ground_top(pxh) - 56.0)
		level.player.velocity = Vector2.ZERO
		level.scene1.reset()
		level.scene1.intro_time = 99.0
		for i in 20:
			await physics_frame
		Input.action_press("move_right")
		var hmarks: Array = [["foot", 1, 0.2, "h0_start"], ["foot", 1, 1.0, "h1_omen"], ["foot", 1, 1.75, "h2_omen"], ["foot", 3, 0.12, "h3_strike"], ["foot", 3, 0.9, "h4_rest"],
				["arm", 1, 0.5, "h5_arm"], ["arm", 1, 1.0, "h6_arm"], ["arm", 1, 1.3, "h7_arm"]]
		var hdone: Array = []
		var jump_until := -1
		for i in 1500:
			await physics_frame
			var hh = level.scene1.hunter
			# (a jump over the thorns, by the keys, as a player would)
			var hx: float = level.player.position.x + 13.0
			if jump_until < 0 and hx > Scene1.START_X + Scene1.BRAMBLE_OFFSET - 36.0 and hx < Scene1.START_X + Scene1.BRAMBLE_OFFSET - 20.0:
				Input.action_press("jump")
				jump_until = i + 26
			if jump_until >= 0 and i >= jump_until and Input.is_action_pressed("jump"):
				Input.action_release("jump")
			for m in hmarks:
				if hdone.has(m[3]):
					continue
				var phase: int = hh.foot_phase if m[0] == "foot" else hh.arm_phase
				var t: float = hh.foot_time if m[0] == "foot" else hh.arm_time
				if phase == m[1] and t >= m[2]:
					hdone.append(m[3])
					print("HUNTER %s gap %.0f pressure %.2f x %.0f" % [m[3], hh.gap, hh.pressure, level.player.position.x + 13.0])
					await _snap_here(m[3])
			if hdone.size() == hmarks.size():
				break
		Input.action_release("move_right")
		print("HUNTER done: %s" % [hdone])
	if only.split(",").has("onlog"):
		# standing on the fallen trunk at three places along it
		var log_feature: Dictionary = {}
		for f: Dictionary in Scene1.FEATURES:
			if String(f["t"]) == "log":
				log_feature = f
				break
		level.scene1.intro_time = 99.0
		for at in [60.0, 190.0, 320.0]:
			var lx: float = Scene1.fx(log_feature) + at
			level.player.position = Vector2(lx - 13.0, Scene1.GROUND_Y - 150.0)
			level.player.velocity = Vector2.ZERO
			for i in 50:
				await physics_frame
			print("ONLOG at %.0f: feet y %.1f on floor %s" % [at, level.player.position.y + 54.0, level.player.is_on_floor()])
			await _snap("ol_%d" % int(at))
	if only.split(",").has("climb"):
		# running at the boulder and climbing it: frames of the climb
		var boulder: Dictionary = {}
		for f: Dictionary in Scene1.FEATURES:
			if String(f["t"]) == "boulder":
				boulder = f
				break
		var edge_x: float = Scene1.fx(boulder) - float(boulder["bottom"]) * 0.5
		var pxc: float = Scene1.fx(boulder) - 230.0
		level.player.position = Vector2(pxc - 13.0, Scene1.ground_top(pxc) - 56.0)
		level.scene1.intro_time = 99.0
		for i in 30:
			await physics_frame
		Input.action_press("move_right")
		for i in 400:
			await physics_frame
			if level.player.position.x + 26.0 >= edge_x - 40.0:
				break
		Input.action_press("jump")
		var shots_taken := 0
		for i in 260:
			await physics_frame
			if i == 28:
				Input.action_release("jump")
			if level.climb_time >= 0.0 and shots_taken == 0:
				var pts: PackedVector2Array = Scene1.boulder_points(boulder)
				var top_y := 1.0e9
				var left_x := 1.0e9
				for pt in pts:
					top_y = minf(top_y, pt.y)
					left_x = minf(left_x, pt.x)
				print("CLIMB corner %s, rock top y %.1f left x %.1f, climb scale %.3f, hero pos %s" % [level.climb_corner, top_y, left_x, level._climb_scale(), level.player.position])
			if level.climb_time >= 0.0 and i % 14 == 0 and shots_taken < 8:
				print("CLIMB t %.2f root %s corner %s actor %s clip %s frame %d" % [level.climb_time, level._climb_root(), level.climb_corner, level.hood_actor.global_position, level.hood_actor.current_clip, level.hood_actor.current_frame_index])
				await _snap("cl_%d" % shots_taken)
				shots_taken += 1
		Input.action_release("move_right")
		print("CLIMB shots %d, ended at x %.0f (rock %.0f..%.0f)" % [shots_taken, level.player.position.x, edge_x, Scene1.fx(boulder) + float(boulder["bottom"]) * 0.5])
	if only.split(",").has("ablate"):
		# frame time with parts of the picture switched off (ms per frame, 90 frames each), standing at the clearing
		var pxa: float = Scene1.START_X + float(OS.get_environment("S1_AT") if OS.has_environment("S1_AT") else "2500")
		level.player.position = Vector2(pxa - 13.0, Scene1.ground_top(pxa) - 56.0)
		level.scene1.intro_time = 9.0
		for i in 30:
			await physics_frame
		var art = level.art
		var marsh = level.marsh_art
		var cases := {
			"all on": [],
			"no marsh fog": [marsh.fog],
			"no marsh effects": [marsh.effects],
			"no marsh dyn": [marsh.dyn],
			"no forest_back": [art.forest_back],
			"no plates": [art.plates_far,art.plates_mid],
			"no near_view": [art.near_view],
			"no fore_view": [art.fore_view],
			"no grass_art": [art.grass_art],
			"no lens": [art.lens],
			"no atmosphere": [art.atmosphere],
			"no marsh stages": [marsh.back_stage.sprite, marsh.front_stage.sprite],
		}
		for label in cases:
			var hidden: Array = cases[label]
			for node in hidden:
				node.visible = false
			var t_start := Time.get_ticks_usec()
			for i in 90:
				await process_frame
				if label != "all on":
					for node in hidden:
						node.visible = false
			var ms := float(Time.get_ticks_usec() - t_start) / 1000.0 / 90.0
			print("ABLATE %-18s %.2f ms/frame  draw calls %d" % [label, ms, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
			for node in hidden:
				node.visible = true
	if only.split(",").has("prof"):
		# which part of the frame costs: ms per call, averaged over 60 calls, at the pond
		var px3: float = Scene1.START_X + 2500.0
		level.player.position = Vector2(px3 - 13.0, Scene1.ground_top(px3) - 56.0)
		if OS.has_environment("S1_PHYS_X"):
			level.player.position = Vector2(float(OS.get_environment("S1_PHYS_X")), float(OS.get_environment("S1_PHYS_Y")))
		level.scene1.intro_time = 9.0
		for i in 20:
			await physics_frame
		var parts := {"art.sync": 0.0, "marsh_art.sync": 0.0, "scene1.tick": 0.0, "all _present": 0.0}
		for i in 60:
			await physics_frame
			var t0 := Time.get_ticks_usec()
			level.art.sync(0.016, level.camera_x, true)
			var t1 := Time.get_ticks_usec()
			level.marsh_art.sync(0.016, level.camera_x, true)
			var t2 := Time.get_ticks_usec()
			level.scene1.tick(0.016)
			var t3 := Time.get_ticks_usec()
			level._present(0.016)
			var t4 := Time.get_ticks_usec()
			parts["art.sync"] += (t1 - t0) / 1000.0
			parts["marsh_art.sync"] += (t2 - t1) / 1000.0
			parts["scene1.tick"] += (t3 - t2) / 1000.0
			parts["all _present"] += (t4 - t3) / 1000.0
		var phys_total := 0.0
		for i in 60:
			await physics_frame
			phys_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		print("PROF physics process (standing): %.2f ms, shapes on the ground body: %d" % [phys_total / 60.0, level.scene1.body.get_child_count()])
		for key in parts:
			print("PROF %s: %.2f ms" % [key, parts[key] / 60.0])
	if only.split(",").has("perf"):
		# frame cost while running east through the first pond: before it, in it, after it (ms per frame: whole frame, script process)
		var px2: float = Scene1.START_X + (float(OS.get_environment("S1_PERF_FROM")) if OS.has_environment("S1_PERF_FROM") else 2300.0)
		level.player.position = Vector2(px2 - 13.0, Scene1.ground_top(px2) - 56.0)
		level.scene1.intro_time = 9.0
		Input.action_press("move_right")
		var groups := {"before": [], "in": [], "after": []}
		var last := Time.get_ticks_usec()
		for i in 420:
			await process_frame
			var now := Time.get_ticks_usec()
			var fx2: float = level.player.position.x + 13.0
			var key := "before" if fx2 < Scene1.START_X + 2680.0 else ("in" if fx2 < Scene1.START_X + 3020.0 else "after")
			if i > 20:
				groups[key].append([float(now - last) / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
			last = now
		Input.action_release("move_right")
		for key in groups:
			var rows: Array = groups[key]
			if rows.is_empty():
				continue
			var tot := 0.0
			var worst := 0.0
			var script := 0.0
			var phys := 0.0
			for r in rows:
				tot += r[0]
				worst = maxf(worst, r[0])
				script += r[1]
				phys += r[2]
			print("PERF %s: frames %d, frame avg %.2f ms, worst %.1f ms, process %.2f ms, physics %.2f ms" % [key, rows.size(), tot / rows.size(), worst, script / rows.size(), phys / rows.size()])
	quit(0)
