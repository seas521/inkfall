extends Node2D

const PolyforkArt=preload("res://scripts/chapters/polyfork_station_art.gd")
const Layout=preload("res://scripts/chapters/descent_route_layout.gd")
const KIT=preload("res://assets/art/descent/post-bridge/silhouette-kit-v1.png")
const RAVINE=preload("res://assets/art/descent/rope-ladder/ravine-depth.png")
const CAVERN=preload("res://assets/art/descent/05-bat-cavern-v2.png")
const LIGHT=preload("res://assets/shaders/cinematic_light_cone.gdshader")
const INK:=Color(0.002,0.002,0.002)
var kit:Texture2D=KIT
var route
var back:CanvasLayer
var background:ColorRect
var middle:Node2D
var polyfork:Node2D
var lower_rigging:Node2D
var drawing:Node2D
var near:CanvasLayer
var near_ink:Node2D
var light:ColorRect
var clock:=0.0
var camera:=Vector2.ZERO

func _ready()->void:
	z_index=3
	back=CanvasLayer.new()
	back.layer=-4
	add_child(back)
	background=ColorRect.new()
	background.size=Vector2(1280,720)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform sampler2D gorge : filter_linear_mipmap;
uniform sampler2D cavern : filter_linear_mipmap;
uniform vec2 camera=vec2(0.0);
uniform float clock=0.0;
uniform float cave=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 uv=clamp(UV*0.70+vec2(0.13,0.08)+camera*vec2(0.000012,0.000024),vec2(0.01),vec2(0.99));
 vec3 a=textureLod(gorge,uv,3.1).rgb;
 vec3 b=textureLod(cavern,clamp(UV*0.7+vec2(0.15,0.12),vec2(0.01),vec2(0.99)),3.7).rgb;
 float v=mix(dot(a,vec3(0.3333)),dot(b,vec3(0.3333)),cave);
 v=mix(0.16,0.58,smoothstep(0.06,0.78,v));
 float haze=noise(UV*vec2(3.0,2.0)+vec2(clock*0.008,-clock*0.004));
 v=mix(v,0.50,haze*0.12);
 COLOR=vec4(vec3(v),1.0);
}"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("gorge",RAVINE)
	mat.set_shader_parameter("cavern",CAVERN)
	background.material=mat
	back.add_child(background)
	middle=Node2D.new()
	middle.draw.connect(_draw_mid)
	back.add_child(middle)
	light=ColorRect.new()
	light.position=Vector2(300,-100)
	light.size=Vector2(850,880)
	light.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var lm:=ShaderMaterial.new()
	lm.shader=LIGHT
	lm.set_shader_parameter("intensity",0.055)
	lm.set_shader_parameter("light_tint",Vector3(0.55,0.55,0.55))
	light.material=lm
	back.add_child(light)
	lower_rigging=Node2D.new()
	lower_rigging.z_index=-1
	lower_rigging.draw.connect(_draw_lower_rigging)
	add_child(lower_rigging)
	drawing=Node2D.new()
	drawing.draw.connect(_draw_world)
	add_child(drawing)
	polyfork=PolyforkArt.new()
	polyfork.route=route
	add_child(polyfork)
	near=CanvasLayer.new()
	near.layer=8
	add_child(near)
	near_ink=Node2D.new()
	near_ink.draw.connect(_draw_near)
	near.add_child(near_ink)
	back.hide()
	near.hide()
	drawing.hide()

func sync(delta:float,enabled:bool)->void:
	clock+=delta
	camera=Vector2(route.level.camera_x,route.level.camera_y)
	var preview:bool=not route.in_c_zone and route.level.player.position.y< -2900 and route.level.player.position.x> -2850 and route.level.player.position.x<50
	var exit_visible:bool=route.in_c_zone and route.feet().x<2000
	visible=enabled or preview or exit_visible
	drawing.visible=enabled or preview or exit_visible
	var reveal:float=smoothstep(-2700,-2050,route.level.player.position.x) if route.stage==0 else 1.0
	var exit_mix:float=1.0-smoothstep(-200,240,route.feet().y) if enabled and route.stage==1 else 1.0
	back.visible=(enabled or preview) and not route.in_c_zone and reveal*exit_mix>0.001
	background.modulate.a=reveal*exit_mix
	middle.modulate.a=reveal*exit_mix
	light.modulate.a=reveal*exit_mix
	near.visible=enabled
	polyfork.sync(visible and drawing.visible)
	if not visible:return
	var mat:=background.material as ShaderMaterial
	mat.set_shader_parameter("camera",camera)
	mat.set_shader_parameter("clock",clock)
	mat.set_shader_parameter("cave",smoothstep(-1700,-300,route.feet().y))
	(light.material as ShaderMaterial).set_shader_parameter("clock",clock)
	middle.queue_redraw()
	lower_rigging.queue_redraw()
	drawing.queue_redraw()
	near_ink.queue_redraw()

func _beam(node:Node2D,a:Vector2,b:Vector2,width:float,tone:=INK)->void:
	var along:Vector2=b-a
	if along.length()<0.1:return
	node.draw_set_transform(a,along.angle())
	node.draw_texture_rect_region(kit,Rect2(0,-width*0.5,along.length(),width),Rect2(38,928,552,72),tone)
	node.draw_set_transform(Vector2.ZERO)

func _rock(node:Node2D,rect:Rect2,seed:int)->void:
	var source:=Rect2(26,255,575,256) if seed%2==0 else Rect2(653,271,573,212)
	var h:float=rect.size.y*1.35
	var target:=Rect2(rect.position-Vector2(rect.size.x*0.04,2),Vector2(rect.size.x*1.08,h))
	if seed%4 in [1,2]:
		node.draw_set_transform(rect.position+Vector2(rect.size.x,0),0,Vector2(-1,1))
		node.draw_texture_rect_region(kit,Rect2(Vector2(-rect.size.x*0.04,-2),target.size),source,INK)
		node.draw_set_transform(Vector2.ZERO)
	else:node.draw_texture_rect_region(kit,target,source,INK)
	# Only this narrow buried contact strip follows the collider exactly;
	# the visual mass comes from individually authored eroded silhouettes.
	_beam(node,rect.position+Vector2(1,3),rect.position+Vector2(rect.size.x-1,3),5)

func _plank(node:Node2D,at:Vector2,width:float,angle:=0.0)->void:
	node.draw_set_transform(at,angle)
	node.draw_texture_rect_region(kit,Rect2(-2,-2,width+4,22),Rect2(38,928,552,72),INK)
	node.draw_set_transform(Vector2.ZERO)

func _wheel(node:Node2D,at:Vector2,radius:float,turn:=0.0,tone:=INK)->void:
	node.draw_arc(at,radius,0,TAU,24,tone,4,true)
	for i in 5:
		var d:=Vector2.from_angle(float(i)*TAU/5+turn)
		_beam(node,at,at+d*radius,3,tone)
	node.draw_circle(at,4,tone)

func _rope(node:Node2D,a:Vector2,b:Vector2,sag:=3.0,tone:=INK)->void:
	var points:=PackedVector2Array()
	for i in 16:
		var t:float=float(i)/15
		points.append(a.lerp(b,t)+Vector2(0,sin(t*PI)*sag))
	node.draw_polyline(points,tone,1.8,true)

func _draw_mid()->void:
	var station_weight:float=1.0-smoothstep(-3300,-2600,route.feet().y)
	# The ravine supplies depth here; extra crane silhouettes compete with
	# the two active mechanisms and make the routes look interconnected.
	if station_weight<0.999:
		var cave_col:=Color(0.10,0.10,0.10,0.50*(1.0-station_weight))
		for i in 4:
			var at:=Vector2(80+float(i)*370-fmod(camera.x*0.08,130),-60)
			_beam(middle,at,at+Vector2(50,245+float(i%2)*120),38,cave_col)

func _draw_lower_rigging()->void:
	var left_anchor:Vector2=polyfork.anchor(polyfork.left_pulley)
	var right_anchor:Vector2=Layout.ORIGIN+Vector2(1380,100)
	_rope(lower_rigging,left_anchor,right_anchor,4)
	_rope(lower_rigging,route.weight.position+Vector2(22,5),left_anchor,1)
	var basket:Vector2=route.basket_position()
	for x in [-65,65]:
		_rope(lower_rigging,right_anchor,basket+Vector2(x,-155),1)

func _draw_world()->void:
	var o:=Layout.ORIGIN
	for i in Layout.STATION.size():
		var rect:Rect2=Layout.STATION[i]
		_rock(drawing,Rect2(o+rect.position,rect.size),i+3)
	# Upper route: a long anchored timber crane, cart rail and mobile board.
	_beam(drawing,o+Vector2(280,-260),o+Vector2(900,-245),24)
	_wheel(drawing,o+Vector2(780,-235),25,route.upper_travel/30)
	_rope(drawing,o+Vector2(310,-240),o+Vector2(780,-260))
	var board:Vector2=route.suspended.position
	for x in [18,122]:_rope(drawing,o+Vector2(780,-232),board+Vector2(x,2),1)
	_plank(drawing,board,140)
	for x in [0,420]:_beam(drawing,o+Vector2(x,8),o+Vector2(x-20,95),12)
	_rope(drawing,route.trolley.position+Vector2(25,6),o+Vector2(310,-230),2)
	_plank(drawing,route.seesaw.position+Vector2(-150,0).rotated(route.seesaw_angle),300,route.seesaw_angle)
	_beam(drawing,o+Vector2(1030,20),o+Vector2(1050,145),27)
	_wheel(drawing,o+Vector2(1040,34),17,route.seesaw_angle)
	_beam(drawing,o+Vector2(930,50),o+Vector2(940,16 if route.seesaw_locked else 42),5)
	# Lower lift is anchored to the existing upper bank. No tower crosses
	# the stepping stones; its cable passes behind their solid silhouettes.
	_beam(drawing,o+Vector2(1370,-28),o+Vector2(1380,87),13)
	_wheel(drawing,o+Vector2(1380,100),18,route.basket_y/25)
	var b:Vector2=route.basket_position()
	drawing.draw_texture_rect_region(kit,Rect2(b-Vector2(85,170),Vector2(170,192)),Rect2(707,657,462,522),INK)
	for x in [-82,82]:
		_beam(drawing,b+Vector2(x,3),b+Vector2(x,-45),5)
	_plank(drawing,b-Vector2(85,0),170)
	_rope(drawing,b+Vector2(-80,-40),b+Vector2(80,-40),2)
	_beam(drawing,o+Vector2(1060,280),o+Vector2(1545,565),9)
	_plank(drawing,route.bar.position,65)
	_beam(drawing,o+Vector2(1240,423),o+Vector2(1225,360),12)
	# Permanent exit shoulder is a natural rock wall, not an invisible gate.
	for i in Layout.DESCENT.size():
		var body=route.ledges[i]
		var at:Vector2=body.position
		var w:float=Layout.ledge_width(i)
		if i in Layout.FRAGILE or i in Layout.SWAYING:
			_plank(drawing,at,w,body.rotation)
			for x in [8,w-8]:_rope(drawing,at+Vector2(x,-190),at+Vector2(x,2),1.5)
		else:
			_rock(drawing,Rect2(at,Vector2(w,70+float(i%4)*17)),i*7+41)
			var toward:float=1 if i%8<4 else -1
			_beam(drawing,at+Vector2(w*0.5,35),at+Vector2(w*0.5+toward*55,110),10)
	var overlook:Vector2=Layout.DESCENT[14]+Vector2(130,-55)
	_rock(drawing,Rect2(overlook,Vector2(160,75)),201)
	_beam(drawing,overlook+Vector2(90,0),overlook+Vector2(85,-50),5)
	_beam(drawing,overlook+Vector2(55,-30),overlook+Vector2(115,-36),5)
	if route.discovered:_rope(drawing,overlook+Vector2(85,-50),overlook+Vector2(100,-10),1)
	var pivot:Vector2=Layout.DESCENT[6]+Vector2(-65,-30)
	_rock(drawing,Rect2(pivot+Vector2(-20,25),Vector2(45,50)),79)
	var end:Vector2=pivot+Vector2.from_angle(lerpf(-2.6,-0.45,route.deflector))*95
	_plank(drawing,pivot,100,lerpf(-2.6,-0.45,route.deflector))
	_wheel(drawing,pivot,10,route.deflector)
	var catcher:Vector2=Layout.DESCENT[7]+Vector2(0,100)
	for sign_x in [-1,1]:
		_beam(drawing,catcher+Vector2(sign_x*43,-20),catcher+Vector2(sign_x*33,37),8)
	_plank(drawing,catcher+Vector2(-35,34),70)
	for i in route.collected:_rock(drawing,Rect2(catcher+Vector2(-25+i*25,5-i*8),Vector2(35,25)),i+80)
	var moving:Vector2=route.ledges[7].position+Vector2(Layout.ledge_width(7)*0.5,0)
	_wheel(drawing,Layout.DESCENT[7]+Vector2(0,-260),24,route.harvest_height/40)
	_rope(drawing,catcher+Vector2(-30,0),Layout.DESCENT[7]+Vector2(-20,-260),1)
	_rope(drawing,Layout.DESCENT[7]+Vector2(20,-260),moving,1)
	for rock in route.rocks:_rock(drawing,Rect2(rock.p-Vector2(13,14),Vector2(27,28)),15 if rock.routed else 16)
	for puff in route.dust:
		var a:float=sin(clampf(puff.age/puff.life,0,1)*PI)*0.17
		drawing.draw_circle(puff.p,3+puff.age*7,Color(0.3,0.3,0.3,a))
	# Falling fragments are readable warnings before a rock enters the route.
	if route.stage==1:
		var phase:float=fmod(route.clock,4.2)
		if phase>3.0:
			for index in [10,18,26]:
				var at:Vector2=Layout.DESCENT[index]
				if absf(route.feet().y-at.y)<350:
					for i in 7:
						var q:=at+Vector2(95,-260)+Vector2(sin(float(i)*2.3)*20,float(i)*14+phase*18)
						drawing.draw_circle(q,0.8,Color(0.5,0.5,0.5,0.25))
		if route.rock_clock>3.0 and route.feet().distance_to(Layout.DESCENT[6])<600:
			for i in 8:
				var q:Vector2=Layout.DESCENT[6]+Vector2(-150+sin(float(i)*2.3)*16,-280+float(i)*9+route.rock_clock*12)
				drawing.draw_circle(q,0.9,Color(0.5,0.5,0.5,0.25))

func _draw_near()->void:
	# Keep the central play corridor clear. Structural ends enter from the
	# image edges, where their supports continue outside the camera.
	var station_weight:float=1.0-smoothstep(-3300,-2600,route.feet().y)
	if station_weight>0.001:
		var shift:float=sin(clock*0.27)*2
		_beam(near_ink,Vector2(-40,30),Vector2(200,70+shift),26,Color(0,0,0,0.6*station_weight))
		_rope(near_ink,Vector2(50,-20),Vector2(60+shift,170),8,Color(0,0,0,0.5*station_weight))
	if station_weight<0.999:
		for i in 3:
			var x:float=30+float(i)*610
			_beam(near_ink,Vector2(x,-25),Vector2(x+18,65+float(i)*30),28,Color(0,0,0,0.6*(1.0-station_weight)))
