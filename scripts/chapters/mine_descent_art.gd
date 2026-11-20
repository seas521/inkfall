extends Node2D

# All contact and timing lives in MineDescentAct. This draws authored rock
# contours and a Polyfork cart as an orthographic black silhouette.
const Geometry = preload("res://scripts/chapters/mine_descent_geometry.gd")
const LEDGES = preload("res://assets/art/descent/mine-v1/cliff-ledges-v1.png")
const MINE_INTERIOR=preload("res://assets/art/descent/mine-v6/mine-interior.png")
const MINE_INK=preload("res://assets/shaders/mine_interior_ink.gdshader")
const MINE_SUPPORTS=preload("res://assets/art/descent/mine-v8/support-silhouettes.png")
const INTERIOR_RECT=Rect2(-3060,-3460,1086,325.8)
var cart_rendered:=false
var chamber:Node2D
var chase_chamber:Node2D
const MOUTH_ART=preload("res://assets/art/descent/mine-v6/rock-mouth-final.png")
const MOUTH_RECT=Rect2(-3250,-3513,438.9,438.9)
const WALLS=preload("res://assets/art/descent/mine-v4/rock-walls.png")
var route
const GRASS=preload("res://assets/art/c_zone_debug/forest/forest_grass_strip.jpg")
var grass:Node2D
var mist:Node2D
var mist_uv_texture:=GradientTexture2D.new()
var mountain:Node2D
var interior:Node2D
var supports:Node2D
var cliff:Node2D
var rail:Node2D
var mechanism:Node2D
var fore:Node2D
var cart_view:SubViewport
var cart_sprite:Sprite2D
var cart_visual:Node2D
var cart_model:Node3D
var wheels:Array[Node3D]=[]
var clock:=0.0

func _ready() -> void:
	mist = _ink_layer(-5, _draw_mist)
	mist_uv_texture.gradient=Gradient.new()
	mist_uv_texture.width=2
	mist_uv_texture.height=2
	var mist_ink:=ShaderMaterial.new()
	mist_ink.shader=preload("res://assets/shaders/cliff_gorge_mist.gdshader")
	mist.material=mist_ink
	grass = _ink_layer(0, _draw_grass)
	var grass_ink:=ShaderMaterial.new()
	grass_ink.shader=preload("res://assets/shaders/cliff_grass_ink.gdshader")
	grass.material=grass_ink
	mountain = _ink_layer(-4, _draw_mountain)
	var exit_mask:=ShaderMaterial.new()
	exit_mask.shader=preload("res://assets/shaders/mine_mountain_exit_mask.gdshader")
	mountain.material=exit_mask
	interior = _ink_layer(0, _draw_interior)
	var ink:=ShaderMaterial.new()
	ink.shader=MINE_INK
	interior.material=ink
	supports = _ink_layer(1, _draw_supports)
	cliff = _ink_layer(-2, _draw_cliff)
	var mouth_ink:=ShaderMaterial.new()
	mouth_ink.shader=preload("res://assets/shaders/mine_mouth_silhouette.gdshader")
	cliff.material=mouth_ink
	rail = _ink_layer(1, _draw_rails)
	var rail_ink:=ShaderMaterial.new();rail_ink.shader=preload("res://assets/shaders/mine_rail_ink.gdshader")
	rail.material=rail_ink
	mechanism = _ink_layer(3, _draw_mechanism)
	fore = _ink_layer(7, _draw_foreground)
	if route.MOUTH_ONLY:fore.material=mouth_ink
	# The imported plate is opaque black through its opening. Placing it above
	# the actor hid the entire ride, so the tunnel is composed in world space.
	_make_cart()
	chase_chamber=preload("res://scripts/chapters/mine_chamber_art.gd").new()
	add_child(chase_chamber)
	chase_chamber.build(1,-2220,1206,route.mine_floor_y,route.mine_floor_base_y)
	chase_chamber.ink.set_shader_parameter("seam_left",-2220.0)
	chamber=preload("res://scripts/chapters/mine_chamber_art.gd").new()
	add_child(chamber)
	chamber.build(0,INTERIOR_RECT.position.x,INTERIOR_RECT.size.x,route.mine_floor_y,route.mine_floor_base_y)
	chamber.ink.set_shader_parameter("fade_out_from",-2110.0)
	chamber.ink.set_shader_parameter("fade_out_to",-1974.0)
	var rim:=ShaderMaterial.new()
	rim.shader=preload("res://assets/shaders/mine_cart_rim.gdshader")
	cart_sprite.material=rim
	sync(0.0)

func _ink_layer(depth:int, callback:Callable) -> Node2D:
	var node := Node2D.new()
	node.z_index = depth
	node.draw.connect(callback)
	add_child(node)
	return node

func _make_cart() -> void:
	cart_visual=preload("res://scripts/chapters/mine_cart_visual.gd").new()
	add_child(cart_visual)
	cart_view=cart_visual.front_view
	cart_sprite=cart_visual.front
	cart_model=cart_visual.models[0]
	wheels.assign(cart_visual.axles)

func sync(delta:float) -> void:
	clock += delta
	visible = route.enabled and not route.in_c_zone
	if route.mine_trial!=null and route.mine_trial.gap.art!=null:
		route.mine_trial.gap.art.pair_room.set_enabled(visible and not route.shaft_preview)
	if not visible:
		cart_visual.front_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		cart_visual.back_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	# Static upper geology reaches well above the old mine-room bounds.
	# Update its state before culling the distant cart render targets.
	mountain.visible=route.feet().y < -1100.0
	var camera_bounds := Rect2(Vector2(route.level.camera_x,route.level.camera_y)-Vector2(260,220),Vector2(1800,1160))
	var outside := not camera_bounds.intersects(Rect2(Vector2(-6000,-4720),Vector2(10300,5620)))
	if outside:
		cart_visual.front_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		cart_visual.back_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var cart_at:Vector2 = Vector2(route.MINE_CART_X,route.mine_floor_y(route.MINE_CART_X)) if route.MOUTH_ONLY else (route.cart_position(route.ride_t) if route.ride_t >= 0 else route.FIRST_RAIL + Vector2(route.cart_x - route.FIRST_RAIL.x,0))
	if route.MOUTH_ONLY and route.mine_trial!=null:
		cart_at=route.mine_trial.cart_position()
	chamber.visible=route.MOUTH_ONLY
	chase_chamber.visible=route.MOUTH_ONLY and not route.shaft_preview
	var cart_light:float=maxf(chamber.light_at(cart_at.x),chase_chamber.light_at(cart_at.x))
	if route.mine_trial!=null and not route.shaft_preview:cart_light=maxf(cart_light,route.mine_trial.escape.end_illumination(cart_at.x))
	cart_sprite.material.set_shader_parameter("illumination",cart_light)
	cart_sprite.material.set_shader_parameter("highlight_x",0.43)
	var motion:=Vector3.ZERO
	if route.mine_trial!=null:motion=route.mine_trial.escape.visual_motion()
	cart_visual.sync_cart(cart_at,motion.x,motion.y,motion.z,cart_at.x-route.MINE_CART_X,cart_light,camera_bounds.has_point(cart_at),route.mine_trial.escape.front_wheel_distance() if route.mine_trial!=null else INF)
	cart_rendered=true
	# Rock contours and the empty legacy layers are static. CanvasItem keeps
	# their commands; camera movement needs no polygon clipping or redraw.
	_sync_rail_light()
	mechanism.queue_redraw()

func _draw_mountain() -> void:
	# Two continuous opposing faces; every ledge is rooted in one of them.
	mountain.draw_colored_polygon(Geometry.left_mass(),Color(0.007,0.007,0.007))
	var outline:=Geometry.wall_edge(true)
	outline.append(Vector2(outline[-1].x,900))
	outline.append(Vector2(4200,900))
	for i in range(256,-1,-1):
		var t:=float(i)/256.0
		var x:=lerpf(-3000.0,4200.0,t)
		outline.append(Vector2(x,_ridge_y(x)))
	outline.append_array(PackedVector2Array([Vector2(-3045,-4196),Vector2(-3085,-4192),Vector2(-3105,-4195)]))
	var shoulder_start:=outline[-1]
	var shoulder_end:=Vector2(-3146,-4194).lerp(outline[0],0.42)
	for j in range(1,17):
		var t:=float(j)/16.0
		outline.append(shoulder_start.lerp(Vector2(-3148,-4198),t).lerp(Vector2(-3148,-4198).lerp(shoulder_end,t),t))
	var opening_cut:=PackedVector2Array([Vector2(-6000,MOUTH_RECT.position.y),Vector2(4300,MOUTH_RECT.position.y),Vector2(4300,900),Vector2(-6000,900)])
	for piece in Geometry2D.clip_polygons(outline,opening_cut):
		mountain.draw_colored_polygon(piece,Color(0.007,0.007,0.007))
	mountain.draw_colored_polygon(PackedVector2Array([Vector2(MOUTH_RECT.end.x,MOUTH_RECT.position.y),Vector2(4300,MOUTH_RECT.position.y),Vector2(4300,900),Vector2(MOUTH_RECT.end.x,900)]),Color(0.007,0.007,0.007))
	mountain.draw_colored_polygon(PackedVector2Array([Vector2(-3145,MOUTH_RECT.end.y-1),Vector2(4300,MOUTH_RECT.end.y-1),Vector2(4300,900),Vector2(-3145,900)]),Color(0.007,0.007,0.007))

func _draw_mist()->void:
	# World-anchored and behind both cliffs: no fog rectangle over black rock.
	mist.draw_texture_rect(mist_uv_texture,Rect2(-4200,-4720,1900,1750),false)

func _draw_grass()->void:
	_grass_run(-3105.0,-1810.0,true)
	_grass_run(route.landing.top[0].x+5.0,route.landing.top[-1].x-5.0,false)

func _grass_ground(x:float,ridge:bool)->float:
	if ridge:return _ridge_y(x) if x>=-3000 else -4194.0
	return Geometry.surface_y(route.landing,x)

func _grass_run(left:float,right:float,ridge:bool)->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=7821 if ridge else 3109
	var center:=left
	while center<right:
		var width:=rng.randf_range(35,49)
		var height:=rng.randf_range(22,39) if ridge else rng.randf_range(17,29)
		var index:=rng.randi_range(0,10)
		var mirrored:=rng.randf()<0.5
		var points:=PackedVector2Array()
		var uv:=PackedVector2Array()
		for row in 2:
			for j in 9:
				var t:=float(j if row==0 else 8-j)/8.0
				var x:=clampf(center-width*0.5+t*width,left,right)
				var edge:=smoothstep(0.0,18.0,minf(x-left,right-x))
				var y:=_grass_ground(x,ridge)+(-height*lerpf(0.25,1.0,edge) if row==0 else 3.0)
				points.append(Vector2(x,y))
				var source_t:=clampf((x-center+width*0.5)/width,0,1)
				if mirrored:source_t=1.0-source_t
				uv.append(Vector2((index+(0.018+source_t*0.964))/11.0,(419.0 if row==0 else 568.0)/720.0))
		grass.draw_polygon(points,PackedColorArray([Color.WHITE]),uv,GRASS)
		center+=rng.randf_range(11,15)

func _ridge_y(x:float)->float:
	var t:float=(x+3000)/7200.0
	return -4190.0+1890.0*t+24.0*sin(t*17.0)+9.0*sin(t*43.0)+2.4*sin(t*319.0)

func _draw_supports() -> void:
	if route.MOUTH_ONLY:
		return # Independent authored supports now belong to the chamber layers.

func _draw_interior() -> void:
	if route.MOUTH_ONLY:
		return
	# The opening starts at the last stone shelf. Every rail below it has
	# rock above and below; only the entrance and C exit face open air.
	for segment in [[Vector2(-3180,route.FIRST_RAIL.y),route.FIRST_RAIL],[route.FIRST_RAIL,route.TURN_RAIL],[route.TURN_RAIL,route.END_RAIL]]:
		var a:Vector2 = segment[0]
		var b:Vector2 = segment[1]
		var slope := (b-a).normalized()
		var n := Vector2(-slope.y,slope.x)
		var roof := PackedVector2Array()
		var floor := PackedVector2Array()
		for i in 49:
			var t := float(i)/48.0
			var p := a.lerp(b,t)
			var r := 119.0 + 10.0*sin(t*23.0) + 5.0*sin(t*61.0)
			roof.append(p-n*r)
			floor.append(p+n*(10.0+3.0*sin(t*37.0)))
		var passage := roof.duplicate()
		for i in range(floor.size()-1,-1,-1): passage.append(floor[i])
		interior.draw_colored_polygon(passage,Color(0.31,0.31,0.31))
		interior.draw_polyline(roof,Color(0.18,0.18,0.18,0.5),4.0,true)
		interior.draw_polyline(floor,Color(0.18,0.18,0.18,0.5),5.0,true)

func _draw_ledge(data:Dictionary,fall:float=0.0) -> void:
	if fall<1.0:
		var socket:=PackedVector2Array()
		for p in [Vector2(-190,8),Vector2(-50,8),Vector2(-40,34),Vector2(-110,84),Vector2(-190,95)]:
			socket.append(data.at+Vector2(p.x*data.side,p.y))
		cliff.draw_colored_polygon(socket,Color(0.007,0.007,0.007))
	cliff.draw_set_transform(data.at+Vector2(0,fall),0,Vector2(data.side,1))
	cliff.draw_texture_rect_region(LEDGES,data.rect,data.source,Color(0.007,0.007,0.007))
	cliff.draw_set_transform(Vector2.ZERO)

func _draw_cliff() -> void:
	var bank:PackedVector2Array=route.landing.top.duplicate()
	var tip:=bank[-1]
	var nose_end:=tip+Vector2(-14,18)
	for j in range(1,13):
		var t:=float(j)/12.0
		bank.append(tip.lerp(tip+Vector2(14,3),t).lerp((tip+Vector2(14,3)).lerp(nose_end,t),t))
	# Broad uneven undercut, with rounded turns instead of a triangular wedge.
	var underside:=[nose_end,Vector2(-3480,-3822),Vector2(-3524,-3810),Vector2(-3592,-3801),Vector2(-3624,-3807),Vector2(-3660,-3842),Vector2(-3680,-3870)]
	for i in range(1,underside.size()-1):
		var corner:Vector2=underside[i]
		var incoming:Vector2=corner.move_toward(underside[i-1],minf(17,corner.distance_to(underside[i-1])*0.35))
		var outgoing:Vector2=corner.move_toward(underside[i+1],minf(21,corner.distance_to(underside[i+1])*0.35))
		bank.append(incoming)
		for j in range(1,9):
			var t:=float(j)/8.0
			bank.append(incoming.lerp(corner,t).lerp(corner.lerp(outgoing,t),t))
	bank.append(underside[-1])
	cliff.draw_colored_polygon(bank,Color(0.007,0.007,0.007))
	# Preserve the approved entrance composition. Only its near shoulder
	# is also used for local character occlusion below.
	cliff.draw_texture_rect(MOUTH_ART,MOUTH_RECT,false,Color(0.18,0.18,0.18))

func _draw_rails() -> void:
	if route.MOUTH_ONLY:
		# Recessed timber sleepers support two continuous iron profiles. No
		# tiled bright ballast or disconnected speckles on the walking surface.
		var length:float=route.MINE_EDGE-16+3130.0
		for i in int(ceil(length/29.0)):
			var x:float=-3130+i*29.0
			var y:float=route.mine_floor_base_y(x)
			var timber:=PackedVector2Array([Vector2(x-4,y-7),Vector2(x+1,y-7),Vector2(x+5,y+3),Vector2(x-1,y+3)])
			rail.draw_colored_polygon(timber,Color(.009,0,0))
			rail.draw_line(Vector2(x-4,y-7),Vector2(x+1,y-7),Color(.006,.009,0),.8,true)
		var count:=int(ceil(length/12.0))
		var near_points:=PackedVector2Array()
		var far_points:=PackedVector2Array()
		for i in count:
			var x:float=lerpf(-3130,route.MINE_EDGE-16,float(i)/float(count-1))
			var y:float=route.mine_floor_base_y(x)
			near_points.append(Vector2(x,y-1.3));far_points.append(Vector2(x,y-7))
		# The rail webs sit on the sleepers; only the upper steel face catches
		# a restrained part of the actual pendant, so these never emit light.
		rail.draw_polyline(far_points,Color(.009,0,0),2.6,true)
		rail.draw_polyline(near_points,Color(.012,0,0),3.4,true)
		for i in range(1,count):
			rail.draw_line(near_points[i-1]-Vector2(0,1),near_points[i]-Vector2(0,1),Color(.009,.047,0),1.15,true)
			rail.draw_line(far_points[i-1]-Vector2(0,.5),far_points[i]-Vector2(0,.5),Color(.009*.52,.047*.52,0),.8,true)
		for i in range(1,int(length/232.0)):
			var x:float=-3130+i*232.0
			var y:float=route.mine_floor_base_y(x)
			rail.draw_line(Vector2(x-4,y),Vector2(x+4,y+.6),Color(.016,0,0),2.5,true)
		return
	for segment in [[route.FIRST_RAIL,route.TURN_RAIL],[route.TURN_RAIL,route.END_RAIL]]:
		var a:Vector2 = segment[0]
		var b:Vector2 = segment[1]
		var travel := b-a
		var length := travel.length()
		var normal := Vector2(-travel.y,travel.x).normalized()
		for i in int(length/42):
			var p := a + travel * (float(i)*42.0/length)
			var irregular := 1.0 + 0.14*sin(float(i)*2.37)
			rail.draw_line(p-normal*7*irregular,p+normal*8*irregular,Color(0.015,0.015,0.015),5.5,true)
		rail.draw_line(a,b,Color(0.048,0.048,0.048),5.0,true)
		rail.draw_line(a+normal*8,b+normal*8,Color(0.018,0.018,0.018),3.0,true)

func _draw_mechanism() -> void:
	if route.MOUTH_ONLY:
		for chip in route.branch_debris:
			mechanism.draw_line(chip.p,chip.p+chip.v.normalized()*4,Color(0.03,0.03,0.03,1.0-chip.age/1.2),1.3,true)
		return
	var pulley_y:float=route.FIRST_RAIL.y-160
	var stop := Vector2(route.STOP_X,route.STEPS[route.MOUTH_STEP].y)
	var rock := Vector2(route.ROCK_X,route.STEPS[route.MOUTH_STEP].y-17)
	var bucket := Vector2(route.BUCKET_X,route.STEPS[route.MOUTH_STEP].y+8+clampf(route.rock_progress,0,1)*44)
	# Separate drawing of the stop, brake, rope and weight makes the cause
	# of the release visible before the player commits to the ride.
	mechanism.draw_line(Vector2(route.BUCKET_X,pulley_y),bucket,Color(0.045,0.045,0.045),2.5,true)
	mechanism.draw_colored_polygon(PackedVector2Array([bucket+Vector2(-25,-9),bucket+Vector2(25,-9),bucket+Vector2(19,14),bucket+Vector2(-19,14)]),Color(0.012,0.012,0.012))
	mechanism.draw_arc(Vector2(route.BUCKET_X,pulley_y),11,PI,TAU,18,Color(0.035,0.035,0.035),3,true)
	var brake := Vector2(route.FIRST_RAIL.x+32,route.FIRST_RAIL.y)
	mechanism.draw_line(Vector2(route.BUCKET_X,pulley_y),brake+Vector2(0,-25),Color(0.040,0.040,0.040),2,true)
	mechanism.draw_line(brake,brake+Vector2(-24,-30 if route.brake_open else -8),Color(0.018,0.018,0.018),7,true)
	mechanism.draw_line(stop,stop+Vector2(0,-33 if route.stop_set else -6),Color(0.012,0.012,0.012),9,true)
	if route.rock_progress < 0:
		_draw_stone(rock,1.0)
	elif not route.brake_open:
		var t:float=route.rock_progress
		var flying:=rock.lerp(bucket+Vector2(0,-24),t)+Vector2(0,-42*sin(t*PI))
		_draw_stone(flying,1.0)
	if route.rockfall_time >= 0:
		_draw_stone(Vector2(route.rockfall_x,route.rockfall_y),0.83)

func _draw_stone(at:Vector2,size:float)->void:
	var outline:=PackedVector2Array()
	for p in [Vector2(-17,3),Vector2(-16,-5),Vector2(-11,-14),Vector2(-4,-17),Vector2(6,-15),Vector2(10,-11),Vector2(16,-8),Vector2(18,1),Vector2(14,9),Vector2(6,14),Vector2(-5,15),Vector2(-12,10)]:
		outline.append(at+p*size)
	mechanism.draw_colored_polygon(outline,Color(0.012,0.012,0.012))

func _draw_foreground() -> void:
	if route.MOUTH_ONLY:
		# Only the rooted near shoulder occludes the descent. The rest of the
		# approved plate stays behind the chamber, preserving its open seam.
		var width:float=INTERIOR_RECT.position.x-MOUTH_RECT.position.x
		var source:=Rect2(Vector2.ZERO,Vector2(MOUTH_ART.get_width()*width/MOUTH_RECT.size.x,MOUTH_ART.get_height()))
		fore.draw_texture_rect_region(MOUTH_ART,Rect2(MOUTH_RECT.position,Vector2(width,MOUTH_RECT.size.y)),source,Color(0.18,0.18,0.18))
		return
	for danger in [0.31,0.78]:
		var p:Vector2 = route.cart_position(danger)
		for i in 4:
			var x:float = p.x - 55 + i*29
			var tip := Vector2(x+7*sin(float(i)*3.2),p.y-54+6*i)
			fore.draw_colored_polygon(PackedVector2Array([Vector2(x-13,p.y-155),Vector2(x+21,p.y-158),tip]),Color(0.008,0.008,0.008))

func track_light_at(x:float)->float:
	var light:float=maxf(chamber.light_at(x),chase_chamber.light_at(x))
	if route.mine_trial!=null and not route.shaft_preview:light=maxf(light,route.mine_trial.escape.end_illumination(x))
	return light

func _sync_rail_light()->void:
	if route.mine_trial==null:return
	var lamps:Array=[chamber.lamp,chase_chamber.lamp,route.mine_trial.escape.chase_lamp,route.mine_trial.escape.end_lamp]
	for i in lamps.size():
		var fixture=lamps[i]
		rail.material.set_shader_parameter("lamp"+str(i),fixture.light_position())
		rail.material.set_shader_parameter("angle"+str(i),fixture.light_angle())
		rail.material.set_shader_parameter("power"+str(i),fixture.energy)
	rail.material.set_shader_parameter("collapse_clock",route.mine_trial.impact_age if route.mine_trial.broken and not route.shaft_preview else -1.0)
