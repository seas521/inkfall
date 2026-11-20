extends Node2D
# Tensioned hemp rope: fixed wheel wrap, flexible free leg. Low-order
# transverse modes model bending waves without a long constraint solver.
var points:=PackedVector2Array()
var rendered_points:=PackedVector2Array()
var travel:=0.0
var thickness:=3.7
var redraws:=0
var displacement:=Vector3.ZERO
var velocity:=Vector3.ZERO
var load_blend:=0.0
var previous_speed:=0.0
var previous_end:=Vector2.ZERO
var end_velocity:=Vector2.ZERO
var initialized:=false
var last_loaded:=false
func set_path(value:PackedVector2Array,distance:float)->void:
 if value==points and is_equal_approx(distance,travel):return
 var paid_out:=not is_equal_approx(distance,travel)
 var before:=redraws
 points=value;travel=distance
 _rebuild()
 if paid_out and redraws==before:redraws+=1;queue_redraw()
func reset_motion()->void:
 displacement=Vector3.ZERO;velocity=Vector3.ZERO
 load_blend=0;previous_speed=0;end_velocity=Vector2.ZERO
 initialized=false;last_loaded=false
 _rebuild()
func tick_motion(delta:float,loaded:bool,hoist_speed:float)->void:
 if points.size()<3 or delta<=0:return
 var end:=points[-1]
 if not initialized:
  initialized=true;previous_end=end;last_loaded=loaded
  load_blend=1.0 if loaded else 0.0
 var dt:=minf(delta,.05)
 var next_velocity:Vector2=(end-previous_end)/maxf(delta,.001)
 var lateral_acceleration:float=(next_velocity.x-end_velocity.x)/maxf(delta,.001)
 var lift_acceleration:float=(hoist_speed-previous_speed)/maxf(delta,.001)
 if loaded!=last_loaded:
  # Taking up / releasing the basket load sends a pulse up the free leg.
  velocity+=Vector3(15,-10,6)*(1.0 if loaded else -1.3)
  last_loaded=loaded
 load_blend=move_toward(load_blend,1.0 if loaded else 0.0,dt*3)
 var length:float=points[-2].distance_to(end)
 # Wave speed grows with sqrt(tension); a loaded rope stays straighter.
 var fundamental:float=clampf(1400/maxf(100,length),2.8,8.5)*sqrt(1+1.8*load_blend)
 var forcing:float=clampf(-lateral_acceleration*.055+lift_acceleration*.018,-32,32)
 var left:=dt
 while left>.000001:
  var h:=minf(left,1.0/120.0);left-=h
  for mode in 3:
   var frequency:float=fundamental*(mode+1)
   var drive:float=forcing*[1.0,-.45,.22][mode]
   velocity[mode]+=(drive-frequency*frequency*displacement[mode]-(3.2+mode*.7)*velocity[mode])*h
   displacement[mode]=clampf(displacement[mode]+velocity[mode]*h,-7,7)
 if displacement.length()<.002 and velocity.length()<.01 and absf(forcing)<.01:
  displacement=Vector3.ZERO;velocity=Vector3.ZERO
 previous_end=end;end_velocity=next_velocity;previous_speed=hoist_speed
 _rebuild()
func _rebuild()->void:
 if points.size()<3:return
 var next:=PackedVector2Array()
 # The exact drum tangent and sheave arc stay seated on their machinery.
 for i in points.size()-1:next.append(points[i])
 var a:=points[-2];var b:=points[-1]
 var normal:Vector2=(b-a).normalized().orthogonal()
 for i in range(1,33):
  var t:=float(i)/32.0
  # Zero value AND slope at both ends prevents detached / kinked tangents.
  var bend:float=sin(PI*t)*(displacement.x*sin(PI*t)+displacement.y*sin(2*PI*t)+displacement.z*sin(3*PI*t))
  next.append(a.lerp(b,t)+normal*bend)
 if next==rendered_points:return
 rendered_points=next;redraws+=1;queue_redraw()
func _draw()->void:
 if rendered_points.size()<2:return
 draw_polyline(rendered_points,Color(.0005,.0005,.0005),thickness,true)
 # Matte twisted strands, with no metallic central highlight.
 var station:=fposmod(travel,7.2)
 var begin:=0.0
 for i in rendered_points.size()-1:
  var a:=rendered_points[i];var b:=rendered_points[i+1]
  var length:=a.distance_to(b)
  if length<.0001:continue
  var tangent:Vector2=(b-a)/length
  var normal:=tangent.orthogonal()
  while station<begin+length:
   if station>=begin:
    var at:=a+tangent*(station-begin)
    draw_line(at-tangent*1.5-normal*.85,at+tangent*1.5+normal*.85,Color(.009,.009,.009),1.0,true)
    draw_line(at-tangent*1.25+normal*.75,at+tangent*1.25-normal*.75,Color(.003,.003,.003),.7,true)
   station+=7.2
  begin+=length
 var end:=rendered_points[-1]
 var direction:Vector2=(end-rendered_points[-2]).normalized()
 var normal:=direction.orthogonal()
 # Rope whipping and a tied loop round the existing basket eye.
 for distance:float in [4.,6.,8.,10.]:
  var at:=end-direction*distance
  draw_line(at-normal*2.1,at+normal*2.1,Color(.004,.004,.004),1.5,true)
 draw_arc(end-direction*.9,3.0,0,TAU,20,Color(.001,.001,.001),2.5,true)
