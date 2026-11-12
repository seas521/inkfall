extends Node2D

# Explicit art review, not placeholder rope/hoist gameplay. The existing actor is
# used as a scale reference at rest. Camera travel follows the continuous world.
const Layout = preload("res://scripts/demos/c_zone_debug/descent_layout.gd")
const Art = preload("res://scripts/demos/c_zone_debug/descent_art.gd")
const Pose = preload("res://scripts/actors/actor_pose_state.gd")

var level
var art: Node2D
var enabled := false
var rail := 0.0
var target := 0.0
var hud: CanvasLayer
var label: Label
var help_time := 0.0
var autoplay := false

func _ready() -> void:
	art = Art.new()
	art.level = level
	add_child(art)
	hud = CanvasLayer.new()
	hud.layer = 80
	add_child(hud)
	label = Label.new()
	label.position = Vector2(32,28)
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",Color(0.8,0.82,0.8,0.75))
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	hud.add_child(label)
	hud.hide()

func enter(shot := 0, instant := true) -> void:
	if level.log_bridge != null and level.log_bridge.active:
		level.log_bridge.stop()
	enabled = true
	autoplay = false
	target = float(clampi(shot,0,Layout.SHOTS.size()-1))
	if instant:
		rail = target
	else:
		# Begin on the camera's current frame, then travel to the first set.
		entry_origin = Vector2(level.camera_x,level.camera_y)
		entry_time = 0.0
		rail = target
	help_time = 7.0
	hud.show()
	level.camera.zoom = Vector2.ONE
	level.camera.offset = Vector2.ZERO
	level.fan.hide()
	level.rope_art.hide()
	if level.iris != null:
		level.iris.call("set_state",0.0,Vector2(640,360))

var entry_origin := Vector2.ZERO
var entry_time := 3.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F6:
		if not enabled:
			enter()
		else:
			hud.visible = not hud.visible
		get_viewport().set_input_as_handled()
	if not enabled:
		return
	if event.keycode in [KEY_PAGEDOWN,KEY_RIGHT,KEY_D]:
		target = minf(float(Layout.SHOTS.size()-1),floorf(target)+1.0)
		help_time = 5.0
	elif event.keycode in [KEY_PAGEUP,KEY_LEFT,KEY_A]:
		target = maxf(0.0,ceilf(target)-1.0)
		help_time = 5.0
	elif event.keycode == KEY_SPACE:
		autoplay = not autoplay
	elif event.keycode == KEY_F and rail > 5.95:
		leave_to_river()
	elif event.keycode == KEY_R:
		target = 0.0
		autoplay = false

func tick(delta: float) -> bool:
	if not enabled:
		return false  # art review is manual; the cliff now enters the playable log puzzle
	if autoplay:
		target = minf(target+delta*0.12,float(Layout.SHOTS.size()-1))
		if target >= float(Layout.SHOTS.size()-1):
			autoplay = false
	if Input.is_physical_key_pressed(KEY_DOWN):
		target = minf(target+delta*0.36,float(Layout.SHOTS.size()-1))
	elif Input.is_physical_key_pressed(KEY_UP):
		target = maxf(0.0,target-delta*0.36)
	rail = move_toward(rail,target,delta*0.62)
	var origin: Vector2 = Layout.path(rail)
	if entry_time < 2.5:
		entry_time += delta
		origin = entry_origin.lerp(origin,smoothstep(0,2.5,entry_time))
	level.camera_x = origin.x
	level.camera_y = origin.y
	level.camera.position = origin+Vector2(640,360)
	level.camera.offset = Vector2.ZERO
	# Keep the normal C renderers alive: the mouth uncovers those exact layers.
	level.art.sync(delta,origin.x,true)
	level.marsh_art.sync(delta,origin.x,true)
	art.sync(delta,origin,true)
	var nearest := clampi(roundi(rail),0,Layout.SHOTS.size()-1)
	var parked := absf(rail-float(nearest)) < 0.025 and absf(rail-target) < 0.01 and entry_time >= 2.5 and nearest != 5
	level.actor.visible = parked
	if parked:
		var feet: Vector2=Layout.SHOTS[nearest].feet
		var pose = Pose.new()
		pose.apply({"style_id":Pose.STYLE_HOOD,"feet":feet+Vector2(0,2),"velocity":Vector2.ZERO,"grounded":true,"facing":1.0,"action":Pose.ACTION_NONE,"visual_scale":Pose.HOOD_VISUAL_SCALE,"fog_blur":level.ACTOR_EDGE_SOFTNESS})
		level.actor.sync_pose(delta,pose)
		level.actor.modulate.a = 1.0
		level.actor.rotation = 0.0
	help_time = maxf(0.0,help_time-delta)
	label.text = "美术巡览  %d / 5 · %s\n← → / PgUp PgDn 切换空间　↑ ↓ 沿途查看　空格 自动巡览　F6 隐藏文字%s" % [mini(nearest+1,5),Layout.SHOTS[nearest].name,"\nF 进入原有 C 区玩法" if nearest == Layout.SHOTS.size()-1 else ""]
	label.modulate.a = 1.0 if help_time > 0.0 else 0.24
	return true

func leave_to_river() -> void:
	enabled = false
	hud.hide()
	level.scene1.cut = level.scene1.Cut.DONE
	level.player.position = Vector2(407,496)
	level.player.velocity = Vector2.ZERO
	level.camera_x = 0.0
	level.camera_y = 0.0
	level.camera.position = Vector2(640,360)
	level.checkpoint = 0
	level.intro_time = 0.0
	level.actor.show()
	level._present(0.0)

func stop() -> void:
	enabled = false
	hud.hide()
	level.actor.show()
