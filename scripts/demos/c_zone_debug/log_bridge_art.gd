extends Node2D

# Same black ink/edge pass as C. Every moving shape follows its actual body.
const MarshArt = preload("res://scripts/demos/c_zone_debug/marsh_art.gd")
const DEPTH = preload("res://assets/shaders/log_bridge_depth.gdshader")
const LIGHT = preload("res://assets/shaders/cinematic_light_cone.gdshader")
const DEADWOOD = preload("res://assets/art/descent/rope-ladder/deadwood-silhouette.png")
const RAVINE = preload("res://assets/art/descent/rope-ladder/destination-valley-v3.png")
const CLIFF = preload("res://assets/art/descent/rope-ladder/cliff-silhouette.png")
const BANK = preload("res://assets/art/descent/rope-ladder/bank-silhouette.png")
const INK := Color("050606")
const BLUR := """shader_type canvas_item;
uniform float radius=4.0;
uniform bool flatten=false;
uniform vec3 fill=vec3(0.25);
uniform float opacity=1.0;
void fragment(){
 vec2 px=TEXTURE_PIXEL_SIZE*radius; vec4 c=texture(TEXTURE,UV)*0.25;
 c+=(texture(TEXTURE,UV+vec2(px.x,0))+texture(TEXTURE,UV-vec2(px.x,0))+texture(TEXTURE,UV+vec2(0,px.y))+texture(TEXTURE,UV-vec2(0,px.y)))*0.125;
 c+=(texture(TEXTURE,UV+px)+texture(TEXTURE,UV-px)+texture(TEXTURE,UV+vec2(px.x,-px.y))+texture(TEXTURE,UV+vec2(-px.x,px.y)))*0.0625;
 COLOR=vec4(flatten?fill:c.rgb/max(c.a,0.0001),c.a*opacity);
}"""
var puzzle
var back: CanvasLayer
var front: CanvasLayer
var depth: ColorRect
var cone: ColorRect
var ink_stage: Dictionary
var mid_stage: Dictionary
var near_stage: Dictionary
var log_ink: Node2D
var pin_ink: Node2D
var flecks: Node2D
var camera := Vector2.ZERO
var clock := 0.0
var noise := FastNoiseLite.new()
var particles: Array[Dictionary] = []
var dust_puffs: Array[Dictionary] = []
var dust_texture: GradientTexture2D
var impact_count := 0
var scrape_distance := 0.0
var scrape_count := 0
var release_count := 0
var landing_dust_count := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	noise.seed = 63057
	noise.frequency = 0.026
	rng.seed = 6843
	var dust_gradient:=Gradient.new()
	dust_gradient.offsets=PackedFloat32Array([0.0,0.28,0.64,1.0])
	dust_gradient.colors=PackedColorArray([Color(1,1,1,0.6),Color(1,1,1,0.35),Color(1,1,1,0.1),Color(1,1,1,0)])
	dust_texture=GradientTexture2D.new()
	dust_texture.width=64
	dust_texture.height=64
	dust_texture.gradient=dust_gradient
	dust_texture.fill=GradientTexture2D.FILL_RADIAL
	dust_texture.fill_from=Vector2(0.5,0.5)
	dust_texture.fill_to=Vector2(1,0.5)
	back = CanvasLayer.new()
	back.layer = -12
	add_child(back)
	depth = ColorRect.new()
	depth.size = Vector2(1280,720)
	depth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material_value := ShaderMaterial.new()
	material_value.shader = DEPTH
	material_value.set_shader_parameter("ravine",RAVINE)
	material_value.set_shader_parameter("mountain_contour",_destination_contour())
	depth.material = material_value
	back.add_child(depth)
	# One render target for the terrain AND the original cabin/yard/tree.
	# Separate viewport color transforms had made equal inks look different.
	depth.reparent(puzzle.level.art.landmark_view,false)
	depth.z_index=-100
	mid_stage = _stage(back,7.0,false)
	mid_stage.output.material.set_shader_parameter("flatten",true)
	mid_stage.output.material.set_shader_parameter("fill",Vector3(0.24,0.24,0.24))
	cone = ColorRect.new()
	cone.position = Vector2(130,-240)
	cone.size = Vector2(1100,1050)
	cone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light_material := ShaderMaterial.new()
	light_material.shader = LIGHT
	light_material.set_shader_parameter("intensity",0.10)
	light_material.set_shader_parameter("light_tint",Vector3(0.7,0.7,0.7))
	cone.material = light_material
	back.add_child(cone)
	cone.reparent(puzzle.level.art.landmark_view,false)
	cone.z_index=-50
	ink_stage = _stage(self,1.5,true)
	ink_stage.output.z_index = 2
	var land := Node2D.new()
	land.draw.connect(_draw_land)
	ink_stage.root.add_child(land)
	log_ink = Node2D.new()
	log_ink.draw.connect(_draw_log)
	ink_stage.root.add_child(log_ink)
	pin_ink = Node2D.new()
	pin_ink.draw.connect(_draw_pin)
	ink_stage.root.add_child(pin_ink)
	var socket := Node2D.new()
	socket.draw.connect(_draw_socket)
	ink_stage.root.add_child(socket)
	front = CanvasLayer.new()
	front.layer = 16
	add_child(front)
	near_stage = _stage(front,4.0,false)
	var near := Node2D.new()
	near.draw.connect(_draw_near)
	near_stage.root.add_child(near)
	flecks = Node2D.new()
	flecks.draw.connect(_draw_flecks)
	front.add_child(flecks)
	sync(0,Vector2.ZERO,false)

func _destination_contour() -> Texture2D:
	# Follow the authored ridge instead of imposing a straight diagonal.
	# This tiny one-row lookup describes the source contour, not new terrain.
	var source:Image=RAVINE.get_image()
	if source.is_compressed(): source.decompress()
	source.resize(512,288,Image.INTERPOLATE_BILINEAR)
	source.convert(Image.FORMAT_L8)
	var pixels:PackedByteArray=source.get_data()
	var w:int=source.get_width()
	var h:int=source.get_height()
	var ridge:=Image.create(w,1,false,Image.FORMAT_RF)
	var previous:float=0.44*h
	var previous_step:=0.0
	for x in range(w-1,-1,-1):
		var y:float=previous
		if previous>=h-6:
			y=minf(float(h)+4.0,previous+maxf(0.2,previous_step))
		else:
			var best:=INF
			for candidate in range(maxi(4,int(previous)-5),mini(h-4,int(previous)+6)):
				var contrast:=0.0
				for dx in [-1,0,1]:
					var sx:int=clampi(x+dx,0,w-1)
					contrast+=float(pixels[(candidate+2)*w+sx])+float(pixels[(candidate+3)*w+sx])-float(pixels[(candidate-2)*w+sx])-float(pixels[(candidate-3)*w+sx])
				var cost:float=contrast/6.0+absf(candidate-previous)
				if cost<best:
					best=cost
					y=candidate
		previous_step=y-previous
		previous=y
		ridge.set_pixel(x,0,Color(y/float(h),0,0,1))
	return ImageTexture.create_from_image(ridge)

func _stage(parent: Node, radius: float, ink: bool) -> Dictionary:
	var view := SubViewport.new()
	view.size = Vector2i(1328,768) if ink else Vector2i(1280,720)
	view.transparent_bg = true
	view.disable_3d = true
	view.msaa_2d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	parent.add_child(view)
	var root := Node2D.new()
	view.add_child(root)
	var output := Sprite2D.new()
	output.centered = false
	output.texture = view.get_texture()
	output.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = MarshArt.INK_SHADER if ink else BLUR
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("soften" if ink else "radius",radius)
	if ink:
		material_value.set_shader_parameter("ink",INK)
	output.material = material_value
	parent.add_child(output)
	return {"view":view,"root":root,"output":output}

func sync(delta: float, origin: Vector2, enabled: bool) -> void:
	visible = enabled
	back.visible = enabled
	front.visible = enabled
	for stage in [ink_stage,mid_stage,near_stage]:
		stage.view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	mid_stage.output.hide()
	mid_stage.view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if not enabled:
		return
	camera = origin
	flecks.position=-puzzle.level.camera.offset
	clock += delta
	# Camera impacts must never expose a hard viewport edge around the ground.
	ink_stage.root.position = -origin.round()+Vector2(24,24)
	ink_stage.output.position = origin-Vector2(24,24)
	log_ink.transform = Transform2D(puzzle.angle,puzzle.PIVOT)
	pin_ink.transform = puzzle.pin_body.global_transform
	var relative: Vector2 = origin-puzzle.ORIGIN
	mid_stage.root.position = -relative*Vector2(0.24,0.14)
	near_stage.root.position = -relative*1.08
	# Background, foreground and fog share the whole gorge, independent of
	# whether the player is climbing, in flight or standing on either bank.
	var entrance:float=puzzle.level.rope_ladder.entry_mix() if puzzle.level.rope_ladder != null else 1.0
	for item in [cone]:
		item.modulate.a=entrance
	depth.modulate.a=1.0
	depth.material.set_shader_parameter("opacity",1.0)
	mid_stage.output.material.set_shader_parameter("opacity",entrance)
	cone.material.set_shader_parameter("intensity",0.10*entrance)
	near_stage.output.visible = false
	near_stage.view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	(depth.material as ShaderMaterial).set_shader_parameter("clock",clock)
	(depth.material as ShaderMaterial).set_shader_parameter("camera",relative)
	(cone.material as ShaderMaterial).set_shader_parameter("clock",clock)
	for i in range(particles.size()-1,-1,-1):
		particles[i].age += delta
		particles[i].p += particles[i].v*delta
		particles[i].v.y += 100*delta
		if particles[i].age > 0.9:
			particles.remove_at(i)
	for i in range(dust_puffs.size()-1,-1,-1):
		dust_puffs[i].age+=delta
		dust_puffs[i].p+=dust_puffs[i].v*delta
		dust_puffs[i].v*=exp(-delta*1.5)
		if dust_puffs[i].age>dust_puffs[i].life:
			dust_puffs.remove_at(i)
	flecks.queue_redraw()

func impact() -> void:
	impact_count+=1
	var at: Vector2 = puzzle.PIVOT+Vector2(puzzle.LENGTH,0).rotated(puzzle.END_ANGLE)
	for i in range(14):
		particles.append({"p":at,"v":Vector2(rng.randf_range(-70,70),rng.randf_range(-65,-12)),"age":0.0,"r":rng.randf_range(0.7,1.6)})
	for point in [at,puzzle.PIVOT+Vector2(5,5)]:
		for i in range(14):
			dust_puffs.append({"p":point+Vector2(rng.randf_range(-12,12),rng.randf_range(-4,2)),"v":Vector2(rng.randf_range(-60,60),rng.randf_range(-65,-18)),"age":0.0,"life":rng.randf_range(1.25,2.0),"r":rng.randf_range(10,20),"alpha":rng.randf_range(0.28,0.46)})

func scrape(travel:float,progress:float)->void:
	scrape_distance+=travel
	while scrape_distance>=3.5:
		scrape_distance-=3.5
		scrape_count+=1
		var contact:Vector2=puzzle.support_world()
		for i in 3:
			dust_puffs.append({"p":contact+Vector2(rng.randf_range(-4,4),rng.randf_range(-3,3)),"v":Vector2(rng.randf_range(-28,14),rng.randf_range(-35,-12)),"age":0.0,"life":rng.randf_range(0.55,0.85),"r":rng.randf_range(3.5,6.5)*(1.0+progress*0.25),"alpha":rng.randf_range(0.30,0.48)})
		particles.append({"p":contact,"v":Vector2(rng.randf_range(-35,12),rng.randf_range(-35,-12)),"age":0.0,"r":rng.randf_range(0.55,1.1)})

func release_dust()->void:
	release_count+=1
	for i in 6:
		dust_puffs.append({"p":puzzle.support_world()+Vector2(rng.randf_range(-5,5),rng.randf_range(-3,2)),"v":Vector2(rng.randf_range(-30,20),rng.randf_range(-36,-12)),"age":0.0,"life":rng.randf_range(0.6,1.0),"r":rng.randf_range(4,8),"alpha":rng.randf_range(0.22,0.35)})

func landing_dust(at:Vector2,force:float)->void:
	landing_dust_count+=1
	for side in [-1.0,1.0]:
		for i in 2:
			dust_puffs.append({"p":at+Vector2(side*7,0),"v":Vector2(side*rng.randf_range(12,28),rng.randf_range(-15,-5)),"age":0.0,"life":rng.randf_range(0.35,0.6),"r":rng.randf_range(3,5)*sqrt(force),"alpha":0.22})

func _draw_land() -> void:
	var node: Node2D = ink_stage.root.get_child(0)
	var o: Vector2 = puzzle.ORIGIN
	# Authored natural rock masses replace the low-point polygon silhouettes.
	node.draw_texture_rect(CLIFF,Rect2(o+Vector2(445-795*0.7,400-197*0.48),Vector2(1024*0.7,1536*0.48)),false)
	# Extend the opaque interior beyond the sprite's left/bottom crop. Only
	# the authored exposed face may meet fog; a sprite border never does.
	node.draw_rect(Rect2(o+Vector2(-1500,415),Vector2(1410,1000)),INK)
	node.draw_texture_rect(BANK,Rect2(o+Vector2(770-376*0.5,555-201*0.5),Vector2(BANK.get_size())*0.5),false)
	# End shoulder; collider shares the visible beginning at x=1225.
	if not puzzle.exit_open:
		node.draw_colored_polygon(PackedVector2Array([o+Vector2(1225,555),o+Vector2(1225,448),o+Vector2(1232,425),o+Vector2(1290,420),o+Vector2(1320,1100)]),INK)
	# A buried root crotch supports the removable chock. Thick, worn and asymmetric.
	_branch(node,[puzzle.PIVOT+Vector2(-57,11),puzzle.PIVOT+Vector2(-31,-3),puzzle.PIVOT+Vector2(-24,-27),puzzle.PIVOT+Vector2(-13,-36)],[14.0,11.0,7.0,3.6])
	_branch(node,[o+Vector2(414,438),o+Vector2(402,464),o+Vector2(409,493),o+Vector2(397,522)],[3.6,2.4,1.4,0.25])
	_branch(node,[o+Vector2(397,478),o+Vector2(379,489),o+Vector2(375,512)],[1.7,1.1,0.2])
	_branch(node,[o+Vector2(791,589),o+Vector2(783,616),o+Vector2(798,640),o+Vector2(792,672)],[3.2,2.2,1.0,0.2])
	# A small dead shrub and buried stones punctuate the shore, clear of the grip.
	_branch(node,[o+Vector2(240,401),o+Vector2(232,382),o+Vector2(234,362)],[2.0,1.3,0.2])
	_branch(node,[o+Vector2(233,386),o+Vector2(219,379),o+Vector2(213,366)],[1.2,0.8,0.2])
	_branch(node,[o+Vector2(234,380),o+Vector2(246,372)],[1.0,0.2])

func _draw_log() -> void:
	# Independent authored deadwood matte. The root area overlaps the static socket.
	log_ink.draw_texture_rect_region(DEADWOOD,Rect2(-12,-14.5,409.6,66.96),Rect2(250,230,1843,372))
	# A narrow ink mass joins the gently worn contact ridge to the exact collider.
	var ridge := PackedVector2Array()
	for x in range(20,381,4):
		ridge.append(Vector2(x,noise.get_noise_1d(x)*0.6-0.4))
	ridge.append(Vector2(380,7))
	ridge.append(Vector2(20,7))
	log_ink.draw_colored_polygon(ridge,INK)
	# A worn underside bearing joins the authored bark to the actual ramp
	# contact. Its outer surface and the collider share the same point.
	_branch(log_ink,[Vector2(26,19),Vector2(35,23),Vector2(43,19)],[4.0,4.3,3.0])

func _draw_pin() -> void:
	pin_ink.draw_colored_polygon(puzzle.wedge_polygon(),INK)
	# An integral worn timber tail meets the wedge below its bearing face.
	# The original recorded hand contact stays at the left end.
	_branch(pin_ink,[Vector2(-33,0),Vector2(-10,9),Vector2(18,25)],[6.0,6.0,5.0])

func _draw_socket() -> void:
	var node: Node2D = ink_stage.root.get_child(3)
	var p: Vector2 = puzzle.PIVOT
	# Fixed timber guide beneath the wedge, visibly rooted into the bank.
	_branch(node,[p+Vector2(-38,9),p+Vector2(10,9),p+Vector2(56,8),p+Vector2(97,6)],[13.0,11.0,8.0,6.0])
	_branch(node,[p+Vector2(-42,34),p+Vector2(7,26),p+Vector2(62,17),p+Vector2(92,9)],[9.0,8.0,5.0,3.0])
	_branch(node,[p+Vector2(-4,14),p+Vector2(-26,23),p+Vector2(-42,19)],[7.0,4.0,0.4])

func _eroded(points: Array, amount: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i+1]
		var normal := (b-a).orthogonal().normalized()
		var count := maxi(2,int(a.distance_to(b)/3))
		for j in range(count):
			var t := float(j)/count
			var p := a.lerp(b,t)
			var chips := noise.get_noise_2d(p.x*2.1,p.y*2.1)+noise.get_noise_2d(p.x*5.0,p.y*5.0)*0.3
			result.append(p+normal*chips*amount*sin(t*PI))
	result.append(points[-1])
	return result

func _branch(node: Node2D, points: Array, widths: Array, color := INK) -> void:
	# The same tapering Bezier mass construction used for C's dead wood.
	var spine: Array[Vector2] = []
	var radii: Array[float] = []
	for i in range(points.size()-1):
		var a: Vector2 = points[i]
		var d: Vector2 = points[i+1]
		var b: Vector2 = a+(d-Vector2(points[maxi(0,i-1)]))/6
		var c: Vector2 = d-(Vector2(points[mini(points.size()-1,i+2)])-a)/6
		for j in range(14):
			var t := float(j)/14
			spine.append(a.bezier_interpolate(b,c,d,t))
			radii.append(lerpf(widths[i],widths[i+1],t))
	spine.append(points[-1])
	radii.append(widths[-1])
	var outline := PackedVector2Array()
	for side in [1.0,-1.0]:
		for j in range(spine.size()):
			var i: int = j if side>0 else spine.size()-1-j
			var normal := (spine[mini(i+1,spine.size()-1)]-spine[maxi(0,i-1)]).orthogonal().normalized()
			outline.append(spine[i]+normal*radii[i]*side)
	node.draw_colored_polygon(outline,color)

func _draw_near() -> void:
	var node: Node2D = near_stage.root.get_child(0)
	# A heavily cropped near shoulder stays below the climbing path. It never
	# switches on when the player lets go of the ladder.
	node.draw_texture_rect(BANK,Rect2(-450,600,500,400),false)

func _draw_flecks() -> void:
	for puff in dust_puffs:
		var t:float=puff.age/puff.life
		var radius:float=puff.r*(1.0+t*2.4)
		var alpha:float=puff.alpha*smoothstep(0,0.10,puff.age)*pow(1.0-t,1.5)
		var size:=Vector2(radius*2.7,radius*1.8)
		flecks.draw_texture_rect(dust_texture,Rect2(Vector2(puff.p)-camera-size*0.5,size),false,Color(0.52,0.52,0.52,alpha))
	for p in particles:
		flecks.draw_circle(Vector2(p.p)-camera,p.r,Color(0.48,0.48,0.48,(1-float(p.age)/0.9)*0.34),true,-1,true)
	for i in range(15):
		var age := fposmod(clock*0.016+float(i)*0.173,1)
		var at := Vector2(fposmod(float(i)*147.73+sin(age*3+i)*19,1280),740-age*800)
		flecks.draw_circle(at,0.55+float(i%3)*0.2,Color(0.7,0.7,0.7,sin(age*PI)*0.07),true,-1,true)
