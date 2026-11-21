extends Node2D
const PLAYER_COLLISION_MASK:=43 # world/props plus the mine-cart layer (32)

# Chapter 1's continuous route from the rope ladder to C's left bank.
# The ore cart follows two connected grades; world coordinates never jump.
const Art = preload("res://scripts/chapters/mine_descent_art.gd")
const SwingRope=preload("res://scripts/chapters/cliff_swing_rope.gd")
const TreePlatform = preload("res://scripts/chapters/cliff_tree_platform.gd")
const MOUTH_ONLY := true
const MOUTH_STEP := 3
const MINE_FLOOR:=[Vector2(-3060,-3270),Vector2(-2790,-3249),Vector2(-2535,-3210),Vector2(-2260,-3151),Vector2(-1974,-3096),Vector2(-1580,-3008),Vector2(-1460,-2992),Vector2(-1405,-3004),Vector2(-1360,-2993),Vector2(-1180,-2938),Vector2(-1014,-2938)]
const MINE_CART_X:=-2705.0
const MINE_PREVIEW_END:=-1050.0
const MINE_EDGE:=-1014.0
const Pose = preload("res://scripts/actors/actor_pose_state.gd")
const Geometry = preload("res://scripts/chapters/mine_descent_geometry.gd")
const STEPS := [Vector2(-3240,-3775),Vector2(-3515,-3440),Vector2(-3260,-3377),Vector2(-3010,-3270)]
const WIDTHS := [180.0,210.0,210.0,880.0]
const FIRST_RAIL := Vector2(-2680, -3395)
const TURN_RAIL := Vector2(3480, -1850)
const END_RAIL := Vector2(-180, 310)
const FIRST_RUN := 0.57
const RIDE_SECONDS := 16.0
const ROCK_X := -3080.0
const STOP_X := -2580.0
const BUCKET_X := -2855.0
const SAVE_STEPS := [0, 2, 3]
var level
var swing_rope:Node2D
var art:Node2D
var active := false
var in_c_zone := false
var c_zone_prepared:=false
var enabled := true
var platforms:Array[PhysicsBody2D] = []
var trees:Array[Node2D]=[]
var doomed_branch:Node2D
var doomed_y:=0.0
var gripping_tree:Node2D
var grip_corner_local:=Vector2.ZERO
var grip_end_local:=Vector2.ZERO
var branch_debris:Array[Dictionary]=[]
var terrain_bodies:Array[StaticBody2D] = []
var ledges:Array[Dictionary] = []
var landing:Dictionary
var checkpoint_step := -1
var last_step := -1
var reached_step := -1
var checkpoint_candidate := -1
var checkpoint_dwell := 0.0
var fall_origin := -3870.0
var was_grounded := true
var fragile_age := -1.0
var stop_set := false
var rock_progress := -1.0
var brake_open := false
var cart_x := FIRST_RAIL.x
var ride_t := -1.0
var failure_time := 0.0
var failure_airborne := false
var failure_close := -1.0
var respawn_reveal := 0.0
var failure_center := Vector2(640,360)
var mine_trial
var shaft
var shaft_preview:=false
var clock := 0.0
var rockfall_time := -1.0
var rockfall_x := -3420.0
var rockfall_y := -3660.0

func _ready() -> void:
	level.actor.load_group("fall")
	level.actor.load_group("rope_swing")
	level.actor.load_group("rope_climb")
	level.actor.load_group("rope_climb_up")
	landing=Geometry.ledge(Geometry.LANDING,Geometry.LANDING_WIDTH,1,3)
	terrain_bodies.append(_surface(landing.polygon,true))
	terrain_bodies.append(_surface(Geometry.left_mass(),false))
	terrain_bodies.append(_surface(Geometry.upper_right_mass(),false))
	for i in 3:
		var tree:=TreePlatform.new()
		tree.z_index=-1
		add_child(tree)
		tree.build(i,[Vector2(-3175,-3760),Vector2(-3625,-3430),Vector2(-3135,-3362)][i])
		trees.append(tree)
		platforms.append(tree.body)
		ledges.append({"at":STEPS[i],"top":tree.world_top()})
	# Follow the rooted shoulder down into the opening. Overlap the last
	# sound bough samples, then descend below the near rock, never requiring
	# a jump over the old steep trunk collision or a free-fall to the shelf.
	var mouth_top:=PackedVector2Array([
		Vector2(-3221.45,-3378.25),Vector2(-3209.1,-3375.0),
		Vector2(-3196.75,-3367.85),Vector2(-3185.05,-3362.65),
		Vector2(-3172,-3355),Vector2(-3157,-3345),Vector2(-3139,-3329),
		Vector2(-3118,-3310),Vector2(-3094,-3292),Vector2(-3067,-3277),
		Vector2(-3045,mine_floor_y(-3045)),Vector2(-3010,mine_floor_y(-3010))])
	# The cart collapse controller replaces the mine's main polygon with
	# movable floor pads. Keep the rooted approach independent of those
	# pads, so their old flat entrance profile cannot erase this descent.
	var approach_polygon:=mouth_top.duplicate()
	for i in range(mouth_top.size()-1,-1,-1):approach_polygon.append(mouth_top[i]+Vector2(0,18))
	# The bough flexes below this fixed approach on a heavy landing. A
	# solid polygon exposed its left closing edge as a tiny upright wall.
	# Like the bough, accept support from above without blocking its side.
	var approach_body:=_surface(approach_polygon,true)
	approach_body.name="rooted_mine_approach"
	terrain_bodies.append(approach_body)
	for p:Vector2 in MINE_FLOOR:
		if p.x> -3010 and p.x<MINE_PREVIEW_END:mouth_top.append(p)
	mouth_top.append(Vector2(MINE_PREVIEW_END,mine_floor_y(MINE_PREVIEW_END)))
	ledges.append({"at":STEPS[MOUTH_STEP],"top":mouth_top})
	var mouth_polygon:=mouth_top.duplicate()
	mouth_polygon.append(Vector2(MINE_EDGE,-2500))
	mouth_polygon.append(Vector2(mouth_top[0].x,-2500))
	platforms.append(_surface(mouth_polygon,false))
	platforms[-1].set_meta("cliff_handhold",true)
	platforms[-1].set_meta("cliff_handhold_step",MOUTH_STEP)

	swing_rope=SwingRope.new()
	swing_rope.route=self
	swing_rope.z_index=2
	add_child(swing_rope)
	art = Art.new()
	art.route = self
	add_child(art)
	mine_trial=preload("res://scripts/chapters/mine_cart_act.gd").new()
	mine_trial.route=self
	add_child(mine_trial)
	shaft=preload("res://scripts/chapters/mine_shaft_act.gd").new()
	shaft.route=self
	add_child(shaft)
	shaft.set_enabled(false)

func _surface(points:PackedVector2Array,one_way:bool)->StaticBody2D:
	var body:=StaticBody2D.new()
	body.collision_layer=1
	body.collision_mask=0
	var shape:=CollisionPolygon2D.new()
	shape.polygon=points
	shape.one_way_collision=one_way
	body.add_child(shape)
	add_child(body)
	return body

func reset() -> void:
	if mine_trial!=null:mine_trial.reset()
	if shaft!=null:
		shaft.reset()
		shaft.set_enabled(enabled and shaft_preview)
	swing_rope.reset()
	active = false
	in_c_zone = false
	c_zone_prepared=false
	enabled = true
	checkpoint_step = -1
	last_step = -1
	reached_step = -1
	checkpoint_candidate = -1
	checkpoint_dwell = 0.0
	fall_origin = -3870.0
	fragile_age = -1.0
	stop_set = false
	rock_progress = -1.0
	failure_airborne = false
	failure_close = -1.0
	respawn_reveal = 0.0
	brake_open = false
	cart_x = FIRST_RAIL.x
	ride_t = -1.0
	failure_time = 0.0
	rockfall_time = -1.0
	rockfall_y = -3660.0
	for tree in trees: tree.reset()
	for body in platforms: body.collision_layer = 1
	for body in terrain_bodies: body.collision_layer = 1
	level.log_bridge.set_mine_geometry(true)
	art.sync(0.0)

func set_enabled(value:bool) -> void:
	enabled = value
	if mine_trial!=null:mine_trial.sync_visual(0)
	if shaft!=null:shaft.set_enabled(value and shaft_preview)
	if not enabled:
		swing_rope.reset()
		active = false
		level.log_bridge.set_mine_geometry(false)
	for body in platforms: body.collision_layer = 1 if enabled else 0
	for body in terrain_bodies: body.collision_layer = 1 if enabled else 0
	art.sync(0.0)

func mine_floor_y(x:float)->float:
	var shift:=0.0
	if art!=null and art.chamber!=null and not shaft_preview:
		shift=art.chamber.floor_shift(x)+art.chase_chamber.floor_shift(x)
	return mine_floor_base_y(x)+shift

func mine_floor_base_y(x:float)->float:
	# Round the recovery crest and its run-out with tangent-continuous
	# quadratic bends. Art, contact pads and cart gravity share this curve.
	for i in range(5,10):
		var corner:Vector2=MINE_FLOOR[i]
		var previous:Vector2=MINE_FLOOR[i-1]
		var next:Vector2=MINE_FLOOR[i+1]
		var radius:float=minf(40.,minf(corner.x-previous.x,next.x-corner.x)*.45)
		if absf(x-corner.x)>radius:continue
		var a:=Vector2(corner.x-radius,corner.y-radius*(corner.y-previous.y)/(corner.x-previous.x))
		var b:=Vector2(corner.x+radius,corner.y+radius*(next.y-corner.y)/(next.x-corner.x))
		var t:float=(x-a.x)/(2.*radius)
		return a.lerp(corner,t).lerp(corner.lerp(b,t),t).y
	for i in range(MINE_FLOOR.size()-1):
		var a:Vector2=MINE_FLOOR[i]
		var b:Vector2=MINE_FLOOR[i+1]
		if x<=b.x:return lerpf(a.y,b.y,clampf(inverse_lerp(a.x,b.x,x),0,1))
	return MINE_FLOOR[-1].y

func feet() -> Vector2:
	return level.player.position + Vector2(13, 54)

func cart_position(t:float) -> Vector2:
	if t <= FIRST_RUN:
		return FIRST_RAIL.lerp(TURN_RAIL, clampf(t / FIRST_RUN, 0, 1))
	return TURN_RAIL.lerp(END_RAIL, clampf((t - FIRST_RUN) / (1.0 - FIRST_RUN), 0, 1))

func camera_target_y() -> float:
	if mine_trial!=null and mine_trial.gap.art!=null:
		var relay=mine_trial.gap.art.pair_room.relay
		if relay.completed and feet().x>2760:
			return lerpf(minf(0.0,level.player.position.y-440.0),-3050.0,smoothstep(2760,3280,feet().x))
	return minf(0.0, level.player.position.y - 440.0) if feet().y < 100.0 else 0.0

func enter(place := false) -> void:
	active = true
	level.log_bridge.active = true # keep the lower ladder catch available
	level.scene1.cut = level.scene1.Cut.DONE
	level.scene1.intro_time = 99.0
	level.intro_time = 0.0
	level.climb_time = -1.0
	fall_origin = feet().y
	was_grounded = level.player.is_on_floor()
	level.player.collision_mask|=32
	if place: restore_checkpoint()

func restore_checkpoint() -> void:
	if mine_trial!=null and mine_trial.gap!=null and mine_trial.gap.art!=null:mine_trial.gap.art.pair_room.ladders.cancel()
	if mine_trial!=null:mine_trial.cancel_operation()
	var relay_home:Variant=null
	if mine_trial!=null and mine_trial.gap!=null and not shaft_preview:
		var relay=mine_trial.gap.art.pair_room.relay
		if relay.arrival_checkpoint:relay_home=relay.restore_arrival()
		elif relay.checkpoint_active:relay_home=relay.restore_attempt()
	var mine_home:Variant=relay_home if relay_home!=null else (mine_trial.restore_attempt() if mine_trial!=null and not shaft_preview else null)
	failure_close=-1.0
	respawn_reveal=0.0
	if level.iris!=null:level.iris.set_state(0.0,Vector2(640,360))
	# A doomed landing can straddle the intact/loose collision seam. Restore
	# normal support on respawn after the temporary slip-through below.
	for tree in trees:
		if tree.stable_body!=null:
			level.player.remove_collision_exception_with(tree.stable_body)
	doomed_branch=null
	swing_rope.reset()
	failure_time = 0.0
	failure_airborne = false
	rockfall_time = -1.0
	rockfall_y = -3660.0
	fragile_age = -1.0
	for tree in trees: tree.reset()
	gripping_tree=null
	branch_debris.clear()
	level.climb_time=-1.0
	platforms[2].collision_layer = 1
	ride_t = -1.0
	level.scene1.low_stance.reset()
	level.player.collision_mask = PLAYER_COLLISION_MASK
	var home:Vector2 = STEPS[checkpoint_step] if checkpoint_step >= 0 else Geometry.LANDING+Vector2(70,0)
	if checkpoint_step==MOUTH_STEP: home=Vector2(STEPS[MOUTH_STEP].x,mine_floor_y(STEPS[MOUTH_STEP].x))
	elif checkpoint_step>=0: home.y=Geometry.surface_y(ledges[checkpoint_step],home.x)
	else: home.y=Geometry.surface_y(landing,home.x)
	if relay_home!=null or (mine_home!=null and checkpoint_step==MOUTH_STEP):home=mine_home
	level.player.position = home - Vector2(13, 55)
	if shaft_preview and shaft!=null:shaft.respawn()
	level.player.velocity = Vector2.ZERO
	level.jump_buffer = 0.0
	level.jump_windup_left = 0.0
	level.coyote = 0.0
	fall_origin = home.y
	was_grounded = true
	last_step = checkpoint_step if checkpoint_step>=0 else -1
	reached_step = last_step
	checkpoint_candidate = -1
	checkpoint_dwell = 0.0
	level.camera_x = level.player.position.x - 525.0
	level.camera_y = camera_target_y()
	level.camera.position = Vector2(level.camera_x + 640, level.camera_y + 360)
	art.sync(0.0)

func fail() -> void:
	if failure_time > 0: return
	if mine_trial!=null and mine_trial.gap!=null and mine_trial.gap.art!=null:mine_trial.gap.art.pair_room.ladders.cancel()
	failure_time = 0.001
	failure_close=-1.0
	failure_center=(feet()-Vector2(level.camera_x,level.camera_y)).clamp(Vector2(160,120),Vector2(1120,600))
	failure_airborne = not level.player.is_on_floor()
	if failure_airborne:
		# Fatal free fall keeps its momentum until the entire actor exits frame.
		level.player.collision_mask=0
		level.climb_time=-1
		level.jump_windup_left=0
	else:
		level.player.velocity = Vector2.ZERO

func _refresh_tree_contacts(delta:float)->void:
	for i in trees.size():
		var tree=trees[i]
		var top:PackedVector2Array=tree.world_top()
		var p:=feet()
		var loaded:bool=level.player.is_on_floor() and p.x>=top[0].x-14 and p.x<=top[-1].x+14 and absf(p.y-Geometry.surface_y({"top":top},p.x))<12
		var was_broken:bool=tree.broken
		tree.touch_twigs(p,level.player.velocity)
		if tree.twig_pulse:
			tree.twig_pulse=false
			for j in 6:branch_debris.append({"p":p,"v":Vector2(-40+j*16,-15-j*3),"age":0.0})
		var unsafe:bool=loaded and tree.dangerous(p)
		if unsafe and doomed_branch==null:
			doomed_branch=tree
			doomed_y=p.y
			level.jump_buffer=0
			level.jump_windup_left=0
		tree.tick(delta,unsafe if tree.fragile else loaded,gripping_tree==tree,0.0)
		ledges[i].top=tree.world_top()
		if tree.fragile and tree.warning_pulse:
			for j in 4:
				branch_debris.append({"p":tree.branch.to_global(tree.top[mini(9,tree.top.size()-1)]),"v":Vector2(-25+j*16,12+j*7),"age":0.0})
		if not was_broken and tree.broken:
			for j in 14:
				branch_debris.append({"p":tree.global_position+Vector2(-10,0),"v":Vector2(-80+j*11,-20-absf(sin(j*3.0))*65),"age":0.0})
	for chip in branch_debris:
		chip.age+=delta
		chip.v.y+=500*delta
		chip.p+=chip.v*delta
	branch_debris=branch_debris.filter(func(chip):return chip.age<1.2)

func _tick_stones(delta:float) -> void:
	_refresh_tree_contacts(delta)
	if doomed_branch!=null:
		if doomed_branch.broken and doomed_branch.stable_body!=null:
			# The outer tip has failed, but part of the capsule may still overlap
			# the intact edge. Do not let that edge suspend a control-locked actor.
			level.player.add_collision_exception_with(doomed_branch.stable_body)
		level.player.velocity=Vector2(0,minf(850,level.player.velocity.y+1500*delta))
		level.player.move_and_slide()
		if feet().y-doomed_y>115 or (doomed_branch.broken and level.player.is_on_floor() and feet().y-doomed_y>20):fail()
		return
	if swing_rope.tick(delta):return
	level.climb_cooldown=maxf(0.0,level.climb_cooldown-delta)
	if level.climb_time>=0:
		if gripping_tree!=null:
			level.climb_corner=gripping_tree.branch.to_global(grip_corner_local)
			level.climb_end_feet=gripping_tree.branch.to_global(grip_end_local)
		level._update_climb(delta)
		fall_origin=feet().y
		was_grounded=true
		if level.climb_time<0:
			gripping_tree=null
			mine_trial.gap.climb_finished()
		return
	level.scene1.tick_low_stance(delta)
	var direction:float=Input.get_axis("move_left","move_right")
	if absf(direction)>0.1:level.facing=signf(direction)
	# An already held boarding key is not another dismount request. Settle
	# into the tub first; a fresh jump immediately restores direction control.
	if mine_trial.escape.riding and not mine_trial.escape.dismount_pending and mine_trial.escape.is_riding() and level.jump_windup_left<=0 and not Input.is_action_just_pressed("jump"):
		direction=0
		level.player.velocity.x=0 # landing in the tub must not run off its opposite rim
	var previous_vy:float=level.player.velocity.y
	if level.player.is_on_floor():level.climb_floor_y=feet().y
	mine_trial.gap.prepare_move()
	var air_target:float=mine_trial.gap.target_velocity(direction,delta)
	# Boarding intent after releasing a grip applies from either side. It
	# only steers an explicit jump toward the tub; active dismounts and rail
	# launches keep their own controls and can never be pulled back inside.
	var car:Vector2=mine_trial.cart_position()
	var offset:Vector2=feet()-car
	var boarding:bool=not mine_trial.escape.saved or mine_trial.gap.boarding_window>0
	var boarding_assist:=false
	if boarding and not mine_trial.escape.dismount_pending and not mine_trial.gap.air_active and not level.player.is_on_floor() and offset.y< -35:
		if direction>0 and offset.x> -110 and offset.x<15:
			boarding_assist=true
			air_target=clampf(mine_trial.cart_speed-offset.x*8,mine_trial.cart_speed,mine_trial.cart_speed+228)
		elif direction<0 and offset.x> -15 and offset.x<110:
			boarding_assist=true
			air_target=clampf(mine_trial.cart_speed-offset.x*8,mine_trial.cart_speed-228,mine_trial.cart_speed)
	level._update_player(delta,direction,0,air_target,900 if boarding_assist else 210,mine_trial.gap.art.pair_room.stair_speed_cap(feet()))
	mine_trial.gap.after_move(direction)
	var p:=feet()
	if not shaft_preview and p.x>mine_trial.escape.EDGE_X-24:
		var pair=mine_trial.gap.art.pair_room
		var grounded:bool=level.player.is_on_floor()
		# Only the first cart's authored gap jump owns its fall envelope.
		# Ordinary movement in the mine chamber (including ladder dismounts)
		# uses the same lethal drop distance as the rest of the game.
		if pair.enabled and not mine_trial.gap.air_active:
			if not grounded:fall_origin=minf(fall_origin,p.y)
			if (not grounded or not was_grounded) and p.y-fall_origin>level.LETHAL_FALL:
				fail()
				return
			if grounded:fall_origin=p.y
		else:fall_origin=p.y
		was_grounded=grounded
		if p.y>mine_trial.gap.BANK_Y+430:fail()
		return
	var grounded:bool=level.player.is_on_floor()
	if grounded:
		if not was_grounded and p.y-fall_origin>level.LETHAL_FALL:
			fail()
			return # A lethal landing must never write a new checkpoint.
		fall_origin=p.y
		for i in ledges.size():
			var top:PackedVector2Array=ledges[i].top
			if p.x<top[0].x-14 or p.x>top[-1].x+14:continue
			if absf(p.y-Geometry.surface_y(ledges[i],p.x))<12:
				# Save inside the visible opening, not behind the near shoulder.
				if i==MOUTH_STEP and p.x< -3050:continue
				last_step=i
				if i==reached_step+1:reached_step=i
				if i in SAVE_STEPS and i<=reached_step and doomed_branch==null:
					if checkpoint_candidate!=i:
						checkpoint_candidate=i
						checkpoint_dwell=0.0
					checkpoint_dwell+=delta
					if checkpoint_dwell>=0.18:checkpoint_step=maxi(checkpoint_step,i)
				if not was_grounded and i<trees.size():trees[i].angular_velocity+=trees[i].side*minf(previous_vy/650.0,1.0)*0.12
	else:
		fall_origin=minf(fall_origin,p.y)
		checkpoint_candidate=-1
		checkpoint_dwell=0.0
		if p.y-fall_origin>level.LETHAL_FALL:
			fail()
			return
	was_grounded=grounded
	if p.y>(mine_floor_y(p.x) if p.x>=-3205 else STEPS[MOUTH_STEP].y)+185:fail()
	# The mine interior and unlocking prototype remain isolated for a later pass.
	if MOUTH_ONLY:return


func _tick_ride(delta:float) -> void:
	var previous := ride_t
	ride_t = minf(1.0, ride_t + delta / RIDE_SECONDS)
	var car := cart_position(ride_t)
	var old := cart_position(previous)
	level.facing = 1.0 if ride_t < FIRST_RUN else -1.0
	level.player.position = car - Vector2(13, 88)
	level.player.velocity = (car - old) / maxf(delta, 0.001)
	var crouch := Input.is_action_pressed("climb_down")
	level.scene1.low_stance.tick(delta, crouch, true)
	# Both cave hazards have a visible lead-in. Staying low is a decision made
	# before the cart reaches them, never a one-frame reflex test.
	for hazard in [0.31, 0.78]:
		if absf(ride_t - hazard) < 0.011 and not crouch: fail()
	if ride_t >= 1.0: _reach_c_zone()

func _reach_c_zone() -> void:
	active = false
	in_c_zone = true
	ride_t = -1.0
	level.log_bridge.active = false
	level.scene1.low_stance.reset()
	level.player.collision_mask = 11
	level.player.position = END_RAIL - Vector2(13, 54)
	level.player.velocity = Vector2.ZERO
	prepare_c_zone_preview()
	level.air_top_y = level.player.position.y
	art.sync(0.0)

func prepare_c_zone_preview()->void:
	if c_zone_prepared:return
	c_zone_prepared=true
	level.checkpoint = 0
	# Entry from the upper forest is a fresh C route, even when a DEBUG
	# forest spawn had pre-cleared C's later traps through checkpoint 6.
	level.marsh_save=0
	# Forest checkpoint 6 stages this box at the completed ledge position.
	# A fresh C route must restore the unsolved box before it becomes visible.
	level.puzzle_box.position=level.PUZZLE_BOX_START
	level.puzzle_box.velocity=Vector2.ZERO
	level._reset_marsh_rocks()
	level.crate.position = level.CRATE_START
	level.crate.velocity = Vector2.ZERO
	level.beached = false
	level.landed = false
	level.floating = false
	level.fan_owned = false
	level.fan_on_tree = true
	level.fan_revealed = true
	level.fan_left_behind = false
	# Warm the retained boat drawings while it is still beyond the exit's
	# view, instead of changing its world position at the coordinate handoff.
	level.art.crate_art.queue_redraw();level.art.raft_front.queue_redraw()

func tick(delta:float) -> bool:
	if not enabled: return false
	clock += delta
	# A fatal ladder landing can be inside our entry rectangle. Its owner
	# must finish the death/respawn timeline before this route may take over;
	# otherwise super._physics_process never advances log_bridge.failure_time.
	if level.log_bridge.failure_time>0:
		active=false
		art.sync(delta)
		return false
	if in_c_zone:
		if mine_trial!=null and mine_trial.gap.art.pair_room.relay.try_return_from_valley():
			return true
		art.sync(delta)
		return false
	if respawn_reveal>0:
		respawn_reveal=maxf(0,respawn_reveal-delta)
		_present(delta)
		return true
	if not active:
		art.sync(delta)
		var p := feet()
		if level.log_bridge.active and not level.rope_ladder.active() and p.x > -3630 and p.x < -3390 and p.y > -3940 and p.y < -3790:
			enter()
		else:
			return false
	if failure_time > 0:
		mine_trial.tick_failure_visual(delta)
		failure_time += delta
		if failure_airborne:
			level.player.velocity.y=minf(1000.0,level.player.velocity.y+1500.0*delta)
			level.player.move_and_slide()
			var screen_y:float=level.player.get_global_transform_with_canvas().origin.y
			if screen_y>level.get_viewport_rect().size.y+110.0 and failure_time>0.3 and failure_close<0:
				failure_close=0.0
		elif failure_close<0:
			var done:bool=mine_trial.escape.crush_animation_complete() if mine_trial.escape.crushed else failure_time>.45
			if done:failure_close=0.0
		if failure_close>=0:
			failure_close+=delta
			if failure_close>=0.50:
				restore_checkpoint()
				respawn_reveal=0.45
		_present(delta)
		return true
	if ride_t < 0 and feet().y < -4010:
		active = false # climbed back above the cliff lip
		art.sync(delta)
		return false
	if ride_t >= 0:
		_tick_ride(delta)
	else:
		# Once on the lower bank, S and a jump may still catch the rope ladder.
		var returning_to_rope:bool=Input.get_axis("move_left","move_right")<=0.0 or Input.is_action_pressed("climb_up")
		if feet().x < -3400 and (level.rope_ladder.active() or returning_to_rope) and level.rope_ladder.tick(delta):
			art.sync(delta)
			return true
		mine_trial.gap.tick_world(delta)
		if in_c_zone:
			level.art.sync(0,level.camera_x,true)
			return false
		var first_control:bool=mine_trial.tick(delta)
		var relay_control:bool=not shaft_preview and not first_control and mine_trial.gap.art.pair_room.relay.tick_control(delta)
		var hoist_control:bool=not shaft_preview and not first_control and not relay_control and mine_trial.gap.art.pair_room.hoist.tick_control(delta)
		var ladder_control:bool=not shaft_preview and not first_control and not relay_control and not hoist_control and mine_trial.gap.art.pair_room.ladders.tick(delta)
		var pair_control:bool=not shaft_preview and not first_control and not relay_control and not hoist_control and not ladder_control and mine_trial.gap.art.pair_room.tick_cart_control(delta)
		if not first_control and not relay_control and not hoist_control and not ladder_control and not pair_control:
			if not shaft_preview or not shaft.tick(delta):_tick_stones(delta)
	_present(delta)
	return true

func _present(delta:float) -> void:
	_sync_death_iris()
	if swing_rope.presenting() and failure_time<=0:
		level._update_camera(delta)
		level.camera.offset=Vector2.ZERO
		swing_rope.present(delta)
		level.art.sync(delta,level.camera_x,true)
		art.sync(delta)
		return
	if not failure_airborne or (not shaft_preview and mine_trial.gap.art.pair_room.relay.wrecked and mine_trial.gap.art.pair_room.relay.crash_camera_owns()):
		if not shaft_preview and mine_trial.gap.art.pair_room.relay.camera_owns():mine_trial.gap.art.pair_room.relay.present_camera(delta)
		else:level._update_camera(delta)
	level.camera.offset = Vector2.ZERO
	var pose := Pose.new()
	var action:StringName = Pose.ACTION_NONE
	var progress := 0.0
	if failure_time > 0:
		action = Pose.ACTION_UNCONTROLLED_FALL if failure_airborne else Pose.ACTION_FALL_IMPACT
		progress = clampf(failure_time / 0.5, 0, 1)
	elif doomed_branch!=null and doomed_branch.broken:
		action=Pose.ACTION_UNCONTROLLED_FALL
	elif level.climb_time>=0.0:
		action=Pose.ACTION_CLIMB
		progress=clampf(level.climb_time/level.climb_total,0.0,1.0)
	elif level.scene1.low_stance.active():
		var low:Dictionary = level.scene1.low_stance.pose_info()
		action = low.action
		progress = low.progress
	pose.apply({"feet":level._climb_root() if level.climb_time>=0 else feet(), "velocity":level.player.velocity, "grounded":not failure_airborne and level.climb_time<0 and (level.player.is_on_floor() or ride_t >= 0),
		"facing":level.facing, "action":action, "action_progress":progress,
		"jump_windup":(1.0-level.jump_windup_left/Pose.HOOD_JUMP_WINDUP) if level.jump_windup_left>0 else -1.0,
		"grab_frame": (level.climb_bridge_start+mini(int((1.0-level.climb_bridge_left/level.climb_bridge_total)*float(int(level.HoodManifest.CLIPS["grab_bridge"]["bridge_frames"]))),int(level.HoodManifest.CLIPS["grab_bridge"]["bridge_frames"])-1)) if level.climb_time>=0 and level.climb_bridge_left>0 and level.climb_bridge_total>0 else -1,
		"visual_scale":Pose.HOOD_VISUAL_SCALE, "fog_blur":level.ACTOR_EDGE_SOFTNESS})
	if failure_time<=0:
		mine_trial.apply_pose(pose)
		if shaft_preview:shaft.apply_pose(pose)
		else:
			mine_trial.gap.art.pair_room.ladders.apply_pose(pose)
			mine_trial.gap.art.pair_room.apply_cart_pose(pose)
			mine_trial.gap.art.pair_room.hoist.apply_pose(pose)
			mine_trial.gap.art.pair_room.stairs.apply_pose(pose)
			mine_trial.gap.art.pair_room.relay.apply_pose(pose)
	if failure_time>0 and mine_trial.escape.crushed:mine_trial.escape.apply_escape_pose(pose)
	level.actor.sync_pose(delta, pose)
	if mine_trial.shake>0:
		level.camera.offset=Vector2(sin(clock*75),cos(clock*93))*mine_trial.shake*7
	if not shaft_preview and (failure_time<=0 or (mine_trial.gap.art.pair_room.relay.wrecked and failure_time<.35)):level.camera.offset+=mine_trial.gap.art.pair_room.relay.contact_camera_offset()
	level.actor.modulate.a = 1.0
	level.actor.rotation = mine_trial.escape.visual_motion().x+mine_trial.escape.passenger_lean() if pose.action==&"mine_cart_ride" else 0.0
	if ride_t < 0 and level.climb_time<0 and not mine_trial.gap.art.pair_room.ladders.active() and not mine_trial.gap.art.pair_room.stairs.active:
		var contact_delta:float=mine_trial.gap.art.pair_room.ladders.contact_delta(delta)
		if mine_trial.gap.art.pair_room.on_stair(feet()):contact_delta*=.35
		level.actor.apply_surface_contact(contact_delta, level.player, pose.grounded)
	mine_trial.gap.art.pair_room.ladders.post_present()
	mine_trial.escape.fit_recovery_hands()
	mine_trial.gap.art.pair_room.fit_cart_hands()
	mine_trial.gap.art.pair_room.hoist.post_present(delta)
	mine_trial.gap.art.pair_room.stairs.post_present(delta)
	mine_trial.gap.art.pair_room.relay.post_present()
	# Read the final hand transform after the actor is fitted to the ground.
	mine_trial.sync_visual(delta)
	level.art.sync(delta, level.camera_x, true)
	# The established landmark and its supporting ridge remain in their world
	# coordinates. The near mountain occludes them naturally on entry.
	if level.art.landmark_layer != null and ride_t >= 0:
		level.art.landmark_layer.visible = false
	art.sync(delta)

func _sync_death_iris()->void:
	if level.iris==null:
		level.iris=preload("res://scripts/shared/screen_iris.gd").new()
		level.add_child(level.iris)
	var amount:=smoothstep(0.0,0.50,failure_close) if failure_close>=0 else 0.0
	var center:=failure_center
	if respawn_reveal>0:
		amount=smoothstep(0.0,0.45,respawn_reveal)
		center=feet()-Vector2(level.camera_x,level.camera_y)-Vector2(0,27)
	# Stored death centres use the controller's nominal camera window. Map
	# that world point through the optical pullback before closing the iris.
	center=(level.get_canvas_transform()*(Vector2(level.camera_x,level.camera_y)+center))/level.get_viewport_rect().size*Vector2(1280,720)
	level.iris.set_state(amount,center)

func _reach_c_zone_at(at:Vector2)->void:
	_reach_c_zone()
	level.player.position=at-Vector2(13,54)
	level.player.velocity=Vector2(80,0)
	level.air_top_y=level.player.position.y
	shaft.visible=false

func set_shaft_preview(value:bool)->void:
	shaft_preview=value
	if shaft!=null:shaft.set_enabled(enabled and value)
