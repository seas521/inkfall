extends Node2D

# A short, occluded connector between the high bridge bank and C zone's
# original left bank.  The two authored spaces live more than 4000 px apart
# vertically, so the coordinate handoff happens only while near-black rock and
# undergrowth completely cover the actor and frame.  Input and walking never
# stop: to the player this reads as passing behind a close natural buttress,
# not as a load screen or a camera cut.

const ENTRY_FEET:=Vector2(-2255.0,-3715.0)
const COVER_START_X:=-2195.0
const SWAP_X:=-2035.0
const EXIT_FEET:=Vector2(-105.0,325.4)
const RELEASE_X:=55.0

var level
var active:=false
var in_c_zone:=false
var enabled:=true
var swapped:=false
var cover:=0.0
var floor_body:StaticBody2D
var art:Node2D

func _ready()->void:
	floor_body=StaticBody2D.new()
	floor_body.collision_layer=1
	floor_body.collision_mask=0
	var shape:=CollisionPolygon2D.new()
	shape.polygon=PackedVector2Array([
		Vector2(-2310,-3715),Vector2(-2240,-3717),Vector2(-2170,-3712),
		Vector2(-2100,-3707),Vector2(-2010,-3702),Vector2(-1940,-3700),
		Vector2(-1940,-3560),Vector2(-2310,-3560),
	])
	floor_body.add_child(shape)
	add_child(floor_body)
	art=BridgeToCArt.new()
	art.route=self
	add_child(art)
	set_enabled(true)

func reset()->void:
	active=false
	in_c_zone=false
	enabled=true
	swapped=false
	cover=0.0
	if floor_body!=null:floor_body.collision_layer=1
	if art!=null:art.sync(0.0)

func set_enabled(value:bool)->void:
	enabled=value
	if floor_body!=null:floor_body.collision_layer=1 if value else 0
	if not value:
		active=false
		cover=0.0
		if art!=null:art.sync(0.0)

func feet()->Vector2:
	return level.player.position+Vector2(13,54)

func camera_target_y()->float:
	if swapped:return 0.0
	return minf(0.0,level.player.position.y-500.0)

func _begin()->void:
	active=true
	swapped=false
	cover=0.0
	level.log_bridge.active=false
	level.rope_ladder.stop()
	level.actor.finish_rope_ladder()
	level.player.velocity.x=maxf(0.0,level.player.velocity.x)

func _swap_worlds()->void:
	swapped=true
	level.player.position=EXIT_FEET-Vector2(13,54)
	level.player.velocity=Vector2(maxf(58.0,level.player.velocity.x),0.0)
	level.player.collision_mask=11
	level.camera_x=level.player.position.x-525.0
	level.camera_y=0.0
	level.camera.position=Vector2(level.camera_x+640.0,360.0)
	level.scene1.cut=level.scene1.Cut.DONE
	level.scene1.intro_time=99.0
	level.intro_time=0.0
	level.climb_time=-1.0

func _finish()->void:
	active=false
	in_c_zone=true
	cover=0.0
	level.checkpoint=0
	level.player.velocity.x=maxf(0.0,level.player.velocity.x)
	art.sync(0.0)

func tick(delta:float)->bool:
	if not enabled or in_c_zone:return false
	if not active:
		if level.log_bridge.reached_bank and feet().x>COVER_START_X-75.0 and feet().y<-3500.0:
			_begin()
		else:
			art.sync(delta)
			return false
	var direction:=Input.get_axis("move_left","move_right")
	# Once he enters the close foreground passage he keeps moving through it;
	# allowing a reversal during the hidden coordinate swap would expose the seam.
	if cover>0.72:direction=maxf(0.35,direction)
	if absf(direction)>0.1:level.facing=signf(direction)
	level._update_player(delta,direction,0)
	var p:=feet()
	if not swapped:
		cover=smoothstep(COVER_START_X,SWAP_X,p.x)
		if p.x>=SWAP_X and cover>0.96:_swap_worlds()
	else:
		cover=1.0-smoothstep(EXIT_FEET.x,RELEASE_X,p.x)
		if p.x>=RELEASE_X:
			_finish()
			return false
	level._update_camera(delta)
	level.camera.offset=Vector2.ZERO
	level._present(delta)
	art.sync(delta)
	return true

func restore_checkpoint()->void:
	# There is no hazard in the connector.  A manual restart while crossing it
	# returns to the earned bridge-bank checkpoint instead of skipping C's start.
	active=false
	swapped=false
	cover=0.0
	level.log_bridge.active=true
	level.log_bridge.reached_bank=true
	level.log_bridge.respawn()
	art.sync(0.0)


class BridgeToCArt extends Node2D:
	var route
	var bank_tree:Texture2D=preload("res://assets/art/descent/post-bridge/ancient-bank-occluder-v1.png")
	var world:Node2D
	var veil:CanvasLayer
	var veil_draw:Node2D
	var clock:=0.0

	func _ready()->void:
		world=Node2D.new()
		world.z_index=2
		world.draw.connect(_draw_world)
		add_child(world)
		veil=CanvasLayer.new()
		veil.layer=7
		add_child(veil)
		veil_draw=Node2D.new()
		veil_draw.draw.connect(_draw_veil)
		veil.add_child(veil_draw)

	func sync(delta:float)->void:
		clock+=delta
		visible=route.enabled and not route.in_c_zone
		world.visible=visible and not route.swapped
		veil.visible=visible and route.cover>0.001
		world.queue_redraw()
		veil_draw.queue_redraw()

	func _draw_world()->void:
		var top:=PackedVector2Array([
			Vector2(-2310,-3715),Vector2(-2260,-3718),Vector2(-2200,-3714),
			Vector2(-2140,-3709),Vector2(-2070,-3706),Vector2(-2000,-3702),
			Vector2(-1940,-3700),Vector2(-1940,-3500),Vector2(-2310,-3500),
		])
		world.draw_colored_polygon(top,Color("050606"))
		# Sparse irregular grass breaks the bridge-bank edge without creating a
		# repeated comb or a grey top strip.
		for x in range(-2275,-1960,19):
			var seed:=fposmod(float(x)*0.137,1.0)
			var base:=Vector2(x,-3713.0+sin(float(x)*0.047)*3.0)
			var h:=6.0+seed*9.0
			world.draw_polyline(PackedVector2Array([base+Vector2(-3,1),base+Vector2(0,-h),base+Vector2(2,-h*0.38)]),Color("050606"),2.6,true)
		# Image-authored contour: the collision stays simple, while the visible
		# ancient trunk keeps soft antialiasing, unequal buried roots and natural
		# branch taper instead of exposing the collision polygon as artwork.
		world.draw_colored_polygon(PackedVector2Array([
			Vector2(-2115,-3710),Vector2(-2050,-3707),Vector2(-1980,-3696),
			Vector2(-1915,-3690),Vector2(-1840,-3698),Vector2(-1760,-3708),
			Vector2(-1380,-3702),Vector2(-1380,-3400),Vector2(-2115,-3400),
		]),Color("030404"))
		world.draw_texture_rect(bank_tree,Rect2(-2285,-4300,900,600),false,Color("030404"))

	func _draw_veil()->void:
		var a:float=clampf(route.cover,0.0,1.0)
		if a<=0.001:return
		var progress:=smoothstep(0.0,0.94,a)
		var entering:bool=not route.swapped
		var edge:float=lerpf(1325.0,-55.0,progress) if entering else lerpf(-45.0,1325.0,progress)
		var ink:=Color(0.006,0.007,0.007,smoothstep(0.02,0.28,a))
		var poly:=PackedVector2Array()
		if entering:
			poly.append(Vector2(1325,-20))
			poly.append(Vector2(1325,740))
			for y in range(740,-21,-24):
				var organic:=sin(float(y)*0.018+0.7)*18.0+sin(float(y)*0.041)*7.0
				poly.append(Vector2(edge+organic,y))
		else:
			poly.append(Vector2(-5,-20))
			for y in range(-20,741,24):
				var organic:=sin(float(y)*0.018+0.7)*18.0+sin(float(y)*0.041)*7.0
				poly.append(Vector2(edge+organic,y))
			poly.append(Vector2(-5,740))
		veil_draw.draw_colored_polygon(poly,ink)
		if a>0.86:
			veil_draw.draw_rect(Rect2(-5,-5,1290,730),Color(0.004,0.005,0.005,smoothstep(0.86,0.98,a)))
