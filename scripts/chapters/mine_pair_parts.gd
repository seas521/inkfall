extends Node2D
# Independent, complete parts for the approved 2D mine. No puzzle state is
# advanced here; setters also allow checking full travel before gameplay.
const KIT=preload("res://assets/art/descent/mine-pair-v3/props.png")
const RIG=preload("res://assets/art/descent/mine-pair-v3/restraint.png")
const INK=preload("res://assets/shaders/mine_pair_layer.gdshader")
const HempRope=preload("res://scripts/chapters/mine_hemp_rope.gd")
var room
var parts:Dictionary={}
var native_ink:ShaderMaterial
var moving_clamp:Node2D
var basket:Node2D
var ballast:Node2D
var lever:Node2D
var drum:Node2D
var crown_wheel:Node2D
var guide_wheel:Node2D
var basket_rope:Node2D
var clamp_rope:Line2D
var restraint_fairlead:Node2D
var restraint_rope_eye:Marker2D
var basket_wall_material:ShaderMaterial
var basket_front:Node2D
var selector_mount:Node2D
var balance_rope:Line2D
var basket_rest:=Vector2(515,844)
var basket_travel:=360.0
var drum_phase:=0.0
var basket_rise:=0.0
var clamp_rise:=0.0
var clamp_rest:=Vector2(1188,554)
# The ore cradle is low enough to load over its rim by hand. Suspension
# and tub are separate: compressing the whole sprite would shorten the sling.
const BASKET_TUB_SCALE:=.62
const BASKET_RIM_Y:=-4.0
const BASKET_SEAT_Y:=23.0
const BASKET_REST:=Vector2(515,844)
const CROWN:=Vector2(510,101)
const CROWN_RADIUS:=44.0
const DRUM_CENTER:=Vector2(302,286)
const DRUM_RADIUS:=22.0
var drum_takeoff:=Vector2.ZERO
var crown_entry:=Vector2.ZERO
var crown_exit:=Vector2.ZERO
const GUIDE:=Vector2(1023,427)
const GUIDE_RADIUS:=21.6
# Measured centre of the protruding guide sleeve in restraint.png.
const RESTRAINT_FAIRLEAD:=Vector2(1184,427)
const CLAMP_REST:=Vector2(1188,554)
const CLAMP_TRAVEL:=42.0
const TOOL_HOOK_X=[16.0,55.0,94.0]
func _material(near:bool=true)->ShaderMaterial:
 var m:=ShaderMaterial.new();m.shader=INK;m.set_shader_parameter("near_ink",near)
 m.set_shader_parameter("value_scale",.74 if near else 1.0)
 return m
func _node(key:String,at:Vector2,depth:int)->Node2D:
 if native_ink==null:
  native_ink=ShaderMaterial.new();var shader:=Shader.new()
  shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){ COLOR=vec4(vec3(.00012),COLOR.a); }"
  native_ink.shader=shader
 var n:=Node2D.new();n.name=key;n.position=room.ORIGIN+at
 n.material=native_ink
 n.z_as_relative=false;n.z_index=depth;add_child(n);parts[key]=n
 return n
func _piece(parent:Node2D,source:Texture2D,rect:Rect2,source_pivot:Vector2,near:bool=true)->Sprite2D:
 var atlas:=AtlasTexture.new();atlas.atlas=source;atlas.region=rect;atlas.filter_clip=true
 var sprite:=Sprite2D.new();sprite.texture=atlas;sprite.centered=false
 sprite.position=rect.position-source_pivot;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 sprite.material=_material(near);parent.add_child(sprite);return sprite
func _round(sprite:Sprite2D,pivot:Vector2,radius:float)->void:
 sprite.material.set_shader_parameter("round_crop",true)
 sprite.material.set_shader_parameter("crop_center",pivot)
 sprite.material.set_shader_parameter("crop_radius",radius)
func _rope()->Line2D:
 var line:=Line2D.new();line.width=1.35;line.default_color=Color(.003,.003,.003)
 line.antialiased=true;line.material=native_ink;line.z_as_relative=false;line.z_index=3;add_child(line);return line
func _contact(n:Node2D,key:String,at:Vector2,size:Vector2)->void:
 var marker:=Marker2D.new();marker.name=key;marker.position=at;n.add_child(marker)
 var area:=Area2D.new();area.name=key+"_reach";area.position=at
 area.collision_layer=0;area.collision_mask=0;area.monitoring=false;n.add_child(area)
 var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=size;shape.shape=box;area.add_child(shape)
 n.set_meta("interaction_anchor",marker.get_path())
func _ink_shape(parent:Node2D,points:PackedVector2Array)->void:
 var shape:=Polygon2D.new();shape.polygon=points;shape.color=Color(.003,.003,.003)
 shape.antialiased=true;shape.use_parent_material=true;parent.add_child(shape)
func _draw_restraint()->void:
 # Slender bent iron saddle: two short shoes bear on the cart's rim.
 # The cheeks overlap the outside lip rather than hanging above the car.
 _ink_shape(moving_clamp,[Vector2(-66,0),Vector2(-58,-4),Vector2(-22,-9),Vector2(20,-9),Vector2(58,-4),Vector2(66,0),Vector2(64,7),Vector2(22,0),Vector2(-22,0),Vector2(-64,7)])
 for side:float in [-1.0,1.0]:
  _ink_shape(moving_clamp,[Vector2(side*48,-3),Vector2(side*60,0),Vector2(side*60,17),Vector2(side*54,20),Vector2(side*48,16)])
 moving_clamp.draw.connect(func():
  var eye_x:float=restraint_rope_eye.position.x
  moving_clamp.draw_arc(Vector2(eye_x,-15),7,0,TAU,32,Color(.003,.003,.003),3,true)
  moving_clamp.draw_arc(Vector2(eye_x,-30),5,-.8,4.5,24,Color(.003,.003,.003),3,true)
  moving_clamp.draw_line(Vector2(eye_x,-25),Vector2(eye_x,-22),Color(.003,.003,.003),3,true))
func _pick_profile(tool:Node2D,length_scale:float)->void:
 tool.draw.connect(func():
  tool.draw_arc(Vector2.ZERO,3.2,0,TAU,24,Color.WHITE,1.3,true)
  tool.draw_line(Vector2(0,3),Vector2(0,10),Color.WHITE,2.1,true)
  # One long curved pick, one shorter flat adze: not a symmetric arch
  # with an extra horizontal bar like the former atlas drawing.
  tool.draw_colored_polygon(PackedVector2Array([Vector2(-22,24),Vector2(-19,16),Vector2(-12,11),Vector2(-4,9),Vector2(2,11),Vector2(8,10),Vector2(17,11),Vector2(18,17),Vector2(8,16),Vector2(3,16),Vector2(-3,14),Vector2(-10,15),Vector2(-16,18)]),Color.WHITE)
  tool.draw_polyline(PackedVector2Array([Vector2(0,13),Vector2(-.6,30*length_scale),Vector2(.3,51*length_scale),Vector2(-1.5,73*length_scale)]),Color.WHITE,3,true))
func _rope_coil_profile(tool:Node2D)->void:
 tool.draw.connect(func():
  tool.draw_arc(Vector2.ZERO,3.2,0,TAU,24,Color.WHITE,1.3,true)
  tool.draw_line(Vector2(0,3),Vector2(0,6),Color.WHITE,1.6,true)
  for j in 3:
   var strand:=PackedVector2Array()
   for k in 49:
    var a:=TAU*float(k)/48.0
    strand.append(Vector2(sin(a)*(7.0+float(j)*.6)+float(j-1)*.45,21.0-cos(a)*(16.0+float(j)*.5)))
   tool.draw_polyline(strand,Color.WHITE,1.15,true)
  tool.draw_polyline(PackedVector2Array([Vector2(-1,37),Vector2(-.7,45),Vector2(-2,49)]),Color.WHITE,1.2,true)
  tool.draw_polyline(PackedVector2Array([Vector2(2,37),Vector2(3,43),Vector2(2,47)]),Color.WHITE,1.2,true))
func _ready()->void:
 var base:=_node("winch_base",Vector2(300,326),3)
 _piece(base,KIT,Rect2(236,258,163,72),Vector2(300,326))
 lever=_node("winch_lever",Vector2(279,261),4)
 _piece(lever,KIT,Rect2(276,193,40,68),Vector2(279,261))
 _contact(base,"crank_hands",Vector2(-59,-50),Vector2(65,80))
 drum=_node("winch_drum",DRUM_CENTER,4);drum.material=null;drum.draw.connect(_draw_drum)
 crown_wheel=_node("headframe_sheave",CROWN,4)
 var crown_sprite:=_piece(crown_wheel,KIT,Rect2(459,51,106,100),CROWN)
 _round(crown_sprite,CROWN,46.0)
 # Independent tool profiles, each located by its actual hanging eye.
 var upper_rack:=_node("upper_tool_rack",Vector2(140,316),1)
 upper_rack.draw.connect(func():
  upper_rack.draw_line(Vector2(0,0),Vector2(2,-97),Color(.003,.003,.003),5,true)
  upper_rack.draw_line(Vector2(106,0),Vector2(103,-97),Color(.003,.003,.003),5,true)
  upper_rack.draw_line(Vector2(1,-81),Vector2(104,-81),Color(.003,.003,.003),5,true)
  for x:float in TOOL_HOOK_X:
   upper_rack.draw_line(Vector2(x,-82),Vector2(x,-75),Color(.003,.003,.003),3,true))
 for i in 3:
  var hook:=Marker2D.new();hook.name="hook_"+str(i)
  hook.position=Vector2(TOOL_HOOK_X[i],-78);upper_rack.add_child(hook)
  var tool:=_node(["hung_pick_long","hung_pick_short","hung_rope_coil"][i],Vector2(140,316)+hook.position,1)
  var eye:=Marker2D.new();eye.name="hanging_eye";tool.add_child(eye)
  var tone:=ShaderMaterial.new();var shader:=Shader.new()
  shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){ COLOR=vec4(vec3(.00012),COLOR.a); }"
  tone.shader=shader;tool.material=tone
  if i<2:
   _pick_profile(tool,1.0 if i==0 else .86)
   if i==1:tool.scale.x=-.9
  else:_rope_coil_profile(tool)
 var shovels:=_node("lower_tool_rack",Vector2(380,890),1)
 var shovel_sprite:=_piece(shovels,KIT,Rect2(338,729,84,108),Vector2(380,835),false)
 shovel_sprite.material.set_shader_parameter("flat_ink_tone",.00012)
 # A grounded rack, behind tools, not three freestanding shovels.
 var rack_shader:=Shader.new();rack_shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){ COLOR=vec4(vec3(.00012),COLOR.a); }"
 var rack_material:=ShaderMaterial.new();rack_material.shader=rack_shader;shovels.material=rack_material
 shovels.draw.connect(func():
  shovels.draw_line(Vector2(-46,-62),Vector2(44,-62),Color(.018,.018,.018),6,true)
  shovels.draw_line(Vector2(-45,0),Vector2(-40,-88),Color(.018,.018,.018),6,true)
  shovels.draw_line(Vector2(43,0),Vector2(38,-88),Color(.018,.018,.018),6,true))
 basket=_node("ore_basket",BASKET_REST,3)
 _piece(basket,KIT,Rect2(466,755,103,66),BASKET_REST)
 _basket_tub(basket)
 basket.draw.connect(func():
  for side in [-1.,1.]:
   basket.draw_line(Vector2(side*35,-24),Vector2(side*43,BASKET_RIM_Y+3),Color.BLACK,2.2,true))
 _contact(basket,"basket_load",Vector2(0,-7),Vector2(88,62))
 ballast=_node("ballast",Vector2(643,880),4)
 _piece(ballast,KIT,Rect2(596,803,95,75),Vector2(643,872))
 _contact(ballast,"lift_hands",Vector2(-31,-23),Vector2(70,70))
 # Fixed rig pieces NEVER contain a cart or a moving restraint.
 var gantry:=_node("fixed_gantry",Vector2.ZERO,3)
 var rig_top:=_piece(gantry,RIG,Rect2(991,397,368,48),Vector2.ZERO)
 rig_top.material.set_shader_parameter("part_mask",2)
 var rear_upright:=_piece(gantry,RIG,Rect2(1303,441,57,229),Vector2.ZERO)
 rear_upright.material.set_shader_parameter("flat_ink_tone",.0035)
 gantry.draw.connect(func():
  gantry.draw_colored_polygon(PackedVector2Array([Vector2(1247,439),Vector2(1265,437),Vector2(1322,491),Vector2(1322,516)]),Color(.003,.003,.003)))
 # Axle bracket bolts through the timber; the sheave sits in a fork,
 # with a visible axle cap in front. It is not a disk pasted onto the end.
 var bearing:=_node("restraint_axle_bracket",GUIDE,3)
 _ink_shape(bearing,[Vector2(-20,-12),Vector2(46,-14),Vector2(46,12),Vector2(18,14),Vector2(2,5),Vector2(-20,5)])
 var axle_cap:=_node("restraint_axle_cap",GUIDE,5)
 axle_cap.draw.connect(func():
  axle_cap.draw_line(Vector2(0,0),Vector2(29,9),Color(.003,.003,.003),5,true)
  axle_cap.draw_circle(Vector2.ZERO,4.6,Color(.003,.003,.003))
  axle_cap.draw_line(Vector2(29,-15),Vector2(29,13),Color(.003,.003,.003),4,true))
 # Independent wheel texture reused at a smaller axle; actual rope radius
 # determines angular travel, not an unrelated looping animation.
 guide_wheel=_node("restraint_sheave",GUIDE,4)
 var guide_sprite:=_piece(guide_wheel,KIT,Rect2(459,51,106,100),CROWN)
 _round(guide_sprite,CROWN,46.0)
 guide_wheel.scale=Vector2.ONE*.47
 restraint_fairlead=_node("restraint_beam_guide",RESTRAINT_FAIRLEAD,3)
 for entry in [["inlet",Vector2(0,-21)],["outlet",Vector2(0,19)]]:
  var marker:=Marker2D.new();marker.name=entry[0];marker.position=entry[1];restraint_fairlead.add_child(marker)
 moving_clamp=_node("lifting_restraint",CLAMP_REST,6)
 restraint_rope_eye=Marker2D.new();restraint_rope_eye.name="rope_eye";restraint_rope_eye.position=Vector2(0,-30);moving_clamp.add_child(restraint_rope_eye)
 _draw_restraint()
 _contact(moving_clamp,"cart_contact",Vector2(0,8),Vector2(124,16))
 var plate:=_node("pressure_plate",Vector2(879,513),4)
 var plate_base:=_node("pressure_plate_base",Vector2(879,513),3)
 plate_base.draw.connect(func():
  plate_base.draw_line(Vector2(-29,6),Vector2(29,6),Color(.002,.002,.002),3,true)
  plate_base.draw_line(Vector2(-29,3),Vector2(-29,7),Color(.002,.002,.002),2,true)
  plate_base.draw_line(Vector2(29,3),Vector2(29,7),Color(.002,.002,.002),2,true))
 plate.draw.connect(func():
  plate.draw_line(Vector2(-32,0),Vector2(32,-1),Color(.003,.003,.003),6,true)
  # Riveted eye on the moving board; the rope terminates through its eye.
  plate.draw_line(Vector2(23,-1),Vector2(29,-1),Color(.003,.003,.003),3,true)
  plate.draw_arc(Vector2(26,-4),3,0,TAU,20,Color(.003,.003,.003),1.8,true))
 var rope_anchor:=Marker2D.new();rope_anchor.name="rope_anchor";rope_anchor.position=Vector2(26,-4);plate.add_child(rope_anchor)
 var rope_guide:=_node("plate_rope_guide",Vector2(970,483),4)
 rope_guide.draw.connect(func():
  rope_guide.draw_line(Vector2(0,0),Vector2(0,8),Color(.003,.003,.003),3,true)
  rope_guide.draw_arc(Vector2.ZERO,2.6,0,TAU,20,Color(.003,.003,.003),1.6,true))
 _contact(plate,"plate_load",Vector2(0,-15),Vector2(62,36))
 # Counterbalance sits behind the right pier; the plate therefore lifts
 # only a small residual load. The approved raised frame does not move a car.
 var balance:=_node("restraint_counterweight",Vector2(1350,524),2)
 balance.draw.connect(func():
  balance.draw_rect(Rect2(-10,-16,20,32),Color(.009,.009,.009)))
 basket_rope=HempRope.new();basket_rope.name="flexible_hoist_hemp_rope"
 basket_rope.z_as_relative=false;basket_rope.z_index=5;add_child(basket_rope)
 clamp_rope=_rope();balance_rope=_rope();_sync_ropes()
func fit_to_floor()->void:
 # The free hanging leg must be vertical at rest: hang below the
 # sheave's right tangent, rather than below its axle / old atlas pivot.
 var hanging_x:float=CROWN.x+CROWN_RADIUS
 var floor_y:float=room.lower_floor_y(room.ORIGIN.x+hanging_x)
 basket_rest=Vector2(hanging_x,floor_y-room.ORIGIN.y-36.0)
 basket_travel=floor_y-room.MID_Y
 ballast.position.y=room.lower_floor_y(room.ORIGIN.x+643)+2.0
 parts["lower_tool_rack"].position.y=room.lower_floor_y(room.ORIGIN.x+380)+5.0
 set_basket_rise(0)
func fit_restraint_to_cart(cart:Node2D,at:Vector2)->void:
 # All three cars share the original hollow cart model. Fit this room's
 # saddle to its actual projected tub, not the discarded atlas silhouette.
 var bounds:=Rect2(cart.grip_outline[0],Vector2.ZERO)
 for point:Vector2 in cart.grip_outline:bounds=bounds.expand(point)
 moving_clamp.scale.x=(bounds.size.x-6.0)/108.0
 clamp_rest=at-room.ORIGIN+Vector2(bounds.get_center().x,bounds.position.y-12.0)
 # The saddle is fitted to the cart, but the iron sleeve is fixed to the
 # beam. Move only the eye within the saddle so the hanging leg remains
 # coaxial with the actual hole through the entire lifting stroke.
 restraint_rope_eye.position.x=(RESTRAINT_FAIRLEAD.x-clamp_rest.x)/moving_clamp.scale.x
 moving_clamp.queue_redraw()
 set_restraint_rise(0)
func _draw_drum()->void:
 # Coil marks wrap on a cylindrical drum instead of rotating its body
 # silhouette like a flat wheel. This is deliberately subdued in the ink.
 drum.draw_rect(Rect2(-25,-17,50,34),Color(.0008,.0008,.0008))
 for i in 8:
  var phase:=fposmod(drum_phase+float(i)/8.0,1.0)
  var x:=lerpf(-25,25,phase)
  drum.draw_polyline(PackedVector2Array([Vector2(x-1,-16),Vector2(x+1,-7),Vector2(x+1,7),Vector2(x-1,16)]),Color(.008,.008,.008),.85,true)
 drum.draw_line(Vector2(-26,-18),Vector2(-26,18),Color(.001,.001,.001),3,true)
 drum.draw_line(Vector2(26,-18),Vector2(26,18),Color(.001,.001,.001),3,true)
func _hoist_cable_path()->PackedVector2Array:
 # A common external tangent leaves the actual drum surface and meets
 # the upper-left wheel groove. The hanging leg leaves the right groove
 # tangentially; starting at the axle/bottom of the disk is incorrect.
 var drum_at:Vector2=room.ORIGIN+DRUM_CENTER
 var crown_at:Vector2=room.ORIGIN+CROWN
 var delta:Vector2=crown_at-drum_at
 var normal:=delta.normalized().rotated(-acos((DRUM_RADIUS-CROWN_RADIUS)/delta.length()))
 drum_takeoff=drum_at+normal*DRUM_RADIUS
 crown_entry=crown_at+normal*CROWN_RADIUS
 var end:Vector2=to_local(basket.to_global(Vector2(0,-84)))
 var hanging:Vector2=end-crown_at
 var exit_normal:=hanging.normalized().rotated(-acos(CROWN_RADIUS/hanging.length()))
 crown_exit=crown_at+exit_normal*CROWN_RADIUS
 var start_angle:=normal.angle()
 var end_angle:=exit_normal.angle()
 while end_angle<start_angle:end_angle+=TAU
 var path:=PackedVector2Array([drum_takeoff,crown_entry])
 for i in range(1,49):
  path.append(crown_at+Vector2.from_angle(lerpf(start_angle,end_angle,float(i)/48))*CROWN_RADIUS)
 path.append(end)
 return path
func _sync_ropes()->void:
 if balance_rope!=null:balance_rope.points=PackedVector2Array([room.ORIGIN+Vector2(1350,435),parts["restraint_counterweight"].position-Vector2(0,16)])
 if basket_rope!=null:basket_rope.set_path(_hoist_cable_path(),-basket_rise)
 var anchor:Marker2D=parts["pressure_plate"].get_node("rope_anchor")
 var inlet:Marker2D=restraint_fairlead.get_node("inlet")
 var outlet:Marker2D=restraint_fairlead.get_node("outlet")
 clamp_rope.points=PackedVector2Array([to_local(anchor.global_position),to_local(parts["plate_rope_guide"].global_position),parts["restraint_sheave"].position+Vector2(-15,-15),to_local(inlet.global_position),to_local(outlet.global_position),to_local(restraint_rope_eye.global_position)])
func set_basket_rise(distance:float)->void:
 basket_rise=clampf(distance,0,basket_travel)
 basket.position=room.ORIGIN+basket_rest-Vector2(0,basket_rise)
 crown_wheel.rotation=-basket_rise/44.0
 var next_phase:=basket_rise/(TAU*DRUM_RADIUS)
 if not is_equal_approx(drum_phase,next_phase):drum_phase=next_phase;drum.queue_redraw()
 _sync_ropes()
 if basket_front!=null:sync_basket_front()
func configure_selector()->void:
 # Side selector at hand height: the tall decorative handle was above
 # the boy's head and could not be operated from the approved platform.
 for child in lever.get_children():
  if child is Sprite2D:child.hide()
 lever.position=room.ORIGIN+Vector2(302,281);lever.rotation=0
 lever.draw.connect(func():
  lever.draw_line(Vector2(13,0),Vector2(-50,0),Color(.003,.003,.003),4,true)
  lever.draw_line(Vector2(-50,-8),Vector2(-50,8),Color(.003,.003,.003),5,true))
 var handle:=Marker2D.new();handle.name="selector_hand";handle.position=Vector2(-50,0);lever.add_child(handle)
 selector_mount=_node("selector_collar",Vector2(302,281),5)
 selector_mount.draw.connect(func():
  selector_mount.draw_rect(Rect2(-8,-6,16,12),Color(.003,.003,.003)))
 basket_front=_node("basket_near_lip",BASKET_REST,6)
 # Include the actual rolled rim (atlas y821), not a slice below it.
 var near_tub:=_basket_tub(basket_front)
 basket_wall_material=near_tub.material
 basket_wall_material.set_shader_parameter("basket_wall",true)
 sync_basket_front()
func set_selector(stroke:float)->void:
 lever.position=room.ORIGIN+Vector2(302-clampf(stroke,0,1)*14,281)
 lever.rotation=0
func selector_grip()->Vector2:return lever.to_global(Vector2(-50,0))
func _basket_tub(parent:Node2D)->Sprite2D:
 var tub:=_piece(parent,KIT,Rect2(466,821,103,57),BASKET_REST)
 tub.scale.y=BASKET_TUB_SCALE
 tub.position.y=BASKET_RIM_Y
 return tub
func sync_basket_front()->void:
 if basket_front==null:return
 basket_front.transform=basket.transform
 if basket_wall_material!=null:
  var mouth:Vector2=basket.to_global(Vector2(0,BASKET_RIM_Y))
  var nearest:=Vector2.ZERO
  var nearest_distance:=INF
  for fixture in room.lamps:
   var bulb:Vector2=fixture.light_position()
   if bulb.distance_squared_to(mouth)<nearest_distance:
    nearest=bulb;nearest_distance=bulb.distance_squared_to(mouth)
  basket_wall_material.set_shader_parameter("basket_mouth",mouth)
  basket_wall_material.set_shader_parameter("basket_lamp",nearest)
func set_restraint_rise(distance:float)->void:
 clamp_rise=clampf(distance,0,CLAMP_TRAVEL)
 moving_clamp.position=room.ORIGIN+clamp_rest-Vector2(0,clamp_rise)
 guide_wheel.rotation=clamp_rise/GUIDE_RADIUS
 parts["restraint_counterweight"].position=room.ORIGIN+Vector2(1350,524+clamp_rise)
 _sync_ropes()
func reset_pose()->void:
 set_basket_rise(0);set_restraint_rise(0)
