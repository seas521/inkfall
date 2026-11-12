extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const L=preload("res://scripts/chapters/rock_crevice_layout.gd")
var level
var spider
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
	level.scene1.cut=S.Cut.NONE
	level.scene1.intro_time=99
func arm():
	spider.position=Vector2(level.player.position.x+13-165,S.ground_top(level.player.position.x+13-165))
	spider.state=spider.State.CHASE
	spider.time=0
	spider.motion_clock=0.3
func _run():
	level=SCENE.instantiate();root.add_child(level)
	await frames(8)
	level.debug_enter_scene1()
	level.scene1.predator.enabled=false
	spider=level.scene1.spider
	put(3650);await frames(15)
	Input.action_press("jump");await frames(14);Input.action_release("jump")
	check(not level.player.is_on_floor(),"a real jump creates the airborne interception case")
	arm();await frames(2)
	check(spider.state==spider.State.CAUGHT and spider.execution_airborne,"airborne interception selects the supported aerial execution")
	var before_y:float=level.player.position.y
	await frames(16)
	check(spider.victim_hooked and not spider.victim_grounded and level.player.collision_mask==0,"a primary needle leg hooks and carries the body")
	check(level.art.spider_art.view.carrier_error<4,"carrying leg remains connected to the moving suspended torso")
	await frames(17)
	var air_gap:float=S.ground_top(level.player.position.x+13)-(level.player.position.y+54)
	print("AIR HOLD gap=",air_gap," y=",level.player.position.y," before=",before_y," t=",spider.time)
	check(air_gap>65,"the body is visibly raised off the ground on the spear")
	await frames(29)
	print("AIR IMPACT time=",spider.time," stabbed=",spider.stabbed," error=",level.art.spider_art.view.execution_error)
	check(spider.stabbed and spider.blood.size()>25 and level.art.spider_art.view.execution_error<4,"the second leg impales the raised body and sprays blood in the air")
	var recoil_peak:=0.0
	for i in 12:
		recoil_peak=maxf(recoil_peak,spider.reaction_shift().length())
		await physics_frame
	check(recoil_peak>1 or spider.time>spider.impact_time()+0.15,"the air victim receives a timed impact recoil")
	check(level.actor.modulate.a>0.99,"the suspended body stays complete and does not fade individually")
	await frames(180)
	check(level.player.collision_mask==11 and spider.state==spider.State.DORMANT,"aerial execution restores collision and retry state")
	level.debug_enter_scene1();put(3650);await frames(12)
	arm();await frames(2)
	check(spider.victim_grounded and not spider.execution_airborne,"grounded victims keep the grounded execution")
	var largest:=0.0
	for i in 65:
		await physics_frame
		largest=maxf(largest,spider.reaction_shift().length())
	check(largest>4.5,"ground impale creates a clearly visible body kick")
	await frames(180)
	level.debug_enter_scene1();put(4045);await frames(55)
	spider.state=spider.State.CHASE
	spider.position=Vector2(L.BODY_STOP,S.ground_top(L.BODY_STOP))
	check(not spider._can_attack(level.player.position+Vector2(13,54)),"the actual rock roof blocks a reaching leg from hitting a player inside")
	spider.position=Vector2(L.BODY_STOP,S.ground_top(L.BODY_STOP))
	check(spider._can_attack(Vector2(L.BODY_STOP+210,S.ground_top(L.BODY_STOP+210))),"the outside approach remains dangerous within actual leg reach")
	print("spider execution smoke OK" if failures==0 else "spider execution smoke: %d FAILED"%failures)
	quit(0 if failures==0 else 1)
