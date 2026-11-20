extends RefCounted
# A point mass pendulum with a geared reversible haul and viscous bearing
# loss. Positive angle is right of the pivot. No angle tween, modulo turn,
# timed freeze or per-swing multiplier is applied.
const BEARING_DAMPING:=.16
static func step(at:Vector2,h:float,length:float,gravity:float,target:float=NAN,engagement:float=0.0,clutch_drag:float=0.0)->Vector2:
 var angle:=at.x;var omega:=at.y
 var g:=gravity/length
 var acceleration:float=-g*sin(angle)-(BEARING_DAMPING+clutch_drag)*omega
 if not is_nan(target) and engagement>0:
  var error:=target-angle
  var desired:float=clampf(error*1.9,-.72,.72)
  # The winch opposes existing motion progressively, then hauls in the
  # selected direction. Gravity feed-forward holds a raised mass steadily.
  var torque:float=clampf((desired-omega)*7.0+g*sin(angle),-5.0,5.0)
  acceleration+=torque*engagement
 omega+=acceleration*h
 angle+=omega*h
 return Vector2(angle,omega)
static func energy(at:Vector2,length:float,gravity:float)->float:
 return .5*length*length*at.y*at.y+gravity*length*(1-cos(at.x))
