extends "res://scripts/demos/c_zone_debug/river_art.gd"
const PHOTO=preload("res://assets/art/fog_bay_v89/fog-valley.png")
const TREES=preload("res://scripts/art/valley_forest_depth.gd")
var bay_back:ColorRect
var front_root:Node2D
var front_view:SubViewport
var shore:Node2D
var reeds:Node2D
var rear:Node2D
var bay_water:ShaderMaterial
var bay_trees:Array=[]

func _ready()->void:
 bank_noise.seed=6317;bank_noise.frequency=.018
 spray_rng.seed=8907
 _init_waves()
 dust_texture=_soft_texture()
 var bg:=CanvasLayer.new();bg.layer=-10;add_child(bg)
 bay_back=ColorRect.new();bay_back.size=Vector2(1280,720);bay_back.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var bm:=ShaderMaterial.new();bm.shader=preload("res://assets/shaders/fog_bay/atmosphere.gdshader")
 bm.set_shader_parameter("landscape",PHOTO);bay_back.material=bm;bg.add_child(bay_back)
 rear=Node2D.new();rear.z_index=-6;rear.draw.connect(_draw_rear);add_child(rear)
 # Atmospheric trunks only return well inland; none occupy the open lake.
 for spec in [Vector4(2830,646,900,2),Vector4(3480,630,1050,0)]:
  var at:=AtlasTexture.new();at.atlas=TREES.ATLAS;at.region=TREES.REGIONS[int(spec.w)]
  var tr:=Sprite2D.new();tr.texture=at;tr.scale=Vector2(.42,1)*spec.z/960.;tr.position=Vector2(spec.x,spec.y-spec.z*.5);tr.z_index=-5
  var m:=ShaderMaterial.new();m.shader=TREES.INK;m.set_shader_parameter("tone",.08);m.set_shader_parameter("strength",.24);m.set_shader_parameter("softness",7.);m.set_shader_parameter("root_haze",1.);tr.material=m;add_child(tr)
 # All roots are authored behind opaque land. No entire roots dangling over air.
 for spec in [Vector4(-210,650,960,0),Vector4(2920,590,1170,1)]:
  var atlas:=AtlasTexture.new();atlas.atlas=TREES.ATLAS;atlas.region=TREES.REGIONS[int(spec.w)]
  var tree:=Sprite2D.new();tree.texture=atlas;tree.scale=Vector2(.47,1)*spec.z/960.
  tree.position=Vector2(spec.x,spec.y-spec.z*.5);tree.z_index=-3
  var tm:=ShaderMaterial.new();tm.shader=TREES.INK;tm.set_shader_parameter("tone",.0015);tm.set_shader_parameter("strength",1.);tm.set_shader_parameter("softness",1.8);tm.set_shader_parameter("root_haze",0.)
  tree.material=tm;add_child(tree);bay_trees.append(tree)
 shore=Node2D.new();shore.z_index=0;shore.draw.connect(_draw_shores);add_child(shore)
 props=Node2D.new();props.z_index=1;props.draw.connect(_draw_jetty);add_child(props)
 crate_art=Node2D.new();crate_art.z_index=2;crate_art.draw.connect(_draw_crate);add_child(crate_art)
 raft_front=Node2D.new();raft_front.z_index=7;raft_front.draw.connect(_draw_raft_front);add_child(raft_front)
 fan_pickup=Fan.new();fan_pickup.z_index=1;add_child(fan_pickup)
 dust_layer=Node2D.new();dust_layer.z_index=8;dust_layer.draw.connect(_draw_ground_dust);add_child(dust_layer)
 water_volume=Polygon2D.new();water_volume.z_index=9
 water_volume.polygon=PackedVector2Array([Vector2(400,570),Vector2(2840,570),Vector2(2840,1500),Vector2(400,1500)])
 bay_water=ShaderMaterial.new();bay_water.shader=preload("res://assets/shaders/fog_bay/water.gdshader")
 bay_water.set_shader_parameter("landscape",PHOTO);bay_water.set_shader_parameter("swell",wave_texture)
 water_volume.material=bay_water;add_child(water_volume)
 surface=Node2D.new();surface.z_index=10;surface.draw.connect(_draw_bay_splash);add_child(surface)
 reeds=Node2D.new();reeds.z_index=11;reeds.draw.connect(_draw_shore_reeds);add_child(reeds)
 var fg:=CanvasLayer.new();fg.layer=3;add_child(fg)
 front_view=_blur_layer(fg,5.,Vector2(64,64))
 front_root=Node2D.new();front_root.draw.connect(_draw_near_bank)
 front_view.get_meta(&"draw_root").add_child(front_root)


func sync(delta:float,new_camera:float,active:bool)->void:
 visible=active;clock+=delta;camera_x=new_camera;view_camera_y=level.camera_y
 _update_waves(delta);_update_ground_dust(delta)
 for i in range(water_impacts.size()-1,-1,-1):
  water_impacts[i].age+=delta
  if water_impacts[i].age>2.4:water_impacts.remove_at(i)
 var centre:Vector2=level.camera.position
 var z:float=level.camera.zoom.x
 for mat in [bay_back.material,bay_water]:
  mat.set_shader_parameter("camera",centre);mat.set_shader_parameter("zoom",z);mat.set_shader_parameter("clock",clock)
 bay_water.set_shader_parameter("boat",level.crate.position+Vector2(72,20))
 bay_water.set_shader_parameter("boat_speed",level.crate.velocity.x)
 bay_water.set_shader_parameter("afloat",1. if level.floating else 0.)
 crate_art.position=level.crate.position+level.CRATE_SIZE*.5;crate_art.rotation=level.crate_tilt
 raft_front.transform=crate_art.transform
 fan_pickup.visible=level.fan_revealed and not level.fan_owned
 fan_pickup.position=level.fan_rest_position()
 fan_pickup.scale=Vector2.ONE*level.FAN_SCALE if level.fan_on_tree else Vector2(level.fan_ground_facing*.17,1)*level.FAN_SCALE
 fan_pickup.rotation=-.75 if level.fan_on_tree else level.fan_ground_facing*1.5+(level.crate_tilt if level.fan_on_raft else 0.)
 for node in [crate_art,raft_front,dust_layer,surface,reeds]:node.queue_redraw()
 front_root.scale=Vector2.ONE*z
 front_root.position=Vector2(640,360)-centre*z
 front_root.queue_redraw()

func _poly(node:Node2D,xy:Array,color:Color)->void:
 var p:=PackedVector2Array()
 for v in xy:p.append(Vector2(v[0],v[1]))
 node.draw_colored_polygon(p,color)

func _draw_shores()->void:
 for profile in [level.LEFT_PROFILE,level.RIGHT_PROFILE]:
  var shape:=PackedVector2Array()
  for i in range(profile.size()-2):
   var a:Vector2=profile[i];var b:Vector2=profile[i+1]
   var steps:=maxi(1,int(a.distance_to(b)/6.))
   for j in steps:
    var p:Vector2=a.lerp(b,float(j)/steps)
    p.x+=bank_noise.get_noise_1d(p.y+190.)*.9
    p.y+=bank_noise.get_noise_1d(p.x)*1.3
    shape.append(p)
  shape.append(profile[-2]);shape.append(Vector2(profile[-2].x,1500));shape.append(Vector2(profile[0].x,1500))
  shore.draw_colored_polygon(shape,Color("070808"))
 # The broad cave vault recedes out over the arrival vista, enclosing the launch cove.
 _soft_poly(shore,[[-1900,-1800],[1050,-1800],[1050,-580],[973,-392],[841,-204],[774,-107],[689,-24],[595,30],[498,62],[433,116],[350,166],[210,218],[80,234],[-70,270],[-280,327],[-760,365],[-1900,390]],Color("070808"))

func _soft_poly(node:Node2D,xy:Array,ink:Color)->void:
 var pts:=PackedVector2Array()
 for i in xy.size():
  var p0:=Vector2(xy[(i-1+xy.size())%xy.size()][0],xy[(i-1+xy.size())%xy.size()][1])
  var p1:=Vector2(xy[i][0],xy[i][1]);var p2:=Vector2(xy[(i+1)%xy.size()][0],xy[(i+1)%xy.size()][1])
  var p3:=Vector2(xy[(i+2)%xy.size()][0],xy[(i+2)%xy.size()][1])
  for j in 10:
   var t:=float(j)/10.
   pts.append(.5*((2.*p1)+(-p0+p2)*t+(2.*p0-5.*p1+4.*p2-p3)*t*t+(-p0+3.*p1-3.*p2+p3)*t*t*t))
 node.draw_colored_polygon(pts,ink)

func _draw_rear()->void:
 # Land ends fade in atmospheric depth; no decorative polygon ledges behind both shores.
 pass

func _draw_jetty()->void:
 # The fan grows from a rooted, twisted bough under the vault. There is no old rack.
 _soft_poly(props,[[-400,434],[-180,402],[-16,383],[132,389],[260,403],[380,421],[504,429],[527,435],[500,441],[373,435],[256,420],[130,411],[-10,406],[-172,426],[-400,471]],INK)
 _beam(props,Vector2(245,416),Vector2(281,370),5,26)
 _beam(props,Vector2(281,370),Vector2(316,357),2.4,29)

func _reed_patch(node:Node2D,start:float,end:float,base:float,seed_value:int,tall:float,grounded:bool)->void:
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var x:=start
 while x<end:
  x+=rng.randf_range(4.,11.)
  var t:float=(x-start)/(end-start)
  var envelope:=pow(maxf(0.,sin(clampf(t,0.,1.)*PI)),.45)
  var ht:=rng.randf_range(tall*.30,tall)*envelope
  if ht<2.:continue
  var y:float=level.ground_y(x)+3. if grounded else base+sin(x*.009)*11.
  var lean:=rng.randf_range(-ht*.32,ht*.40)+sin(clock*.65+x*.017)*ht*.018
  var curve:=PackedVector2Array()
  for j in 9:
   var u:=float(j)/8.;curve.append(Vector2(x+lean*u*u,y-ht*u))
  node.draw_polyline(curve,Color("070808"),rng.randf_range(1.,2.1),true)
  for j in range(1,4):
   var u:float=float(j)*.21;var at:=Vector2(x+lean*u*u,y-ht*u)
   var side:float=-1. if rng.randf()<.5 else 1.
   var length:=ht*rng.randf_range(.24,.48)
   var tip:=at+Vector2(side*length,-length*.28)
   node.draw_colored_polygon(PackedVector2Array([at,at+Vector2(side*length*.38,-length*.30),tip,at+Vector2(side*length*.34,-length*.09)]),Color("070808"))
  if ht>tall*.65 and rng.randf()<.32:
   node.draw_line(curve[7],curve[8]+Vector2(0,-ht*.12),Color("0b0c0c"),3.7,true)

func _draw_shore_reeds()->void:
 _reed_patch(reeds,260,555,0,82,24,true)
 _reed_patch(reeds,2620,2800,0,83,26,true)
 _reed_patch(reeds,3050,3310,0,84,30,true)

func _draw_near_bank()->void:
 # Real foreground shore is lower and closer than the landing, never a mirrored pair of slopes.
 _soft_poly(front_root,[[-2000,560],[-320,598],[-70,624],[120,649],[290,681],[413,733],[545,807],[660,920],[660,1800],[-2000,1800]],Color("030404"))
 _soft_poly(front_root,[[1720,1130],[1940,977],[2150,873],[2380,806],[2590,770],[2770,755],[3190,756],[4200,730],[4200,1800],[1720,1800]],Color("030404"))
 _reed_patch(front_root,-160,390,699,90,100,false)
 _reed_patch(front_root,2350,3310,805,92,130,false)

func _draw_bay_splash()->void:
 for impact in water_impacts:
  var t:float=impact.age
  var width:float=impact.spread+32.*t
  var size:=Vector2(width*2.,8.+t*8.)
  surface.draw_texture_rect(dust_texture,Rect2(Vector2(impact.x,water_line(impact.x)+3)-size*.5,size),false,Color(1,1,1,maxf(0.,.30-t*.20)))

const BAY_WAVE_N=560
const BAY_WAVE_X0=580.

func _init_waves() -> void:
 wave_h.resize(BAY_WAVE_N)
 wave_v.resize(BAY_WAVE_N)
 wave_damp.resize(BAY_WAVE_N)
 for i in BAY_WAVE_N:
  var x := BAY_WAVE_X0 + i * WAVE_DX
  # the banks soak the swell up (it does not bounce back off the mud like off a wall)
  var shore := minf(absf(x - 650.0), absf(x - 2470.0))
  var outside := 1.0 if (x < 650.0 or x > 2470.0) else 0.0
  wave_damp[i] = WAVE_DAMP + 5.0 * (1.0 - smoothstep(0.0, 70.0, shore)) + 8.0 * outside
 wave_texture = ImageTexture.create_from_image(Image.create_from_data(BAY_WAVE_N, 1, false, Image.FORMAT_RF, wave_h.to_byte_array()))


func wave_at(x: float) -> float:
 if wave_h.is_empty():
  return 0.0
 var f := clampf((x - BAY_WAVE_X0) / WAVE_DX, 0.0, BAY_WAVE_N - 1.001)
 var i := int(f)
 return lerpf(wave_h[i], wave_h[i + 1], f - float(i))


func _update_waves(delta: float) -> void:
 if wave_h.is_empty():
  return
 for k in range(wave_kicks.size() - 1, -1, -1):
  wave_kicks[k].delay = float(wave_kicks[k].delay) - delta
  if float(wave_kicks[k].delay) <= 0.0:
   disturb(float(wave_kicks[k].x), float(wave_kicks[k].impulse), float(wave_kicks[k].width))
   wave_kicks.remove_at(k)
 var steps := clampi(int(ceil(delta * 120.0)), 1, 5)
 var dt := minf(delta, 0.05) / float(steps)
 var c2 := WAVE_SPEED * WAVE_SPEED / (WAVE_DX * WAVE_DX)
 var energy := 0.0
 for step in steps:
  for i in range(1, BAY_WAVE_N - 1):
   var accel := c2 * (wave_h[i - 1] + wave_h[i + 1] - 2.0 * wave_h[i]) - wave_damp[i] * wave_v[i]
   wave_v[i] += accel * dt
  for i in range(1, BAY_WAVE_N - 1):
   # (the water level also settles by itself: without this a displaced volume would only spread out, never go away)
   wave_h[i] = clampf((wave_h[i] + wave_v[i] * dt) * (1.0 - WAVE_LEAK * dt), -WAVE_MAX, WAVE_MAX)
 for i in BAY_WAVE_N:
  energy += absf(wave_h[i])
 wave_energy = energy
 wave_texture.update(Image.create_from_data(BAY_WAVE_N, 1, false, Image.FORMAT_RF, wave_h.to_byte_array()))

# The raft on the water, every frame: the bow pushes a swell ahead, the stern leaves a trough that follows, the hull sinking
# (`press`, px/s downwards) or tipping (`tip`, rad/s) shoves the water under it outwards.

func disturb(x: float, impulse: float, width: float) -> void:
 if wave_v.is_empty():
  return
 var centre := (x - BAY_WAVE_X0) / WAVE_DX
 var reach := int(ceil(width * 2.2 / WAVE_DX))
 for i in range(maxi(1, int(centre) - reach), mini(BAY_WAVE_N - 1, int(centre) + reach + 1)):
  var d := (float(i) - centre) * WAVE_DX / width
  wave_v[i] += impulse * exp(-d * d)
