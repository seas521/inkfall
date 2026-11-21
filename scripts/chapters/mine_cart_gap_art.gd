extends Node2D
# Static bank commands remain cached; only the small deck and carried rock redraw.
const Chock=preload("res://scripts/chapters/mine_cart_chock_art.gd")
const DEPTH=preload("res://assets/art/descent/mine-v10/depth-exit.png")
const Pendant=preload("res://scripts/chapters/mine_pendant.gd")
const PairRoom=preload("res://scripts/chapters/mine_cart_pair_room.gd")
var gap
var dynamic:Node2D
var front:Node2D
var shore:Node2D
var wall:Node2D
var ink:ShaderMaterial
var service_lamp:Node2D
var pair_room:Node2D
func _ready()->void:
 # One continuous authored mine back wall spans the parking bay, break,
 # and next chamber. Keep the outdoor ravine plate disabled.
 wall=Node2D.new();wall.z_index=-5;wall.draw.connect(_draw_wall);add_child(wall)
 ink=ShaderMaterial.new();ink.shader=preload("res://assets/shaders/mine_black_plate.gdshader")
 ink.set_shader_parameter("rows",2.0);ink.set_shader_parameter("row",0.0)
 ink.set_shader_parameter("seam_left",-1460.0)
 wall.material=ink
 service_lamp=Pendant.new();service_lamp.z_index=0
 service_lamp.position=Vector2(-770,-3260)-Pendant.BULB_OFFSET;add_child(service_lamp)
 pair_room=PairRoom.new();pair_room.gap=gap;add_child(pair_room)
 shore=Node2D.new();shore.z_index=2;shore.draw.connect(_draw_shore);add_child(shore)
 dynamic=Node2D.new();dynamic.draw.connect(_draw_dynamic);add_child(dynamic)
 front=Node2D.new();front.z_index=2;front.draw.connect(_draw_front);add_child(front)
func tick(_delta:float)->void:
 service_lamp.update_swing(_delta)
 ink.set_shader_parameter("lamp",gap.escape.end_lamp.light_position())
 ink.set_shader_parameter("angle",gap.escape.end_lamp.light_angle())
 ink.set_shader_parameter("end_lamp",service_lamp.light_position())
 ink.set_shader_parameter("end_tilt",service_lamp.light_angle())
 ink.set_shader_parameter("aux_lamp",pair_room.lamp.light_position())
 ink.set_shader_parameter("aux_angle",pair_room.lamp.light_angle())
 ink.set_shader_parameter("aux2_lamp",pair_room.far_lamp.light_position())
 ink.set_shader_parameter("aux2_angle",pair_room.far_lamp.light_angle())
 pair_room.tick(_delta)
 dynamic.queue_redraw();front.queue_redraw()
func _draw_shore()->void:
 # The new authored layers own the bank. The old filled polygon would
 # black out the lower working chamber.
 # Bare compacted mine floor, with the rock face rooted below it.
 var y:float=gap.rail_y(gap.RAIL_END)
 for i in ceili((gap.RAIL_END-gap.escape.EDGE_X)/16.0):
  var x:float=gap.escape.EDGE_X+float(i)*16
  shore.draw_line(Vector2(x-2,y+2),Vector2(x+5,y+11+sin(i*3)*2),Color(.018,.018,.018),5,true)
 shore.draw_line(Vector2(gap.escape.EDGE_X-5,y),Vector2(gap.RAIL_END+2,y),Color(.047,.047,.047),2.7,true)
 shore.draw_line(Vector2(gap.escape.EDGE_X-5,y+5),Vector2(gap.RAIL_END-3,y+5),Color(.015,.015,.015),3.2,true)
 shore.draw_line(Vector2(gap.RAIL_END,y),Vector2(gap.RAIL_END+7,y+3),Color(.04,.04,.04),2,true)
func _draw_dynamic()->void:
 for chip in gap.rail_chips:
  var d:Vector2=Vector2(cos(chip.angle),sin(chip.angle))*chip.length
  dynamic.draw_line(chip.p-d,chip.p+d,Color(.035,.035,.035,1.0-smoothstep(1.3,2.2,chip.age)),1.4,true)
 var a:Vector2=gap.DECK_ANCHOR
 for side in [-1.0,1.0]:
  var b:Vector2=gap.deck.to_global(Vector2(side*37,-7))
  var anchor:=a+Vector2(side*46,0)
  dynamic.draw_line(anchor,b,Color(.012,.012,.012),2.3,true)
  dynamic.draw_line(anchor+Vector2(3,0),b+Vector2(3,0),Color(.023,.023,.023),1.0,true)
 if gap.rock_visible and gap.rock_state>0 and not gap.escape.chock_present and not gap.level.actor.heavy_item.visible:
  Chock.draw_stone(dynamic,gap.rock_position,gap.rock_angle)
func _draw_front()->void:
 front.draw_set_transform(gap.deck.position,gap.tilt)
 for i in 5:
  var x:float=-45+float(i)*18
  front.draw_colored_polygon(PackedVector2Array([Vector2(x,-7+sin(i*3)*1.2),Vector2(x+16,-7+sin(i)*.9),Vector2(x+17,6),Vector2(x+1,8)]),Color(.009,.009,.009))
  front.draw_line(Vector2(x+2,-6),Vector2(x+14,-6),Color(.045,.045,.045),.8,true)
 front.draw_line(Vector2(-40,10),Vector2(40,8),Color(.014,.014,.014),4,true)
 for side in [-1.0,1.0]:
  front.draw_line(Vector2(side*37,-10),Vector2(side*37,15),Color(.025,.025,.025),2,true)
 front.draw_set_transform(Vector2.ZERO)

func _draw_wall()->void:
 # Sample only the underground row's open bay. Its floor stays behind the
 # playing plane: the foreground break remains a genuine unfilled void.
 for i in 64:
  var x0:float=lerpf(-1460,960,float(i)/64)
  var x1:float=lerpf(-1460,960,float(i+1)/64)
  var points:=PackedVector2Array([Vector2(x0,-3510),Vector2(x1,-3510),Vector2(x1,-2390),Vector2(x0,-2390)])
  var u0:float=lerpf(.30,.52,float(i)/64)
  var u1:float=lerpf(.30,.52,float(i+1)/64)
  wall.draw_polygon(points,PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(u0,.13),Vector2(u1,.13),Vector2(u1,.39),Vector2(u0,.39)]),DEPTH)
  # Continue the same cave air beneath wide framing, without a flat
  # rectangular backdrop end cutting across the open fracture.
  var lower:=PackedVector2Array([Vector2(x0,-2390),Vector2(x1,-2390),Vector2(x1,-1650),Vector2(x0,-1650)])
  wall.draw_polygon(lower,PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(u0,.39),Vector2(u1,.39),Vector2(u1,.42),Vector2(u0,.42)]),DEPTH)
 # Continuous solid overburden, with broad, quiet changes of direction.
 var roof:=PackedVector2Array([Vector2(-1460,-3900),Vector2(960,-3900)])
 for i in range(64,-1,-1):
  var x:float=lerpf(-1460,960,float(i)/64)
  var y:float=-3330-48*smoothstep(-1130,-690,x)+sin(x*.005)*13+sin(x*.011)*4
  roof.append(Vector2(x,y))
 wall.draw_colored_polygon(roof,Color(.002,.002,.002))
