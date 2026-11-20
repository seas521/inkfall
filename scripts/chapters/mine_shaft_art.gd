extends Node2D
const DEPTH=preload("res://assets/art/descent/mine-v10/depth-exit.png")
const BALLAST=preload("res://assets/art/descent/mine-v12/ballast.png")
const STONE=preload("res://assets/art/descent/mine-v12/stone-2.png")
const Pendant=preload("res://scripts/chapters/mine_pendant.gd")
const UPPER:=-3170.0
const LOWER:=-2940.0
var shaft
var background:Node2D
var machinery:Node2D
var fore:Node2D
var lamps:Array[Node2D]=[]
var textures:Dictionary={}
var depth_ink:ShaderMaterial
var mechanism_ink:ShaderMaterial
var rock_ink:ShaderMaterial
var lower_rock:Node2D

func _ready()->void:
	lower_rock=Node2D.new();lower_rock.z_index=-1;add_child(lower_rock)
	rock_ink=ShaderMaterial.new();rock_ink.shader=preload("res://assets/shaders/mine_shaft_rock_depth.gdshader")
	lower_rock.material=rock_ink
	lower_rock.draw.connect(_draw_lower_rock)
	background=Node2D.new();background.z_index=-1;add_child(background)
	depth_ink=ShaderMaterial.new();depth_ink.shader=preload("res://assets/shaders/mine_shaft_depth.gdshader")
	background.material=depth_ink;background.draw.connect(_draw_depth)
	machinery=Node2D.new();machinery.z_index=3;add_child(machinery)
	mechanism_ink=ShaderMaterial.new();mechanism_ink.shader=depth_ink.shader
	mechanism_ink.set_shader_parameter("silhouette",true)
	machinery.material=mechanism_ink;machinery.draw.connect(_draw_mechanisms)
	fore=Node2D.new();fore.z_index=6;add_child(fore);fore.draw.connect(_draw_fore)
	for name in ["cage","headframe","pulley","counterweight","lock-pin"]:
		textures[name]=load("res://assets/art/descent/mine-shaft-v1/"+name+".png")
	for at in [Vector2(-1820,UPPER-171),Vector2(-1625,UPPER-178),Vector2(-1145,UPPER-210),Vector2(-1680,LOWER-155),Vector2(-1280,LOWER-155),Vector2(-1025,-2700),Vector2(-1025,-1750),Vector2(-1010,-770)]:
		var lamp:=Pendant.new();lamp.position=at-Pendant.BULB_OFFSET;lamp.phase=lamps.size()*1.73
		lamp.z_index=2;add_child(lamp);lamps.append(lamp)
	queue_redraw()

func _process(_delta:float)->void:
	visible=shaft.route.enabled and shaft.route.shaft_preview and not shaft.route.in_c_zone
	if not visible:return
	var positions:=PackedVector2Array();var angles:=PackedFloat32Array()
	for lamp in lamps:
		lamp.update_swing(_delta);positions.append(lamp.light_position());angles.append(lamp.light_angle())
	for ink in [depth_ink,mechanism_ink,rock_ink]:
		ink.set_shader_parameter("lamps",positions);ink.set_shader_parameter("tilts",angles)
	background.queue_redraw();machinery.queue_redraw();fore.queue_redraw();queue_redraw()

func _bay(rect:Rect2,lower:bool=false)->void:
	# Authored rock remains in depth, separate from interactive supports.
	var uv:=PackedVector2Array([Vector2(.40,.11),Vector2(.59,.11),Vector2(.59,.45),Vector2(.40,.45)])
	if lower:uv=PackedVector2Array([Vector2(.59,.12),Vector2(.40,.12),Vector2(.40,.44),Vector2(.59,.44)])
	var p:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	background.draw_polygon(p,PackedColorArray([Color.WHITE]),uv,DEPTH)

func _draw_depth()->void:
	_bay(Rect2(-2190,UPPER-320,1245,365))
	_bay(Rect2(-2015,UPPER+15,920,285),true)
	pass # continuous authored bedrock is a separate depth plane
	# Exit light gradually reveals the existing forest farther below.
	pass
	for i in 7:
		var x:float=-1850+i*117
		background.draw_line(Vector2(x,LOWER-135),Vector2(x+12,LOWER-8),Color(.02,.02,.02),5,true)
		background.draw_line(Vector2(x,LOWER-135),Vector2(x+50,LOWER-118),Color(.02,.02,.02),4,true)

func _plate(a:Vector2,b:Vector2,depth:float=24)->void:
	var top:=PackedVector2Array()
	for i in 13:
		var p:=a.lerp(b,i/12.0);p.y+=sin(i*2.73)*.6;top.append(p)
	top.append(b+Vector2(0,depth));top.append(a+Vector2(0,depth))
	if a.y>shaft.EXIT_Y-5 and b.y>shaft.EXIT_Y and depth>12.0:
		var anchor_x:float=-920 if (a.x+b.x)*.5 < -580 else -240
		var root:=PackedVector2Array()
		if anchor_x<a.x:
			root=PackedVector2Array([a,b,b+Vector2(0,12),Vector2(a.x-20,a.y+38),Vector2(anchor_x,a.y+125),Vector2(anchor_x,a.y+8)])
		elif anchor_x>b.x:
			root=PackedVector2Array([a,b,Vector2(anchor_x,b.y+8),Vector2(anchor_x,b.y+125),Vector2(b.x+20,b.y+38),a+Vector2(0,12)])
		if root.size()>2:draw_colored_polygon(root,Color(.003,.003,.003))

	draw_colored_polygon(top,Color(.002,.002,.002))
	for i in int(maxf(1,a.distance_to(b)/80)):
		var t:float=float(i)/maxf(1,a.distance_to(b)/80)
		var p:=a.lerp(b,t)
		draw_texture_rect(BALLAST,Rect2(p+Vector2(-2,-1),Vector2(84,12)),false,Color(.12,.12,.12))

func _draw()->void:
	draw_colored_polygon(PackedVector2Array([Vector2(-2210,-5200),Vector2(2000,-5200),Vector2(2000,-3470),Vector2(-1160,-3495),Vector2(-1590,-3475),Vector2(-2210,-3485)]),Color.BLACK)
	_plate(Vector2(-2180,UPPER),Vector2(-2010,UPPER))
	if not shaft.inspected or not shaft.jammed:
		_plate(Vector2(-2010,UPPER),Vector2(-1900,UPPER),12)
	else:
		draw_line(Vector2(-2010,UPPER),Vector2(-2014,UPPER-66),Color(.012,.012,.012),7,true)
	_plate(Vector2(-1900,UPPER),Vector2(-1130,UPPER))
	_plate(Vector2(-1990,UPPER+8),Vector2(-1760,LOWER),24)
	_plate(Vector2(-1760,LOWER),Vector2(-1120,LOWER),80)
	# Main walkway and recessed rear weighbridge are separate depth planes.
	var depth:float=shaft.tray_depth
	draw_line(Vector2(-1700,UPPER-1),Vector2(-1580,UPPER-1),Color(.018,.018,.018),3,true)
	for i in 23:
		var x:float=-2160+i*45
		var y:float=UPPER-3+(depth if absf(x-shaft.TRAY_X)<53 else 0.0)
		draw_line(Vector2(x-10,y+3),Vector2(x+11,y+5),Color(.018,.018,.018),4,true)
		if i>0:
			var previous:float=x-45
			var py:float=UPPER-3+(depth if absf(previous-shaft.TRAY_X)<53 else 0.0)
			draw_line(Vector2(previous,py),Vector2(x,y),Color(.075,.075,.075),1.2,true)
	var switch_start:=Vector2(-1280,UPPER-4)
	var switch_end:=Vector2(-1130,UPPER-4 if shaft.routed else UPPER+14)
	draw_line(switch_start,switch_end,Color(.09,.09,.09),2.2,true)
	for y in range(-3140,-530,180):
		for x in [-1175,-920]:
			draw_line(Vector2(x,y-120),Vector2(x,y+100),Color(.008,.008,.008),14,true)
			draw_line(Vector2(-1175,y),Vector2(-920,y),Color(.014,.014,.014),5,true)
	for beam in [-2480,-1580]:
		# A sloping silhouette and hanging fragments telegraph the low clearance.
		draw_colored_polygon(PackedVector2Array([Vector2(-1170,beam-24),Vector2(-920,beam-14),Vector2(-920,beam+18),Vector2(-1070,beam+24),Vector2(-1170,beam+10)]),Color(.004,.004,.004))
		for j in 5:draw_line(Vector2(-1150+j*46,beam+14),Vector2(-1145+j*46,beam+28+(j%2)*8),Color(.012,.012,.012),3,true)
	# The actual exit landings, with a broken middle span rather than empty props.
	_plate(Vector2(-970,shaft.EXIT_Y),Vector2(-820,shaft.EXIT_Y+48))
	if shaft.fragile_age<=.75:
		_plate(Vector2(-760,shaft.EXIT_Y+115),Vector2(-680,shaft.EXIT_Y+115),12)
		draw_polyline(PackedVector2Array([Vector2(-721,shaft.EXIT_Y+114),Vector2(-724,shaft.EXIT_Y+120),Vector2(-715,shaft.EXIT_Y+126)]),Color(.09,.09,.09),1,true)
	for pair in [[Vector2(-590,-335),Vector2(-440,-327)],[Vector2(-740,-245),Vector2(-620,-237)],[Vector2(-510,-155),Vector2(-380,-147)],[Vector2(-660,-65),Vector2(-550,-57)],[Vector2(-450,25),Vector2(-320,33)],[Vector2(-600,115),Vector2(-470,123)],[Vector2(-410,205),Vector2(-280,213)],[Vector2(-220,300),Vector2(-180,310)]]:_plate(pair[0],pair[1],65)

func _asset(name:String,canvas:Node2D,at:Vector2,size:Vector2)->void:
	if textures.get(name)!=null:canvas.draw_texture_rect(textures[name],Rect2(at-size*.5,size),false)

func _draw_mechanisms()->void:
	# Rear rack, pulleys and headframe sit behind the actor; the cage lip is
	# drawn separately in the foreground so the player is inside the structure.
	_asset("headframe",machinery,Vector2(-1040,UPPER-125),Vector2(250,365))
	_asset("pulley",machinery,Vector2(-1040,UPPER-280),Vector2(60,60))
	_asset("pulley",machinery,Vector2(-1640,UPPER-280),Vector2(46,46))
	var tray:=Vector2(-1640,UPPER+shaft.tray_depth)
	var weight:=Vector2(-1810,LOWER-90-shaft.tray_depth*.6)
	_asset("counterweight",machinery,weight,Vector2(85,136))
	for offset in [-7,7]:
		machinery.draw_line(tray+Vector2(offset,-5),Vector2(-1640+offset,UPPER-280),Color(.07,.07,.07),1.5,true)
		machinery.draw_line(Vector2(-1640+offset,UPPER-280),Vector2(-1040+offset,UPPER-280),Color(.07,.07,.07),1.5,true)
		machinery.draw_line(Vector2(-1040+offset,UPPER-280),Vector2(-1040+offset,shaft.cage_y-145),Color(.07,.07,.07),1.5,true)
	machinery.draw_line(Vector2(-1640,UPPER-280),Vector2(-1810,UPPER-245),Color(.05,.05,.05),2,true)
	machinery.draw_line(Vector2(-1810,UPPER-245),weight-Vector2(0,58),Color(.05,.05,.05),2,true)
	_asset("cage",machinery,Vector2(-1040,shaft.cage_y-80),Vector2(202,202))
	# Recessed scale, ratchet and lock share a visibly connected load frame.
	machinery.draw_line(Vector2(-1700,tray.y),Vector2(-1580,tray.y),Color(.14,.14,.14),9,true)
	machinery.draw_line(Vector2(-1580,tray.y),Vector2(-1370,LOWER-125),Color(.06,.06,.06),2,true)
	_asset("lock-pin",machinery,Vector2(shaft.PIN_X+(6 if shaft.pin_locked else 0)+sin(shaft.clock*42)*shaft.refusal*2,LOWER-36),Vector2(45,45))
	machinery.draw_line(Vector2(-1370,LOWER-125),Vector2(shaft.PIN_X,LOWER-36),Color(.08,.08,.08),2,true)
	var gate_y:float=LOWER-54-minf(shaft.tray_depth/18,1)*115
	for i in 5:machinery.draw_line(Vector2(-1370+i*2,gate_y-52),Vector2(-1370+i*2,gate_y+52),Color(.065,.065,.065),1.5,true)
	if shaft.jammed:
		machinery.draw_texture_rect(STONE,Rect2(shaft.jam_body.position-Vector2(30,27),Vector2(60,54)),false)
	for x in [shaft.PROBE_X,shaft.POINTS_X]:
		var working:bool=(x==shaft.PROBE_X and shaft.operation=="probe") or (x==shaft.POINTS_X and shaft.operation=="points")
		var progress:float=shaft.operation_progress if working else (1.0 if shaft.routed and x==shaft.POINTS_X else 0.0)
		progress+=sin(shaft.clock*35)*shaft.refusal*.07
		var base:=Vector2(x,UPPER-4)
		machinery.draw_line(base,base+Vector2(-10-progress*18,-40+progress*10),Color(.13,.13,.13),4,true)
		machinery.draw_line(base+Vector2(-18,2),base+Vector2(13,2),Color(.1,.1,.1),6,true)
	# A real service ladder joins both decks, its rungs never light up alone.
	for x in [-1480,-1460]:machinery.draw_line(Vector2(x,UPPER-24),Vector2(x,LOWER),Color(.12,.12,.12),2,true)
	for y in range(int(UPPER-20),int(LOWER),13):machinery.draw_line(Vector2(-1480,y),Vector2(-1460,y+1),Color(.13,.13,.13),2,true)

func _draw_fore()->void:
	var y:float=shaft.cage_y
	fore.draw_line(Vector2(-1130,y+3),Vector2(-950,y+3),Color(.002,.002,.002),8,true)
	# One-sided rails frame the actor without blocking the cage entrance.
	fore.draw_line(Vector2(-1125,y-37),Vector2(-1125,y+3),Color(.004,.004,.004),4,true)
	fore.draw_line(Vector2(-955,y-37),Vector2(-955,y+3),Color(.004,.004,.004),4,true)

func _draw_lower_rock()->void:
	lower_rock.draw_texture_rect(preload("res://assets/art/descent/mine-shaft-v1/shaft-depth-v1.png"),Rect2(-1450,-3400,1400,3700),false)
