extends RefCounted
# Load -> pedal -> counterbalanced restraint. The approved art owns the
# anchors; gameplay never infers pressure from screen coordinates or F.
const DEPRESSION:=5.5
const RISE_SPEED:=62.0
const LOWER_SPEED:=48.0
var room
var load_active:=false
var depression:=0.0
var pedal_velocity:=0.0
var rise:=0.0
var released:=false
var plate_rest:=Vector2.ZERO
var ballast_loads:Dictionary={}
var dust:Node2D
var dust_texture:Texture2D
var motes:Array[Dictionary]=[]
var dust_armed:=true
var rng:=RandomNumberGenerator.new()
func setup(owner_room)->void:
 room=owner_room
 plate_rest=room.scenery.mechanisms.parts["pressure_plate"].position
 rng.seed=38617
 dust=Node2D.new();dust.z_as_relative=false;dust.z_index=4
 room.add_child(dust);dust.draw.connect(_draw_dust)
 var image:=Image.create(40,24,false,Image.FORMAT_RGBA8)
 var noise:=FastNoiseLite.new();noise.seed=127;noise.frequency=.17
 for y in 24:
  for x in 40:
   var q:=Vector2((x-19.5)/18.,(y-11.5)/9.)
   var density:=clampf((1-q.length_squared())*.6+noise.get_noise_2d(x,y)*.65,0,1)
   image.set_pixel(x,y,Color(1,1,1,density*density))
 dust_texture=ImageTexture.create_from_image(image)
 reset()
func reset()->void:
 load_active=false;depression=0;pedal_velocity=0;rise=0;released=false
 ballast_loads.clear()
 motes.clear();dust_armed=true
 if dust!=null:dust.queue_redraw()
 _present()
func set_ballast(key:String,at:Vector2,supported:bool)->void:
 # Hoist/carry gameplay can register a grounded load through this same
 # physical footprint; held and falling objects cannot hold the pedal.
 if supported:ballast_loads[key]=at
 else:ballast_loads.erase(key)
func footprint_contains(at:Vector2,half_width:float=10)->bool:
 return absf(at.x-plate_rest.x)<29.0+half_width and absf(at.y-room.MID_Y)<10.0
func _loaded()->bool:
 var level=room.gap.level
 if level.player.is_on_floor() and not room.ladders.active() and level.climb_time<0 and footprint_contains(room.gap.route.feet()):return true
 return _ballast_loaded()
func _ballast_loaded()->bool:
 for at:Vector2 in ballast_loads.values():
  if footprint_contains(at,16):return true
 return false
func tick(delta:float)->void:
 _tick_dust(delta)
 if not room.enabled or room.gap.route.failure_time>0:
  load_active=false;return
 load_active=_loaded()
 # Bounded spring integration keeps the pedal calm at either frame rate.
 var remaining:=delta
 while remaining>0:
  var step:=minf(remaining,1.0/120.0);remaining-=step
  var target:=DEPRESSION if load_active else 0.0
  pedal_velocity+=((target-depression)*220.0-pedal_velocity*28.0)*step
  depression=clampf(depression+pedal_velocity*step,0,DEPRESSION)
  if (depression<=0 and pedal_velocity<0) or (depression>=DEPRESSION and pedal_velocity>0):pedal_velocity=0
 if depression>DEPRESSION*.28 and dust_armed:
  _emit_dust(plate_rest,6);room.mechanical_impulse(plate_rest,.018);dust_armed=false
 if depression<DEPRESSION*.08:dust_armed=true
 var travel:float=room.scenery.mechanisms.CLAMP_TRAVEL
 var target_rise:float=travel if room.restraint_cleared or (depression>DEPRESSION*.65 and load_active) else 0.0
 var previous_rise:=rise
 rise=move_toward(rise,target_rise,(RISE_SPEED if target_rise>rise else LOWER_SPEED)*delta)
 if previous_rise>0 and rise==0:
  _emit_dust(room.ORIGIN+room.scenery.mechanisms.clamp_rest,4)
  room.mechanical_impulse(room.ORIGIN+room.scenery.mechanisms.clamp_rest,-.045)
 # Hysteresis avoids a lock toggling on adjacent frames at full lift.
 released=rise>=travel*.88 if not released else rise>travel*.76
 # A person only previews/holds the lift. Permanent release requires the
 # grounded stone to take their place; stepping off alone must lower it.
 if released and _ballast_loaded():room.restraint_cleared=true
 _present()
func _present()->void:
 var art=room.scenery.mechanisms
 var plate:Node2D=art.parts["pressure_plate"]
 plate.position=plate_rest+Vector2(0,depression)
 plate.rotation=depression*.003
 art.set_restraint_rise(rise)
func _emit_dust(at:Vector2,count:int)->void:
 for i in count:
  var side:float=-1 if i%2==0 else 1
  motes.append({"p":at+Vector2(side*rng.randf_range(21,29),-2),"v":Vector2(side*rng.randf_range(7,19),rng.randf_range(-15,-6)),"age":0.,"life":rng.randf_range(.34,.62),"size":Vector2(rng.randf_range(11,20),rng.randf_range(5,10)),"angle":rng.randf_range(-.35,.35)})
func _tick_dust(delta:float)->void:
 if motes.is_empty():return
 for mote in motes:
  mote.age+=delta;mote.v*=exp(-2.6*delta);mote.p+=mote.v*delta
 motes=motes.filter(func(mote):return mote.age<mote.life)
 dust.queue_redraw()
func _draw_dust()->void:
 for mote in motes:
  var age:float=mote.age/mote.life
  var size:Vector2=mote.size*(1+age*.45)
  dust.draw_set_transform(mote.p,mote.angle)
  var tone:float=mote.get("tone",.24)
  var opacity:float=mote.get("opacity",1.0)
  dust.draw_texture_rect(dust_texture,Rect2(-size*.5,size),false,Color(tone,tone,tone,.25*opacity*(1-age)*smoothstep(0,.12,age)))
 dust.draw_set_transform(Vector2.ZERO)
