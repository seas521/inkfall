extends Node2D

# Presentation follows the encounter state; the actor still uses existing
# Seedance clips and retains the shared player scale.
const Layout=preload("res://scripts/chapters/forest_predator_layout.gd")
const Scene1=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const IDLE_SHADER=preload("res://assets/shaders/forest_predator_idle.gdshader")
const Motion=preload("res://scripts/chapters/forest_predator_motion.gd")
const HANGING_TREE=preload("res://assets/art/polyfork/forest-v1/hanging-larch-v1.png")
const ROOT_GRASS=preload("res://assets/art/polyfork/forest-v1/scorched-grass-no-soil-v1.png")
const GRASS_ROOT:=Vector2(269.303,425.342)
const ATLAS=preload("res://assets/art/c_zone_debug/forest/predator-v1/predator-atlas-v1.png")
const TREE_X:=Layout.TREE_X
const PLANT_X:=Layout.PLANT_X
const TREE_SCALE:=Layout.TREE_SCALE
const PLANT_SCALE:=0.35
const TREE_ROOT:=Layout.TREE_ROOT
const BRANCH_TIP:=Layout.BRANCH_TIP
const ROPE_LENGTH:=146.0
var encounter
var clip_frames:Array[Texture2D]=[]
var clip_sprite:Sprite2D
var current_frame:=-1
var current_idle:=false
var idle_material:ShaderMaterial
var loose:Node2D
var loose_sprite:Sprite2D
var particles:Node2D
var tree:Sprite2D
var plant:Node2D
var hanger:Node2D
var carcass:Sprite2D
var clock:=0.0

func _ready()->void:
	z_index=3
	var shader:=preload("res://assets/shaders/forest_prop_soft_ink.gdshader")
	var material_value:=ShaderMaterial.new()
	material_value.shader=shader
	material_value.set_shader_parameter("key_white",false)
	material_value.set_shader_parameter("ink",Color(0.003,0.003,0.003,1.0))
	var tree_ground:=Vector2(TREE_X,Scene1.ground_top(TREE_X)+Layout.TREE_EMBED)
	tree=Sprite2D.new()
	tree.centered=false
	tree.texture=HANGING_TREE
	tree.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	tree.material=material_value
	tree.scale=Vector2.ONE*TREE_SCALE
	tree.position=tree_ground-TREE_ROOT*TREE_SCALE
	add_child(tree)
	hanger=Node2D.new()
	hanger.position=tree_ground+(BRANCH_TIP-TREE_ROOT)*TREE_SCALE
	add_child(hanger)
	var rope:=Line2D.new()
	rope.width=1.5
	rope.default_color=Color(0.008,0.008,0.008)
	rope.antialiased=true
	rope.points=PackedVector2Array([Vector2.ZERO,Vector2(0.8,48),Vector2(-0.5,100),Vector2(0,ROPE_LENGTH)])
	hanger.add_child(rope)
	carcass=_sprite(Rect2(640,250,300,600),material_value)
	carcass.scale=Vector2.ONE*0.14
	carcass.position=Vector2(0,ROPE_LENGTH)-Vector2(130,50)*0.14
	hanger.add_child(carcass)
	plant=Node2D.new()
	plant.position=Vector2(PLANT_X,Scene1.ground_top(PLANT_X)+6)
	add_child(plant)
	clip_sprite=Sprite2D.new()
	clip_sprite.centered=false
	clip_sprite.z_index=4
	clip_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	plant.add_child(clip_sprite)
	for index in int(Motion.DATA.frames):
		clip_frames.append(load("res://assets/art/c_zone_debug/forest/predator-seedance-v1/f_%03d.png"%index))
	idle_material=ShaderMaterial.new()
	idle_material.shader=IDLE_SHADER
	_set_frame(0,true)
	# Sparse soil-free tufts overlap only the tree foot and lowest plant roots.
	for tuft in [[TREE_X-42,33.0,false],[TREE_X+37,28.0,true],[PLANT_X-30,30.0,true],[PLANT_X+35,36.0,false]]:
		_add_root_grass(float(tuft[0]),float(tuft[1]),bool(tuft[2]),material_value)
	loose=Node2D.new()
	loose.z_index=3
	add_child(loose)
	loose_sprite=_sprite(Rect2(640,250,300,600),material_value)
	loose_sprite.scale=Vector2.ONE*0.14
	loose_sprite.position=-Vector2(130,50)*0.14
	loose.add_child(loose_sprite)
	loose.hide()
	particles=Node2D.new()
	particles.z_index=5
	particles.draw.connect(_draw_particles)
	add_child(particles)
	hide()

func _add_root_grass(x:float,height:float,mirror:bool,ink:Material)->void:
	var tuft:=Sprite2D.new()
	tuft.texture=ROOT_GRASS
	tuft.centered=false
	tuft.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tuft.material=ink
	tuft.z_index=8
	var size:=height/339.0
	tuft.scale=Vector2(-size if mirror else size,size)
	tuft.position=Vector2(x,Scene1.ground_top(x)+6)-GRASS_ROOT*tuft.scale
	add_child(tuft)

func _sprite(region:Rect2,ink:Material)->Sprite2D:
	var sprite:=Sprite2D.new()
	var texture:=AtlasTexture.new()
	texture.atlas=ATLAS
	texture.region=region
	texture.filter_clip=true
	sprite.texture=texture
	sprite.centered=false
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.material=ink
	return sprite

func _set_frame(index:int,idle:=false)->void:
	if index==current_frame and idle==current_idle:return
	current_frame=index
	current_idle=idle
	var rect:Array=Motion.DATA.rects[0 if idle else index]
	clip_sprite.texture=clip_frames[0 if idle else index]
	clip_sprite.material=idle_material if idle else null
	clip_sprite.position=Vector2(float(rect[0]),float(rect[1]))-Vector2(float(Motion.DATA.root[0]),float(Motion.DATA.root[1]))

func sync(delta:float,camera_x:float,camera_y:float,active:bool)->void:
	var left:=TREE_X-140
	var right:=PLANT_X+150
	var carrying_visible:bool=encounter!=null and encounter.owns_bait()
	var bait_visible:bool=encounter!=null and encounter.bait in [encounter.Bait.FLYING,encounter.Bait.GROUND] and absf(encounter.bait_position.x-camera_x-640)<900
	visible=active and ((camera_x<right+200 and camera_x+1280>left-200) or carrying_visible or bait_visible) and camera_y< -4000
	if not visible:return
	clock+=delta
	hanger.rotation=encounter.hanging_angle() if encounter!=null else 0.0
	if encounter==null:return
	# One fixed video root and scale. Never rotate, stretch or crossfade the
	# recorded plant; all poses come from the continuous source frames.
	plant.scale=Vector2(-encounter.attack_side,1.0)*Layout.VIDEO_DISPLAY_SCALE
	plant.rotation=0.0
	plant.position=encounter.base()
	_set_frame(Motion.frame_index(encounter.flower,encounter.animation_time()),encounter.flower==encounter.Flower.ALERT)
	if current_idle:idle_material.set_shader_parameter("closure",Motion.idle_closure(encounter.animation_time()))
	carcass.visible=encounter.rope_attached
	loose.visible=not encounter.rope_attached and encounter.bait!=encounter.Bait.GONE
	loose.position=encounter.hand() if encounter.bait==encounter.Bait.HELD else encounter.bait_position
	loose.rotation=encounter.bait_angle if encounter.bait in [encounter.Bait.FLYING,encounter.Bait.GROUND] else 0.0
	loose.scale=Vector2.ONE
	loose.modulate.a=1.0
	if encounter.bait==encounter.Bait.IN_MOUTH:
		var age:float=encounter.swallow_age()
		var swallow:float=smoothstep(0.05,0.65,age)
		loose.position=encounter.mouth()+Vector2(0,-20).lerp(Vector2(18,-20),swallow)
		loose.scale=Vector2.ONE*lerpf(1.0,0.70,swallow)
		loose.modulate.a=1.0-smoothstep(0.38,0.70,age)
	particles.queue_redraw()

func _draw_particles()->void:
	if encounter==null:return
	for puff in encounter.dust:
		var alpha:float=sin(puff.age/puff.life*PI)*0.22
		particles.draw_circle(puff.p,2.0+puff.age*5.0,Color(0.12,0.12,0.12,alpha))

	for drop in encounter.fluid:
		if drop.age<0:continue
		var alpha:float=(1.0-smoothstep(0.65,1.0,drop.age/drop.life))*0.85
		var ink:=Color(0.025,0.025,0.025,alpha)
		if drop.landed:
			particles.draw_line(drop.p-Vector2(drop.size*2,0),drop.p+Vector2(drop.size*2,0),ink,1.2,true)
		else:
			var tail:Vector2=Vector2(drop.v).normalized()*minf(7.0,Vector2(drop.v).length()*0.028)
			particles.draw_line(drop.p-tail,drop.p,ink,drop.size,true)
			particles.draw_circle(drop.p,drop.size*0.65,ink)
	# Thin strands stretch between the lips as the bolus is swallowed, then
	# break before the head settles. They belong to the mouth, not the air.
	var age:float=encounter.swallow_age()
	if age>0.18 and age<0.72:
		var opacity:float=sin((age-0.18)/0.54*PI)*0.7
		var at:Vector2=encounter.mouth()
		for i in 2:
			var x:float=-26+float(i)*19
			var points:=PackedVector2Array([at+Vector2(x,-12),at+Vector2(x-2,4+age*8),at+Vector2(x+3,16)])
			particles.draw_polyline(points,Color(0.02,0.02,0.02,opacity),0.8,true)
