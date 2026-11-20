extends Node2D
# Rear-bay joinery is visible before failure. Each member breaks at an
# off-centre joint, hinges briefly, then falls as independent jagged lengths.
var trial
var x:=0.0
var delay:=0.0
var age:=-1.0
var beams:Array[Dictionary]=[]
var parts:Array[Dictionary]=[]
var front:=false

func build(owner_trial,at:float,start_delay:float)->void:
 trial=owner_trial;x=at;delay=start_delay
 var room=trial.route.art.chamber if x< -2340 else trial.route.art.chase_chamber
 var roof:float=room.ceiling_y(x)+12
 var l:=Vector2(x-68,trial.ground(x-68)-2)
 var r:=Vector2(x+68,trial.ground(x+68)-2)
 var tl:=Vector2(x-72,roof)
 var tr:=Vector2(x+72,roof+5)
 beams=[{"a":tl,"b":tr,"w":12.0},{"a":tl+Vector2(5,0),"b":l,"w":11.0},{"a":tr-Vector2(5,0),"b":r,"w":11.0},{"a":tl+Vector2(3,49),"b":tl+Vector2(42,5),"w":7.0},{"a":tr+Vector2(-3,49),"b":tr+Vector2(-42,2),"w":7.0}]
 reset()

func reset()->void:
 age=-1;front=false;z_index=-2;parts.clear()
 for i in beams.size():
  var beam:Dictionary=beams[i]
  var split:Vector2=beam.a.lerp(beam.b,.44 if i%2==0 else .58)
  for side in 2:
   var a:Vector2=beam.a if side==0 else split
   var b:Vector2=split if side==0 else beam.b
   var p:Vector2=(a+b)*.5
   var id:=i*2+side
   parts.append({"home":p,"p":p,"previous":p,"angle":(b-a).angle(),"rest":(b-a).angle(),"half":a.distance_to(b)*.5,"w":beam.w,"anchor":a if side==0 else b,"hinge":(.34 if side==0 else -.30)*(1 if i==0 else -.55),"spin":sin(id*2.4+.8)*1.6,"vx":sin(id*3.7+.5)*48,"land_time":-1.0,"land_angle":0.0,"moving":false,"id":id})
 queue_redraw()

func tick(delta:float)->void:
 var next_age:float=trial.impact_age-delay
 if next_age<0:return
 var changed:=false
 age=next_age
 if not front and age>.22:front=true;z_index=4
 for part in parts:
  var previous:Vector2=part.p;var previous_angle:float=part.angle
  part.previous=previous;part.moving=false
  var load:float=smoothstep(0,.22,age)*7
  if age<=.42:
   var bend:float=part.hinge*smoothstep(.16,.42,age)
   part.angle=part.rest+bend
   part.p=part.anchor+(part.home-part.anchor).rotated(bend)+Vector2(0,load)
  elif part.land_time<0:
   var fall:float=age-.42
   var release:Vector2=part.anchor+(part.home-part.anchor).rotated(part.hinge)+Vector2(0,7)
   part.p=release+Vector2(part.vx*fall,25*fall+490*fall*fall)
   part.angle=part.rest+part.hinge+part.spin*fall
   part.moving=true
   var bottom:float=absf(sin(part.angle))*part.half+part.w*.5
   if part.p.y+bottom>=trial.ground(part.p.x)-2:
    part.p.y=trial.ground(part.p.x)-2-bottom
    part.land_time=age;part.land_angle=part.angle
    if int(part.id)%3==0:trial._emit_dust(part.p+Vector2(0,bottom),Vector2(part.vx*.2,-5),Vector2(72,42),1.35,0)
  else:
   var settle:float=age-part.land_time
   var target:float=roundf(part.land_angle/PI)*PI
   part.angle=lerp_angle(part.land_angle,target,smoothstep(0,.34,settle))
   var bottom:float=absf(sin(part.angle))*part.half+part.w*.5
   part.p.y=trial.ground(part.p.x)-2-bottom
  changed=changed or previous.distance_squared_to(part.p)>.001 or absf(previous_angle-part.angle)>.0001
 if changed:queue_redraw()

func strikes(upper:Vector2,lower:Vector2)->bool:
 for part in parts:
  if not part.moving:continue
  var arm:Vector2=Vector2(cos(part.angle),sin(part.angle))*part.half
  var a:Vector2=part.p-arm;var b:Vector2=part.p+arm
  var points:=Geometry2D.get_closest_points_between_segments(a,b,upper,lower)
  if points[0].distance_to(points[1])<part.w*.5+9:return true
  var swept:=Geometry2D.get_closest_points_between_segments(part.previous,part.p,upper,lower)
  if swept[0].distance_to(swept[1])<part.w*.5+9:return true
 return false

func _draw()->void:
 if age<.22:
  var load:=smoothstep(0,.22,maxf(0,age))*7
  for i in beams.size():
   var beam:Dictionary=beams[i]
   var a:Vector2=beam.a+Vector2(0,load)
   var b:Vector2=beam.b+Vector2(0,load if i==0 or i>=3 else 0)
   draw_set_transform((a+b)*.5,(b-a).angle())
   _wood(a.distance_to(b)*.5,beam.w,i,false)
 else:
  for part in parts:
   draw_set_transform(part.p,part.angle)
   _wood(part.half,part.w,part.id,true)
 draw_set_transform(Vector2.ZERO)

func _wood(half:float,width:float,id:int,broken:bool)->void:
 var h:=width*.5
 var tooth:=5.0+float(id%3)*1.7 if broken else 0.0
 var shape:=PackedVector2Array([Vector2(-half,-h),Vector2(half-2,-h-.6),Vector2(half+tooth,-h*.42),Vector2(half-2,h*.05),Vector2(half+tooth*.5,h*.42),Vector2(half,h),Vector2(-half+2,h+.5),Vector2(-half-tooth*.6,h*.1),Vector2(-half+2,-h*.2)])
 draw_colored_polygon(shape,Color(.002,.002,.002))
 # A dull steel strap remains attached to its broken timber; no bright crack.
 if id%3==0:draw_line(Vector2(half*.45,-h),Vector2(half*.45,h),Color(.014,.014,.014),2,true)
