extends Node2D
# Braided wire rope for a smooth hoist sheave (a chain needs a sprocket).
# Points include the wheel wrap, not two disconnected decorative lines.
var points:=PackedVector2Array()
var travel:=0.0
var thickness:=3.1
var redraws:=0
func set_path(value:PackedVector2Array,distance:float)->void:
 if value==points and is_equal_approx(distance,travel):return
 points=value;travel=distance;redraws+=1;queue_redraw()
func _draw()->void:
 if points.size()<2:return
 draw_polyline(points,Color(.0005,.0005,.0005),thickness,true)
 draw_polyline(points,Color(.004,.004,.004),thickness*.48,true)
 # Lay marks follow arc length over the rim and move with the paid-out
 # cable. Muted highlights stay inside the rope, never a white outline.
 var station:=fposmod(travel,5.8)
 var begin:=0.0
 for i in points.size()-1:
  var a:=points[i];var b:=points[i+1]
  var length:=a.distance_to(b)
  if length<.0001:continue
  var tangent:Vector2=(b-a)/length
  var normal:=tangent.orthogonal()
  while station<begin+length:
   if station>=begin:
    var at:=a+tangent*(station-begin)
    var half:=minf(1.15,length*.4)
    draw_line(at-tangent*half-normal*.72,at+tangent*half+normal*.72,Color(.012,.012,.012),.65,true)
   station+=5.8
  begin+=length
 # Two short retaining bands and a steel eye are seated in the basket bail.
 var end:=points[-1]
 var direction:Vector2=(end-points[-2]).normalized()
 var normal:=direction.orthogonal()
 for distance:float in [4.,8.]:
  var at:=end-direction*distance
  draw_line(at-normal*2,at+normal*2,Color(.008,.008,.008),1.5,true)
 draw_arc(end-direction*.8,2.6,0,TAU,24,Color(.003,.003,.003),1.7,true)
