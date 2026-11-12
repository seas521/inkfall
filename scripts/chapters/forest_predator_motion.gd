extends RefCounted
const Clip=preload("res://scripts/chapters/forest_predator_clip.gd")
const DATA=Clip.DATA
const WINDUP_TIME:=27.0/60.0
const SNAP_TIME:=WINDUP_TIME+10.0/24.0
const RECOVER_TIME:=32.0/24.0
const FEED_TIME:=15.0/24.0+5.0 # source 65 and 88 closely match, one-second digestion cycle
static func idle_closure(time:float)->float:
	return 0.5-0.5*cos(TAU*time/4.2)

static func frame_index(state:int,time:float)->int:
	match state:
		0:return 0 # Ambient lower-jaw hinge uses the rest silhouette only.
		1:return mini(39,13+int(time*60.0))
		2:return mini(120,40+int(time*60.0)) # complete missed bite and return
		3:
			if time<WINDUP_TIME:return mini(39,13+int(time*60.0))
			return mini(49,40+int((time-WINDUP_TIME)*24.0))
		4:return _eat_frame(time)
		5:return mini(120,89+int(time*24.0))
		6:
			if time<10.0/24.0:return mini(49,40+int(time*24.0))
			return _eat_frame(time-10.0/24.0)
	return 0
static func source_mouth(state:int,time:float)->Vector2:
	var at:Array=DATA.mouth[frame_index(state,time)]
	return Vector2(float(at[0]),float(at[1]))

static func _eat_frame(time:float)->int:
	if time<15.0/24.0:return 50+int(time*24.0)
	return 65+int((time-15.0/24.0)*24.0)%24
