extends RefCounted
# Constrained rigid contacts. A hinge has angular q / inertia; a rail has
# tangential q / mass. The same unilateral Jacobian impulse solves both.
# No vehicle indices, launch zones, direction cases or visual state here.
const SKIN:=.025
const SLOP:=.008
const RELEASE_GAP:=.8
const BOUNCE_THRESHOLD:=8.0
const VELOCITY_ITERATIONS:=16
const POSITION_ITERATIONS:=4
const MAX_TRAVEL:=2.0
var active:Dictionary={}
var last_contacts:Array=[]
func clear()->void:
 active.clear();last_contacts.clear()
static func box(center:Vector2,half:Vector2,rotation:float)->PackedVector2Array:
 var points:=PackedVector2Array()
 for p:Vector2 in [-half,Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]:points.append(center+p.rotated(rotation))
 return points
static func shape(body:Dictionary,profile:String="solid")->PackedVector2Array:
 if body.motion==&"hinge":
  var center:Vector2=body.origin+Vector2(sin(body.q),cos(body.q))*float(body.length)+Vector2(body.offset).rotated(-float(body.q))
  return box(center,body.half,-body.q)
 var center:Vector2=body.origin+Vector2(body.axis)*float(body.q)
 var half:Vector2=body.half
 var offset:Vector2=body.offset
 if profile=="buffer":half=body.buffer_half;offset=body.buffer_offset
 return box(center+offset.rotated(body.rotation),half,body.rotation)
static func jacobian(body:Dictionary,point:Vector2)->Vector2:
 if body.motion==&"rail":return body.axis
 var arm:Vector2=point-(Vector2(body.origin)+Vector2(sin(body.q),cos(body.q))*float(body.length))
 return Vector2(float(body.length)*cos(body.q)+arm.y,-float(body.length)*sin(body.q)-arm.x)
static func limit_translation(body:Dictionary,obstacles:Array,displacement:float)->float:
 var original:float=body.q
 var safe:=0.0
 var depths:Array=[]
 for obstacle in obstacles:
  var contact:=manifold(shape(body,obstacle.get("self_shape","solid")),shape(obstacle.body,obstacle.get("other_shape","solid")),0.0)
  depths.append(maxf(0,float(contact.get("depth",0))))
 var steps:=maxi(1,ceili(absf(displacement)/MAX_TRAVEL))
 for i in range(1,steps+1):
  var trial:=displacement*float(i)/steps
  body.q=original+trial
  for j in obstacles.size():
   var obstacle:Dictionary=obstacles[j]
   var contact:=manifold(shape(body,obstacle.get("self_shape","solid")),shape(obstacle.body,obstacle.get("other_shape","solid")),0.0)
   var depth:float=maxf(0,float(contact.get("depth",0)))
   if depth>float(depths[j])+SLOP:
    body.q=original;return safe
   depths[j]=depth
  safe=trial
 body.q=original
 return safe
static func _interval(points:PackedVector2Array,axis:Vector2)->Vector2:
 var low:=INF;var high:=-INF
 for p in points:
  var d:=p.dot(axis);low=minf(low,d);high=maxf(high,d)
 return Vector2(low,high)
static func _feature(points:PackedVector2Array,normal:Vector2,tangent:Vector2,limit:float)->Vector2:
 var low:=INF;var high:=-INF
 for p in points:
  if absf(p.dot(normal)-limit)>.35:continue
  var d:=p.dot(tangent);low=minf(low,d);high=maxf(high,d)
 return Vector2(low,high)
static func manifold(a:PackedVector2Array,b:PackedVector2Array,margin:float=SKIN)->Dictionary:
 var bounds_a:=Rect2(a[0],Vector2.ZERO);var bounds_b:=Rect2(b[0],Vector2.ZERO)
 for point in a:bounds_a=bounds_a.expand(point)
 for point in b:bounds_b=bounds_b.expand(point)
 if not bounds_a.grow(margin).intersects(bounds_b,true):return {}
 var depth:=INF;var normal:=Vector2.ZERO
 for points in [a,b]:
  for i in points.size():
   var edge:Vector2=points[(i+1)%points.size()]-points[i]
   if edge.length_squared()<.000001:continue
   var axis:=edge.orthogonal().normalized()
   var pa:=_interval(a,axis);var pb:=_interval(b,axis)
   var forward:=pa.y-pb.x;var backward:=pb.y-pa.x
   if forward< -margin or backward< -margin:return {}
   var overlap:=minf(forward,backward)
   if overlap<depth:
    depth=overlap;normal=axis if forward<=backward else -axis
 if not is_finite(depth):return {}
 var tangent:=normal.orthogonal()
 var an:=_interval(a,normal);var bn:=_interval(b,normal)
 var af:=_feature(a,normal,tangent,an.y);var bf:=_feature(b,normal,tangent,bn.x)
 var low:=maxf(af.x,bf.x);var high:=minf(af.y,bf.y)
 var along:float=(low+high)*.5
 return {"normal":normal,"depth":depth,"point":normal*((an.y+bn.x)*.5)+tangent*along}
static func _key(pair:Dictionary)->String:return str(mini(pair.a,pair.b))+":"+str(maxi(pair.a,pair.b))
static func _coefficients(a:Dictionary,b:Dictionary,contact:Dictionary)->Vector3:
 var ja:float=-Vector2(contact.normal).dot(jacobian(a,contact.point))
 var jb:float=Vector2(contact.normal).dot(jacobian(b,contact.point))
 return Vector3(ja,jb,ja*ja*float(a.inv)+jb*jb*float(b.inv))
static func _restitution(pair:Dictionary,speed:float)->float:
 if pair.material==&"buffer":return float(pair.restitution)
 return lerpf(float(pair.get("restitution_low",.45)),float(pair.get("restitution_high",.40)),smoothstep(350,650,speed))
func step(bodies:Array,pairs:Array,h:float)->Array:
 var events:Array=[];last_contacts.clear()
 var travel:=0.0
 for body in bodies:
  var radius:float=float(body.length)+Vector2(body.half).length()+Vector2(body.offset).length() if body.motion==&"hinge" else 1.0
  travel=maxf(travel,absf(float(body.speed))*radius*h)
 # Adaptive collision sampling bounds travel below the thinnest bumper.
 # External gravity/motors are integrated by the caller once, not per pass.
 var slices:=clampi(ceili(travel/MAX_TRAVEL),1,128)
 var dt:=h/float(slices)
 for _slice in slices:
  for body in bodies:
   if not body.fixed:body.q+=float(body.speed)*dt
  var contacts:Array=[];var retained:Dictionary={}
  for pair in pairs:
   var a:Dictionary=bodies[pair.a];var b:Dictionary=bodies[pair.b]
   var ap:=shape(a,pair.get("shape_a","solid"));var bp:=shape(b,pair.get("shape_b","solid"))
   var key:=_key(pair)
   if active.has(key) and not manifold(ap,bp,RELEASE_GAP).is_empty():retained[key]=true
   var contact:=manifold(ap,bp)
   if contact.is_empty():continue
   var coefficients:=_coefficients(a,b,contact)
   var closing:float=coefficients.x*float(a.speed)+coefficients.y*float(b.speed)
   var fresh:=not active.has(key)
   contact.merge({"a":pair.a,"b":pair.b,"pair":pair,"key":key,"ja":coefficients.x,"jb":coefficients.y,"k":coefficients.z,"before_a":a.speed,"before_b":b.speed,"closing_speed":maxf(0,-closing),"target":_restitution(pair,-closing)*(-closing) if fresh and closing< -BOUNCE_THRESHOLD else 0.0,"impulse":0.0,"fresh":fresh})
   contacts.append(contact);retained[key]=true
  for _iteration in VELOCITY_ITERATIONS:
   for contact in contacts:
    if contact.k<1e-12:continue
    var a:Dictionary=bodies[contact.a];var b:Dictionary=bodies[contact.b]
    var vn:float=contact.ja*float(a.speed)+contact.jb*float(b.speed)
    var previous:float=contact.impulse
    contact.impulse=maxf(0,previous+(float(contact.target)-vn)/float(contact.k))
    var impulse:float=contact.impulse-previous
    a.speed+=float(contact.ja)*float(a.inv)*impulse
    b.speed+=float(contact.jb)*float(b.inv)*impulse
  for _iteration in POSITION_ITERATIONS:
   for contact in contacts:
    var a:Dictionary=bodies[contact.a];var b:Dictionary=bodies[contact.b]
    var pair:Dictionary=contact.pair
    var current:=manifold(shape(a,pair.get("shape_a","solid")),shape(b,pair.get("shape_b","solid")))
    if current.is_empty() or current.depth<=SLOP:continue
    var c:=_coefficients(a,b,current)
    if c.z<1e-12:continue
    var correction:float=minf(4.0,(float(current.depth)-SLOP)*.65)/c.z
    for entry in [[a,c.x],[b,c.y]]:
     var body:Dictionary=entry[0]
     var scale:float=float(body.length)+Vector2(body.half).length() if body.motion==&"hinge" else 1.0
     body.q+=clampf(float(entry[1])*float(body.inv)*correction,-4.0/scale,4.0/scale)
  for contact in contacts:
   contact.after_a=bodies[contact.a].speed;contact.after_b=bodies[contact.b].speed
   last_contacts.append(contact)
   if contact.fresh and contact.closing_speed>BOUNCE_THRESHOLD and contact.impulse>0:events.append(contact)
  active=retained
 return events
