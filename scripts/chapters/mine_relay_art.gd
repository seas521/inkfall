extends Node2D
# Rear plate, distant shaft silhouettes, rooted playing rock and independent
# ironwork. Nothing interactive is baked into the environmental painting.
const REAR=preload("res://assets/art/descent/mine-relay-v1/cavern-to-forest.png")
const Pendant=preload("res://scripts/chapters/mine_pendant.gd")
const DEPTH_SHADER=preload("res://assets/shaders/mine_relay_depth.gdshader")
const Dust=preload("res://assets/art/descent/mine-cart-escape-v1/mineral-dust.png")
const Softness=preload("res://scripts/chapters/mine_cached_softness.gd")
var relay
var rear:Sprite2D
var static_layer:Node2D
var dynamic:Node2D
var near_layer:Node2D
var fixture:Node2D
var lamp_cable:Line2D
var fixture_pivot:=Vector2(1085,-3420)
var lamp_angle:=0.0
var lamp_omega:=0.0
var lamps_age:=0.0
var particles:Array[Dictionary]=[]
var sparks:Array[Dictionary]=[]
var wreck_parts:Array[Dictionary]=[]
var clock:=0.0
var hammer_sprite:Sprite2D
var slider_sprite:Sprite2D
var slider_glow:ColorRect
var slider_electric:Node2D
var slider_sparks:Array[Dictionary]=[]
var slider_spark_emitted:=0
var slider_spark_distance:=0.0
var slider_previous:=0.0
var slider_arc_age:=0.0
var slider_arc_origin:=Vector2.ZERO
var slider_random:=RandomNumberGenerator.new()
var buffer_layer:Node2D
var warning_was_active:=false
func _ready()->void:
 # Continue the far wall into the actual fall space. The previous plate
 # stopped above the impact height, hiding black wreckage on black void.
 var abyss:=Sprite2D.new();abyss.name="deep_shaft_wall_continuation"
 abyss.texture=REAR;abyss.centered=false;abyss.position=Vector2(780,-2800)
 abyss.scale=Vector2(2200,1000)/REAR.get_size();abyss.z_as_relative=false;abyss.z_index=1
 var abyss_ink:=ShaderMaterial.new();abyss_ink.shader=preload("res://assets/shaders/mine_relay_abyss.gdshader")
 abyss.material=abyss_ink;add_child(abyss)
 rear=Sprite2D.new();rear.texture=REAR;rear.centered=false
 rear.position=Vector2(780,-3490);rear.scale=Vector2(2200,733.333)/REAR.get_size()
 rear.z_as_relative=false;rear.z_index=2
 var shader:=ShaderMaterial.new();shader.shader=DEPTH_SHADER;rear.material=shader
 add_child(rear)
 var continuation:=Sprite2D.new();continuation.texture=REAR;continuation.centered=false
 continuation.region_enabled=true;continuation.region_rect=Rect2(REAR.get_width()-600,0,600,REAR.get_height())
 continuation.position=Vector2(2830,-3490);continuation.scale=Vector2(1.8,733.333/REAR.get_height())
 continuation.z_as_relative=false;continuation.z_index=2
 var continuation_ink:=ShaderMaterial.new();continuation_ink.shader=DEPTH_SHADER
 continuation_ink.set_shader_parameter("origin",continuation.position)
 continuation_ink.set_shader_parameter("extent",Vector2(1080,733.333))
 continuation_ink.set_shader_parameter("left_feather",.15)
 continuation.material=continuation_ink;add_child(continuation)
 _build_ground_rock()
 static_layer=Node2D.new();static_layer.z_as_relative=false;static_layer.z_index=3
 static_layer.draw.connect(_draw_static);add_child(static_layer)
 near_layer=Node2D.new();near_layer.z_as_relative=false;near_layer.z_index=7
 add_child(near_layer);_build_near_rock()
 dynamic=Node2D.new();dynamic.z_as_relative=false;dynamic.z_index=4
 dynamic.draw.connect(_draw_dynamic);add_child(dynamic)
 fixture=Pendant.new();fixture.position=fixture_pivot+Vector2(0,70)
 fixture.z_as_relative=false;fixture.z_index=3;add_child(fixture)
 lamp_cable=Line2D.new();lamp_cable.width=1.6;lamp_cable.antialiased=true
 lamp_cable.default_color=Color(.006,.006,.006)
 lamp_cable.points=PackedVector2Array([fixture_pivot,fixture.position])
 lamp_cable.z_as_relative=false;lamp_cable.z_index=3;add_child(lamp_cable)
 hammer_sprite=Sprite2D.new();hammer_sprite.name="forged_rounded_pendulum_head"
 hammer_sprite.texture=preload("res://assets/art/descent/mine-relay-v2/symmetric-cast-impact-weight.png")
 hammer_sprite.scale=Vector2(64,86)/hammer_sprite.texture.get_size()
 hammer_sprite.offset=Vector2(1.5,-10/hammer_sprite.scale.y)
 hammer_sprite.z_as_relative=false;hammer_sprite.z_index=4
 var iron:=ShaderMaterial.new();iron.shader=preload("res://assets/shaders/mine_pendulum_iron.gdshader")
 hammer_sprite.material=iron;add_child(hammer_sprite)
 slider_sprite=Sprite2D.new();slider_sprite.name="large_handle_sliding_iron_box"
 slider_sprite.texture=preload("res://assets/art/descent/mine-slider-v18/iron-control-box.png")
 slider_sprite.scale=Vector2(82,52)/slider_sprite.texture.get_size()
 slider_sprite.z_as_relative=false;slider_sprite.z_index=4
 var slider_ink:=ShaderMaterial.new();slider_ink.shader=preload("res://assets/shaders/mine_slider_control.gdshader")
 slider_ink.set_shader_parameter("idle_strength",.025)
 slider_sprite.material=slider_ink;add_child(slider_sprite)
 slider_glow=ColorRect.new();slider_glow.mouse_filter=Control.MOUSE_FILTER_IGNORE
 slider_glow.size=Vector2(52,54);slider_glow.z_as_relative=false;slider_glow.z_index=5
 var bloom:=ShaderMaterial.new();bloom.shader=preload("res://assets/shaders/mine_slider_glow.gdshader")
 slider_glow.material=bloom;add_child(slider_glow)
 slider_electric=Node2D.new();slider_electric.z_as_relative=false;slider_electric.z_index=6
 var electric_blend:=CanvasItemMaterial.new();electric_blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
 slider_electric.material=electric_blend;slider_electric.draw.connect(_draw_slider_electric);add_child(slider_electric)
 slider_random.seed=18001
 buffer_layer=Node2D.new();buffer_layer.z_as_relative=false;buffer_layer.z_index=7
 buffer_layer.draw.connect(_draw_buffers);add_child(buffer_layer)
func _beam(canvas:Node2D,a:Vector2,b:Vector2,width:float,tone:float=.003)->void:
 var n:Vector2=(b-a).normalized().orthogonal()*width*.5
 canvas.draw_colored_polygon(PackedVector2Array([a+n*.94,b+n,b-n*.97,a-n]),Color(tone,tone,tone))
 canvas.draw_polyline(PackedVector2Array([a+n*.94,b+n]),Color(tone+.002,tone+.002,tone+.002),1.2,true)
func _rail(canvas:Node2D)->void:
 var path:=PackedVector2Array();var lower:=PackedVector2Array()
 for x in range(int(relay.room.STAIR_START+20),int(relay.RAMP_END)+1,5):
  var at:=Vector2(x,relay.track_y(x))
  path.append(at);lower.append(at+Vector2(0,5))
 for i in range(int(relay.room.STAIR_START+20),int(relay.RAMP_END)-6,22):
  var at:=Vector2(i,relay.track_y(i)+6)
  var rotation:float=relay.track_angle(i)
  var a:=at+Vector2(-7,0).rotated(rotation)
  var b:=at+Vector2(9,0).rotated(rotation)
  _beam(canvas,a,b,5,.004)
 canvas.draw_polyline(lower,Color(.010,.010,.010),3,true)
 canvas.draw_polyline(path,Color(.027,.027,.027),2.5,true)
 # The return siding follows the existing bank, with mounted timber
 # drag shoes below the wheels instead of a hidden auto-parking clamp.
 for x in range(450,738,24):
  var at:=Vector2(x,relay.track_y(x)+3)
  _beam(canvas,at+Vector2(-8,2),at+Vector2(8,2),9,.003)
  _beam(canvas,at+Vector2(-6,5),at+Vector2(6,5),3,.009)
 var guard:=Vector2(relay.room.STAIR_START+20,relay.track_y(relay.room.STAIR_START+20))
 var pitch:float=relay.track_angle(guard.x)
 _beam(canvas,guard+Vector2(-37,4).rotated(pitch),guard+Vector2(-34,-25).rotated(pitch),9,.003)
 _beam(canvas,guard+Vector2(-42,-23).rotated(pitch),guard+Vector2(-30,-23).rotated(pitch),8,.004)
 # A small broken tip with a dark underside, not a bright dotted line.
 var tip:=Vector2(relay.RAMP_END,relay.track_y(relay.RAMP_END))
 canvas.draw_line(tip,tip+Vector2(8,-5),Color(.022,.022,.022),2.5,true)
func _build_ground_rock()->void:
 var y:float=relay.room.TRACK_Y
 # Large quiet contours, visible bevel confined to actual lamp pools.
 Softness.polygon(self,PackedVector2Array([Vector2(1007,y+2),Vector2(1170,y+1),Vector2(1370,y+2),Vector2(1530,y+1),Vector2(1620,y+3),Vector2(1710,y-11),Vector2(1740,y+3),Vector2(1750,y+31),Vector2(1734,y+96),Vector2(1722,y+182),Vector2(1731,y+276),Vector2(1682,y+510),Vector2(1007,y+510)]),Color(.001,.001,.001),1.35,3).name="soft_launch_bank"
func _draw_static()->void:
 var y:float=relay.room.TRACK_Y
 _rail(static_layer)
 # The receiving car's best force range is a visible reinforced bed.
 for x in range(int(relay.RECEIVER_CENTER-70),int(relay.RECEIVER_CENTER+70)+1,16):
  var at:=Vector2(x,y+2)
  _beam(static_layer,at+Vector2(-6,0),at+Vector2(6,0),8,.004)
  static_layer.draw_circle(at+Vector2(0,-3),1.2,Color(.020,.020,.020),true,-1,true)
 for x in [relay.RECEIVER_CENTER-70,relay.RECEIVER_CENTER+70]:
  _beam(static_layer,Vector2(x-17,y-2),Vector2(x+17,y-2),5,.008)
  for dx in [-12.,12.]:static_layer.draw_circle(Vector2(x+dx,y-3),1.5,Color(.025,.025,.025),true,-1,true)
 # Steel fishplates supporting the upturned rail from the rooted bank.
 _beam(static_layer,Vector2(1690,y+26),Vector2(1860,y-78),12,.005)
 _beam(static_layer,Vector2(1690,y+86),Vector2(1800,y-35),11,.003)
 _beam(static_layer,Vector2(1690,y+20),Vector2(1690,y+89),18,.002)
 for x in [1738,1790,1844]:
  var at:=Vector2(x,relay.track_y(x)+7)
  static_layer.draw_circle(at,2.0,Color(.016,.016,.016),true,-1,true)
 # Pendulum has a buried bearing and an actual gantry, never a wire from air.
 var pivot:Vector2=relay.PIVOT
 _beam(static_layer,pivot+Vector2(-80,-92),pivot+Vector2(95,-92),32)
 _beam(static_layer,pivot+Vector2(-80,-92),pivot+Vector2(-68,38),24)
 _beam(static_layer,pivot+Vector2(95,-92),pivot+Vector2(52,43),22)
 _beam(static_layer,pivot+Vector2(-68,38),pivot+Vector2(52,43),24)
 _beam(static_layer,pivot+Vector2(-76,-56),pivot+Vector2(-5,28),14)
 static_layer.draw_circle(pivot,21,Color(.002,.002,.002),true,-1,true)
 static_layer.draw_circle(pivot,7,Color(.028,.028,.028),true,-1,true)
 # Open slide channel, separate carriage and raised end stops. The
 # projecting handles pass above the stops while the lower shoes meet them.
 var l:Vector2=relay.LEVER
 var floor_y:float=relay.room.TRACK_Y
 _beam(static_layer,Vector2(l.x-95,floor_y+1),Vector2(l.x+95,floor_y+1),8,.002)
 for dy in [-12.,-5.]:
  _beam(static_layer,Vector2(l.x-78,floor_y+dy),Vector2(l.x+78,floor_y+dy),4,.003)
 for side in [-1.,1.]:
  # Stops meet the box's solid sliding sole, below its open hand grips.
  var x:float=l.x+side*78
  _beam(static_layer,Vector2(x,floor_y-4),Vector2(x,floor_y-14),8,.002)
  _beam(static_layer,Vector2(x-side*3,floor_y-14),Vector2(x+side*4,floor_y-14),5,.004)
 # Cable guide bolts physically mount into a continuous ceiling brace.
 _beam(static_layer,Vector2(750,-3440),Vector2(1100,-3420),13)
 _beam(static_layer,Vector2(300,-3430),Vector2(750,-3440),15)
 _beam(static_layer,Vector2(300,-3530),Vector2(300,-3400),20)
 _beam(static_layer,Vector2(1100,-3420),Vector2(1110,-3520),21)
 _beam(static_layer,fixture_pivot+Vector2(-7,-20),fixture_pivot+Vector2(7,2),10)
 # Worn ballast/direction pictograms on a rear-mounted sign; no floating tools.
 var sign:=Vector2(1125,y-100)
 _beam(static_layer,Vector2(sign.x+8,y+4),sign+Vector2(8,-6),7)
 static_layer.draw_colored_polygon(PackedVector2Array([sign+Vector2(-31,-15),sign+Vector2(28,-13),sign+Vector2(35,0),sign+Vector2(26,15),sign+Vector2(-30,13)]),Color(.007,.007,.007))
 static_layer.draw_line(sign+Vector2(-16,0),sign+Vector2(17,0),Color(.055,.055,.055),1.4,true)
 static_layer.draw_polyline(PackedVector2Array([sign+Vector2(10,-5),sign+Vector2(17,0),sign+Vector2(10,5)]),Color(.055,.055,.055),1.4,true)
func _build_near_rock()->void:
 var y:float=relay.room.TRACK_Y
 # A shallow foreground rock lip overlaps old and new ground horizontally.
 Softness.polygon(self,PackedVector2Array([Vector2(990,y+12),Vector2(1090,y+10),Vector2(1300,y+15),Vector2(1520,y+12),Vector2(1660,y+18),Vector2(1730,y+30),Vector2(1700,y+500),Vector2(990,y+500)]),Color(.0008,.0008,.0008),1.6,7).name="soft_near_rock_lip"
 # The mouth opens upward before the descent, rather than carrying a
 # flat ceiling and a transition curtain across the visible forest.
 var brow:=Curve2D.new();brow.bake_interval=8
 brow.add_point(Vector2(920,-3478),Vector2.ZERO,Vector2(180,12))
 brow.add_point(Vector2(1650,-3440),Vector2(-180,-12),Vector2(160,10))
 brow.add_point(Vector2(2220,-3425),Vector2(-150,-9),Vector2(150,-5))
 brow.add_point(Vector2(2580,-3510),Vector2(-110,45),Vector2(90,-100))
 brow.add_point(Vector2(2810,-3900),Vector2(-35,120),Vector2(15,-120))
 brow.add_point(Vector2(2850,-4350),Vector2(-5,120),Vector2.ZERO)
 var roof:=brow.get_baked_points();roof.append(Vector2(920,-4350))
 Softness.polygon(self,roof,Color(.001,.001,.001),1.6,7).name="soft_cave_roof"
func impact(at:Vector2,strength:float,rail_sparks:bool=true)->void:
 lamp_omega+=clampf(strength*.003,-.18,.18)
 for i in 12:
  var a:float=float(i)*2.39996
  particles.append({"p":at+Vector2(sin(a)*16,-absf(cos(a))*8),"v":Vector2(sin(a)*strength,-12-absf(cos(a))*strength*.65),"age":0.,"life":.45+float(i%5)*.09,"size":Vector2(23+i%4*9,11+i%3*6),"angle":a})
 for i in 26:
  var a:float=sin(i*4.7)*1.1
  var direction:float=-1 if i%2==0 else 1
  sparks.append({"p":at+Vector2(sin(i*2.1)*2,cos(i*3.7)*3),"v":Vector2(direction*(95+float(i%7)*26),-35-float(i%5)*27).rotated(a*.45),"age":0.,"life":.16+float(i%6)*.035})
 # Wheel/rail friction sprays at the actual contact footprint as well.
 for i in (8 if rail_sparks else 0):
  sparks.append({"p":Vector2(at.x+(i-4)*5,relay.room.TRACK_Y-1),"v":Vector2(-55-i*10,-12-i%4*14),"age":0.,"life":.18+i%3*.035})
func bank_crash(at:Vector2,incoming:Vector2)->void:
 var first_spark:=sparks.size()
 impact(at,100,false)
 for i in range(first_spark,sparks.size()):
  sparks[i].v.x=-absf(sparks[i].v.x)
  if i%4==0:sparks[i].v.y=absf(sparks[i].v.y)*.5
 for i in 2:
  wreck_parts.append({"wheel":true,"p":at+Vector2(-10-i*7,12),"v":Vector2(-130-i*55,-155+i*40),"age":-.065,"life":1.8,"angle":.2,"spin":-8.0-i*2,"size":15.0-i*2})
 for i in 12:
  var stone:bool=i%3==0
  var size:=Vector2(5+i%4*3,3+i%3*3)
  var outline:=PackedVector2Array([Vector2(-.9,-.3)*size,Vector2(-.25,-.7)*size,Vector2(.85,-.35)*size,Vector2(.55,.6)*size,Vector2(-.65,.4)*size])
  wreck_parts.append({"wheel":false,"p":at+Vector2(-float(i%4)*3,float(i%5)*4-6),"v":Vector2(-65-float(i%5)*32,-145+float(i%4)*45),"age":-.02-float(i%3)*.025,"life":1.5+float(i%4)*.12,"angle":float(i),"spin":sin(i*3.1)*7,"shape":outline,"tone":.016 if stone else .002})
 for i in 10:
  particles.append({"p":at+Vector2(-3-i%3*7,i*4-17),"v":Vector2(-25-i%4*20,-22+i%5*14),"age":0.,"life":.8+i%4*.12,"size":Vector2(26+i%4*10,19+i%3*12),"angle":float(i)*1.7,"gravity":85.,"drag":1.1,"opacity":.20,"tone":.12})
func _draw_wreck_parts()->void:
 for part in wreck_parts:
  if part.age<0:continue
  var fade:float=1-smoothstep(part.life-.25,part.life,part.age)
  buffer_layer.draw_set_transform(part.p,part.angle)
  if part.wheel:
   var r:float=part.size
   buffer_layer.draw_arc(Vector2.ZERO,r,0,TAU,40,Color(.003,.003,.003,fade),3.5,true)
   buffer_layer.draw_circle(Vector2.ZERO,3.1,Color(.003,.003,.003,fade),true,-1,true)
   for i in 5:
    var tip:=Vector2.from_angle(TAU*i/5)*r
    buffer_layer.draw_line(tip*.18,tip*.88,Color(.005,.005,.005,fade),2.4,true)
  else:
   var tone:float=part.tone
   buffer_layer.draw_colored_polygon(part.shape,Color(tone,tone,tone,fade))
  buffer_layer.draw_set_transform(Vector2.ZERO)
func tick(delta:float)->void:
 clock+=delta;lamps_age+=delta
 var left:=minf(delta,.12)
 while left>.000001:
  var h:=minf(left,1./120.);left-=h
  lamp_omega+=(-980./150.*sin(lamp_angle)-.42*lamp_omega+sin(lamps_age*.71)*.008)*h
  lamp_angle=clampf(lamp_angle+lamp_omega*h,-.16,.16)
 fixture.position=fixture_pivot+Vector2(sin(lamp_angle)*70,cos(lamp_angle)*70)
 fixture.rotation=lamp_angle;fixture.update_swing(delta)
 lamp_cable.points=PackedVector2Array([fixture_pivot,fixture.position])
 rear.material.set_shader_parameter("lamp",fixture.light_position())
 rear.material.set_shader_parameter("lamp_angle",fixture.light_angle())
 for mote in particles:
  mote.age+=delta;mote.v.y+=float(mote.get("gravity",0))*delta
  mote.v*=exp(-delta*float(mote.get("drag",2.1)));mote.p+=mote.v*delta
 for part in wreck_parts:
  part.age+=delta
  if part.age<0:continue
  part.v.y+=980*delta;part.p+=part.v*delta;part.angle+=part.spin*delta
 wreck_parts=wreck_parts.filter(func(p):return p.age<p.life)
 if wreck_parts.size()>24:wreck_parts=wreck_parts.slice(wreck_parts.size()-24)
 particles=particles.filter(func(p):return p.age<p.life)
 for spark in sparks:
  spark.age+=delta;spark.v.y+=700*delta;spark.p+=spark.v*delta
 sparks=sparks.filter(func(p):return p.age<p.life)
 if sparks.size()>90:sparks=sparks.slice(sparks.size()-90)
 if particles.size()>48:particles=particles.slice(particles.size()-48)
 _tick_slider_feedback(delta)
 slider_sprite.position=Vector2(relay.LEVER.x+relay.slider_position,relay.room.TRACK_Y-30.5)
 slider_sprite.material.set_shader_parameter("lamp_left",relay.slider_lamp if relay.slider_position<0 else 0.0)
 slider_sprite.material.set_shader_parameter("lamp_right",relay.slider_lamp if relay.slider_position>0 else 0.0)
 slider_glow.position=slider_sprite.position+Vector2(-12 if relay.slider_position<0 else 12,2.6)-slider_glow.size*.5
 slider_glow.material.set_shader_parameter("strength",relay.slider_lamp)
 var bob:Vector2=relay.PIVOT+Vector2(sin(relay.angle),cos(relay.angle))*relay.LENGTH
 hammer_sprite.position=bob+relay.warning_offset();hammer_sprite.rotation=-relay.angle
 if relay.warning_strength>.15 and not warning_was_active:
  warning_was_active=true
  particles.append({"p":relay.PIVOT+Vector2(0,8),"v":Vector2(-3,14),"age":0.,"life":.6,"size":Vector2(17,25),"angle":.2})
 if relay.warning_strength<=0:warning_was_active=false
 dynamic.queue_redraw()
 buffer_layer.queue_redraw()
func _cable_arc(path:PackedVector2Array,center:Vector2,radius:float,first:float,last:float)->void:
 while last<first:last+=TAU
 for i in range(1,33):
  path.append(center+Vector2.from_angle(lerpf(first,last,float(i)/32))*radius)
func _haul_cable(side:float,attachment:Vector2,sag:float)->PackedVector2Array:
 var left:=Vector2(300,-3413);var right:=Vector2(1085,-3413)
 var radius:=18.0 if side<0 else 13.0
 var guide:Vector2=left if side<0 else right
 var lead:=attachment-guide
 var normal:=lead.normalized().rotated(acos(clampf(radius/lead.length(),-1,1)))
 var entry:=guide+normal*radius
 var path:=PackedVector2Array()
 for i in 25:
  var t:=float(i)/24
  path.append(attachment.lerp(entry,t)+Vector2(0,pow(sin(PI*t),2)*sag))
 var drum_end:Vector2=Vector2(relay.LEVER.x+side*18,relay.room.TRACK_Y-8)
 if side<0:
  _cable_arc(path,left,radius,normal.angle(),-PI*.5)
  path.append(right+Vector2(0,-radius))
  var drop:=drum_end-right
  var exit_normal:=drop.normalized().rotated(-acos(clampf(radius/drop.length(),-1,1)))
  _cable_arc(path,right,radius,-PI*.5,exit_normal.angle())
 else:
  var drop:=drum_end-right
  var exit_normal:=drop.normalized().rotated(-acos(clampf(radius/drop.length(),-1,1)))
  _cable_arc(path,right,radius,normal.angle(),exit_normal.angle())
 path.append(drum_end)
 return path
func _draw_dynamic()->void:
 var bob:Vector2=relay.PIVOT+Vector2(sin(relay.angle),cos(relay.angle))*relay.LENGTH
 bob+=relay.warning_offset()
 # A single iron arm enters the worn hammer's short socketed shaft.
 var axis:Vector2=(bob-relay.PIVOT).normalized()
 _beam(dynamic,relay.PIVOT,bob-axis*43,10,.002)
 # Reversible two-line haul: each cable goes through a seated side
 # sheave and onto its own half of the winding drum. In freewheel both
 # pay out, rather than a decorative line holding a freely swinging head.
 var left_guide:=Vector2(300,-3413)
 var right_guide:=Vector2(1085,-3413)
 var attachment:=bob-axis*40
 for side in [-1.,1.]:
  var guide:Vector2=left_guide if side<0 else right_guide
  var hauling:bool=relay.charge_owner and relay.control_side==side
  var sag:float=1.0 if hauling else (7.0 if relay.pendulum_live else 3.0)
  var cable:=_haul_cable(side,attachment,sag)
  dynamic.draw_polyline(cable,Color(.006,.006,.006),1.6,true)
 for wheel:Vector2 in [left_guide,right_guide]:
  dynamic.draw_arc(wheel,18,0,TAU,48,Color(.003,.003,.003),3,true)
  dynamic.draw_arc(wheel,13,0,TAU,48,Color(.004,.004,.004),3,true)
  for i in 5:
   var a:float=TAU*i/5.+relay.angle*4
   dynamic.draw_line(wheel+Vector2(3,0).rotated(a),wheel+Vector2(11,0).rotated(a),Color(.006,.006,.006),2.3,true)
 # Mounted band brake on the main shaft. Its shoes visibly withdraw when
 # the freewheel clutch opens; the haul, not a delayed timer, sets height.
 var brake:float=relay.brake_amount
 dynamic.draw_arc(relay.PIVOT,28,PI*.10,PI*1.90,60,Color(.004,.004,.004),5,true)
 for side in [-1.,1.]:
  var shoe:Vector2=relay.PIVOT+Vector2(side*(31+(1-brake)*5),0)
  _beam(dynamic,shoe+Vector2(0,-15),shoe+Vector2(0,15),6,.002)
  _beam(dynamic,shoe+Vector2(side*2,-9),relay.PIVOT+Vector2(side*47,-32),5,.003)
 # The two carriage shoes move inside the fixed channel. No part of
 # the rail follows the hands; the character follows the actual slider.
 var shuttle:=Vector2(relay.LEVER.x+relay.slider_position,relay.room.TRACK_Y)
 # A continuous wear strip touches the channel; no legs or chassis gap.
 _beam(dynamic,shuttle+Vector2(-31,-9),shuttle+Vector2(31,-9),6,.001)
 for mote in particles:
  var t:float=mote.age/mote.life
  dynamic.draw_set_transform(mote.p,mote.angle)
  var size:Vector2=mote.size*(1+t*.55)
  var tone:float=mote.get("tone",.15)
  dynamic.draw_texture_rect(Dust,Rect2(-size*.5,size),false,Color(tone,tone,tone,(1-t)*float(mote.get("opacity",.10))))
 dynamic.draw_set_transform(Vector2.ZERO)
 for spark in sparks:
  var t:float=spark.age/spark.life
  dynamic.draw_line(spark.p-spark.v.normalized()*(4+minf(6,spark.v.length()*.02))*(1-t),spark.p,Color(.72,.69,.60,(1-t)*.9),1.15,true)

func _draw_buffers()->void:
 # Visible buffer rods and plates share the solver's exact contact span.
 for index in 2:
  if relay.cart_lost[index] or (index==1 and relay.wrecked):continue
  var at:Vector2=relay.cart_at(index)+Vector2(0,relay.suspension[index])
  buffer_layer.draw_set_transform(at,relay.pitches[index])
  for side in [-1.,1.]:
   var stroke:float=absf(relay.impact_shift[index]) if side==relay.contact_sides[index] else 0.0
   var face:float=side*(relay.BUMPER_HALF-stroke)
   buffer_layer.draw_line(Vector2(side*24,-23),Vector2(face,-23),Color(.004,.004,.004),4,true)
   buffer_layer.draw_line(Vector2(face,-29),Vector2(face,-17),Color(.009,.009,.009),3,true)
   buffer_layer.draw_line(Vector2(side*26,-25),Vector2(side*31,-25),Color(.019,.019,.019),.85,true)
  buffer_layer.draw_set_transform(Vector2.ZERO)
 _draw_wreck_parts()

func reset_slider_feedback()->void:
 slider_sparks.clear();slider_spark_emitted=0;slider_spark_distance=0;slider_previous=0;slider_arc_age=0
 if slider_electric!=null:slider_electric.queue_redraw()
func _tick_slider_feedback(delta:float)->void:
 for spark in slider_sparks:
  spark.age+=delta;spark.v.y+=430*delta;spark.v*=exp(-1.8*delta);spark.p+=spark.v*delta
 slider_sparks=slider_sparks.filter(func(spark):return spark.age<spark.life)
 slider_arc_age=maxf(0,slider_arc_age-delta)
 var moved:float=relay.slider_position-slider_previous
 slider_previous=relay.slider_position
 if relay.charge_owner and relay.lever_contact and absf(moved)>.025:
  slider_spark_distance+=absf(moved)
  while slider_spark_distance>=2.6:
   slider_spark_distance-=2.6
   var heading:=signf(moved)
   slider_arc_origin=Vector2(relay.LEVER.x+relay.slider_position+heading*31,relay.room.TRACK_Y-9)
   slider_arc_age=.045
   var count:=slider_random.randi_range(3,5)
   for i in count:
    var vx:float=heading*slider_random.randf_range(25,105)*( -1.0 if i%3==0 else 1.0)
    slider_sparks.append({"p":slider_arc_origin+Vector2(slider_random.randf_range(-1,1),0),"v":Vector2(vx,slider_random.randf_range(-105,-25)),"age":0.0,"life":slider_random.randf_range(.10,.24),"length":slider_random.randf_range(2.2,6.5),"width":slider_random.randf_range(.65,1.1)})
    slider_spark_emitted+=1
 if slider_sparks.size()>48:slider_sparks=slider_sparks.slice(slider_sparks.size()-48)
 if slider_electric!=null:slider_electric.queue_redraw()
func _draw_slider_electric()->void:
 # White needle-like cores, weak feathered shoulders and short falling
 # streaks, observed from LIMBO's electrified rail. No colored fireballs.
 for spark in slider_sparks:
  var fade:float=pow(1.0-float(spark.age)/float(spark.life),1.35)
  var tip:Vector2=spark.p
  var tail:Vector2=tip-Vector2(spark.v).normalized()*float(spark.length)*(.4+.6*fade)
  slider_electric.draw_line(tail,tip,Color(1,1,1,fade*.035),float(spark.width)*4.0,true)
  slider_electric.draw_line(tail,tip,Color(1,1,1,fade*.13),float(spark.width)*2.0,true)
  slider_electric.draw_line(tail,tip,Color(1,1,1,fade*.82),float(spark.width),true)
 if slider_arc_age>0:
  var fade:float=slider_arc_age/.045
  var at:=slider_arc_origin
  var points:=PackedVector2Array([at+Vector2(-2,2),at+Vector2(-.7,-.8),at+Vector2(1.0,1.1),at+Vector2(2,-1)])
  slider_electric.draw_polyline(points,Color(1,1,1,fade*.08),3.0,true)
  slider_electric.draw_polyline(points,Color(1,1,1,fade*.85),.85,true)
