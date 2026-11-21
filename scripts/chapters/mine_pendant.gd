extends Node2D
const TEXTURE=preload("res://assets/art/descent/mine-v10/lamp.png")
const CABLE_LENGTH:=52.0
const BULB_OFFSET:=Vector2(0,76)
var swing:Node2D
var elapsed:=0.0
var phase:=0.0
var failure_age:=-1.0
var landing_y:=0.0
var energy:=1.0
var fixture:Sprite2D
var failure_angle:=0.0
var failure_velocity:=0.0
var cable_length:=CABLE_LENGTH
var bulb_offset:=BULB_OFFSET
func fit_suspension(drop:float)->void:
	bulb_offset=Vector2(0,maxf(76,drop));cable_length=bulb_offset.y-24
	if fixture!=null:fixture.position=Vector2(-21,cable_length)
	update_swing(0)

func set_failure(age:float,floor_y:float)->void:
	if failure_age<0 and age>=0:
		failure_angle=0.085*sin(elapsed*1.53+phase)+0.012*sin(elapsed*.73+phase)
		# A single ceiling impulse, followed by the cable pendulum response.
		failure_velocity=.085*1.53*cos(elapsed*1.53+phase)+.012*.73*cos(elapsed*.73+phase)+1.35
	failure_age=age;landing_y=floor_y
	update_swing(0)

func restore_fixture()->void:
	failure_age=-1;energy=1
	update_swing(0)

func _ready()->void:
	if not has_meta("light_plane"):set_meta("light_plane",&"gameplay")
	if get_meta("light_plane")==&"gameplay":add_to_group(&"chapter_gameplay_focus")
	swing=Node2D.new();add_child(swing)
	swing.draw.connect(_draw_wire)
	var sprite:=Sprite2D.new()
	sprite.texture=TEXTURE
	sprite.centered=false
	sprite.position=Vector2(-21,cable_length)
	sprite.scale=Vector2(42,28)/TEXTURE.get_size()
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var ink:=ShaderMaterial.new();ink.shader=preload("res://assets/shaders/mine_pendant_ink.gdshader")
	sprite.material=ink
	fixture=sprite
	swing.add_child(sprite)
	update_swing(0)

func _draw_wire()->void:
	swing.draw_line(Vector2(0,24) if failure_age>.36 else Vector2.ZERO,Vector2(0,cable_length+2),Color(0.04,0.04,0.04),1.2,true)

func update_swing(delta:float)->void:
	elapsed+=delta
	if swing==null:return
	swing.position=Vector2.ZERO
	swing.rotation=0.085*sin(elapsed*1.53+phase)+0.012*sin(elapsed*0.73+phase)
	energy=1.0
	if failure_age>=0:
		var t:=failure_age
		# Damped pendulum: omega ~= sqrt(g / cable-to-centre length).
		var frequency:=3.55
		var damping:=.65
		var release_time:=.36
		var attached_time:=minf(t,release_time)
		var angle:=exp(-damping*attached_time)*(failure_angle*cos(frequency*attached_time)+(failure_velocity+damping*failure_angle)/frequency*sin(frequency*attached_time))
		swing.rotation=angle
		if t>release_time:
			var fall:=t-release_time
			var distance:=maxf(0,landing_y-global_position.y-bulb_offset.y-8.0)
			var landing_time:=sqrt(2.0*distance/860.0)
			var airborne:=minf(fall,landing_time)
			var release_velocity:=exp(-damping*release_time)*(failure_velocity*cos(frequency*release_time)-(frequency*failure_angle+damping*(failure_velocity+damping*failure_angle)/frequency)*sin(frequency*release_time))
			swing.rotation=angle+airborne*release_velocity
			swing.position=Vector2(airborne*22,430*airborne*airborne)+bulb_offset-bulb_offset.rotated(swing.rotation)
			if fall>=landing_time:
				var settle:=fall-landing_time
				var contact_angle:=angle+landing_time*release_velocity
				# Keep angle and angular velocity continuous at floor impact.
				var displacement:=contact_angle-1.36
				swing.rotation=1.36+exp(-settle*6)*(displacement*cos(settle*8)+(release_velocity+6*displacement)/8*sin(settle*8))
				swing.position.y=landing_y-global_position.y-8-bulb_offset.rotated(swing.rotation).y
				energy=(1.0-smoothstep(0,.22,settle))*.8
			else:energy=.8
		else:energy=1.0-.2*smoothstep(0,release_time,t)
	if fixture!=null:fixture.material.set_shader_parameter("energy",energy)
	swing.queue_redraw()

func light_position()->Vector2:
	return swing.to_global(bulb_offset)

func light_angle()->float:
	return swing.global_rotation
