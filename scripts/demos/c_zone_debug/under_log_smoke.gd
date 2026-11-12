extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const L=preload("res://scripts/chapters/rock_crevice_layout.gd")
var level
var failures:=0
func _initialize():call_deferred("run")
func frames(n:int):
	for i in n:await physics_frame
func check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func put(x:float):
	level.player.position=Vector2(x-13,S.ground_top(x)-54)
	level.player.velocity=Vector2.ZERO
	level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
func arm(x:float):
	var sp=level.scene1.spider
	sp.enabled=true;sp.log_hunt=true;sp.heard_x=x;sp.quiet_time=0;sp.noise_time=0
	sp.position=Vector2(x,sp.log_surface(x));sp.last_motion_x=x
	sp._begin(sp.State.SEARCH)
func run():
	level=SCENE.instantiate();root.add_child(level);await frames(8)
	level.debug_enter_scene1();level.scene1.predator.enabled=false
	var sp=level.scene1.spider;sp.enabled=false
	put(L.LEFT-100);await frames(12)
	Input.action_press("move_right");await frames(75);Input.action_release("move_right")
	check(not level.scene1.low_stance.active() and level.player.position.x+13<L.LEFT+10,"walking to timber does not automatically bend")
	Input.action_press("climb_down");await frames(65)
	Input.action_press("move_right")
	for i in 300:
		await physics_frame
		if level.player.position.x+13>L.LEFT+100:break
	Input.action_release("move_right");Input.action_release("climb_down")
	await frames(30)
	check(level.scene1.low_stance.active() and level.player.position.x+13>L.LEFT+80,"S initiates entry and releasing S preserves the sheltered pose")
	Input.action_press("move_left")
	for i in 350:
		await physics_frame
		if level.player.position.x+13<L.DUCK_LEFT-45 and not level.scene1.low_stance.active():break
	Input.action_release("move_left")
	check(level.player.position.x+13<L.DUCK_LEFT-30 and not level.scene1.low_stance.active(),"backing out through the entrance restores standing")
	check(is_equal_approx(level.pose.visual_scale,.9),"global player scale remains 0.90")
	for entry_x in [L.LEFT,L.LEFT+110,L.LEFT+230]:
		var gap:float=S.ground_top(entry_x)-L.ceiling(entry_x,Callable())
		check(gap>42 and gap<53,"real shelter clearance fits low stance and blocks standing at %.0f"%entry_x)
	var root_left:=L.image_point(Vector2(430,798))
	var root_right:=L.image_point(Vector2(1698,879))
	check(root_left.y>=S.ground_top(root_left.x)-2 and root_left.y<S.ground_top(root_left.x)+15,"the left supporting branch is embedded in the actual collidable bank")
	check(root_right.y>=S.ground_top(root_right.x)-2 and root_right.y<S.ground_top(root_right.x)+15,"the heavy right end physically meets its raised terrain bank")
	check(S.ground_top(L.ART_LEFT+1060*L.ART_SCALE)>S.ground_top(root_left.x)+40,"the terrain forms the reference shallow hollow beneath the tree")
	put(L.LEFT-85);level.scene1.low_stance.reset();await frames(10)
	Input.action_press("jump");Input.action_press("move_right")
	var bypass:=false
	for i in 95:
		await physics_frame
		var x:float=level.player.position.x+13
		bypass=bypass or level.climb_time>=0 or (x>L.LEFT and level.player.position.y+54<L.roof_top(x,Callable())+8)
	Input.action_release("jump");Input.action_release("move_right")
	check(not bypass,"jump and ledge grab cannot bypass the tree roof")
	# Repeated jump presses against the jagged left break used to let the generic
	# climb detector grab the timber and place the actor in mid-air above it.
	put(L.LEFT-92);level.scene1.low_stance.reset();await frames(10)
	var grabbed_timber:=false
	var floated_over_timber:=false
	for attempt in 4:
		Input.action_press("move_right");Input.action_press("jump")
		await frames(3);Input.action_release("jump")
		for i in 55:
			await physics_frame
			grabbed_timber=grabbed_timber or level.climb_time>=0
			var feet:Vector2=level.player.position+Vector2(13,54)
			floated_over_timber=floated_over_timber or (feet.x>L.LEFT-40 and feet.y<L.roof_top(feet.x,Callable())-6)
		Input.action_release("move_right");await frames(8)
	check(not grabbed_timber and not floated_over_timber,"fallen timber cannot be climbed or leave the actor floating above it")
	# Bending at the mouth is not protection: the whole body must be under the
	# substantial trunk before the spider loses a direct attack line.
	put(L.LEFT+48);await frames(5)
	sp.log_hunt=true
	sp.position=Vector2(L.LEFT-85,sp.log_surface(L.LEFT-85))
	var exposed_feet:Vector2=level.player.position+Vector2(13,54)
	check(not sp._sheltered(exposed_feet) and sp._can_attack(exposed_feet),"player standing in front of the timber remains attackable")
	put(L.LEFT-25);level.scene1.low_stance.reset();await frames(8)
	Input.action_press("climb_down");await frames(55)
	Input.action_press("move_right")
	for i in 100:
		await physics_frame
		if level.player.position.x+13>L.LEFT+42:break
	Input.action_release("move_right");Input.action_release("climb_down");await frames(3)
	check(sp._sheltered(level.player.position+Vector2(13,54)),"the same position becomes protected after the player deliberately bends beneath the timber")
	level.scene1.low_stance.reset()
	sp.reset(true)
	put(L.LEFT-70);level.scene1.low_stance.reset();await frames(10)
	Input.action_press("climb_down");await frames(65)
	put(L.LEFT+100);await frames(10);Input.action_release("climb_down");arm(L.LEFT+100)
	await frames(65)
	check(sp.state==sp.State.SEARCH and not sp.cleared,"a short stop does not instantly remove the threat")
	Input.action_press("move_right");await frames(130);Input.action_release("move_right")
	check(sp.state==sp.State.FRENZY and sp.log_strike_count>0,"sustained movement draws the spider and only a contacting leg triggers the timber strike")
	check(not sp._can_attack(level.player.position+Vector2(13,54)) and level.marsh_hit_time<=0,"solid wood protects the actual sheltered player")
	await frames(100)
	Input.action_press("move_left");await frames(12);Input.action_release("move_left")
	check(sp.quiet_time<.3,"new movement resets the quiet countdown")
	await frames(225)
	check(sp.state==sp.State.RETREAT and not sp.cleared,"3.5 seconds of stillness begins a real retreat")
	Input.action_press("move_right");await frames(12);Input.action_release("move_right")
	check(sp.state in [sp.State.SEARCH,sp.State.FRENZY],"nearby retreat can be interrupted by renewed movement")
	await frames(700)
	check(sp.cleared and sp.state in [sp.State.RETREAT,sp.State.ASCEND,sp.State.GONE],"quiet withdrawal leaves the player safe only after the spider moves away")
	# Fairness at the mouth: if the player reacts immediately with S + right,
	# the faster bend and the spider's visible approach window reach protection
	# before a stab can land.
	sp.reset(true);put(L.DUCK_LEFT+2);level.scene1.low_stance.reset();await frames(5)
	sp.state=sp.State.CHASE;sp.position=Vector2(L.BODY_STOP,S.ground_top(L.BODY_STOP))
	sp.last_motion_x=level.player.position.x+13
	Input.action_press("climb_down");Input.action_press("move_right")
	var entered_in_time:=false
	for i in 120:
		await physics_frame
		entered_in_time=sp._sheltered(level.player.position+Vector2(13,54))
		if entered_in_time or sp.state==sp.State.CAUGHT:break
	Input.action_release("move_right");Input.action_release("climb_down")
	check(entered_in_time and sp.state!=sp.State.CAUGHT,"immediate S plus right reaches timber protection before the spider can stab")
	level.marsh_hit_time=0;level.marsh_hit_kind="";sp.reset(true);level.scene1.low_stance.reset()
	# Reaching the mouth while still exposed changes from the bounded body chase
	# to the long-leg log hunt. The spider advances instead of freezing at its
	# old body stop outside ordinary catch range.
	sp.reset(true);put(L.DUCK_LEFT+5);level.scene1.low_stance.reset();await frames(5)
	sp.state=sp.State.CHASE;sp.position=Vector2(L.BODY_STOP,S.ground_top(L.BODY_STOP))
	sp.last_motion_x=level.player.position.x+13
	var old_spider_x:float=sp.position.x
	await frames(3)
	check(sp.log_hunt and sp.state in [sp.State.SEARCH,sp.State.FRENZY] and sp.position.x>old_spider_x,"spider advances into long-leg hunt when an exposed player reaches the timber mouth")
	await frames(180)
	check(sp.state==sp.State.CAUGHT,"standing exposed at the timber mouth is caught instead of creating a dead zone")
	level.marsh_hit_time=0;level.marsh_hit_kind="";sp.reset(true)
	sp.reset(true);put(L.EXIT_MOUTH+65);await frames(5)
	sp.log_hunt=true;sp.state=sp.State.SEARCH
	sp.position=Vector2(L.EXIT_MOUTH+95,S.ground_top(L.EXIT_MOUTH+95));sp.heard_x=L.EXIT_MOUTH+65;sp.last_motion_x=L.EXIT_MOUTH+65
	await frames(5)
	check(sp.state==sp.State.CAUGHT,"leaving cover before withdrawal remains lethal within real reach")
	print("UNDER LOG OK" if failures==0 else "UNDER LOG FAILED %d"%failures)
	quit(0 if failures==0 else 1)
