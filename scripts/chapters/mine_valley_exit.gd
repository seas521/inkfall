extends Node2D
# A registered walking bank, independent root dressing and the existing C
# forest preview. The coordinate handoff preserves screen-space transforms.
const C_OFFSET:=Vector2(3600,-3050)
const C_START:=3080.0
const JOIN_X:=3420.0
const INK:=Color("050606")
const ROOTS=preload("res://assets/art/descent/mine-valley-exit-v8/rooted-rock-bank.png")
const Softness=preload("res://scripts/chapters/mine_cached_softness.gd")
const Plants=preload("res://scripts/chapters/mine_valley_plants.gd")
var relay
var detached:=false
var terrain:Polygon2D
var body:StaticBody2D
var top:=PackedVector2Array()
var face:=PackedVector2Array()
var collider_points:=PackedVector2Array()
func _ready()->void:
 var curve:=Curve2D.new();var x:float=relay.EXIT_X;var y:float=relay.EXIT_Y
 curve.bake_interval=5
 curve.add_point(Vector2(x,y),Vector2.ZERO,Vector2(-15,16))
 curve.add_point(Vector2(x-22,y+70),Vector2(1,-26),Vector2(-5,37))
 curve.add_point(Vector2(x-29,y+170),Vector2(-4,-33),Vector2(6,48))
 curve.add_point(Vector2(x-7,y+315),Vector2(-12,-49),Vector2(15,90))
 curve.add_point(Vector2(x+39,y+585),Vector2(-18,-80),Vector2(29,116))
 curve.add_point(Vector2(x+116,y+1200),Vector2(-33,-130),Vector2.ZERO)
 face=curve.get_baked_points()
 for at in range(int(x),int(JOIN_X+180),6):top.append(Vector2(at,ground_y(at)))
 top.append(Vector2(JOIN_X+180,ground_y(JOIN_X+180)))
 collider_points=top.duplicate()
 collider_points.append(Vector2(top[-1].x,y+1500))
 collider_points.append(Vector2(face[-1].x,y+1500))
 for i in range(face.size()-1,-1,-1):collider_points.append(face[i])
 body=StaticBody2D.new();body.name="registered_valley_bank";body.collision_layer=1;body.collision_mask=0
 var shape:=CollisionPolygon2D.new();shape.polygon=collider_points;body.add_child(shape);add_child(body)
 terrain=Polygon2D.new();terrain.polygon=collider_points;terrain.color=INK
 terrain.z_as_relative=false;terrain.z_index=3
 terrain.clip_children=CanvasItem.CLIP_CHILDREN_AND_DRAW
 add_child(terrain)
 var roots:=Sprite2D.new();roots.texture=ROOTS;roots.centered=false
 roots.position=Vector2(x+130,y-70);roots.scale=Vector2(750,300)/ROOTS.get_size()
 var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/mine_valley_rock.gdshader")
 roots.material=material;terrain.add_child(roots)
 var bounds:=Rect2(collider_points[0],Vector2.ZERO)
 for point in collider_points:bounds=bounds.expand(point)
 Softness.node(self,terrain,bounds,1.35,3).name="soft_rooted_valley_bank"
 var plants:=Plants.new();plants.ground=ground_y;plants.start_x=x;add_child(plants)
 z_as_relative=false;z_index=3
 queue_redraw()
func ground_y(x:float)->float:
 var start:float=relay.EXIT_X+450
 if x<=start:return relay.EXIT_Y
 if x>=C_START:return relay.room.gap.level.ground_y(x-C_OFFSET.x)+C_OFFSET.y
 var t:float=clampf((x-start)/(C_START-start),0,1)
 # Hermite end tangents join the level landing and C's existing 1:10 bank.
 var end:float=280+C_OFFSET.y
 var h00:=2*t*t*t-3*t*t+1
 var h01:=-2*t*t*t+3*t*t
 var h11:=t*t*t-t*t
 return h00*relay.EXIT_Y+h01*end+h11*(C_START-start)*.1
func face_x(y:float)->float:
 if face.is_empty():return relay.EXIT_X
 for i in face.size()-1:
  if y>=face[i].y and y<=face[i+1].y:
   return lerpf(face[i].x,face[i+1].x,inverse_lerp(face[i].y,face[i+1].y,y))
 return face[0].x if y<face[0].y else face[-1].x
func set_enabled(value:bool)->void:
 if detached:return
 visible=value
 if body!=null:body.collision_layer=1 if value else 0
func detach_to_c()->void:
 reparent(relay.room.gap.level)
 position=-C_OFFSET;detached=true;visible=true
 body.collision_layer=1
func restore_to_mine()->void:
 if not detached:return
 reparent(relay);position=Vector2.ZERO;detached=false
func _draw()->void:
 if relay==null or top.is_empty():return
 draw_polyline(top,INK,2.0,true)
 draw_polyline(face,INK,2.0,true)
 var end:float=relay.CART_STOP_X+35
 for x in range(int(relay.EXIT_X+8),int(end),24):
  draw_line(Vector2(x-7,relay.EXIT_Y+3),Vector2(x+8,relay.EXIT_Y+3),Color(.012,.012,.012),6,true)
 draw_line(Vector2(relay.EXIT_X,relay.EXIT_Y),Vector2(end,relay.EXIT_Y),Color(.027,.027,.027),2.2,true)
 draw_line(Vector2(relay.EXIT_X,relay.EXIT_Y+5),Vector2(end,relay.EXIT_Y+5),Color(.011,.011,.011),3,true)
 var stop:float=relay.CART_STOP_X+relay.BUMPER_HALF
 draw_line(Vector2(stop-8,relay.EXIT_Y+6),Vector2(stop,relay.EXIT_Y-29),INK,12,true)
 draw_line(Vector2(stop-9,relay.EXIT_Y-25),Vector2(stop+9,relay.EXIT_Y-25),INK,10,true)
