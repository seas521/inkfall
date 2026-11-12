extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const L=preload("res://scripts/chapters/rock_crevice_layout.gd")
var level
var failures:=0
func _initialize():call_deferred("_run")
func frames(n:int):
	for i in n:await physics_frame
func check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func put(offset:float):
	var x:=S.START_X+offset
	level.player.position=Vector2(x-13,S.ground_top(x)-56)
	level.player.velocity=Vector2.ZERO
	level.scene1.intro_time=99
	level.scene1.cut=S.Cut.NONE
func _run():
	level=SCENE.instantiate();root.add_child(level)
	await frames(10)
	level.debug_enter_scene1()
	level.scene1.predator.enabled=false
	level.scene1.spider.enabled=false
	put(3780)
	await frames(10)
	check(not S.FEATURES.any(func(f):return f.t=="boulder"),"the short rock tunnel replaces the boulder rather than adding a second obstacle")
	Input.action_press("move_right")
	var seen:Dictionary={}
	var low_size:=true
	var common_size:=true
	var caught:=false
	for i in 2100:
		await physics_frame
		seen[level.actor.current_clip]=true
		if level.scene1.low_stance.active():low_size=low_size and is_equal_approx((level.player.get_child(0).shape as CapsuleShape2D).height,40)
		common_size=common_size and is_equal_approx(level.pose.visual_scale,0.90)
		caught=caught or level.marsh_hit_time>0
		if level.player.position.x+13>L.DUCK_RIGHT+32 and not level.scene1.low_stance.active():break
	Input.action_release("move_right")
	await frames(5)
	check(seen.has(&"low_enter") and seen.has(&"low_walk") and seen.has(&"low_exit"),"normal movement bends, steps through, and stands up using the new source clips")
	check(level.player.position.x+13>L.DUCK_RIGHT+32 and not caught,"the entire tunnel is traversable without death or a hidden ledge rescue")
	check(low_size and common_size,"only the collision capsule lowers; the common actor scale stays unchanged")
	check(is_equal_approx((level.player.get_child(0).shape as CapsuleShape2D).height,54),"standing restores the normal capsule at the exit")
	level.scene1.low_stance.reset()
	put(3930)
	await frames(60)
	check(level.scene1.low_stance.mode==level.scene1.low_stance.Mode.LOW and level.actor.current_clip==&"low_idle","stopping inside uses an independent low idle")
	var y:float=level.player.position.y
	Input.action_press("jump");await frames(15);Input.action_release("jump")
	check(absf(level.player.position.y-y)<3 and level.climb_time<0,"a low ceiling prevents jumps and accidental ledge grabs")
	Input.action_press("move_left")
	for i in 1400:
		await physics_frame
		if level.player.position.x+13<L.DUCK_LEFT-35 and not level.scene1.low_stance.active():break
	Input.action_release("move_left")
	check(level.player.position.x+13<L.DUCK_LEFT-30 and not level.scene1.low_stance.active(),"the tunnel can be traversed backward and exited at the original side")
	check(L.height_at(L.MIDDLE)<L.height_at(L.LEFT) and L.height_at(L.MIDDLE)<79,"the middle is tighter than the entrance and below the standing visual height")
	check(L.occluded(L.EXIT_MOUTH-65),"the near rock cheek is foreground occlusion while the tested route remains traversable")
	var cave_fx=level.art.crevice_art
	var landed_before:int=cave_fx.chips_landed
	put(3930)
	await frames(210)
	check(cave_fx.chips_landed>landed_before and cave_fx.dust_bursts>0,"small ceiling fragments fall to the actual ground and emit dust")
	check(level.marsh_hit_time<=0,"small falling fragments remain atmospheric and do not harm the player")
	check(level.actor.eye_light.visible,"the low clips use the same single tracked eye as normal locomotion")
	print("rock crevice smoke OK" if failures==0 else "rock crevice smoke: %d FAILED"%failures)
	quit(0 if failures==0 else 1)
