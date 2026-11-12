extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
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
func release():
	for key in ["move_right","move_left","jump","interact"]:Input.action_release(key)
func fresh(offset:=2740.0):
	release()
	level.debug_enter_scene1()
	put(offset)
	for i in 100:
		await physics_frame
		if level.curtain_phase==0 and level.player.is_on_floor():break
func _run():
	level=SCENE.instantiate();root.add_child(level)
	await frames(8)
	spider=level.scene1.spider
	level.scene1.predator.enabled=false
	if level.scene1.hunter!=null:level.scene1.hunter.enabled=false
	await fresh()
	await frames(90)
	check(spider.state==spider.State.DORMANT and not level.art.spider_art.visible,"spider stays concealed before the pond midpoint")
	Input.action_press("move_right")
	for i in 200:
		await physics_frame
		if spider.state==spider.State.DESCEND:break
	Input.action_release("move_right")
	check(spider.state==spider.State.DESCEND and spider.silk_visible() and level.art.spider_art.visible,"crossing the pond midpoint starts a silk suspension descent")
	var silk_leg:int=level.art.spider_art.view.legs[0].hip
	var initial_leg:Quaternion=level.art.spider_art.view.skeleton.get_bone_pose_rotation(silk_leg)
	var start_y:float=spider.position.y
	await frames(55)
	check(initial_leg.angle_to(level.art.spider_art.view.skeleton.get_bone_pose_rotation(silk_leg))>0.05,"hanging spider actively flexes its legs instead of holding a frozen pose")
	check(level.art.spider_art.silk.points[-1].distance_to(level.art.spider_art.rig.position+level.art.spider_art.view.attachment.rotated(level.art.spider_art.rig.rotation))<0.01,"silk remains attached to the moving abdomen")
	check(spider.position.y>start_y+100 and spider.state==spider.State.DESCEND and level.marsh_hit_time==0,"descent is visible and gives the player warning before chasing")
	for i in 250:
		await physics_frame
		if spider.state==spider.State.CAUGHT:break
	check(spider.caught_count==1 and level.marsh_hit_kind=="fall" and level.marsh_hit_time>0,"waiting is caught by the walking spider and triggers fallen death")
	var before_stabs:int=spider.stab_count
	await frames(40)
	check(spider.time>0.60 and not spider.stabbed and spider.blood.is_empty(),"fallen player precedes the raised-leg windup and blood")
	await frames(12)
	check(spider.stabbed and spider.stab_count==before_stabs+1 and spider.blood.size()>=32,"a single hard impale triggers its blood burst at contact")
	check(Vector2(level.actor.sprite.material.get_shader_parameter("impact_push")).length()>0.001,"impale applies local torso pressure without scaling the whole player")
	check(level.art.spider_art.view.execution_error<3.0,"the attacking needle leg lands on the actual fallen-body target")
	await frames(12)
	check(spider.blood.size()>10 and spider.blood[0].p.distance_to(spider.execution_target)>15,"blood sprays ballistically from the wound rather than remaining a decal")
	await frames(25)
	check(spider.state==spider.State.CAUGHT and level.actor.modulate.a>0.99,"the complete fallen body remains visible after withdrawal instead of fading away")
	for i in 300:
		await physics_frame
		if level.marsh_hit_time<=0 and level.curtain_phase==0 and spider.state==spider.State.DORMANT:break
	check(absf(level.player.position.x+13-spider.x_at(spider.RETRY_OFFSET))<4 and not level.scene1.locks_move(),"death retries just before the ambush with normal controls")
	check(not spider.cleared and spider.retry_armed and spider.blood.is_empty(),"retry clears the execution effects and rearms the failed chase")
	await fresh()
	Input.action_press("move_right")
	var bramble_jump:=false
	var low_passage_seen:=false
	var jump_age:=-1
	var saw_walk:=false
	var faced_player:=true
	var used_run:=true
	var planted_contacts:=0
	var water_contacts:=0
	var worst_contact:=0.0
	var peak_cpu:=0
	var walk_frames:Dictionary={}
	var died:=false
	for i in 2500:
		await physics_frame
		var front:float=level.player.position.x+26
		if not bramble_jump and front>S.START_X+S.BRAMBLE_OFFSET-26:
			bramble_jump=true;Input.action_press("jump");jump_age=0
		if not low_passage_seen and front>S.START_X+4009-40:
			low_passage_seen=level.scene1.low_stance.active()
		if jump_age>=0:
			jump_age+=1
			if jump_age>=30:Input.action_release("jump");jump_age=-1
		if spider.state==spider.State.CHASE:
			saw_walk=true
			peak_cpu=maxi(peak_cpu,level.art.spider_art.view.last_cpu_usec)
			used_run=used_run and level.art.spider_art.current_clip=="run"
			for contact:Dictionary in level.art.spider_art.view.foot_contacts:
				if contact.planted and contact.lift<0.001:
					planted_contacts+=1
					worst_contact=maxf(worst_contact,float(contact.error))
					if contact.p.x>S.START_X+2680 and contact.p.x<S.START_X+3020:water_contacts+=1
			faced_player=faced_player and level.art.spider_art.sprite.scale.x<0
			walk_frames[level.art.spider_art.current_frame]=true
		if level.marsh_hit_time>0:
			print("CHASE FAILURE player=",level.player.position+Vector2(13,54)," spider=",spider.position," low=",level.scene1.low_stance.mode," intro=",level.scene1.intro_time)
			died=true;break
		if spider.cleared:break
	release()
	check(saw_walk and used_run and faced_player and walk_frames.size()>20,"pursuit cycles through the fast authored Run while facing the player")
	check(not died and spider.cleared and level.player.position.x+13>=spider.x_at(spider.ESCAPE_OFFSET),"running, jumping the bramble and bending through the rock tunnel escapes the chase")
	print("FOOT CONTACTS ",planted_contacts," water=",water_contacts," worst pixel error=",worst_contact," peak pose CPU us=",peak_cpu)
	check(planted_contacts>100 and water_contacts>10 and worst_contact<5.0,"stance feet stay planted in the pond and on sloping ground")
	check(bramble_jump and low_passage_seen and level.scene1.trip_count==0,"the bramble and low passage remain meaningful during the chase")
	check(spider.position.x<=spider.x_at(spider.STOP_OFFSET)+1,"long legs stop on the near side of the rock tunnel rather than crossing it")
	level.scene1.cut=S.Cut.DONE
	var stop_x:float=spider.position.x
	await frames(75)
	check(spider.state==spider.State.STOP and spider.rage()>0.5,"at the entrance the spider remains agitated and strikes before withdrawing")
	await frames(85)
	check(spider.state==spider.State.RETREAT and spider.position.x<stop_x and spider.facing>0 and level.art.spider_art.sprite.scale.x<0,"after the tunnel the spider backs away while still facing the player")
	# Returning during withdrawal is safe, rather than starting another kill.
	level.player.position=spider.position-Vector2(13,54)
	level.player.velocity=Vector2.ZERO
	await frames(4)
	check(level.marsh_hit_time==0 and spider.cleared,"the retreat no longer catches a returning player")
	for i in 1000:
		await physics_frame
		if spider.state==spider.State.GONE:break
	check(spider.state==spider.State.GONE and not level.art.spider_art.visible,"withdrawal reaches its original silk and climbs out of the scene")
	level.restore_checkpoint();await frames(8)
	check(spider.cleared and spider.state==spider.State.GONE,"ordinary retry preserves the completed spider encounter")
	level.debug_enter_scene1();await frames(4)
	check(not spider.cleared and not spider.retry_armed and spider.state==spider.State.DORMANT,"full chapter restart resets the spider ambush")
	print("forest spider smoke OK" if failures==0 else "forest spider smoke: %d FAILED"%failures)
	quit(0 if failures==0 else 1)
