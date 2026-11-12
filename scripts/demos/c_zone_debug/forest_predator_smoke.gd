extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
var p
var failures:=0
func _initialize():call_deferred("_run")
func frames(n:int):
	for i in n:await physics_frame
func check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func put(offset:float):
	var x:float=S.START_X+offset
	level.player.position=Vector2(x-13,S.ground_top(x)-56)
	level.player.velocity=Vector2.ZERO
	level.scene1.intro_time=99
	level.scene1.cut=S.Cut.NONE
func fresh(offset:=2290.0):
	Input.action_release("move_right");Input.action_release("move_left");Input.action_release("jump");Input.action_release("interact")
	level.debug_enter_scene1()
	put(offset)
	await frames(8)
	for i in 90:
		if level.curtain_phase==0:break
		await physics_frame
func tap():
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)
func take():
	await tap()
	await frames(58)
func _run():
	level=SCENE.instantiate();root.add_child(level)
	await frames(8)
	level.scene1.spider.enabled=false # independent encounter has forest_spider_smoke.gd
	p=level.scene1.predator
	if level.scene1.hunter!=null:level.scene1.hunter.enabled=false
	await fresh(1700)
	check(not p.near(),"ambient breathing is tested before entering the encounter radius")
	var ambient_frames:Dictionary={}
	for i in 260:
		await physics_frame
		ambient_frames[int(p.Motion.idle_closure(p.animation_time())*100)]=true
	check(p.flower==p.Flower.ALERT and ambient_frames.size()>=90,"distant plant keeps breathing through a visible full opening/closing cycle")
	var before_time:float=p.animation_time()
	put(2290)
	await frames(1)
	check(p.animation_time()>=before_time and p.animation_time()-before_time<0.05,"approaching the plant does not restart or jump its idle phase")
	await fresh()
	check(absf(p.mouth().y-(S.ground_top(p.Layout.RETRY_X)-34))<55,"the horizontal filmed mouth stays within actor body height")
	check(level.art.predator_art.clip_sprite.material==level.art.predator_art.idle_material and level.art.predator_art.clip_sprite.texture==level.art.predator_art.clip_frames[0],"idle holds the rest silhouette and moves only the masked lower jaw around its hinge")
	check(is_zero_approx(level.art.predator_art.plant.rotation),"video playback does not rotate the whole plant into a bow")
	check(absf(p.base().y-S.GROUND_Y)<4,"the full plant is rooted at the original forest floor")
	check(S.GROUND_Y-S.ground_top(p.Layout.TREE_X)>85,"the player and tree stand on a raised bank")
	check(p.Layout.TREE_X-p.Layout.RISE_TOP>=65,"the hill crown extends behind the tree root fan")
	var old_x:=S.START_X+1740.0
	var old_ray:=PhysicsRayQueryParameters2D.create(Vector2(old_x,S.ground_top(old_x)-20),Vector2(old_x,S.ground_top(old_x)+20),1)
	check(not level.get_world_2d().direct_space_state.intersect_ray(old_ray).is_empty(),"old hollow before the spike pit is restored to normal forest ground")
	var root_ray:=PhysicsRayQueryParameters2D.create(p.base()-Vector2(0,10),p.base()+Vector2(0,15),1)
	var root_hit:Dictionary=level.get_world_2d().direct_space_state.intersect_ray(root_ray)
	check(not root_hit.is_empty() and absf(Vector2(root_hit.position).y-p.base().y)<6,"plant roots sit on continuous normal ground")
	check(p.can_take(),"hanging carcass is reachable from the safe side")
	await take()
	check(p.bait==p.Bait.HELD and not p.rope_attached,"F detaches the carcass and finishes a real pickup clip")
	check(level.actor.current_clip in [&"small_hold",&"small_pickup"],"carrying uses the existing actor clips")
	Input.action_press("move_left");await frames(12);Input.action_release("move_left")
	check(level.facing<0 and level.pose.facing<0 and level.actor.body.scale.x>0,"carrying left turns both the actor pose and rendered body")
	Input.action_press("move_right");await frames(12);Input.action_release("move_right")
	check(level.facing>0 and level.actor.body.scale.x<0,"carrying right turns forward again")
	level.facing=1
	await tap()
	var flew:bool=p.bait==p.Bait.FLYING
	for i in 120:
		await physics_frame
		flew=flew or p.bait==p.Bait.FLYING
		if p.flower==p.Flower.EATING:break
	check(flew and p.flower==p.Flower.EATING and p.feed_count==1,"second F throws a ballistic carcass into the mouth and starts eating")
	check(level.art.predator_art.current_frame>=50 and level.art.predator_art.current_frame<=88,"swallowing uses the recorded closed-mouth and digestion frames")
	check(p.bite_count==0,"feeding targets the bait without swallowing the safe player")
	Input.action_press("move_right")
	var grabbed:=false
	for i in 240:
		await physics_frame
		grabbed=grabbed or level.climb_time>=0
		if level.player.position.x+13>p.EXIT_RETRY_X:break
	Input.action_release("move_right")
	await frames(20)
	check(p.solved and not p.captured() and level.player.position.x+13>p.Layout.PLANT_X+150,"running down the bank clears the eating flower")
	check(not grabbed and is_equal_approx(level.pose.visual_scale,0.90),"the natural descent needs no ledge rescue or enlarged actor")
	await frames(300)
	check(p.flower==p.Flower.ALERT,"digestion ends and the completed plant becomes hungry again")
	var before_bites:int=p.bite_count
	put(2590);await frames(40)
	check(p.captured() and p.bite_count==before_bites+1,"returning from the right after digestion is swallowed")
	await frames(130)
	check(p.solved and p.flower==p.Flower.ALERT and level.player.position.x+13>p.Layout.PLANT_X+150,"retry preserves progress and spawns safely beyond the plant")
	await fresh()
	await take()
	level.facing=-1;await tap()
	await frames(130)
	check(p.bait==p.Bait.GROUND and p.feed_count==1,"a backwards throw lands on actual terrain rather than feeding remotely")
	level.player.position=Vector2(p.bait_position.x-13,p.bait_position.y+15-56)
	level.player.velocity=Vector2.ZERO
	await frames(8)
	check(p.can_take(),"a missed throw on the safe forest bank can be picked up again")
	await take()
	check(p.bait==p.Bait.HELD,"dropped carcass can be recovered with F")
	await fresh()
	await take();level.facing=1;await tap()
	for i in 600:
		await physics_frame
		if p.flower==p.Flower.ALERT and p.bait==p.Bait.GONE:break
	check(not p.solved and p.flower==p.Flower.ALERT and p.bait==p.Bait.GONE,"missing the feeding window restores the plant danger")
	level.restore_checkpoint();await frames(8)
	check(p.bait==p.Bait.HANGING and not level.scene1.locks_move(),"retry after a missed window restores a usable bait and controls")
	await fresh(2300)
	Input.action_press("move_right")
	var caught:=false
	for i in 130:
		await physics_frame
		if p.captured():caught=true;break
	Input.action_release("move_right")
	check(caught,"approaching an unfed plant triggers its bite")
	await frames(130)
	check(not p.captured() and p.bait==p.Bait.HANGING and absf(level.player.position.x+13-p.Layout.RETRY_X)<4,"swallowing restores nearby with the carcass and controls reset")
	check(level.actor.modulate.a>0.99 and is_equal_approx(level.pose.visual_scale,0.90),"death restores visibility and the global actor scale")
	await fresh(2330)
	Input.action_press("move_left")
	await frames(35)
	Input.action_release("move_left")
	check(not p.captured(),"retreat during the telegraph escapes the bite")
	await fresh(2305)
	Input.action_press("jump");Input.action_press("move_right")
	caught=false
	for i in 100:
		await physics_frame
		if p.captured():caught=true;break
	Input.action_release("jump");Input.action_release("move_right")
	check(caught,"jumping directly through the plant is not a bypass")
	level.debug_enter_scene1();await frames(3)
	check(not p.solved and not p.retry_armed and p.bait==p.Bait.HANGING,"full chapter restart clears encounter checkpoint and completion")
	print("forest predator smoke OK" if failures==0 else "forest predator smoke: %d FAILED"%failures)
	quit(0 if failures==0 else 1)
