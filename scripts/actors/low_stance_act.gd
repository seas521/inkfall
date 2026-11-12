extends RefCounted
# Reusable low-stance controller. A level supplies clearance demand; S can
# request the same stance in open space. Actor scale and world feet never change.
enum Mode { UP, ENTER, LOW, EXIT }
const ENTER_TIME:=25.0/24.0/1.85
const EXIT_TIME:=25.0/24.0/1.55
const SPEED:=60.0
var level
var enter_duration:=ENTER_TIME
var exit_duration:=EXIT_TIME
var mode:=Mode.UP
var time:=0.0
var distance:=0.0
var last_x:=0.0
func _init(owner):level=owner
func active()->bool:return mode!=Mode.UP
func transitioning()->bool:return mode in [Mode.ENTER,Mode.EXIT]
func locks_translation()->bool:
	return (mode==Mode.ENTER and time<enter_duration*.42) or (mode==Mode.EXIT and time<exit_duration*.80)
func _shape(low:bool)->void:
	var node:CollisionShape2D=level.player.get_child(0)
	var capsule:=node.shape as CapsuleShape2D
	if capsule==null:return
	capsule.height=40.0 if low else 54.0
	node.position=Vector2(13,54-capsule.height*0.5)
func reset()->void:
	mode=Mode.UP
	time=0
	distance=0
	last_x=level.player.position.x
	_shape(false)
func tick(delta:float,wanted:bool,allowed:bool,tight_mouth:=false)->void:
	if level.actor!=null and not level.actor.loaded_groups.has("low_stance"):level.actor.load_group("low_stance")
	if not allowed:
		if active():reset()
		last_x=level.player.position.x
		return
	distance+=absf(level.player.position.x-last_x)
	last_x=level.player.position.x
	time+=delta
	match mode:
		Mode.UP:
			if wanted:mode=Mode.ENTER;time=0;distance=0;enter_duration=0.48 if tight_mouth else ENTER_TIME
		Mode.ENTER:
			if time>=enter_duration:mode=Mode.LOW;time=0
		Mode.LOW:
			if not wanted:mode=Mode.EXIT;time=0;exit_duration=0.84 if tight_mouth else EXIT_TIME
		Mode.EXIT:
			if time>=exit_duration:mode=Mode.UP;time=0
	_shape(active())
func pose_info()->Dictionary:
	match mode:
		Mode.ENTER:return {"action":&"low_enter","progress":clampf(time/enter_duration,0,1)}
		Mode.EXIT:return {"action":&"low_exit","progress":clampf(time/exit_duration,0,1)}
		Mode.LOW:
			if absf(level.player.velocity.x)>3:return {"action":&"low_walk","progress":fposmod(distance/64.0,1.0)}
			return {"action":&"low_idle","progress":fposmod(time/(11.0/24.0),1.0)}
	return {"action":&"none","progress":0.0}
