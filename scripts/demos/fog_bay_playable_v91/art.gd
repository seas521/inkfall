extends "res://scripts/demos/c_zone_debug/river_art.gd"
var ripples:Array[Dictionary]=[]
var gusts:Array[Dictionary]=[]
var hull_activity:=0.
var rope_draw:Node2D
func _ready()->void:
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 bank_noise.seed=6317;bank_noise.frequency=.018
 crate_art=Node2D.new();crate_art.z_index=2;crate_art.draw.connect(_draw_crate);add_child(crate_art)
 raft_front=Node2D.new();raft_front.z_index=7;raft_front.draw.connect(_draw_raft_front);add_child(raft_front)
 var immersion:=ShaderMaterial.new();immersion.shader=preload("res://assets/shaders/fog_bay_static_v90/boat_immersion.gdshader")
 crate_art.material=immersion;raft_front.material=immersion
 fan_pickup=Fan.new();fan_pickup.z_index=3;add_child(fan_pickup)
 rope_draw=Node2D.new();rope_draw.z_index=8;rope_draw.draw.connect(_draw_tow_ropes);add_child(rope_draw)
 surface=Node2D.new();surface.z_index=9;surface.draw.connect(_draw_contact);add_child(surface)
func sync(dt:float,_camera:float,_active:bool)->void:
 clock+=dt
 for list in [ripples,gusts]:
  for i in range(list.size()-1,-1,-1):
   list[i].age+=dt
   if list[i].age>1.3:list.remove_at(i)
 crate_art.position=level.crate.position+level.CRATE_SIZE*.5;crate_art.rotation=level.crate_tilt
 raft_front.transform=crate_art.transform
 crate_art.material.set_shader_parameter("water_y",water_line(level.crate.position.x+72.))
 fan_pickup.visible=not level.fan_owned
 fan_pickup.position=level.fan_rest_position();fan_pickup.scale=Vector2.ONE*level.FAN_SCALE;fan_pickup.rotation=1.5
 for node in [crate_art,raft_front,surface,rope_draw]:node.queue_redraw()
func water_line(x:float)->float:
 return level.WATER_Y+sin(x*.022+clock*1.2)*.75+sin(x*.051-clock*.8)*.35
func raft_waves(_x:float,_half:float,vx:float,press:float,tip:float,dt:float)->void:
 hull_activity=lerpf(hull_activity,clampf(absf(vx)*.008+absf(press)*.02+absf(tip),0.,1.),1.-exp(-dt*5.))
func emit_water_impact(x:float,impulse:float,spread:float,_rings:bool=true)->void:
 ripples.append({"x":x,"strength":clampf(impulse/220.,.2,1.),"spread":spread,"age":0.})
func emit_gust(origin:Vector2,direction:float)->void:
 gusts.append({"origin":origin,"direction":direction,"age":0.})
func _draw_contact()->void:
 for ripple in ripples:
  var t:float=ripple.age
  var alpha:float=(1.-t/1.3)*.25
  for side in [-1.,1.]:
   var pos:Vector2=Vector2(ripple.x+side*(8.+t*35.),level.WATER_Y)
   surface.draw_line(pos-Vector2(8,0),pos+Vector2(8,0),Color(.8,.8,.8,alpha),1.4,true)
   if t<.6:
    var drop:Vector2=pos+Vector2(side*t*14.,-55.*t+100.*t*t)
    surface.draw_circle(drop,1.1,Color(.8,.8,.8,alpha))
 for gust in gusts:
  var t:float=gust.age
  var pos:Vector2=gust.origin+Vector2(gust.direction*t*100.,0.)
  surface.draw_line(pos,pos+Vector2(gust.direction*18.,-2.),Color(.8,.8,.8,(1.-t/1.3)*.18),1.,true)
 if not level.floating:return
 var x:float=level.crate.position.x+72.
 var speed:float=absf(level.crate.velocity.x)
 # White displaced water hugs the two stems, not a rectangular strip under the hull.
 for side in [-1.,1.]:
  var bow:float=x+side*66.
  for k in 5:
   var length:float=9.+k*4.+hull_activity*14.
   surface.draw_set_transform(Vector2(bow+side*length*.5,water_line(bow)+k*.4),0.,Vector2(length,1.1+k*.5))
   surface.draw_circle(Vector2.ZERO,1.,Color(.94,.94,.94,(.09+hull_activity*.15)*(1.-k*.13)),true,-1,true)
  surface.draw_set_transform(Vector2.ZERO)
  if hull_activity>.12:
   var crest:=PackedVector2Array([Vector2(bow,water_line(bow)+1.)])
   for j in 19:
    var t:float=j/18.
    var h:float=sin(t*PI)*(3.+hull_activity*8.)*(.65+.35*sin(t*28.+clock*5.)*sin(t*28.+clock*5.))
    crest.append(Vector2(bow+side*t*(24.+hull_activity*26.),water_line(bow)-h))
   crest.append(Vector2(bow+side*(24.+hull_activity*26.),water_line(bow)+1.))
   surface.draw_colored_polygon(crest,Color(.96,.96,.96,hull_activity*.43))
   for j in 11:
    var phase:float=fposmod(clock*(.7+hull_activity)+j*.173,1.)
    var offset:float=phase*(18.+hull_activity*23.)
    var height:float=sin(phase*PI)*(3.+hull_activity*9.)
    var point:=Vector2(bow+side*offset,water_line(bow)-height)
    surface.draw_circle(point,1.4*(1.-phase)+.4,Color(.93,.93,.93,(1.-phase)*hull_activity*.65),true,-1,true)
 var contact:=PackedVector2Array()
 for i in 35:
  var px:float=x-66.+i*132./34.
  contact.append(Vector2(px,water_line(px)+.3+sin(px*.28+clock*1.8)*.3))
 surface.draw_polyline(contact,Color(.8,.8,.8,.15),.9,true)

const CONCEPT_BOAT=preload("res://assets/art/fog_bay_playable_v91/concept-boat.png")
func _draw_crate()->void:
 crate_art.draw_set_transform(-level.CRATE_SIZE*.5)
 crate_art.draw_texture_rect_region(CONCEPT_BOAT,Rect2(-37.5,-84.25,221.75,81.25),Rect2(0,0,1774,650),Color(.48,.48,.48,1.))
 crate_art.draw_texture_rect_region(CONCEPT_BOAT,Rect2(-37.5,-3.,221.75,41.5),Rect2(0,650,1774,237),Color(.48,.48,.48,1.))
 # Continuous rigging keeps the fine mast stays readable after minification.
 crate_art.draw_line(Vector2(104,-59),Vector2(89,-3),Color(.04,.04,.04),.65,true)
 crate_art.draw_line(Vector2(104,-59),Vector2(120,-5),Color(.04,.04,.04),.65,true)
func _draw_raft_front()->void:
 raft_front.draw_set_transform(-level.CRATE_SIZE*.5)
 # Only the near hull occludes the feet; mast and stays remain behind the actor.
 raft_front.draw_texture_rect_region(CONCEPT_BOAT,Rect2(-37.5,-3.,221.75,41.5),Rect2(0,650,1774,237),Color(.48,.48,.48,1.))
func _draw_tow_ropes()->void:
 for side in [-1.,1.]:
  var anchor:Vector2=level.crate.position+Vector2(72,16)+Vector2(side*76.,-24.).rotated(level.crate_tilt)
  var end:Vector2=anchor+Vector2(side*54.,25.)
  var floor_y:float=level.ground_y(end.x)
  end.y=minf(floor_y,level.WATER_Y+3.) if floor_y>=anchor.y+8. else level.WATER_Y+3.
  var held:bool=level.dragging and side==level.grip_side
  if held:end=level.actor.grip_hand_world()
  var points:=PackedVector2Array()
  for i in 25:
   var t:float=i/24.
   var p:Vector2=anchor.lerp(end,t)
   p.y+=sin(t*PI)*(2. if held else 13.)
   p.y+=sin(t*PI)*sin(clock*2.2+t*4.)*(.25 if held else 1.3)
   var ground:float=level.ground_y(p.x)
   if not held:p.y=minf(p.y,minf(ground,level.WATER_Y+5.) if ground>=anchor.y else level.WATER_Y+5.)
   points.append(p)
  rope_draw.draw_polyline(points,Color(.045,.045,.045),1.5,true)
  rope_draw.draw_circle(anchor,2.,Color(.02,.02,.02))
