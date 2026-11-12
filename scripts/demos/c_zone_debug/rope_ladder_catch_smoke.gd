extends SceneTree

const SCENE=preload("res://scenes/debug/c_zone_river.tscn")
var failures:=0
func _initialize():call_deferred("_run")
func _check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func _run():
	var level=SCENE.instantiate()
	root.add_child(level)
	await physics_frame
	level.set_physics_process(false)
	level.debug_enter_log_bridge()
	var ladder=level.rope_ladder
	for offset in [0.0,22.0,40.0,68.0,84.0]:
		level.player.position=Vector2(ladder.anchor().x+offset-13,level.log_bridge.LEFT.position.y-54)
		ladder.swing=0
		ladder.swing_speed=0
		ladder.catch_from_bank()
		var bank_feet:Vector2=ladder.feet()
		var ground_error:=0.0
		var hand_error:=0.0
		var reversals:=0
		var last_dy:=0.0
		var previous:=Vector2.ZERO
		var x_error:=0.0
		var start_head:Vector2=bank_feet-ladder._track(ladder.CATCH_LAUNCH,"feet")+ladder._catch_head(ladder.CATCH_LAUNCH)
		var end_head:Vector2=ladder._catch_hand()-ladder._track(ladder.CATCH_CONTACT,"hand")+ladder._catch_head(ladder.CATCH_CONTACT)
		for step in 311:
			ladder.frame=ladder.CATCH_FROM+float(step)*0.1
			ladder._present_catch_motion()
			if ladder.frame<=ladder.CATCH_LAUNCH:
				ground_error=maxf(ground_error,ladder.feet().distance_to(bank_feet))
			elif ladder.frame<ladder.CATCH_CONTACT:
				var head:Vector2=ladder.source_origin+ladder._catch_head(ladder.frame)
				if previous!=Vector2.ZERO:
					var dy:float=head.y-previous.y
					if dy*last_dy<0:reversals+=1
					last_dy=dy
					x_error=maxf(x_error,-(head.x-previous.x)*signf(end_head.x-start_head.x))
				previous=head
			else:
				var hand:Vector2=ladder.source_origin+ladder._track(ladder.frame,"hand")
				hand_error=maxf(hand_error,hand.distance_to(ladder._catch_hand()))
		_check(ground_error<0.002,"%.0f px: crouch remains planted on the real bank"%offset)
		_check(reversals<=1 and x_error<0.002,"%.0f px: flight has one arc and never jumps backward"%offset)
		_check(hand_error<0.002,"%.0f px: settling legs cannot detach the bearing hand"%offset)
		for boundary in [ladder.CATCH_LAUNCH,ladder.CATCH_CONTACT]:
			# At launch compare the same recorded pose on either side of the
			# grounded/flight branch, not two different 24 fps source images.
			ladder.frame=boundary if boundary==ladder.CATCH_LAUNCH else boundary-0.0001
			ladder._present_catch_motion()
			var before:Vector2=ladder.source_origin+ladder._catch_head(ladder.frame)
			ladder.frame=boundary+0.0001 if boundary==ladder.CATCH_LAUNCH else boundary
			ladder._present_catch_motion()
			var after:Vector2=ladder.source_origin+ladder._catch_head(ladder.frame)
			_check(before.distance_to(after)<0.002,"%.0f px: continuous head position at frame %.0f"%[offset,boundary])
	print("rope ladder catch smoke OK" if failures==0 else "rope ladder catch smoke FAILED")
	quit(0 if failures==0 else 1)
