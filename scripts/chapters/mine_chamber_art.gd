extends Node2D

# Approved black architecture; no baked actor, cart, rails or fixture.
const ENTRY=preload("res://assets/art/descent/mine-v10/entry.png")
const DEPTH=preload("res://assets/art/descent/mine-v10/depth-exit.png")
const Pendant=preload("res://scripts/chapters/mine_pendant.gd")
var section:=0
var left:=-3060.0
var width:=1086.0
var floor_at:Callable
var rest_floor_at:Callable
var rock:Node2D
var ink:ShaderMaterial
var lamp:Node2D
var resting_light:=Vector2.ZERO
var earth:Node2D
var front:Node2D
var collapse_age:=-1.0
var ceiling_samples:=PackedVector2Array()

func collapse_weight(x:float)->float:
	if section==0:return smoothstep(-3100,-2985,x)*(1.0-smoothstep(-2450,-2340,x))
	return smoothstep(left,left+90,x)*(1.0-smoothstep(-1540,-1420,x)) if section==1 else 0.0

func local_collapse_age(x:float)->float:
	return collapse_age if section==0 else collapse_age-(1.3+maxf(0,x+2340)/310.0)

func floor_shift(x:float)->float:
	if collapse_age<0:return 0.0
	var t:=maxf(0,local_collapse_age(x))
	var slump:=smoothstep(.24,1.25,t)*(18.0+9.0*sin((x+2900)*.011))
	var shock:=sin((x+3000)*.037-t*37)*3.8*exp(-maxf(0,t-.25)*3)*smoothstep(0,.15,t)
	return collapse_weight(x)*(slump+shock)

func roof_shift(x:float)->float:
	if collapse_age<0:return 0.0
	var delay:=.08+absf(x+2620)*.00018
	var t:=maxf(0,local_collapse_age(x)-delay)
	var sag:=smoothstep(0,.65,t)*24.0
	return collapse_weight(x)*(sag+smoothstep(.32,1.25,t)*(200.0+18.0*sin(x*.012)))

func set_collapse(age:float)->void:
	collapse_age=age
	if lamp==null:return
	if age<0:lamp.restore_fixture()
	else:
		var lamp_age:=age if section==0 else age-3.8
		if lamp_age<0:lamp.restore_fixture()
		else:lamp.set_failure(lamp_age,float(floor_at.call(lamp.global_position.x)))
	for canvas in [rock,front,earth]:canvas.material.set_shader_parameter("collapse_clock",age)
	_process(0)

func build(which:int,start:float,span:float,surface:Callable,rest_surface:Callable=Callable())->void:
	section=which;left=start;width=span;floor_at=surface
	rest_floor_at=rest_surface if rest_surface.is_valid() else surface
	rock=Node2D.new();add_child(rock);rock.draw.connect(_draw_rock)
	ink=ShaderMaterial.new();ink.shader=preload("res://assets/shaders/mine_black_plate.gdshader")
	ink.set_shader_parameter("rows",1.0 if section==0 else 2.0)
	ink.set_shader_parameter("row",maxi(0,section-1))
	ink.set_shader_parameter("entry",section==0)
	ink.set_shader_parameter("entry_left",left)
	rock.material=ink
	var x:=left+width*([0.32,0.40,0.78][section] as float)
	resting_light=Vector2(x,float(floor_at.call(x))-165)
	lamp=Pendant.new();lamp.z_index=3;lamp.phase=float(section)*1.7
	lamp.position=resting_light-Pendant.BULB_OFFSET
	add_child(lamp)
	# Match the extra chase/parking fixtures: anchor the wire inside the
	# sampled rock roof, retaining the authored bulb and light-pool height.
	var roof_y:float=ceiling_y(x)
	if lamp.position.y>roof_y-8.0:
		lamp.position.y=roof_y-14.0
		lamp.fit_suspension(resting_light.y-lamp.position.y)
	ink.set_shader_parameter("rest_light",resting_light)
	front=Node2D.new();front.z_index=7;add_child(front)
	var mask:=ShaderMaterial.new();mask.shader=preload("res://assets/shaders/mine_black_occlusion.gdshader")
	mask.set_shader_parameter("rows",1.0 if section==0 else 2.0)
	mask.set_shader_parameter("row",maxi(0,section-1))
	front.material=mask
	front.draw.connect(func():_paint(front))
	earth=Node2D.new()
	add_child(earth)
	var earth_ink:=ShaderMaterial.new();earth_ink.shader=preload("res://assets/shaders/mine_earth_warp.gdshader")
	earth.material=earth_ink
	for canvas in [rock,front,earth]:canvas.material.set_shader_parameter("chamber_section",section)
	earth.draw.connect(func():_draw_ground(earth))
	if section in [0,1]:
		for i in 65:
			var sample_x:=lerpf(left-120,left+width,i/64.0)
			ceiling_samples.append(Vector2(sample_x,ceiling_y(sample_x)))
	_process(0)
	queue_redraw()

func _process(delta:float)->void:
	if lamp==null:return
	lamp.update_swing(delta)
	ink.set_shader_parameter("lamp",lamp.light_position())
	ink.set_shader_parameter("angle",lamp.light_angle())
	ink.set_shader_parameter("lamp_strength",lamp.energy)

func _paint(canvas:Node2D)->void:
	var texture:Texture2D=ENTRY if section==0 else DEPTH
	var rows:=1.0 if section==0 else 2.0
	var row:=float(maxi(0,section-1))
	for i in 48:
		var points:=PackedVector2Array();var uv:=PackedVector2Array()
		for p:Vector2 in [Vector2(i/48.0,0),Vector2((i+1)/48.0,0),Vector2((i+1)/48.0,1),Vector2(i/48.0,1)]:
			var x:=left-120.0+p.x*(width+120.0) if section==0 else left+p.x*width
			# Use the open rock bay; baked posts must not impersonate the breakable wall.
			var u:float=p.x
			if section==0:
				u=lerpf(0.43,0.65,p.x)
			elif section==1:u=lerpf(.30,.55,p.x)
			var edge:=lerpf(0.74,0.89,u) if section==0 else lerpf(0.79,0.92,u)
			points.append(Vector2(x,float(rest_floor_at.call(x))+(p.y-edge)*560.0+4))
			uv.append(Vector2(u,(row+p.y)/rows))
		canvas.draw_polygon(points,PackedColorArray([Color.WHITE]),uv,texture)

func _draw_rock()->void:
	# A continuous overburden stays connected to the mountain as the bay buckles.
	if not ceiling_samples.is_empty():
		# The exterior cliff already owns the upper mountain silhouette.
		# The old 700px extrusion escaped that silhouette near the entrance,
		# exposing its closing edge as a faint triangular black sliver.
		var cap_y:=INF
		for sample in ceiling_samples:cap_y=minf(cap_y,sample.y-80.)
		var mass:=PackedVector2Array([Vector2(ceiling_samples[0].x,cap_y)])
		for sample in ceiling_samples:mass.append(sample-Vector2(0,8))
		mass.append(Vector2(ceiling_samples[-1].x,cap_y))
		var uv:=PackedVector2Array([Vector2.ZERO])
		for sample in ceiling_samples:uv.append(Vector2(0,1))
		uv.append(Vector2.ZERO)
		rock.draw_polygon(mass,PackedColorArray([Color(.002,.002,.002)]),uv)
	_paint(rock)

func _draw_ground(canvas:Node2D)->void:
	if not floor_at.is_valid():return
	var base:=PackedVector2Array()
	for i in 129:
		var start:=left-20.0 if section==0 else left
		var x:=lerpf(start,left+width,i/128.0)
		base.append(Vector2(x,float(rest_floor_at.call(x))-1.5+sin(i*2.17)*0.4))
	base.append(Vector2(left+width,float(rest_floor_at.call(left+width))+600))
	var start:=left-20.0 if section==0 else left
	base.append(Vector2(start,float(rest_floor_at.call(start))+600))
	canvas.draw_colored_polygon(base,Color.BLACK)

func light_at(x:float)->float:
	if lamp==null:return 0.0
	var d:Vector2=Vector2(x,float(floor_at.call(x)))-lamp.light_position()
	var angle:float=lamp.light_angle()
	d=Vector2(cos(angle)*d.x+sin(angle)*d.y,-sin(angle)*d.x+cos(angle)*d.y)
	if section==0:
		var spread:=28.0+maxf(d.y,0.0)*0.95
		var beam:=smoothstep(-12.0,24.0,d.y)*exp(-pow(absf(d.x)/spread,2.0))*exp(-maxf(d.y,0.0)/330.0)
		var scatter:=0.20*exp(-pow(d.x/310.0,2.0))*exp(-pow((d.y-95.0)/215.0,2.0))*smoothstep(-40.0,30.0,d.y)
		return (beam+scatter)*lamp.energy
	var spread:=18.0+maxf(d.y,0.0)*0.70
	return exp(-pow(absf(d.x)/spread,2.2))*exp(-maxf(d.y,0.0)/310.0)*lamp.energy

# Same source coordinates as the rendered bay: masonry meets actual roof.
func ceiling_y(x:float)->float:
	var t:=clampf((x-left+120.0)/(width+120.0),0.0,1.0) if section==0 else clampf((x-left)/width,0,1)
	var u:=lerpf(.43,.65,t) if section==0 else lerpf(.30,.55,t)
	var source:Image=(ENTRY if section==0 else DEPTH).get_image()
	var column:=int(u*(source.get_width()-1))
	var row_height:=source.get_height() if section==0 else source.get_height()/2
	for y in range(int(row_height*.2),int(row_height*.75)):
		var c:=source.get_pixel(column,y)
		if c.r*.299+c.g*.587+c.b*.114>.025:
			var edge:=lerpf(.74,.89,u) if section==0 else lerpf(.79,.92,u)
			return float(rest_floor_at.call(x))+(float(y)/row_height-edge)*560.0+4
	return float(rest_floor_at.call(x))-240.0
