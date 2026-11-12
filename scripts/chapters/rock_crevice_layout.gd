extends RefCounted
# Shared image, ground and collision calibration for the approved fallen tree.
# Compatibility filename retained for forest/ladder callers.
const START:=-9500.0
const ART_SCALE:=0.45
const LEFT:=START+3800
const EXIT_MOUTH:=LEFT+(1810.0-300.0)*ART_SCALE
const MIDDLE:=LEFT+330
const RIGHT:=EXIT_MOUTH+70
const DUCK_LEFT:=LEFT-58
const DUCK_RIGHT:=EXIT_MOUTH+38
# The actor may begin bending at the mouth, but spider protection starts only
# after his whole body has moved beneath the substantial part of the trunk.
const SHELTER_LEFT:=LEFT+30
const SHELTER_RIGHT:=EXIT_MOUTH-22
const EXIT_SAFE:=EXIT_MOUTH+140
const BODY_STOP:=LEFT-330
const CLEARANCE:=48.0
const ART_LEFT:=LEFT-300*ART_SCALE
const ART_RIGHT:=ART_LEFT+2048*ART_SCALE
const ART_Y:=-4684.0
const GROUND:=[Vector2(-200,760),Vector2(0,756),Vector2(200,762),Vector2(300,770),Vector2(400,800),Vector2(510,815),Vector2(600,833),Vector2(740,862),Vector2(900,897),Vector2(1060,910),Vector2(1180,913),Vector2(1300,910),Vector2(1420,902),Vector2(1520,887),Vector2(1600,877),Vector2(1680,873),Vector2(1740,866),Vector2(1820,864),Vector2(2048,850),Vector2(2250,840)]
const UNDERSIDE:=[Vector2(250,630),Vector2(300,650),Vector2(400,665),Vector2(480,695),Vector2(580,709),Vector2(740,725),Vector2(940,756),Vector2(1100,780),Vector2(1250,810),Vector2(1400,850),Vector2(1520,880),Vector2(1700,885),Vector2(1780,850),Vector2(1840,805)]
const TOP:=[Vector2(250,470),Vector2(300,480),Vector2(480,490),Vector2(580,510),Vector2(740,535),Vector2(940,561),Vector2(1100,568),Vector2(1250,604),Vector2(1400,650),Vector2(1600,697),Vector2(1780,726),Vector2(1840,760)]
const ROOF_END:=ART_LEFT+1280*ART_SCALE
static func profile(points:Array,x:float)->float:
	if x<=points[0].x:return points[0].y
	for i in range(1,points.size()):
		if x<=points[i].x:return lerpf(points[i-1].y,points[i].y,smoothstep(points[i-1].x,points[i].x,x))
	return points[-1].y
static func source_x(x:float)->float:return (x-ART_LEFT)/ART_SCALE
static func image_point(p:Vector2)->Vector2:return Vector2(ART_LEFT+p.x*ART_SCALE,ART_Y+p.y*ART_SCALE)
static func ceiling(x:float,_ground:Callable)->float:return image_point(Vector2(source_x(x),profile(UNDERSIDE,source_x(x)))).y
static func roof_top(x:float,_ground:Callable)->float:return image_point(Vector2(source_x(x),profile(TOP,source_x(x)))).y
static func height_at(x:float)->float:return (profile(GROUND,source_x(x))-profile(UNDERSIDE,source_x(x)))*ART_SCALE
static func floor_for(x:float,base:float)->float:
	# The complete reference terrain is built with the tree: left bank,
	# shallow bowl, and right load-bearing bank. Never flatten the bank
	# just to maintain an artificial constant-height corridor.
	var w:=smoothstep(ART_LEFT-130,ART_LEFT+160,x)*(1.-smoothstep(ART_RIGHT-90,ART_RIGHT+230,x))
	var floor_y:=image_point(Vector2(source_x(x),profile(GROUND,source_x(x)))).y
	# Stand height is54px, low stance40px: the actual entrance and sheltered
	# walking floor leave48px, rather than merely requesting a bent pose.
	var tight:=smoothstep(LEFT-90,LEFT-10,x)*(1.-smoothstep(ROOF_END-15,ROOF_END+65,x))
	floor_y=lerpf(floor_y,minf(floor_y,ceiling(x,Callable())+CLEARANCE),tight)
	return lerpf(base,floor_y,w)
static func floor_offset(_x:float)->float:return 0.0
static func in_low_zone(x:float,_facing:=1.0)->bool:return x>=DUCK_LEFT and x<=DUCK_RIGHT
static func inside(x:float)->bool:return x>LEFT+22 and x<EXIT_MOUTH-22
static func sheltered(x:float,feet_y:float)->bool:
	return x>SHELTER_LEFT and x<SHELTER_RIGHT and feet_y>ceiling(x,Callable())+25
static func at_mouth(x:float)->bool:return absf(x-LEFT)<85 or absf(x-EXIT_MOUTH)<85
static func low_speed(x:float)->float:return 58.0 if at_mouth(x) else 60.0
# The fallen timber is shelter, not a traversable ledge. Its collision has a
# visible upper contour, but the generic ledge detector must never treat that
# contour (especially the jagged left break) as a climbable platform.
static func blocks_climb(x:float)->bool:return x>=LEFT-145 and x<=ART_RIGHT+35
static func enclosure(x:float)->float:return smoothstep(LEFT-15,LEFT+80,x)*(1.-smoothstep(EXIT_MOUTH-70,EXIT_MOUTH+35,x))
static func occluded(_x:float)->bool:return false # visible beneath the tree, no cave cheeks
static func surface(x:float,ground:Callable)->float:return float(ground.call(x))
static func polygon(ground:Callable)->PackedVector2Array:
	var points:=PackedVector2Array()
	for i in 65:
		var x:float=lerpf(LEFT-25,ROOF_END,float(i)/64)
		points.append(Vector2(x,roof_top(x,ground)))
	for i in range(64,-1,-1):
		var x:float=lerpf(LEFT-25,ROOF_END,float(i)/64)
		points.append(Vector2(x,ceiling(x,ground)))
	return points
