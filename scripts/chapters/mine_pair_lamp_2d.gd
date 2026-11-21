extends Node2D
# Original housing, a complete suspension and a fixed mounting point.
const SOURCE=preload("res://assets/art/descent/mine-pair-v3/approved-source.png")
const SHADER=preload("res://assets/shaders/mine_pair_registered.gdshader")
const BULBS=[Vector2(258,152),Vector2(846,375),Vector2(515,686),Vector2(1539,451),Vector2(959,205),Vector2(790,710)]
# Rock ceiling / rock ceiling / underside of working deck /
# rock ceiling / rear rock ceiling / rear tunnel crossbeam, respectively.
const ANCHOR_Y=[56.0,38.0,538.0,188.0,24.0,620.0]
const SUPPORT_KIND=["rock","rock","working_deck","rock","rock","tunnel_beam"]
var lamp_index:=0
var elapsed:=0.0
var swing:Node2D
var cable:Line2D
var mounting_eye:Marker2D
var angular_velocity:=0.0
var swing_angle:=0.0
var suspension_length:=0.0
func _ready()->void:
 if get_meta("light_plane",&"background")==&"gameplay":add_to_group(&"chapter_gameplay_focus")
 var rear:=lamp_index>=4
 var ink:=ShaderMaterial.new();var shader:=Shader.new()
 shader.code="shader_type canvas_item; render_mode unshaded; uniform float tone=.02; void fragment(){ COLOR=vec4(vec3(tone),COLOR.a); }"
 ink.shader=shader;ink.set_shader_parameter("tone",[.012,.045,.009,.022,.030,.065][lamp_index])
 material=ink
 # Fixed plate and eye remain attached while the cable and shade rotate.
 draw.connect(func():
  draw_colored_polygon(PackedVector2Array([Vector2(-4,-3),Vector2(4,-3),Vector2(3,0),Vector2(-3,0)]),Color.WHITE)
  draw_arc(Vector2.ZERO,1.9,0,TAU,20,Color.WHITE,1.2,true))
 mounting_eye=Marker2D.new();mounting_eye.name="fixed_mounting_eye";add_child(mounting_eye)
 swing=Node2D.new();add_child(swing)
 var bulb:Vector2=BULBS[lamp_index]
 suspension_length=bulb.y-ANCHOR_Y[lamp_index]
 cable=Line2D.new();cable.name="suspension_cable";cable.width=.85 if rear else 1.15
 cable.antialiased=true;cable.material=ink
 cable.points=PackedVector2Array([Vector2.ZERO,Vector2(0,suspension_length-25)])
 swing.add_child(cable)
 # Crop only the original shade: its old truncated wire is not reused.
 var rect:=Rect2(bulb.x-28,bulb.y-31,56,39)
 var atlas:=AtlasTexture.new();atlas.atlas=SOURCE;atlas.region=rect;atlas.filter_clip=true
 var sprite:=Sprite2D.new();sprite.texture=atlas;sprite.centered=false
 sprite.position=rect.position-Vector2(bulb.x,ANCHOR_Y[lamp_index])
 var housing_material:=ShaderMaterial.new();housing_material.shader=SHADER
 housing_material.set_shader_parameter("approved_tex",SOURCE);housing_material.set_shader_parameter("layer_role",6)
 housing_material.set_shader_parameter("lamp_id",lamp_index);sprite.material=housing_material
 sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;swing.add_child(sprite)
 swing_angle=.035*sin(float(lamp_index)*1.91+.6)*(.75 if rear else 1.0)
 angular_velocity=.012*cos(float(lamp_index)*1.37+.3)
 set_angle(swing_angle)
func _process(delta:float)->void:
 if not is_visible_in_tree():return
 advance_swing(delta)
func advance_swing(delta:float)->void:
 # Integrate a damped pendulum in small time steps; longer suspensions
 # have longer periods. Weak air currents keep a little irregular motion.
 var remaining:=clampf(delta,0,.12)
 while remaining>.00001:
  var h:=minf(remaining,1.0/120.0);remaining-=h;elapsed+=h
  var phase:=float(lamp_index)*1.73
  var wind:float=(12*sin(elapsed*.41+phase)+5*sin(elapsed*.79+phase*.4))/suspension_length
  angular_velocity+=(-660.0/suspension_length*sin(swing_angle)-.10*angular_velocity+wind)*h
  swing_angle+=angular_velocity*h
  if absf(swing_angle)>.14:
   swing_angle=signf(swing_angle)*.14
   if angular_velocity*swing_angle>0:angular_velocity*= -.15
 set_angle(swing_angle)
func light_position()->Vector2:return swing.to_global(BULBS[lamp_index]-Vector2(BULBS[lamp_index].x,ANCHOR_Y[lamp_index]))
func light_angle()->float:return swing.global_rotation
func add_impulse(amount:float)->void:
 # A brief support acceleration changes angular velocity, never teleports
 # the shade to a new angle or resets the oscillation clock.
 angular_velocity=clampf(angular_velocity+amount,-.18,.18)
func set_angle(value:float)->void:swing.rotation=clampf(value,-.14,.14)
