extends RefCounted
# Existing controllers retain camera-centre/event ownership. This layer only
# authors lens distance, with continuous world-space approaches and departures.
const Forest=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const Timber=preload("res://scripts/chapters/rock_crevice_layout.gd")
var zoom:=1.0
var last_frame:=-1
var last_feet:=Vector2.INF
var intent:=&"traversal"

func reset()->void:
 zoom=1.0;last_frame=-1;last_feet=Vector2.INF;intent=&"awakening"

func band(x:float,left:float,right:float,feather:float)->float:
 return smoothstep(left-feather,left,x)*(1.0-smoothstep(right,right+feather,x))

func forest_target(level:Node2D,feet:Vector2)->float:
 var scene=level.scene1
 if scene.intro_time<Forest.LIE_TIME+Forest.GET_UP_TIME:
  intent=&"awakening";return 1.0
 if scene.cut not in [Forest.Cut.NONE,Forest.Cut.DONE]:
  intent=&"forest-event";return 1.0
 var x:=feet.x
 # The opening expands with the first actual steps, never while the boy lies
 # still. Returning to the opening retraces the same continuous composition.
 var departure:=smoothstep(Forest.START_X+30.,Forest.START_X+550.,x)
 var distance:=lerpf(1.0,.74,departure)
 var spider:=band(x,-6750.,-6100.,160.)
 distance=lerpf(distance,.68,spider)
 var predator:=band(x,-7510.,-7040.,260.)
 distance=lerpf(distance,1.0,predator)
 var shelter:=band(x,Timber.LEFT-40.,Timber.EXIT_MOUTH+40.,260.)
 distance=lerpf(distance,1.04,shelter)
 # Let the existing cliff event take over at its original composition.
 var cliff:=smoothstep(Forest.AUTO_X-400.,Forest.AUTO_X-60.,x)
 distance=lerpf(distance,1.0,cliff)
 intent=&"forest-explore"
 if spider>.5:intent=&"spider-reveal"
 if predator>.5:intent=&"predator-interaction"
 if shelter>.5:intent=&"timber-shelter"
 if cliff>.5:intent=&"cliff-approach"
 return distance

func valley_target(level:Node2D,feet:Vector2)->float:
 var x:=feet.x
 var entry:=smoothstep(-220.,220.,x)*(1.-smoothstep(7050.,7350.,x))
 var distance:=.84
 var shore_controls:=maxf(band(x,260.,650.,180.),band(x,2290.,2640.,170.))
 distance=lerpf(distance,1.0,shore_controls)
 var water:=band(x,1120.,1930.,200.)
 distance=lerpf(distance,.78,water)
 var box:=band(x,2870.,3110.,130.)
 distance=lerpf(distance,.98,box)
 var jumping:=band(x,3260.,3700.,110.)
 distance=lerpf(distance,.80,jumping)
 var rocks:=band(x,4000.,4400.,160.)
 distance=lerpf(distance,.92,rocks)
 var bridge:=band(x,5920.,6460.,140.)
 distance=lerpf(distance,.94,bridge)
 intent=&"valley-explore"
 if water>.5:intent=&"river-vista"
 if shore_controls>.5:intent=&"shore-interaction"
 if box>.5:intent=&"valley-box"
 if jumping>.5:intent=&"valley-platforms"
 if rocks>.5:intent=&"valley-rock-hazard"
 if bridge>.5:intent=&"valley-bridge"
 return lerpf(1.,distance,entry)

func target(level:Node2D)->float:
 var route=level.bridge_to_c
 var feet:Vector2=level.player.position+Vector2(13,54)
 if route!=null and route.in_c_zone:return valley_target(level,feet)
 # The vertical descent uses its height in the gorge, rather than an input
 # mode. It opens enough to read the next roots, then closes at the mine lip.
 var gorge:=band(feet.x,-3800.,-3190.,250.)*smoothstep(-4160.,-3920.,feet.y)*(1.-smoothstep(-3500.,-3320.,feet.y))
 if gorge>.0001:
  intent=&"gorge-descent"
  return lerpf(1.,.84,gorge)
 if route!=null and not route.active and feet.x<Forest.CLIFF_X and feet.y< -3900.:
  return forest_target(level,feet)
 intent=&"traversal"
 if route==null or not route.active or route.failure_time>0:return 1.0
 feet=route.feet()
 if feet.y< -3510. or feet.x< -3100.:return 1.0
 var hoist:=band(feet.x,-560.,430.,260.)
 var relay:=band(feet.x,650.,1680.,300.)
 var tunnel:=band(feet.x,-2370.,-1210.,180.)
 var gap:=band(feet.x,-1230.,-640.,180.)
 var distance:=1.-maxf(maxf(hoist*.14,relay*.20),maxf(tunnel*.16,gap*.18))
 # Contact areas pull back from the overview without changing the original
 # camera centre, pendulum tracking or mine-cart event ownership.
 var upper:=band(feet.x,-510.,-160.,130.)*(1.-smoothstep(-3190.,-3090.,feet.y))
 var basket:=band(feet.x,-180.,230.,140.)*smoothstep(-2820.,-2730.,feet.y)
 distance=lerpf(distance,1.0,maxf(upper,basket))
 if route.mine_trial!=null and route.mine_trial.escape.riding:
  distance=lerpf(distance,.82,tunnel)
 intent=&"mine-overview"
 if upper>.5 or basket>.5:intent=&"mine-contact"
 return distance

func sync(level:Node2D,delta:float)->void:
 var frame:=Engine.get_process_frames()
 var desired:=target(level)
 var feet:Vector2=level.player.position+Vector2(13,54)
 # Explicit long test-entry/respawn cuts may seed the new framing. Ordinary
 # movement and jumps never reset the lens or change its integration rate.
 if last_feet.is_finite() and feet.distance_to(last_feet)>1800. and feet.x<Forest.CLIFF_X and feet.y< -3900.:zoom=desired
 last_feet=feet
 if frame!=last_frame and delta>0:
  last_frame=frame
  var elapsed:=clampf(maxf(delta,level.get_process_delta_time()),0,.05)
  var rate:=1.35 if String(intent).begins_with("mine") else 1.15
  zoom=lerpf(zoom,desired,1.0-exp(-elapsed*rate))
  if absf(zoom-desired)<.00005:zoom=desired
 level.camera.zoom=Vector2.ONE*zoom
 level.camera.force_update_scroll()
