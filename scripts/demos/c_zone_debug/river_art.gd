extends Node2D

const BACKGROUND = preload("res://assets/art/c_zone_debug/forest-panorama.png")
const Fan = preload("res://scripts/demos/c_zone_debug/fan_art.gd")
const CrookedTree = preload("res://scripts/demos/c_zone_debug/crooked_tree_art.gd")
const LIGHT = preload("res://assets/shaders/cinematic_light_cone.gdshader")
const SCREEN := Vector2(1280, 720)
const DESTINATION_FIRE_UV := Vector2(0.884,0.447)
const DESTINATION_INK := 0.22
const DESTINATION_TREE = preload("res://assets/art/descent/rope-ladder/destination-yard-tree-v2.png")
const DESTINATION_TREE_SCALE := 0.130631135
const DESTINATION_TREE_ROOT := Vector2(521,1456)
const INK := Color("050606")
const SurfaceArt = preload("res://scripts/art/surface_layered_art.gd")
const SurfaceBatFlock = preload("res://scripts/art/surface_bat_flock.gd")
const HunterArt = preload("res://scripts/demos/c_zone_debug/hunter_art.gd")
const Scene1Ref = preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const ForestPlates = preload("res://scripts/demos/c_zone_debug/forest_plates.gd")
const GRASS_STRIP = preload("res://assets/art/c_zone_debug/forest/forest_grass_strip.jpg")
const BOULDER = preload("res://assets/art/c_zone_debug/forest/forest_boulder_block.jpg")
const BRAMBLE = preload("res://assets/art/c_zone_debug/forest/forest_bramble.jpg")
const FALLEN_LOG = preload("res://assets/art/c_zone_debug/forest/forest_fallen_log.jpg")
const CreviceArt=preload("res://scripts/art/rock_crevice_art.gd")
const SpiderArt=preload("res://scripts/art/forest_spider_art.gd")
const PredatorArt = preload("res://scripts/art/forest_predator_art.gd")
const MistyForest = preload("res://scripts/demos/c_zone_debug/misty_forest.gd")
# how bright the fog is along scene 1 (0 = where he wakes, 1 = the cliff): dark at first, the clearing is the brightest
const FOG_LEVEL_KEYS := [Vector2(0.0, 0.54), Vector2(0.08, 0.58), Vector2(0.30, 0.62), Vector2(0.46, 0.80), Vector2(0.56, 0.96), Vector2(0.70, 0.80), Vector2(1.0, 0.72)]

var level: Node2D
var clock := 0.0
var camera_x := 0.0
var background: Sprite2D
var plates_far:Node2D
var plates_mid:Node2D
var plates_close:Node2D
var forest_back: ColorRect
var opening_back: ColorRect
var route_back: ColorRect
var mid: Node2D
var terrain: Node2D
var props: Node2D
var crate_art: Node2D
var raft_front: Node2D
var bank_grass: Node2D
var surface: Node2D
var water_volume: Polygon2D
var water_impacts: Array[Dictionary] = []
var water_impact_count := 0
# The water surface is a row of columns (one every WAVE_DX px) that obeys a damped wave equation: whatever disturbs the water
# (a body falling in, the raft's bow, a stroke of the drowning boy) pushes the columns, and the swell runs outwards, rocks the
# raft and fades by itself. The shader draws it, the raft reads it (wave_at / wave_slope_between).
const WAVE_X0 := 1100.0
const WAVE_DX := 4.0
const WAVE_N := 264
const WAVE_SPEED := 150.0  # px/s: how fast a swell travels
const WAVE_DAMP := 1.9  # 1/s: the swell loses about half its height every 0.75 s
const WAVE_LEAK := 1.3  # 1/s
const WAVE_MAX := 15.0  # px
var wave_h := PackedFloat32Array()
var wave_v := PackedFloat32Array()
var wave_damp := PackedFloat32Array()
var wave_kicks: Array[Dictionary] = []
var wave_texture: ImageTexture
var wave_energy := 0.0
const WAKE_BOW := 1.1  # px/s of swell added per second per px/s of the raft's speed
const HULL_PRESS := 1.5
const HULL_TIP := 120.0
const WADE_PUSH := 1.2
var ground_dust: Array[Dictionary] = []
var dust_layer: Node2D
var dust_texture: GradientTexture2D
var dust_gap := 0.0
var spray_rng := RandomNumberGenerator.new()
var foreground: Node2D
var atmosphere: ColorRect
var lens: ColorRect
var cone: ColorRect
var cone_act_two: ColorRect
var cone_forest: ColorRect
var surface_layer: CanvasLayer
var surface_art: Node2D
var landmark_layer:CanvasLayer
var landmark_view:SubViewport
var landmark_output:Sprite2D
var fan_pickup: Node2D
var mid_view: SubViewport
var fore_view: SubViewport
var near_view: SubViewport
var near_blur_sprite: Sprite2D
var plates_near: Node2D
var opening_trees: Node2D
var opening_middle: Node2D
var grass_art: Node2D
var _grass_cached_edge := INF
var _grass_edge_weights:=PackedFloat32Array()
var _grass_weight_origin:=0.0
const GRASS_WEIGHT_STEP:=2.0
var grass_band: Node2D
var weather_art: Node2D  # scene 1's cliff: rain, blown leaves, dust (screen space, over the world, under the lens)
var bat_flock: Node2D  # level 1's flock, for the scene 1 cliff
var crevice_art:Node2D
var spider_art:Node2D
var predator_art: Node2D
var hunter_art: Node2D  # scene 1's hunter: the lantern, the foot, the arm
var weather_level := 0.0
var weather_gust := 0.0
var weather_time := 0.0  # runs faster in the flock's wind
var mid_blur_sprite: Sprite2D
var fore_blur_sprite: Sprite2D
var bank_noise := FastNoiseLite.new()

func _ready() -> void:
	bank_noise.seed = 6317
	bank_noise.frequency = 0.018
	bank_noise.fractal_octaves = 3
	var back_layer := CanvasLayer.new()
	back_layer.layer = -10
	add_child(back_layer)
	background = Sprite2D.new()
	background.centered = false
	background.texture = BACKGROUND
	background.scale = Vector2.ONE * 1.13
	background.position = Vector2(-90, -95)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var back_shader := Shader.new()
	back_shader.code = """shader_type canvas_item;
uniform float reveal_edge = 2.0;
uniform float reveal_soft = 0.34;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	// A real 5x5 gaussian (sigma about 1.3 texels). The earlier 5-tap cross left four shifted
	// copies of every hard edge, which showed up as stepped bands beside the trunks.
	vec4 c = vec4(0.0);
	float total = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			float w = exp(-float(x * x + y * y) / 3.4);
			c += texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE) * w;
			total += w;
		}
	}
	c /= total;
	float v = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// the cut-away: a ragged fog front sweeping from the right to the left across the screen (lower down it runs ahead, like a clearing)
	// (it opens column by column, like gaps between trunks, not as one straight curtain)
	float columns = (vnoise(vec2(SCREEN_UV.x * 16.0, 1.0)) - 0.5) * 0.34 + (vnoise(vec2(SCREEN_UV.x * 5.0, UV.y * 3.0)) - 0.5) * 0.22;
	float front = reveal_edge + (vnoise(vec2(UV.y * 5.0, 3.0)) - 0.5) * 0.28 + (UV.y - 0.5) * 0.18;
	float keep = 1.0 - smoothstep(front - reveal_soft, front + reveal_soft, SCREEN_UV.x + columns);
	COLOR = vec4(vec3(v * 0.83 + 0.075), keep);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = back_shader
	background.material = mat
	back_layer.add_child(background)
	# scenes 1 to 6 are in the forest: its backdrop is made by the misty forest shader (the panorama above is for the C zone)
	forest_back = MistyForest.new()
	forest_back.visible = false
	back_layer.add_child(forest_back)
	plates_far=ForestPlates.new()
	plates_far.setup(&"far",0.16,1500.0,1700.0,0.85,0.58)
	back_layer.add_child(plates_far)
	plates_mid=ForestPlates.new()
	plates_mid.setup(&"mid",0.32,1900.0,2100.0,1.0,0.20)
	back_layer.add_child(plates_mid)
	route_back = ColorRect.new()
	route_back.size = SCREEN
	route_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var route_material := ShaderMaterial.new()
	route_material.shader = preload("res://assets/shaders/forest_route_v1.gdshader")
	route_material.set_shader_parameter("forest_plate", preload("res://assets/art/c_zone_debug/forest/forest-route-chiaroscuro-v1.png"))
	route_back.material = route_material
	back_layer.add_child(route_back)
	opening_back = ColorRect.new()
	opening_back.size = SCREEN
	opening_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var opening_material := ShaderMaterial.new()
	opening_material.shader = preload("res://assets/shaders/forest_opening_v5.gdshader")
	opening_material.set_shader_parameter("forest_plate", preload("res://assets/art/c_zone_debug/forest/forest_opening_chiaroscuro_v5.png"))
	opening_material.set_shader_parameter("right_plate", preload("res://assets/art/c_zone_debug/forest/forest-opening-right-tree-v6.png"))
	opening_back.material = opening_material
	back_layer.add_child(opening_back)
	opening_middle = ForestPlates.new()
	opening_middle.setup(&"mid",0.34,1150.0,1100.0,0.56,0.25)
	back_layer.add_child(opening_middle)
	plates_close=ForestPlates.new()
	plates_close.setup(&"close",0.50,1650.0,630.0,1.0,0.055)
	back_layer.add_child(plates_close)
	opening_trees = ForestPlates.new()
	opening_trees.setup(&"close",0.82,1500.0,470.0,1.0,0.035)
	back_layer.add_child(opening_trees)
	for sprite in opening_trees.sprites:
		(sprite.material as ShaderMaterial).set_shader_parameter("root_haze",0.0)
	# The original cliff-top picture (the far valley, the cliffs, the house across the gap with its fire, the swaying yard tree), kept as it
	# was: here it is placed in the world at the edge of scene 1's cliff, and it fades in as he comes near.
	surface_layer = CanvasLayer.new()
	surface_layer.layer = -12
	add_child(surface_layer)
	surface_art = SurfaceArt.new()
	surface_art.far_mode = true
	surface_layer.add_child(surface_art)
	# The destination ridge, cabin and tree are one continuous graded plate.
	# Only the live campfire is composited above it, on the same parallax.
	landmark_layer=CanvasLayer.new()
	landmark_layer.layer=-11
	add_child(landmark_layer)
	landmark_view=SubViewport.new()
	landmark_view.size=Vector2i(1280,720)
	landmark_view.transparent_bg=true
	landmark_view.disable_3d=true
	landmark_layer.add_child(landmark_view)
	surface_art.far_group.reparent(landmark_view,false)
	surface_art.far_mist.hide()
	# Keep the authored cabin, its actual window and the full workbench yard.
	surface_art.gameplay_sprite.region_rect=Rect2(1130,220,542,240)
	surface_art.gameplay_region_offset=Vector2(1130,220)*SurfaceArt.PLATE_SCALE
	surface_art.gameplay_sprite.material.set_shader_parameter("original_destination",true)
	surface_art.gameplay_sprite.material.set_shader_parameter("low",DESTINATION_INK)
	surface_art.gameplay_sprite.material.set_shader_parameter("high",DESTINATION_INK)
	surface_art.gameplay_sprite.material.set_shader_parameter("spread",2.0)
	surface_art.tree_material.set_shader_parameter("ink",DESTINATION_INK)
	surface_art.tree_sprite.texture=DESTINATION_TREE
	surface_art.tree_sprite.scale=Vector2.ONE*DESTINATION_TREE_SCALE
	landmark_output=Sprite2D.new()
	landmark_output.centered=false
	landmark_output.texture=landmark_view.get_texture()
	var landmark_shader:=Shader.new()
	landmark_shader.code="""shader_type canvas_item;
uniform float exposure=1.0;
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*2.0;
 vec4 c=texture(TEXTURE,UV)*0.25;
 c+=(texture(TEXTURE,UV+vec2(d.x,0))+texture(TEXTURE,UV-vec2(d.x,0))+texture(TEXTURE,UV+vec2(0,d.y))+texture(TEXTURE,UV-vec2(0,d.y)))*0.125;
 c+=(texture(TEXTURE,UV+d)+texture(TEXTURE,UV-d)+texture(TEXTURE,UV+vec2(d.x,-d.y))+texture(TEXTURE,UV+vec2(-d.x,d.y)))*0.0625;
 // Terrain, original yard props and flame are rendered into the SAME
 // opaque image before this common lens pass, avoiding separate grading.
 vec3 unified=pow(max(c.rgb,vec3(0.0)),vec3(1.0/2.2));
 float l=dot(unified,vec3(0.299,0.587,0.114));
 COLOR=vec4(vec3(l),c.a*exposure);
}
"""
	var landmark_material:=ShaderMaterial.new()
	landmark_material.shader=landmark_shader
	landmark_output.material=landmark_material
	landmark_layer.add_child(landmark_output)
	mid_view = _blur_layer(back_layer, 8.0)
	mid_blur_sprite = mid_view.get_meta(&"output_sprite") as Sprite2D
	mid = Node2D.new()
	mid.draw.connect(_draw_mid)
	mid_view.add_child(mid)
	atmosphere = ColorRect.new()
	atmosphere.size = SCREEN
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.material = _atmosphere_material(false)
	back_layer.add_child(atmosphere)
	cone = ColorRect.new()
	cone.size = Vector2(950, 790)
	cone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light_material := ShaderMaterial.new()
	light_material.shader = LIGHT
	light_material.set_shader_parameter("intensity", 0.12)
	light_material.set_shader_parameter("light_tint", Vector3(0.70, 0.70, 0.70))
	cone.material = light_material
	back_layer.add_child(cone)
	# The same dim window of light returns over the marsh, so the backdrop keeps one mood.
	cone_act_two = ColorRect.new()
	cone_act_two.size = Vector2(950, 790)
	cone_act_two.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light_two := ShaderMaterial.new()
	light_two.shader = LIGHT
	light_two.set_shader_parameter("intensity", 0.12)
	light_two.set_shader_parameter("seed", 0.37)
	light_two.set_shader_parameter("light_tint", Vector3(0.70, 0.70, 0.70))
	cone_act_two.material = light_two
	back_layer.add_child(cone_act_two)
	# and once more over the forest above the lift
	cone_forest = ColorRect.new()
	cone_forest.size = Vector2(950, 790)
	cone_forest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light_forest := ShaderMaterial.new()
	light_forest.shader = LIGHT
	light_forest.set_shader_parameter("intensity", 0.13)
	light_forest.set_shader_parameter("seed", 0.71)
	light_forest.set_shader_parameter("light_tint", Vector3(0.70, 0.70, 0.70))
	cone_forest.material = light_forest
	back_layer.add_child(cone_forest)
	_build_scene1_props()
	predator_art=PredatorArt.new()
	predator_art.encounter=level.scene1.predator
	add_child(predator_art)
	spider_art=SpiderArt.new()
	spider_art.encounter=level.scene1.spider
	add_child(spider_art)
	crevice_art=CreviceArt.new()
	crevice_art.scene=level.scene1
	add_child(crevice_art)
	terrain = Node2D.new()
	terrain.z_index = -2
	terrain.draw.connect(_draw_terrain)
	add_child(terrain)
	props = Node2D.new()
	props.z_index = 2
	props.draw.connect(_draw_props)
	add_child(props)
	var tree := CrookedTree.new()
	tree.position = Vector2(190,520)
	tree.z_index = 2
	add_child(tree)
	crate_art = Node2D.new()
	crate_art.z_index = 2
	crate_art.draw.connect(_draw_crate)
	add_child(crate_art)
	raft_front = Node2D.new()
	raft_front.z_index = 7
	raft_front.draw.connect(_draw_raft_front)
	add_child(raft_front)
	dust_texture = _soft_texture()
	dust_layer = Node2D.new()
	dust_layer.z_index = 8
	dust_layer.draw.connect(_draw_ground_dust)
	add_child(dust_layer)
	bank_grass = Node2D.new()
	bank_grass.z_index = 7
	bank_grass.draw.connect(_draw_bank_grass)
	add_child(bank_grass)
	_build_water_volume()
	fan_pickup = Fan.new()
	fan_pickup.position = level.FAN_SPOT + Vector2(0, -10)
	fan_pickup.rotation = 0.48
	fan_pickup.z_index = 1
	add_child(fan_pickup)
	surface = Node2D.new()
	surface.z_index = 9
	surface.draw.connect(_draw_surface)
	var shore_clip := Shader.new()
	shore_clip.code = """shader_type canvas_item;
uniform sampler2D bank_height : repeat_disable, filter_linear;
varying vec2 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	float bed = texture(bank_height,vec2(((world_position.x+120.0)/4.0+0.5)/706.0,0.5)).r*1024.0;
	if (world_position.y >= bed) { discard; }
}
"""
	var shore_material := ShaderMaterial.new()
	shore_material.shader = shore_clip
	shore_material.set_shader_parameter("bank_height",water_volume.material.get_shader_parameter("bank_height"))
	surface.material = shore_material
	add_child(surface)
	var weather_layer := CanvasLayer.new()
	weather_layer.layer = 14
	add_child(weather_layer)
	weather_art = Node2D.new()
	weather_art.draw.connect(_draw_weather)
	weather_art.visible = false
	weather_layer.add_child(weather_art)
	bat_flock = SurfaceBatFlock.new()
	weather_layer.add_child(bat_flock)
	if Scene1Ref.HUNTER_ON:
		hunter_art = HunterArt.new()
		add_child(hunter_art)
		hunter_art.setup(level, self)
	var front_layer := CanvasLayer.new()
	front_layer.layer = 15
	add_child(front_layer)
	near_view = _blur_layer(front_layer, 9.0)
	near_blur_sprite = near_view.get_meta(&"output_sprite") as Sprite2D
	(near_blur_sprite.material as ShaderMaterial).set_shader_parameter("window", 0.9)
	plates_near = ForestPlates.new()
	plates_near.setup(&"near", 1.45, 1500.0, 1500.0)
	plates_near.root_guard=Callable(self,"_near_tree_land_range")
	plates_near.root_ground=Callable(level.scene1,"ground_top")
	plates_near.initial_index=int(floor((Scene1Ref.START_X-525.0)*1.45/1500.0))
	near_view.add_child(plates_near)
	fore_view = _blur_layer(front_layer, 6.0)
	fore_blur_sprite = fore_view.get_meta(&"output_sprite") as Sprite2D
	foreground = Node2D.new()
	foreground.draw.connect(_draw_foreground)
	fore_view.add_child(foreground)
	grass_band = Node2D.new()  # the low, solid mat the blades grow out of (see _draw_grass_band)
	grass_band.draw.connect(_draw_grass_band)
	front_layer.add_child(grass_band)
	grass_art = Node2D.new()
	grass_art.draw.connect(_draw_ground_grass)
	var grass_material := ShaderMaterial.new()
	var grass_shader := Shader.new()
	grass_shader.code = GRASS_SLICE_SHADER
	grass_material.shader = grass_shader
	grass_art.material = grass_material
	front_layer.add_child(grass_art)
	lens = ColorRect.new()
	lens.size = SCREEN
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lens.material = _atmosphere_material(true)
	front_layer.add_child(lens)

# The weather of level 1's cliff (_draw_surface_weather there: 72 slanted rain streaks, 15 dark leaves blown across), with a little
# dust, here on a pale misty picture, so the strokes are dark and faint; in the flock's wind they slant, speed up and thicken.
func _draw_weather() -> void:
	var level_now := weather_level
	if level_now <= 0.01:
		return
	var wind := weather_gust
	for i in 72:
		var depth := float(i % 3) / 2.0
		var speed := 300.0 + float(i % 5) * 34.0 + depth * 110.0
		var drift := 48.0 + float(i % 4) * 12.0 + wind * 240.0
		var x := fposmod(float(i) * 79.37 - clock * drift, SCREEN.x + 160.0) - 80.0
		var y := fposmod(float(i) * 137.11 + clock * speed, SCREEN.y + 120.0) - 80.0
		var length := 12.0 + float(i % 4) * 5.0 + depth * 9.0
		var slant := 0.22 + wind * 0.8
		weather_art.draw_line(Vector2(x, y), Vector2(x - length * slant, y + length), Color(0.15, 0.16, 0.16, (0.07 + depth * 0.09) * level_now), 1.0 + depth * 0.5)
	# dust, blown with the leaves: fine specks, drifting left and a little up and down
	for i in 64:
		var depth := float(i % 4) / 3.0
		var age := fposmod(weather_time * (0.030 + float(i % 5) * 0.006) + float(i) * 0.171, 1.0)
		var x := SCREEN.x + 60.0 - age * (SCREEN.x + 140.0) * (1.0 + float(i % 3) * 0.1)
		var y := fposmod(float(i) * 97.0, 560.0) + 40.0 + sin(age * TAU * 2.0 + float(i)) * (6.0 + depth * 10.0)
		var fade := sin(age * PI)
		weather_art.draw_circle(Vector2(x, y), 0.7 + depth * 1.1, Color(0.30, 0.31, 0.30, (0.10 + depth * 0.16) * fade * level_now))
	for i in 15:
		var age := fposmod(weather_time * (0.10 + float(i % 4) * 0.018) + float(i) * 0.137, 1.0)
		var x := 1350.0 - age * 1510.0 + sin(age * TAU * 2.0 + float(i)) * 45.0
		var y := 85.0 + float(i % 5) * 86.0 + sin(age * TAU + float(i)) * 34.0
		var angle := weather_time * 2.0 + float(i)
		var direction := Vector2(cos(angle), sin(angle))
		weather_art.draw_line(Vector2(x, y) - direction * 5.0, Vector2(x, y) + direction * 5.0, Color(0.018, 0.020, 0.019, 0.58 * level_now), 3.0, true)

# scene 1's fallen trees: an image of a fallen trunk (black on white, the white is cut away) laid over each log obstacle, so that its top
# lines up with the collision (the log's start is where the trunk proper begins, the torn roots hang out to its left)
# The ground grass is drawn in slices of a strip image (eleven slices in the image's width). A slice ends in a straight vertical line, so
# every slice fades out at its two sides (fract(UV.x * 11) is where we are in a slice): where two overlap, the grass goes on without a cut.
const GRASS_SLICE_SHADER := """shader_type canvas_item;
uniform vec4 ink : source_color = vec4(0.012, 0.013, 0.013, 1.0);
uniform float camera_x = 0.0;
varying float patch_alpha;
void vertex(){patch_alpha=COLOR.a;}
void fragment() {
	float opening=1.0-smoothstep(-4900.0,-4200.0,camera_x+SCREEN_UV.x*1280.0);
	float radius=opening*(3.5+2.0*smoothstep(0.3,0.8,SCREEN_UV.y));
	float l=dot(texture(TEXTURE,UV).rgb,vec3(0.299,0.587,0.114));
	if(opening>0.001){
		float sum=0.0;
		float total=0.0;
		for(int y=-2;y<=2;y++){
			for(int x=-2;x<=2;x++){
				float w=exp(-float(x*x+y*y)/3.0);
				sum+=dot(texture(TEXTURE,UV+vec2(float(x),float(y))*TEXTURE_PIXEL_SIZE*radius).rgb,vec3(0.299,0.587,0.114))*w;
				total+=w;
			}
		}
		l=sum/total;
	}
	float f = fract(UV.x * 11.0);
	float side = smoothstep(0.02, 0.30, f) * (1.0 - smoothstep(0.70, 0.98, f));
	float mask=mix(1.0-smoothstep(0.20,0.80,l),1.0-l,opening);
	COLOR = vec4(ink.rgb, mask * side * patch_alpha);
}"""

func _build_scene1_props() -> void:
	var shader := preload("res://assets/shaders/forest_prop_soft_ink.gdshader")
	for f: Dictionary in Scene1Ref.FEATURES:
		var kind := String(f["t"])
		var texture: Texture2D = null
		var scale_factor := 1.0
		var pos := Vector2.ZERO
		var boulder_scale_y := 0.0
		if kind == "log":
			# in the 1280 x 720 image the trunk proper runs from x 270 to 1230, its top is at y 375 and its foot at y 495
			texture = FALLEN_LOG
			scale_factor = float(f["len"]) / 960.0
			pos = Vector2(Scene1Ref.fx(f) - 270.0 * scale_factor, Scene1Ref.GROUND_Y - float(f["h"]) + 1.0 - 375.0 * scale_factor)
		elif kind == "boulder":
			continue  # (a boulder is part of the ground: scene1_ink.gd, add_boulders, in the ink stage)
			# the image's silhouette is the collision (Scene1Ref.boulder_points); the sprite is placed with the same numbers
			texture = BOULDER
			var k := texture.get_width() / 1024.0  # (the image is 1280 wide, the numbers are on a 1024-wide view: a texture pixel is 1/k view pixel)
			var sc := Scene1Ref.boulder_scale(f)
			var cx := Scene1Ref.fx(f)
			scale_factor = sc.x / k
			pos = Vector2(cx - Scene1Ref.BOULDER_CENTRE_X * sc.x, Scene1Ref.ground_top(cx) + Scene1Ref.BOULDER_SINK - Scene1Ref.BOULDER_BOTTOM_Y * sc.y)
			boulder_scale_y = sc.y / k
		elif kind == "spikes":
			# the thicket spans x 75..950, y 95..480 of the 1024-wide view, centre 512
			texture = BRAMBLE
			var k2 := texture.get_width() / 1024.0
			scale_factor = float(f["w"]) * 1.5 / (875.0 * k2)
			var cx2 := Scene1Ref.fx(f) + float(f["w"]) * 0.5
			pos = Vector2(cx2 - 512.0 * k2 * scale_factor, Scene1Ref.ground_top(cx2) + 4.0 - 480.0 * k2 * scale_factor)
		if texture == null:
			continue
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var material_value := ShaderMaterial.new()
		material_value.shader = shader
		sprite.material = material_value
		sprite.scale = Vector2(scale_factor, boulder_scale_y) if boulder_scale_y > 0.0 else Vector2.ONE * scale_factor
		sprite.position = pos
		sprite.z_index = 0
		add_child(sprite)

func _build_water_volume() -> void:
	water_volume = Polygon2D.new()
	water_volume.z_index = 8
	# The shader uses the same sampled contour as the visible soil, never a shore fog mask.
	water_volume.polygon = PackedVector2Array([Vector2(-120,573),Vector2(2700,573),Vector2(2700,900),Vector2(-120,900)])
	var heights := Image.create(706,1,false,Image.FORMAT_RF)
	for i in heights.get_width():
		heights.set_pixel(i,0,Color(_bank_edge_y(-120.0+i*4.0)/1024.0,0,0,1))
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D bank_height : repeat_disable, filter_linear;
uniform sampler2D waves : repeat_disable, filter_linear;
uniform float wave_x0 = 1100.0;
uniform float wave_dx = 4.0;
uniform float wave_n = 264.0;
uniform float water_y = 575.0;
uniform float clock = 0.0;
varying vec2 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 wave_uv = vec2(((world_position.x - wave_x0) / wave_dx + 0.5) / wave_n, 0.5);
	float swell = texture(waves, wave_uv).r;
	float swell_slope = (texture(waves, wave_uv + vec2(1.0 / wave_n, 0.0)).r - texture(waves, wave_uv - vec2(1.0 / wave_n, 0.0)).r) / (2.0 * wave_dx);
	float wave = sin(world_position.x * 0.035 + clock * 1.6) * 0.55 - swell;
	float depth = world_position.y - water_y - wave;
	if (depth < 0.0) { discard; }
	float bed = texture(bank_height,vec2(((world_position.x+120.0)/4.0+0.5)/706.0,0.5)).r * 1024.0;
	float clearance = bed - world_position.y;
	if (clearance <= 0.0) { discard; }
	float edge_aa = smoothstep(0.0, max(fwidth(world_position.y),0.5), clearance);
	float distortion = sin(world_position.y * 0.14 + clock * 2.1) * 0.35;
	distortion += sin(world_position.x * 0.07 - clock * 1.3) * 0.15;
	distortion *= smoothstep(0.0,4.0,clearance);
	// a moving swell bends what is seen through it, most near the top
	vec2 bend = vec2(distortion + swell_slope * 30.0 * exp(-depth / 40.0), swell_slope * 7.0 * exp(-depth / 25.0));
	vec2 refract_uv = SCREEN_UV + bend * SCREEN_PIXEL_SIZE * smoothstep(0.0, 16.0, depth);
	vec3 submerged = texture(scene_color, refract_uv).rgb;
	// Retain sharp submerged silhouettes; no blur or rapid milky depth extinction.
	float transmission = mix(0.90,0.60,smoothstep(0.0,12.0,depth));
	float water_tone = mix(0.47,0.29,smoothstep(0.0,260.0,depth));
	vec3 water = mix(vec3(water_tone), submerged * 0.82, transmission);
	float world_pixel = SCREEN_PIXEL_SIZE.y / max(fwidth(world_position.y),0.001);
	vec2 reflected_uv = vec2(refract_uv.x,SCREEN_UV.y-(depth*2.0+wave)*world_pixel);
	vec3 reflected = texture(scene_color,clamp(reflected_uv,vec2(0.0),vec2(1.0))).rgb;
	water = mix(water,reflected,0.07*exp(-depth/65.0));
	float surface_band = (1.0-smoothstep(0.0,2.4,depth)) * (0.08+0.03*sin(world_position.x*0.019+clock*0.6));
	surface_band *= 1.0 + abs(swell_slope) * 7.0 + abs(swell) * 0.12;
	water = mix(water,vec3(0.63),clamp(surface_band,0.0,0.7));
	// the faces of a swell catch the light just under the surface
	float glint = clamp(abs(swell_slope) * 2.4, 0.0, 0.45) * (1.0 - smoothstep(0.0, 9.0, depth));
	water += vec3(0.22) * glint;
	COLOR = vec4(water,edge_aa);
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("bank_height",ImageTexture.create_from_image(heights))
	_init_waves()
	material_value.set_shader_parameter("waves", wave_texture)
	water_volume.material = material_value
	add_child(water_volume)

func _init_waves() -> void:
	wave_h.resize(WAVE_N)
	wave_v.resize(WAVE_N)
	wave_damp.resize(WAVE_N)
	for i in WAVE_N:
		var x := WAVE_X0 + i * WAVE_DX
		# the banks soak the swell up (it does not bounce back off the mud like off a wall)
		var shore := minf(absf(x - 1156.0), absf(x - 2060.0))
		var outside := 1.0 if (x < 1156.0 or x > 2060.0) else 0.0
		wave_damp[i] = WAVE_DAMP + 5.0 * (1.0 - smoothstep(0.0, 70.0, shore)) + 8.0 * outside
	wave_texture = ImageTexture.create_from_image(Image.create_from_data(WAVE_N, 1, false, Image.FORMAT_RF, wave_h.to_byte_array()))

func reset_water_impacts() -> void:
	_clear_waves()
	water_impacts.clear()
	ground_dust.clear()
	gust_age = -1.0
	gust_leaves.clear()
	gust_ripples.clear()
	dust_gap = 0.0
	water_impact_count = 0

func _clear_waves() -> void:
	for i in wave_h.size():
		wave_h[i] = 0.0
		wave_v[i] = 0.0
	wave_kicks.clear()
	wave_energy = 0.0

# Push the water at x: `impulse` is a speed in px/s (positive lifts it, negative presses it down), `width` the half width in px.
func disturb(x: float, impulse: float, width: float) -> void:
	if wave_v.is_empty():
		return
	var centre := (x - WAVE_X0) / WAVE_DX
	var reach := int(ceil(width * 2.2 / WAVE_DX))
	for i in range(maxi(1, int(centre) - reach), mini(WAVE_N - 1, int(centre) + reach + 1)):
		var d := (float(i) - centre) * WAVE_DX / width
		wave_v[i] += impulse * exp(-d * d)

func disturb_later(x: float, impulse: float, width: float, delay: float) -> void:
	wave_kicks.append({"x": x, "impulse": impulse, "width": width, "delay": delay})

# The surface height at x in px (positive = above the still level), the swell only.
func wave_at(x: float) -> float:
	if wave_h.is_empty():
		return 0.0
	var f := clampf((x - WAVE_X0) / WAVE_DX, 0.0, WAVE_N - 1.001)
	var i := int(f)
	return lerpf(wave_h[i], wave_h[i + 1], f - float(i))

func wave_slope_between(x0: float, x1: float) -> float:
	if absf(x1 - x0) < 1.0:
		return 0.0
	return (wave_at(x1) - wave_at(x0)) / (x1 - x0)

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
		for i in range(1, WAVE_N - 1):
			var accel := c2 * (wave_h[i - 1] + wave_h[i + 1] - 2.0 * wave_h[i]) - wave_damp[i] * wave_v[i]
			wave_v[i] += accel * dt
		for i in range(1, WAVE_N - 1):
			# (the water level also settles by itself: without this a displaced volume would only spread out, never go away)
			wave_h[i] = clampf((wave_h[i] + wave_v[i] * dt) * (1.0 - WAVE_LEAK * dt), -WAVE_MAX, WAVE_MAX)
	for i in WAVE_N:
		energy += absf(wave_h[i])
	wave_energy = energy
	wave_texture.update(Image.create_from_data(WAVE_N, 1, false, Image.FORMAT_RF, wave_h.to_byte_array()))

# The raft on the water, every frame: the bow pushes a swell ahead, the stern leaves a trough that follows, the hull sinking
# (`press`, px/s downwards) or tipping (`tip`, rad/s) shoves the water under it outwards.
func raft_waves(centre_x: float, half_width: float, vx: float, press: float, tip: float, delta: float) -> void:
	var speed := absf(vx)
	if speed > 3.0:
		var dir := signf(vx)
		disturb(centre_x + dir * half_width * 0.95, WAKE_BOW * speed * delta, 13.0)
		disturb(centre_x - dir * half_width * 0.95, -WAKE_BOW * 0.6 * speed * delta, 15.0)
	if absf(press) > 2.0:
		disturb(centre_x, -press * HULL_PRESS * delta, half_width * 0.6)
	if absf(tip) > 0.02:
		disturb(centre_x + half_width * 0.8, tip * HULL_TIP * delta, 14.0)
		disturb(centre_x - half_width * 0.8, -tip * HULL_TIP * delta, 14.0)

# The boy wading: a little slap at his feet with every stride.
func wade_waves(x: float, vx: float, delta: float) -> void:
	disturb(x, -absf(vx) * WADE_PUSH * delta, 8.0)

# Where the surface really is at x (the still level plus the swell): ripples, foam and the raft's waterline sit on it.
func water_line(x: float) -> float:
	return level.WATER_Y - wave_at(x)

func _soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.62, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

# Dust kicked up where the dragged raft's bottom scrapes the ground: puffs that rise and thin out,
# and a few flecks of grit. `moved` is how far the raft travelled this frame (signed).
func emit_drag_dust(contacts: Array, moved: float) -> void:
	dust_gap += absf(moved)
	var direction := signf(moved)
	while dust_gap >= 4.0:
		dust_gap -= 4.0
		for contact in contacts:
			var at: Vector2 = contact
			# The leading end shoves a heap of earth ahead of it; the trailing end drops what it dragged.
			var leading: bool = signf(at.x - level.crate.position.x - level.CRATE_SIZE.x * 0.5) == direction
			var count := 1 if leading else 2
			for k in range(count):
				ground_dust.append({
					"pos": at + Vector2(spray_rng.randf_range(-9.0, 9.0), spray_rng.randf_range(-3.0, 0.0)),
					"vel": Vector2(-direction * spray_rng.randf_range(8.0, 46.0) + (direction * 14.0 if leading else 0.0), -spray_rng.randf_range(14.0, 50.0)),
					"age": 0.0, "life": spray_rng.randf_range(0.7, 1.35), "size": spray_rng.randf_range(13.0, 28.0), "grit": false,
				})
			if spray_rng.randf() < 0.45:
				ground_dust.append({
					"pos": at + Vector2(spray_rng.randf_range(-6.0, 6.0), -2.0),
					"vel": Vector2(-direction * spray_rng.randf_range(20.0, 90.0), -spray_rng.randf_range(55.0, 130.0)),
					"age": 0.0, "life": spray_rng.randf_range(0.35, 0.65), "size": spray_rng.randf_range(0.9, 1.9), "grit": true,
				})
	while ground_dust.size() > 140:
		ground_dust.pop_front()

# The wind of a fan stroke is not drawn as marks. What shows it is what it moves: the grass of the bank leans away from
# the stroke in a wave that runs ahead and eases back, a few dead leaves are picked up and tumble along, the water
# crinkles where the gust passes over it, and a very faint shove of mist travels in front.
const GUST_SPEED := 380.0
const GUST_DRAG := 1.6
const GUST_LIFE := 1.6
var gust_age := -1.0  # < 0: no gust
var gust_origin := Vector2.ZERO
var gust_dir := 1.0
var gust_leaves: Array[Dictionary] = []
var gust_ripples: Array[Dictionary] = []
var gust_ripple_gap := 0.0

func emit_gust(origin: Vector2, direction: float) -> void:
	gust_age = 0.0
	gust_origin = origin
	gust_dir = direction
	gust_ripple_gap = 0.0
	for i in 8:
		var ahead := spray_rng.randf_range(10.0, 190.0)
		gust_leaves.append({
			"pos": Vector2(origin.x + direction * ahead, origin.y + spray_rng.randf_range(10.0, 40.0)),
			"vel": Vector2(direction * spray_rng.randf_range(110.0, 230.0), -spray_rng.randf_range(40.0, 150.0)),
			"delay": ahead / GUST_SPEED * 0.8, "age": 0.0, "life": spray_rng.randf_range(1.0, 1.7),
			"angle": spray_rng.randf() * TAU, "spin": spray_rng.randf_range(-7.0, 7.0), "flip": spray_rng.randf() * TAU,
			"flip_speed": spray_rng.randf_range(4.0, 9.0), "size": spray_rng.randf_range(4.0, 7.5),
		})

func _gust_reach() -> float:
	return GUST_SPEED / GUST_DRAG * (1.0 - exp(-GUST_DRAG * maxf(gust_age, 0.0)))

# How far the grass at this world x leans (px at the tip of a tall blade, signed).
func gust_lean(world_x: float) -> float:
	if gust_age < 0.0:
		return 0.0
	var t := gust_age / GUST_LIFE
	if t >= 1.0:
		return 0.0
	var ahead := (world_x - gust_origin.x) * gust_dir
	if ahead < -20.0:
		return 0.0
	var reach := _gust_reach()
	var shape := exp(-pow((ahead - reach) / 80.0, 2.0)) if ahead > reach else exp(-(reach - ahead) / 170.0)
	var amplitude := 26.0 * (1.0 - t) * smoothstep(-20.0, 30.0, ahead)
	# after the front has gone by, the blades spring back and forth once or twice
	var passed := maxf(reach - ahead, 0.0)
	var wobble := sin(passed * 0.045 - gust_age * 13.0) * 0.28 * smoothstep(0.0, 40.0, passed)
	return gust_dir * amplitude * shape * (1.0 + wobble)

func _update_gust(delta: float) -> void:
	if gust_age >= 0.0:
		gust_age += delta
		if gust_age >= GUST_LIFE:
			gust_age = -1.0
		else:
			# the water crinkles under the front while it is over the river
			var front_x := gust_origin.x + gust_dir * _gust_reach()
			gust_ripple_gap -= delta
			if gust_ripple_gap <= 0.0 and front_x > 1156.0 and front_x < 2060.0 and gust_age < 1.0:
				gust_ripple_gap = 0.07
				gust_ripples.append({"x": front_x + spray_rng.randf_range(-20.0, 20.0), "age": 0.0, "size": spray_rng.randf_range(0.8, 1.3)})
	for k in range(gust_ripples.size() - 1, -1, -1):
		gust_ripples[k].age = float(gust_ripples[k].age) + delta
		if float(gust_ripples[k].age) > 1.2:
			gust_ripples.remove_at(k)
	for k in range(gust_leaves.size() - 1, -1, -1):
		var leaf: Dictionary = gust_leaves[k]
		if float(leaf.delay) > 0.0:
			leaf.delay = float(leaf.delay) - delta
			continue
		leaf.age = float(leaf.age) + delta
		var v: Vector2 = leaf.vel
		v.x *= exp(-1.3 * delta)
		# a leaf in a gust rides it up, then flutters down
		v.y += (260.0 * delta) * (1.0 if float(leaf.age) > 0.35 else 0.12)
		v.y += sin(float(leaf.age) * 9.0 + float(leaf.flip)) * 120.0 * delta
		leaf.vel = v
		leaf.pos = Vector2(leaf.pos) + v * delta
		leaf.angle = float(leaf.angle) + float(leaf.spin) * delta
		leaf.flip = float(leaf.flip) + float(leaf.flip_speed) * delta
		if float(leaf.age) >= float(leaf.life) or Vector2(leaf.pos).y > level.ground_y(Vector2(leaf.pos).x) - 1.0 and float(leaf.age) > 0.5:
			gust_leaves.remove_at(k)

func _draw_gust() -> void:
	# a very faint shove of mist in front of the stroke
	if gust_age >= 0.0:
		var reach := _gust_reach()
		var t := gust_age / GUST_LIFE
		var centre := Vector2(gust_origin.x + gust_dir * (reach + 20.0), gust_origin.y - 10.0)
		var size := Vector2(70.0 + reach * 0.25, 70.0 + reach * 0.2)
		dust_layer.draw_texture_rect(dust_texture, Rect2(centre - size * 0.5, size), false, Color(0.5, 0.51, 0.49, smoothstep(0.0, 0.1, t) * (1.0 - t) * 0.09))
	for leaf in gust_leaves:
		if float(leaf.delay) > 0.0:
			continue
		var t: float = float(leaf.age) / float(leaf.life)
		var length: float = float(leaf.size)
		var flat := 0.2 + 0.8 * absf(cos(float(leaf.flip)))
		var width := length * 0.42 * flat
		var c := cos(float(leaf.angle))
		var s := sin(float(leaf.angle))
		var shape := [Vector2(-length, 0.0), Vector2(-length * 0.35, -width), Vector2(length * 0.55, -width * 0.8), Vector2(length, 0.0), Vector2(length * 0.4, width * 0.9), Vector2(-length * 0.5, width * 0.7)]
		var points := PackedVector2Array()
		for point in shape:
			var p: Vector2 = point
			points.append(Vector2(leaf.pos) + Vector2(p.x * c - p.y * s, p.x * s + p.y * c))
		dust_layer.draw_colored_polygon(points, Color(0.06, 0.065, 0.06, minf(1.0, (1.0 - t) * 3.0) * 0.85))

func _update_ground_dust(delta: float) -> void:
	_update_gust(delta)
	for k in range(ground_dust.size() - 1, -1, -1):
		var d: Dictionary = ground_dust[k]
		d.age = float(d.age) + delta
		var v: Vector2 = d.vel
		if bool(d.grit):
			v.y += 420.0 * delta
		else:
			v = v.move_toward(Vector2(v.x * 0.3, -9.0), 120.0 * delta)
		d.vel = v
		d.pos = Vector2(d.pos) + v * delta
		if float(d.age) >= float(d.life):
			ground_dust.remove_at(k)

func _draw_ground_dust() -> void:
	_draw_gust()
	for d in ground_dust:
		var t: float = float(d.age) / float(d.life)
		if bool(d.grit):
			dust_layer.draw_circle(d.pos, float(d.size), Color(0.03, 0.03, 0.03, (1.0 - t) * 0.9), true, -1.0, true)
		else:
			var size: float = float(d.size) * (1.0 + t * 1.6)
			var alpha := minf(1.0, t * 8.0) * (1.0 - t) * 0.5
			dust_layer.draw_texture_rect(dust_texture, Rect2(Vector2(d.pos) - Vector2(size * 1.3, size) * 0.5, Vector2(size * 1.3, size)), false, Color(0.47, 0.47, 0.45, alpha))

func emit_water_impact(x: float, speed: float, spread: float, rings: bool = true) -> void:
	var strength := clampf(0.42 + speed / 380.0, 0.42, 1.0)
	water_impacts.append({"x": x, "age": 0.0, "strength": strength, "spread": clampf(spread, 8.0, 52.0), "rings": rings})
	# the water is pressed down where it was hit, springs back as a short column a moment later, and the swell runs out both ways
	var width := clampf(spread * 0.55 + 5.0, 8.0, 30.0)
	var push := 30.0 + 66.0 * strength
	disturb(x, -push, width)
	disturb_later(x, push * 0.62, width * 0.7, 0.17)
	disturb_later(x, -push * 0.28, width * 0.9, 0.42)
	water_impact_count += 1
	if water_impacts.size() > 8:
		water_impacts.pop_front()

func emit_struggle_splash(x: float, side: float) -> void:
	var drops: Array[Dictionary] = []
	# Sample once per stroke, so each drop follows a stable ballistic path.
	for i in spray_rng.randi_range(15, 23):
		var direction := side if spray_rng.randf() < 0.78 else -side
		drops.append({
			"offset": Vector2(direction * spray_rng.randf_range(9.0, 23.0), -1.0),
			"velocity": Vector2(direction * spray_rng.randf_range(22.0, 105.0), -spray_rng.randf_range(80.0, 215.0)),
			"delay": spray_rng.randf_range(0.0, 0.055),
			"radius": spray_rng.randf_range(0.55, 1.6),
			"shade": spray_rng.randf_range(0.48, 0.79),
		})
	water_impacts.append({"age": 0.0, "x": x, "drops": drops})
	# every stroke of the drowning boy slaps the water and sets it rocking
	disturb(x + side * 14.0, -46.0, 11.0)
	disturb_later(x + side * 14.0, 30.0, 9.0, 0.12)
	if water_impacts.size() > 8:
		water_impacts.pop_front()

const BLUR_SHADER := """shader_type canvas_item;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float sigma = 4.0;
uniform float window = 0.0;  // fades the layer out round where the hero stands (screen x about 500)
void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * direction;
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int i = -8; i <= 8; i++) {
		float d = float(i) * sigma * 0.4;
		float w = exp(-0.5 * (d * d) / (sigma * sigma));
		sum += texture(TEXTURE, UV + step_uv * d) * w;
		total += w;
	}
	COLOR = sum / total;
	COLOR.a *= 1.0 - window * (1.0 - smoothstep(170.0, 540.0, abs(SCREEN_UV.x * 1280.0 - 500.0)));
}"""

func _blur_material(direction: Vector2, sigma: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = BLUR_SHADER
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("direction", direction)
	material_value.set_shader_parameter("sigma", sigma)
	return material_value

func _transparent_view() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	return viewport

# Two separable gaussian passes. The old single 9-tap blur laid nine shifted copies of each edge
# over each other, which read as stepped bands and ghost lines instead of a soft, clean edge.
func _blur_layer(parent: Node, radius: float) -> SubViewport:
	var viewport := _transparent_view()
	var horizontal := _transparent_view()
	var first := Sprite2D.new()
	first.centered = false
	first.texture = viewport.get_texture()
	first.material = _blur_material(Vector2(1.0, 0.0), radius * 0.5)
	horizontal.add_child(first)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = horizontal.get_texture()
	sprite.material = _blur_material(Vector2(0.0, 1.0), radius * 0.5)
	parent.add_child(sprite)
	viewport.set_meta(&"output_sprite", sprite)
	return viewport

func _atmosphere_material(is_lens: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float clock = 0.0;
uniform float scroll = 0.0;
uniform bool lens = false;
uniform float atmosphere_strength = 1.0;
uniform float vignette = 0.34;
uniform float grain = 0.018;
uniform float cinema = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	if (lens) {
		float edge = smoothstep(0.30, 0.79, length((UV-0.5)*vec2(0.93,1.0)));
		float speckle = hash(floor(UV*vec2(1280,720))+floor(clock*12.0));
		// A 2.2:1 forest shot within the unchanged gameplay viewport.
		// The lower matte ends below the grounded actor and readable obstacles.
		float matte = 1.0 - smoothstep(0.092, 0.096, min(UV.y, 1.0-UV.y));
		// Global elliptical enclosure is applied once by film_look.gdshader.
		float surround = clamp(edge*vignette + speckle*grain,0.0,0.97);
		COLOR = vec4(vec3(0.0), mix(surround,1.0,matte*cinema));
	} else {
		float a = noise(UV*vec2(3.2,8.0)+vec2(clock*0.018+scroll*0.0001,0));
		float b = noise(UV*vec2(5.0,12.0)-vec2(clock*0.030,clock*0.008));
		float band = exp(-pow((UV.y-0.65)*4.4,2.0));
		COLOR = vec4(vec3(0.72), (a*0.65+b*0.35)*band*0.15*atmosphere_strength);
	}
}"""
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("lens", is_lens)
	return result

# 0 deep in the forest, 1 when he steps out of the trees onto the open ground: the dark forest backdrop gives way to the wide valley
# as the trunks thin out (the trees along the route end where this reaches 1).
func _emergence() -> float:
	return smoothstep(-5000.0, -4100.0, camera_x)

# Redraws are asked for from the physics step, and Godot draws at the end of every step: when a frame needs two or three steps
# (it runs late, and a late frame is the one that needs the most), the same expensive drawing was done two or three times in that frame,
# which made it later still. A node is asked to redraw once per rendered frame, whatever the number of steps in it.
var _redraw_frame := -1
func _redraw_due() -> bool:
	var frame := Engine.get_process_frames()
	if frame == _redraw_frame:
		return false
	_redraw_frame = frame
	return true

func sync(delta: float, new_camera: float, active: bool) -> void:
	var redraw := _redraw_due()
	visible = active
	clock += delta
	camera_x = new_camera
	# Act one's planes never switch off: the backdrop must flow into act two without a seam.
	var first_act_world_animated := camera_x < 2180.0 and camera_x > -200.0
	var emergence := _emergence()
	surface_layer.visible = camera_x < -2400.0
	# the forest backdrop is cut away from the right, so the valley opens up ahead of him before the trees are gone
	# A fixed world-space forest edge. Walking past it reveals the valley
	# already behind the trees; no screen-wide backdrop crossfade.
	var reveal: float = (Scene1Ref.CLIFF_X-1050.0-camera_x)/1280.0 if camera_x < -2400.0 else 2.0
	(background.material as ShaderMaterial).set_shader_parameter("reveal_edge", reveal)
	var gorge_mix:float=level.rope_ladder.entry_mix() if level.rope_ladder != null else 0.0
	var in_forest:bool = camera_x < -2400.0 and not (level.descent != null and level.descent.enabled)
	# Image planes are part of this forest bank. None may grow over the void
	# beyond the actual cliff, even if the plate contains an offscreen trunk.
	for plane in [plates_far,plates_mid,plates_close,plates_near]:
		plane.set_ground_limit(Scene1Ref.edge_x()-camera_x)
	if hunter_art != null:
		hunter_art.sync(delta, camera_x, float(level.camera_y), level.scene1.hunter if level.scene1 != null else null, active and camera_x < -2400.0)
	weather_level = Scene1Ref.weather(camera_x)
	weather_gust = level.scene1.gust() if level.scene1 != null else 0.0
	weather_time += delta * (1.0 + 2.5 * weather_gust)
	weather_art.visible = weather_level > 0.01 and active
	if weather_art.visible and redraw:
		weather_art.queue_redraw()
	var flock_time: float = level.scene1.flock_clock() if level.scene1 != null else -1.0
	if flock_time >= 0.0 and active:
		var player_centre: Vector2 = level.player.position + Vector2(13.0, 27.0)
		# up out of the chasm, not from under the ground: the flock starts over the far side of the edge
		var grave:Vector2=Scene1Ref.grave_position()-Vector2(camera_x,float(level.camera_y))
		bat_flock.start_spread=Vector2(68,24)
		bat_flock.start_shift=grave-Vector2(528+34,748+18)
		bat_flock.approach_arc = 210.0
		bat_flock.sync(delta, flock_time, player_centre - Vector2(camera_x, 0.0), float(level.camera_y), true)
	else:
		bat_flock.sync(delta, 0.0, Vector2.ZERO, 0.0, false)
	background.visible = not in_forest
	(atmosphere.material as ShaderMaterial).set_shader_parameter("atmosphere_strength", 0.0 if in_forest else 1.0)
	forest_back.visible = in_forest
	route_back.visible = in_forest
	var route_material := route_back.material as ShaderMaterial
	route_material.set_shader_parameter("scroll", camera_x)
	route_material.set_shader_parameter("clock", clock)
	route_material.set_shader_parameter("ground_y", Scene1Ref.GROUND_Y-float(level.camera_y))
	route_material.set_shader_parameter("reveal_edge", reveal)
	opening_back.visible = in_forest and camera_x < -7500.0
	var opening_material := opening_back.material as ShaderMaterial
	opening_material.set_shader_parameter("scroll",camera_x)
	opening_material.set_shader_parameter("clock",clock)
	opening_material.set_shader_parameter("ground_y",Scene1Ref.GROUND_Y-float(level.camera_y))
	(grass_art.material as ShaderMaterial).set_shader_parameter("camera_x",camera_x if in_forest else 0.0)
	plates_far.visible=in_forest
	plates_mid.visible=in_forest
	plates_close.visible=in_forest
	opening_trees.visible=in_forest
	opening_middle.visible=in_forest
	if in_forest:
		var ground_screen:float=Scene1Ref.GROUND_Y-float(level.camera_y)
		opening_middle.set_fade(0.0)
		opening_middle.sync(camera_x,ground_screen,(Scene1Ref.START_X+2400.0)*0.34)
		opening_trees.set_fade(0.0)
		opening_trees.sync(camera_x,ground_screen,(Scene1Ref.START_X+2200.0)*0.82)
		plates_far.set_fade(1.0-smoothstep(-8800.0,-8100.0,camera_x))
		plates_mid.set_fade(1.0-smoothstep(-8800.0,-8100.0,camera_x))
		plates_close.set_fade(0.0)
		plates_far.sync(camera_x,ground_screen-30.0,(Scene1Ref.START_X-525.0)*.16+1700.0)
		plates_mid.sync(camera_x,ground_screen,(Scene1Ref.START_X-525.0)*.32+1500.0)
		plates_close.sync(camera_x,ground_screen,(Scene1Ref.START_X-525.0)*.50+700.0)
		plates_near.set_fade(1.0 - smoothstep(-4800.0, -4200.0, camera_x))
		var route := clampf((camera_x + 525.0 - Scene1Ref.START_X) / (Scene1Ref.CLIFF_X - Scene1Ref.START_X), 0.0, 1.0)
		var centre := camera_x + 640.0
		var shaft_strength := 1.0 - smoothstep(500.0, 1900.0, absf(centre - Scene1Ref.LIGHT_X))
		var shaft_screen := 640.0 + (Scene1Ref.LIGHT_X - centre) * 0.30
		var trees := 1.0 - 0.85 * smoothstep(0.68, 0.95, route)
		forest_back.sync(camera_x, clock, Scene1Ref.GROUND_Y - float(level.camera_y), MistyForest.keyed(FOG_LEVEL_KEYS, route), shaft_strength, shaft_screen, trees, reveal)
	# the vignette closes in and the grain thickens in the forest, and both let go as he comes out of the trees
	predator_art.sync(delta,camera_x,float(level.camera_y),active and in_forest)
	spider_art.sync(delta,camera_x,float(level.camera_y),active and in_forest)
	crevice_art.sync(delta,camera_x,float(level.camera_y),active and in_forest)
	var forest_context:bool=camera_x < -2400.0 and float(level.camera_y)<-4250.0 and not (level.descent != null and level.descent.enabled)
	var closed:float=(1.0-emergence*0.45)*(1.0-emergence) if forest_context else 0.0
	var chase_pressure: float = level.scene1.hunter.pressure if (level.scene1 != null and level.scene1.hunter != null and camera_x < -2400.0) else 0.0
	(lens.material as ShaderMaterial).set_shader_parameter("vignette", lerpf(0.34, 0.74, closed) + 0.16 * chase_pressure)
	(lens.material as ShaderMaterial).set_shader_parameter("grain", lerpf(0.018, 0.045, closed))
	(lens.material as ShaderMaterial).set_shader_parameter("cinema", closed)
	if surface_layer.visible:
		# Register the live fire directly to the terrace in the unified plate,
		# using exactly the background shader's camera mapping.
		var relative:Vector2=Vector2(camera_x,float(level.camera_y))-level.log_bridge.ORIGIN
		var fire_ground:Vector2=DESTINATION_FIRE_UV*SCREEN-Vector2(relative.x*0.015,relative.y*0.10+30.0)
		surface_art.set_far_placement(fire_ground-Vector2(1017,378)*0.78,0.78,1.0)
		surface_art.sync(delta, 0.0, 0.0, true, 0.0)
		surface_art.gameplay_sprite.show()
		surface_art.tree_sprite.show()
		surface_art.tree_sprite.position=Vector2(1132,378)-DESTINATION_TREE_ROOT*DESTINATION_TREE_SCALE
		# Keep the live particles; discard the sharp baked campfire/stone decal.
		surface_art.fire_sprite.hide()
		surface_art.fire_flame.position.y+=17.0
		surface_art.fire_flame.glow_scale=0.65
		surface_art.fire_flame.monochrome=true
		surface_art.fire_mist.hide()
		# The common viewport now contains the opaque mountain behind the
		# particles, so the original additive flame renders correctly.
		(surface_art.fire_flame.material as CanvasItemMaterial).blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	landmark_layer.visible=surface_layer.visible and active
	landmark_output.visible=surface_layer.visible
	landmark_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if landmark_layer.visible and landmark_output.visible else SubViewport.UPDATE_DISABLED
	if landmark_layer.visible:
		landmark_output.material.set_shader_parameter("exposure",1.0)
	water_volume.visible = camera_x < 2750.0
	background.position.x = -90.0 - maxf(camera_x, 0.0) * 0.10
	cone.position = Vector2(370.0 - camera_x * 0.22, -155)
	cone_act_two.position = Vector2(370.0 + (3900.0 - camera_x) * 0.22, -155)
	cone_act_two.modulate.a = smoothstep(2000.0, 3000.0, camera_x) * (1.0 - smoothstep(6600.0, 7300.0, camera_x))
	cone_act_two.visible = cone_act_two.modulate.a > 0.01
	cone_forest.position = Vector2(300.0 + (8500.0 - camera_x) * 0.22, -155)
	cone_forest.modulate.a = smoothstep(6900.0, 7500.0, camera_x)
	cone_forest.visible = cone_forest.modulate.a > 0.01
	(cone.material as ShaderMaterial).set_shader_parameter("clock", clock)
	(cone_act_two.material as ShaderMaterial).set_shader_parameter("clock", clock)
	for plane in [atmosphere, lens]:
		(plane.material as ShaderMaterial).set_shader_parameter("clock", clock)
		(plane.material as ShaderMaterial).set_shader_parameter("scroll", camera_x)
	fan_pickup.visible = level.fan_revealed and not level.fan_owned
	fan_pickup.position = level.fan_rest_position()
	fan_pickup.scale = Vector2(level.fan_ground_facing,1.0)*level.FAN_SCALE
	fan_pickup.rotation = level.fan_ground_facing*1.35 + (level.crate_tilt if level.fan_on_raft else 0.0)
	if not level.fan_on_tree:
		# Lying on the ground the blade is seen from the side, almost edge-on: a thin leaf resting on the surface, not
		# the whole face-on blade stuck on the ground (which covered the soil like a sticker).
		fan_pickup.rotation = level.fan_ground_facing*1.50 + (level.crate_tilt if level.fan_on_raft else 0.0)
		fan_pickup.scale = Vector2(level.fan_ground_facing*0.17,1.0)*level.FAN_SCALE
	if level.fan_on_tree:
		fan_pickup.scale = Vector2.ONE*level.FAN_SCALE
		fan_pickup.rotation = -0.75
	crate_art.position = level.crate.position + level.CRATE_SIZE * 0.5
	crate_art.rotation = level.crate_tilt
	raft_front.transform = crate_art.transform
	(water_volume.material as ShaderMaterial).set_shader_parameter("clock", clock)
	_update_waves(delta)
	for i in range(water_impacts.size() - 1, -1, -1):
		water_impacts[i].age += delta
		if water_impacts[i].age > 2.4:
			water_impacts.remove_at(i)
	_update_ground_dust(delta)
	if redraw:
		dust_layer.queue_redraw()
		mid.queue_redraw()
		foreground.queue_redraw()
	near_blur_sprite.visible = in_forest
	# The existing world-space ground cover survives backdrop changes. It
	# leaves the view by scrolling above the camera, never by a scene flag.
	var show_ground:bool = camera_x < -2400.0 and float(level.camera_y)<-4250.0 and not (level.descent != null and level.descent.enabled)
	grass_art.visible = show_ground
	grass_band.visible = show_ground
	var below_cliff := 0.0
	if gorge_mix>0.0:
		below_cliff = emergence
	elif level.descent != null and level.descent.enabled:
		below_cliff = (1.0-smoothstep(-1500.0,-250.0,camera_x))*smoothstep(0.0,2.5,float(level.descent.entry_time))
	fore_blur_sprite.modulate.a = 1.0-below_cliff
	weather_art.modulate.a = 1.0-below_cliff
	near_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if in_forest else SubViewport.UPDATE_DISABLED
	if in_forest:
		plates_near.sync(camera_x, Scene1Ref.GROUND_Y - float(level.camera_y), (Scene1Ref.START_X + 3300.0) * 1.45)
	# Ground cover is static world geometry, prepared across the whole forest.
	# Move retained drawing commands with the camera instead of regenerating
	# only the current screen (and repeatedly sampling/randomising each tuft).
	var grass_origin := -Vector2(camera_x, float(level.camera_y))
	grass_art.position = grass_origin
	grass_band.position = grass_origin
	var grass_edge := Scene1Ref.edge_x()
	if show_ground and grass_edge != _grass_cached_edge:
		_grass_cached_edge = grass_edge
		_prepare_grass_edges()
		grass_art.queue_redraw()
		grass_band.queue_redraw()
	if first_act_world_animated and redraw:
		for plane in [terrain, props, crate_art, raft_front, bank_grass, surface]:
			plane.queue_redraw()

func _draw_mid() -> void:
	if camera_x < -2400.0:
		return  # scene 1 has its own terrain-bounded forest plates
	# These sparse trees move independently of the distant bitmap and playable bank.
	var specs: Array = [Vector3(110, 95, 0.27), Vector3(1180, 74, 0.24), Vector3(1710, 56, 0.25), Vector3(1960, 108, 0.29), Vector3(2230, 120, 0.32), Vector3(2640, 70, 0.26)]
	# Preserve the sparse lift approach: do not overlay an extra stand of trees
	# when the camera reaches the lift. The panorama and existing trees continue.
	if camera_x < -200.0 and camera_x >= -2400.0:
		# (scene 1, west of here, has its own trunks in the misty forest shader) scenes 2 to 6: a stand of trunks that slide slower than the camera, without end (each one is fixed by its index)
		var first := int(floor(camera_x * 0.29 / 92.0)) - 1
		for i in range(first, first + 18):
			var west_rng := RandomNumberGenerator.new()
			west_rng.seed = i * 7919 + 13
			var mid_x := float(i) * 92.0 + west_rng.randf_range(-30.0, 30.0)
			if mid_x < -230.0:  # none beyond this: the last one comes in from the right edge as the backdrop opens, then there are no more
				specs.append(Vector3(mid_x, west_rng.randf_range(40.0, 120.0), west_rng.randf_range(0.20, 0.34)))
	for spec in specs:
		var x: float = spec.x - camera_x * 0.29
		if x < -260.0 or x > 1540.0:
			continue
		var w: float = spec.y
		var c := Color(spec.z, spec.z, spec.z, 0.22 * (1.0 - (_emergence() if camera_x < -200.0 else 0.0)))
		mid.draw_colored_polygon(PackedVector2Array([
			Vector2(x-w*0.4,-30),Vector2(x+w*0.5,-30),Vector2(x+w*0.3,330),
			Vector2(x+w*0.55,470),Vector2(x+w,555),Vector2(x-w,555),
			Vector2(x-w*0.5,470),Vector2(x-w*0.24,300)
		]), c)
		mid.draw_colored_polygon(PackedVector2Array([Vector2(x-5,229),Vector2(x+80,172),Vector2(x+180,140),Vector2(x+87,163),Vector2(x+3,207)]),c)

func _draw_terrain() -> void:
	_draw_bank_mass(-120.0,1350.0)
	_draw_bank_mass(1880.0,2800.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4721
	for i in range(255):
		var x := rng.randf_range(220.0, 2540.0)
		if x > 1250.0 and x < 1980.0:
			continue
		var y := _bank_edge_y(x)
		var height := rng.randf_range(3.0, 14.0)
		var lean := rng.randf_range(-7.0, 9.0) + sin(clock * 0.8 + i) * 1.0
		terrain.draw_colored_polygon(PackedVector2Array([
			Vector2(x-0.7,y+3),Vector2(x+lean,y-height),Vector2(x+0.8,y+3)
		]), INK)
		if i % 5 == 0:
			terrain.draw_circle(Vector2(x,y+2),rng.randf_range(2.0,5.0),INK,true,-1,true)

func _bank_edge_y(x: float) -> float:
	var ground: float = level.ground_y(x)
	var underwater := smoothstep(level.WATER_Y + 8.0, level.WATER_Y + 100.0, ground)
	var rounded: float = (level.ground_y(x-18.0) + ground*2.0 + level.ground_y(x+18.0)) * 0.25
	var earth := bank_noise.get_noise_1d(x) * 9.0 + bank_noise.get_noise_1d(x*3.7) * 2.0
	# Keep exposed contact contours close to the unchanged physics surface.
	return lerpf(ground, rounded, underwater) - 2.0 + earth * lerpf(0.65,2.0,underwater)

func _draw_bank_mass(start: float, end: float) -> void:
	var edge := PackedVector2Array()
	for x in range(int(start),int(end),4):
		edge.append(Vector2(x,_bank_edge_y(x)))
	edge.append(Vector2(end,_bank_edge_y(end)))
	var mass := edge.duplicate()
	mass.append(Vector2(end,1000))
	mass.append(Vector2(start,1000))
	terrain.draw_colored_polygon(mass,INK)
	terrain.draw_polyline(edge,INK,1.8,true)

func _beam(canvas: Node2D, a: Vector2, b: Vector2, width: float, seed_value: float) -> void:
	var normal := (b-a).normalized().orthogonal() * width * 0.5
	var points := PackedVector2Array()
	for i in range(7):
		var t := float(i)/6.0
		points.append(a.lerp(b,t)+normal*(0.88+sin(i*2.7+seed_value)*0.15))
	for i in range(6,-1,-1):
		var t := float(i)/6.0
		points.append(a.lerp(b,t)-normal*(0.9+sin(i*1.8+seed_value)*0.17))
	canvas.draw_colored_polygon(points,INK)

func _draw_props() -> void:
	_beam(props,Vector2(379,550),Vector2(367,418),10,2)
	# The walkable edge shares the collider's height; weathering stays underneath.
	var rack: Rect2 = level.RACK_RECT
	var plank := PackedVector2Array([rack.position, Vector2(rack.end.x, rack.position.y)])
	for i in range(6,-1,-1):
		plank.append(Vector2(lerpf(rack.position.x,rack.end.x,float(i)/6.0), rack.end.y+sin(i*1.8+1.0)*0.85))
	props.draw_colored_polygon(plank,INK)
	_beam(props,Vector2(563,419),Vector2(558,550),8,8)
	_beam(props,Vector2(373,466),Vector2(420,421),6,3)
	if level.completed:
		props.draw_circle(Vector2(2460,517),3.0,Color(0.76,0.76,0.76),true,-1,true)

func _draw_crate() -> void:
	_draw_boat_back()

func _draw_raft_front() -> void:
	_draw_boat_front()

func _draw_boat_back() -> void:
	crate_art.draw_set_transform(-level.CRATE_SIZE * 0.5)
	# far side of the hull, rising to the stem and the stern post
	crate_art.draw_colored_polygon(PackedVector2Array([
		Vector2(-3,-24), Vector2(3,-12), Vector2(6,1), Vector2(30,3), Vector2(72,5), Vector2(114,3), Vector2(138,1),
		Vector2(141,-12), Vector2(147,-24), Vector2(149,-8), Vector2(147,12), Vector2(131,27), Vector2(100,33),
		Vector2(72,34), Vector2(44,33), Vector2(13,27), Vector2(-3,12), Vector2(-5,-8)
	]), INK)
	_beam(crate_art,Vector2(3,8),Vector2(-2,-25),6,11)
	_beam(crate_art,Vector2(141,8),Vector2(146,-25),6,12)
	# a rib and a thwart inside, and the rings the ropes are tied to
	_beam(crate_art,Vector2(44,3),Vector2(42,-9),5,3)
	_beam(crate_art,Vector2(100,3),Vector2(102,-9),5,4)
	_beam(crate_art,Vector2(20,-5),Vector2(124,-6),4,5)
	crate_art.draw_circle(Vector2(-2,-13),3.4,INK,true,-1.0,true)
	crate_art.draw_circle(Vector2(146,-13),3.4,INK,true,-1.0,true)

func _draw_boat_front() -> void:
	raft_front.draw_set_transform(-level.CRATE_SIZE * 0.5)
	# the near side of the hull: low, so it hides his soles but not his legs
	raft_front.draw_colored_polygon(PackedVector2Array([
		Vector2(-5,-6), Vector2(8,-3), Vector2(36,-1), Vector2(72,0), Vector2(108,-1), Vector2(136,-3), Vector2(149,-6),
		Vector2(150,10), Vector2(133,27), Vector2(101,34), Vector2(72,35), Vector2(43,34), Vector2(11,27), Vector2(-6,10)
	]), INK)

func _draw_bank_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8117
	# Dense ankle-height tufts follow world-space ground, including both shore slopes.
	for span in [Vector2(12,250), Vector2(1050,1260), Vector2(1968,2145)]:
		var opening: bool = span.x < 250.0
		var roots := PackedVector2Array()
		for sample in range(int(span.x), int(span.y) + 1, 4):
			var taper := smoothstep(0.0,25.0,minf(sample-span.x,span.y-sample))
			var root_height := (16.0 if opening else 7.0) * taper
			roots.append(Vector2(sample, _bank_edge_y(sample) - root_height - bank_noise.get_noise_1d(sample*1.8)*5.0*taper))
		for sample in range(int(span.y), int(span.x) - 1, -4):
			roots.append(Vector2(sample, level.ground_y(sample) + 10.0))
		bank_grass.draw_colored_polygon(roots, INK)
		var x: float = span.x
		while x < span.y:
			var y := _bank_edge_y(x)
			var cluster := 0.5 + bank_noise.get_noise_1d(x*2.3)*0.5
			var height := rng.randf_range(28,40) if opening else lerpf(12.0,27.0,cluster) + rng.randf_range(-3,3)
			height *= lerpf(0.15,1.0,smoothstep(0.0,25.0,minf(x-span.x,span.y-x)))
			var lean := rng.randf_range(-10,13) + sin(clock * 0.65 + x * 0.11) * 1.2 + gust_lean(x) * clampf(height / 30.0, 0.3, 1.2)
			for offset in [-2.0, 2.0]:
				bank_grass.draw_colored_polygon(PackedVector2Array([
					Vector2(x+offset-2,y+5),Vector2(x+lean+offset*2,y-height+absf(offset)),Vector2(x+offset+2,y+5)
				]), INK)
			x += rng.randf_range(3,6)

func _draw_surface() -> void:
	for i in range(34):
		var x := 1180.0 + fposmod(i*73.79+clock*(1.6+float(i%3)),850.0)
		var y := 578.0+float(i%7)*11.0+sin(clock*0.6+i)*1.8
		var alpha := 0.025 + sin(clock*0.5+i)*0.012
		surface.draw_line(Vector2(x,y),Vector2(x+18.0+float(i%5)*8.0,y),Color(0.83,0.83,0.83,alpha),1.0,true)
	if level.floating:
		var span: Vector2 = level.crate_waterline_span()
		var center := Vector2((span.x + span.y) * 0.5, level.WATER_Y)
		for x in [span.x, span.y]:
			surface.draw_line(Vector2(x-9.0,water_line(x-9.0)),Vector2(x+11.0,water_line(x+11.0)),Color(0.74,0.74,0.74,0.20),1.2,true)
		for i in range(3):
			var phase := fposmod(clock*0.65+i/3.0,1.0)
			surface.draw_set_transform(Vector2(center.x,579.0),0.0,Vector2(1.0,0.13))
			surface.draw_arc(Vector2.ZERO,level.CRATE_SIZE.x*0.5+phase*52.0,0,TAU,40,Color(0.74,0.74,0.74,(1.0-phase)*0.14),1.7,true)
			surface.draw_set_transform(Vector2.ZERO)
	_draw_swell_lines()
	for impact in water_impacts:
		_draw_water_impact(impact)
	for ripple in gust_ripples:
		# a short crinkle of the surface: two flat arcs opening and fading
		var age: float = float(ripple.age)
		var spread: float = (6.0 + age * 46.0) * float(ripple.size)
		var alpha := (1.0 - age / 1.2) * 0.34
		surface.draw_set_transform(Vector2(float(ripple.x), level.WATER_Y + 2.0), 0.0, Vector2(1.0, 0.12))
		surface.draw_arc(Vector2.ZERO, spread, 0.0, TAU, 40, Color(0.74, 0.74, 0.74, alpha), 1.5, true)
		surface.draw_arc(Vector2.ZERO, spread * 0.55, 0.0, TAU, 28, Color(0.74, 0.74, 0.74, alpha * 0.7), 1.2, true)
		surface.draw_set_transform(Vector2.ZERO)

# The swell on the surface: a bright crest line that rides the water (brighter where it moves most) and two fainter lines under it
# that follow it more gently, so the whole surface reads as rocking, not only the spray.
func _draw_swell_lines() -> void:
	if wave_energy < 0.6:
		return
	var from_x := maxf(WAVE_X0 + 8.0, camera_x - 20.0)
	var to_x := minf(WAVE_X0 + (WAVE_N - 2) * WAVE_DX, camera_x + 1300.0)
	if to_x <= from_x:
		return
	var x := from_x
	var base_y: float = level.WATER_Y
	while x < to_x:
		var nx := x + WAVE_DX * 2.0
		var h0 := wave_at(x)
		var h1 := wave_at(nx)
		var activity := clampf(maxf(absf(h0), absf(h1)) * 0.11 + absf(h1 - h0) * 0.16, 0.0, 1.0)
		if activity > 0.03:
			surface.draw_line(Vector2(x, base_y - h0 + 1.5), Vector2(nx, base_y - h1 + 1.5), Color(0.06, 0.06, 0.06, activity * 0.55), 2.6, true)
			surface.draw_line(Vector2(x, base_y - h0), Vector2(nx, base_y - h1), Color(0.86, 0.86, 0.86, activity * 0.75), 1.5, true)
			for k in 2:
				var depth := 7.0 + k * 9.0
				var echo0 := base_y + depth - h0 * (0.55 - 0.2 * k)
				var echo1 := base_y + depth - h1 * (0.55 - 0.2 * k)
				surface.draw_line(Vector2(x, echo0), Vector2(nx, echo1), Color(0.78, 0.78, 0.78, activity * (0.30 - 0.1 * k)), 1.1, true)
		x = nx

func _draw_water_impact(impact: Dictionary) -> void:
	if impact.has("drops"):
		_draw_struggle_splash(impact)
		return
	var t: float = impact.age
	var strength: float = impact.strength
	var origin := Vector2(impact.x, water_line(float(impact.x)))
	# Short displaced-water lobes, then ballistic droplets and expanding ripples.
	if t < 0.30:
		var height := sin(t / 0.30 * PI) * 19.0 * strength
		for side in [-1.0, 1.0]:
			var base := origin + Vector2(side * impact.spread, 0)
			var points := PackedVector2Array([base + Vector2(-9, 1), base + Vector2(side*8, -height), base + Vector2(side*16, -height*0.6), base + Vector2(side*22, 1)])
			surface.draw_colored_polygon(points, Color(0.65,0.65,0.65,(1.0-t/0.30)*0.48))
	for i in 22:
		var side := -1.0 if i % 2 == 0 else 1.0
		var vx := side * (20.0 + fposmod(i * 17.7, 67.0)) * strength
		var vy := -(60.0 + fposmod(i * 29.3, 90.0)) * strength
		var point := origin + Vector2(side * impact.spread * 0.45 + vx * t, vy * t + 180.0 * t * t)
		if point.y > level.WATER_Y or t > 0.9:
			continue
		var alpha := (1.0-t/0.9) * 0.64
		var tail := Vector2(vx, vy + 360.0*t).normalized() * (1.5 + strength*2.0)
		# Slightly offset dark mass keeps spray readable against bright mist.
		surface.draw_line(point+Vector2(0,0.7),point-tail+Vector2(0,0.7),Color(0.16,0.16,0.16,alpha*0.5),2.2,true)
		surface.draw_line(point,point-tail,Color(0.79,0.79,0.79,alpha),1.3,true)
	if not impact.rings:
		return
	# rings run out and fade slowly (the harder the hit the farther and the longer)
	var life := 1.3 + strength * 1.0
	for i in 4:
		var age := t - i * 0.16
		if age < 0.0 or age > life:
			continue
		var fade := 1.0 - age / life
		surface.draw_set_transform(origin + Vector2(0,2),0,Vector2(1,0.14))
		surface.draw_arc(Vector2.ZERO,impact.spread+age*(62.0+strength*34.0),0,TAU,56,Color(0.70,0.70,0.70,fade*fade*(0.34-i*0.05)),1.5,true)
		surface.draw_set_transform(Vector2.ZERO)

func _draw_struggle_splash(impact: Dictionary) -> void:
	var origin := Vector2(impact.x, water_line(float(impact.x)))
	for drop in impact.drops:
		var t: float = impact.age - drop.delay
		if t < 0.0:
			continue
		var velocity: Vector2 = drop.velocity
		var offset: Vector2 = drop.offset
		var point := origin + offset + velocity * t + Vector2(0.0, 300.0*t*t)
		if point.y >= level.WATER_Y:
			continue
		var alpha := minf(t / 0.025, 1.0) * 0.75
		var tail := (velocity + Vector2(0.0, 600.0*t)) * 0.014
		var shade: float = drop.shade
		# Fine streaks shorten into beads at the apex, then fall back into the water.
		surface.draw_line(point+Vector2(0,0.6), point-tail+Vector2(0,0.6), Color(0.13,0.13,0.13,alpha*0.4), drop.radius*2.0+0.6, true)
		surface.draw_line(point, point-tail, Color(shade,shade,shade,alpha), drop.radius*1.5, true)
		surface.draw_circle(point, drop.radius, Color(shade,shade,shade,alpha), true, -1.0, true)

# scene 1: the ground's edge is grown over with real grass (slices of a generated grass strip, placed along the contour, out of the way
# of the pits and the cliff); a slice is about 50 px wide, each a different part of the strip, some turned round, some taller
var _log_ranges: Array = []
func _on_log(x: float) -> bool:
	if _log_ranges.is_empty():
		for f: Dictionary in Scene1Ref.FEATURES:
			if String(f["t"]) == "log":
				_log_ranges.append(Vector2(Scene1Ref.fx(f) - 30.0, Scene1Ref.fx(f) + float(f["len"]) + 20.0))
	for range_value: Vector2 in _log_ranges:
		if x > range_value.x and x < range_value.y:
			return true
	return false

# Where the grass may grow (the same rule for the band and the tufts)
func _forest_grass_surface(x:float)->float:
	return Scene1Ref.ground_top(x)

func _shelter_growth(x:float)->float:
	return smoothstep(Scene1Ref.Crevice.LEFT-190.0,Scene1Ref.Crevice.LEFT+20.0,x)*(1.0-smoothstep(Scene1Ref.Crevice.EXIT_MOUTH,Scene1Ref.Crevice.RIGHT+160.0,x))

func _grass_ok(x: float) -> bool:
	# This depression is dry soil. The old below-baseline test only excluded
	# water; it must not exclude the newly shaped shelter terrain as well.
	var dry_hollow:=x>Scene1Ref.Crevice.ART_LEFT-130 and x<Scene1Ref.Crevice.ART_RIGHT+230
	return not (x < Scene1Ref.WORLD_LEFT or x > Scene1Ref.edge_x() - 22.0 or Scene1Ref.in_pit(x) or (not dry_hollow and Scene1Ref.ground_top(x) > Scene1Ref.GROUND_Y + 6.0) or _on_log(x))

# The ground's edge, drawn a few px thicker and ragged (solid ink, so the same black as the ground): the tufts are cut out of an image and
# fade at their sides, so on their own they leave dips and ends between them; the blades stand in this mat instead, and the line of the
# ground is never bare or cut off. It thins to nothing where the grass stops (pits, ponds, the log, the cliff).
# One cached 1D distance field fades rooted grass into every shore/cut edge.
func _prepare_grass_edges()->void:
	_grass_weight_origin=Scene1Ref.WORLD_LEFT-24.0
	var count:=int(ceil((Scene1Ref.edge_x()+24.0-_grass_weight_origin)/GRASS_WEIGHT_STEP))+1
	var allowed:=PackedByteArray()
	allowed.resize(count)
	_grass_edge_weights.resize(count)
	var distance:=1000.0
	for i in count:
		allowed[i]=1 if _grass_ok(_grass_weight_origin+i*GRASS_WEIGHT_STEP) else 0
		distance=distance+GRASS_WEIGHT_STEP if allowed[i]==1 else 0.0
		_grass_edge_weights[i]=distance
	distance=1000.0
	for i in range(count-1,-1,-1):
		distance=distance+GRASS_WEIGHT_STEP if allowed[i]==1 else 0.0
		_grass_edge_weights[i]=smoothstep(0.0,24.0,minf(distance,_grass_edge_weights[i]))

func _grass_edge_weight(x:float)->float:
	if _grass_edge_weights.is_empty():_prepare_grass_edges()
	var at:=clampf((x-_grass_weight_origin)/GRASS_WEIGHT_STEP,0,_grass_edge_weights.size()-1.001)
	var i:=int(at)
	return lerpf(_grass_edge_weights[i],_grass_edge_weights[i+1],at-i)

func _draw_grass_band() -> void:
	var step := 6.0
	var first := floorf(Scene1Ref.WORLD_LEFT / step) * step - step * 2.0
	var count := int((Scene1Ref.CLIFF_X + step * 4.0 - first) / step) + 1
	var margin := 5  # samples either side, for the thinning at the ends of a run
	# which of the samples (world-aligned, every 6 px) the grass may grow at: asked once each
	var ok := PackedByteArray()
	ok.resize(count + margin * 2)
	for k in count + margin * 2:
		ok[k] = 1 if _grass_ok(first + float(k - margin) * step) else 0
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var ink := Color(0.012, 0.013, 0.013, 1.0)
	var run_open := false
	for k in count:
		var wx := first + float(k) * step
		var at := k + margin
		# thickness: ragged (two sines), and thinning over 30 px towards either end of a run (look 30 px ahead and behind)
		var edge := 1.0 if (ok[at - 5] == 1 and ok[at + 5] == 1) else 0.0
		var near_end := 1.0 if (ok[at - 3] == 1 and ok[at + 3] == 1) else 0.45
		var thick := (5.5 + 2.4 * sin(wx * 0.37) + 1.4 * sin(wx * 0.91 + 1.3)) * (0.35 + 0.65 * edge) * near_end
		if ok[at] == 1:
			var gy: float = _forest_grass_surface(wx)
			var weight:=_grass_edge_weight(wx)
			top.append(Vector2(wx, gy - maxf(thick*weight,0.2)))
			bottom.append(Vector2(wx, gy + lerpf(0.5,3.0,weight)))
			run_open = true
		elif run_open:
			_flush_band(top, bottom, ink)
			top = PackedVector2Array()
			bottom = PackedVector2Array()
			run_open = false
	if run_open:
		_flush_band(top, bottom, ink)
	_draw_shelter_flowers()

# Retained world-space details share the ground-cover cache. Roots are buried
# in the same actual slope; flowers have no glow, collision or camera redraw.
func _draw_shelter_flowers()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=411978
	var ink:=Color(.012,.013,.013,1)
	var from_x:float=Scene1Ref.Crevice.LEFT-130.0
	var to_x:float=Scene1Ref.Crevice.EXIT_MOUTH+40.0
	var x:=from_x
	while x<to_x:
		x+=rng.randf_range(48,87)
		for stem in rng.randi_range(1,2):
			var px:=x+rng.randf_range(-12,12)
			if not _grass_ok(px) or _grass_edge_weight(px)<.85:continue
			var gy:=_forest_grass_surface(px)+1.5
			var height:=rng.randf_range(29,47)
			if Scene1Ref.Crevice.inside(px):height=minf(height,gy-Scene1Ref.Crevice.ceiling(px,Callable())-6)
			if height<24:continue
			var lean:=rng.randf_range(-8,8)
			grass_band.draw_set_transform(Vector2(px,gy),0,Vector2.ONE)
			var tip:=Vector2(lean,-height)
			var middle:=Vector2(lean*.35,-height*.53)
			grass_band.draw_polyline(PackedVector2Array([Vector2.ZERO,middle,tip]),ink,.8,true)
			var side:float=-1 if rng.randf()<.5 else 1
			grass_band.draw_colored_polygon(PackedVector2Array([middle+Vector2(0,3),middle+Vector2(side*6,-2),middle+Vector2(side*2,2)]),ink)
			var radius:=rng.randf_range(.9,1.25)
			var turn:=rng.randf_range(0,TAU)
			for petal in 5:
				var angle:=turn+petal*TAU/5
				grass_band.draw_circle(tip+Vector2.from_angle(angle)*radius,radius,ink,true,-1,true)
			grass_band.draw_circle(tip,radius,ink,true,-1,true)
	grass_band.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _flush_band(top: PackedVector2Array, bottom: PackedVector2Array, ink: Color) -> void:
	if top.size() < 2:
		return
	var points := PackedVector2Array(top)
	for i in range(bottom.size() - 1, -1, -1):
		points.append(bottom[i])
	grass_band.draw_colored_polygon(points, ink)

# Each tuft follows the actual surface across its full width. Only a tiny
# buried root margin is sampled; the source strip's rectangular soil is omitted.
# Valid runs stop at pits/water/logs rather than testing only the tuft centre.
func _draw_ground_grass() -> void:
	var step:=18.0
	var first:=floorf(Scene1Ref.WORLD_LEFT/step)*step-step
	var wx:=first
	var slice_src:=1280.0/11.0
	while wx<Scene1Ref.CLIFF_X+step:
		var snap:=int(floorf(wx/step))
		var here:=wx+step*0.5
		wx+=step
		if not _grass_ok(here):continue
		var rng:=RandomNumberGenerator.new()
		rng.seed=snap*2713+5
		var index:=rng.randi()%11
		var tall:=rng.randf_range(0.7,1.35)
		var bramble_x:float=Scene1Ref.START_X+Scene1Ref.BRAMBLE_OFFSET
		var thorn_clear:=1.0-smoothstep(46.0,105.0,absf(here-(bramble_x+42)))
		tall*=lerpf(1.0,.30,thorn_clear)
		tall*=lerpf(1.0,1.14,_shelter_growth(here))
		var width:=step*2.6
		var blades:=maxf(3.0,143.0*(width/slice_src)*tall-10.0)
		var root_depth:=2.0
		var mirrored:=rng.randf()<0.5
		var gy:=_forest_grass_surface(here)
		grass_art.draw_set_transform(Vector2(here,gy),0,Vector2.ONE)
		var columns:=int(ceil(width/2.0))
		var run_start:=-1
		for column in columns:
			var left:=here-width*0.5+width*float(column)/columns
			var right:=here-width*0.5+width*float(column+1)/columns
			var allowed:=_grass_ok(left+0.01) and _grass_ok((left+right)*0.5) and _grass_ok(right-0.01)
			if allowed and run_start<0:run_start=column
			if not allowed and run_start>=0:
				_grass_surface_run(here,gy,width,blades,root_depth,index,slice_src,mirrored,columns,run_start,column)
				run_start=-1
		if run_start>=0:_grass_surface_run(here,gy,width,blades,root_depth,index,slice_src,mirrored,columns,run_start,columns)
	grass_art.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _grass_surface_run(here:float,gy:float,width:float,blades:float,root_depth:float,index:int,slice_src:float,mirrored:bool,columns:int,first:int,last:int)->void:
	var points:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var colors:=PackedColorArray()
	for column in range(first,last+1):
		var t:=float(column)/columns
		var x:float=-width*0.5+width*t
		var weight:=_grass_edge_weight(here+x)
		points.append(Vector2(x,_forest_grass_surface(here+x)-gy-blades*lerpf(0.12,1.0,weight)))
		colors.append(Color(1,1,1,sqrt(weight)))
		var u:float=(float(index)*slice_src+2.0+(1.0-t if mirrored else t)*(slice_src-4.0))/1280.0
		uv.append(Vector2(u,419.0/720.0))
	for column in range(last,first-1,-1):
		var t:=float(column)/columns
		var x:float=-width*0.5+width*t
		var weight:=_grass_edge_weight(here+x)
		points.append(Vector2(x,_forest_grass_surface(here+x)-gy+root_depth))
		colors.append(Color(1,1,1,sqrt(weight)))
		var u:float=(float(index)*slice_src+2.0+(1.0-t if mirrored else t)*(slice_src-4.0))/1280.0
		uv.append(Vector2(u,568.0/720.0))
	if points.size()>=4:grass_art.draw_polygon(points,colors,uv,GRASS_STRIP)

func _draw_foreground() -> void:
	var x := -70.0 - camera_x*1.10
	if x > -260.0:
		foreground.draw_colored_polygon(PackedVector2Array([Vector2(x-40,-30),Vector2(x+116,-30),Vector2(x+96,150),Vector2(x+55,345),Vector2(x+35,540),Vector2(x-25,590)]),Color("090a0a"))
		foreground.draw_polyline(PackedVector2Array([Vector2(x+70,140),Vector2(x+176,85),Vector2(x+264,52)]),Color("090a0a"),28,true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for i in range(90):
		var wx := rng.randf_range(-150.0,3150.0)
		var sx := wx-camera_x*1.14
		if sx < -60.0 or sx > 1340.0:
			continue
		var height := rng.randf_range(20.0,85.0)
		var lean := rng.randf_range(-38.0,38.0)+sin(clock*0.35+i)*2.0
		var width := rng.randf_range(2.0,4.0)
		foreground.draw_colored_polygon(PackedVector2Array([Vector2(sx-width,744),Vector2(sx+lean,744-height),Vector2(sx+width,744)]),Color(0.012,0.014,0.014,0.85))
	var marsh_rng := RandomNumberGenerator.new()
	marsh_rng.seed = 91
	for i in range(80):
		var wx := marsh_rng.randf_range(3100.0,6500.0)
		var sx := wx-camera_x*1.14
		var height := marsh_rng.randf_range(20.0,85.0)
		var lean := marsh_rng.randf_range(-38.0,38.0)+sin(clock*0.35+i)*2.0
		var width := marsh_rng.randf_range(2.0,4.0)
		if sx < -60.0 or sx > 1340.0:
			continue
		foreground.draw_colored_polygon(PackedVector2Array([Vector2(sx-width,744),Vector2(sx+lean,744-height),Vector2(sx+width,744)]),Color(0.012,0.014,0.014,0.85))
	# Near trunks use the same fixed placement, with only offscreen culling.
	for spec in [Vector3(8700.0, 52.0, 0.0), Vector3(9560.0, 44.0, 1.0), Vector3(10520.0, 56.0, 2.0), Vector3(11500.0, 46.0, 3.0), Vector3(12500.0, 54.0, 4.0)]:
		var tx: float = spec.x - camera_x * 1.14
		if tx < -200.0 or tx > 1480.0:
			continue
		var tw: float = spec.y
		var lean: float = sin(spec.z * 2.3) * 14.0
		foreground.draw_colored_polygon(PackedVector2Array([Vector2(tx - tw * 0.5, -30), Vector2(tx + tw * 0.5, -30), Vector2(tx + tw * 0.62 + lean, 330), Vector2(tx + tw * 0.9, 744), Vector2(tx - tw * 0.9, 744), Vector2(tx - tw * 0.6 + lean, 330)]), Color("090a0a"))
	for i in range(12):
		var age := fposmod(clock*0.019+i*0.117,1.0)
		var mote := Vector2(fposmod(i*137.0-camera_x*0.40+age*30.0,1280.0),580-age*420.0)
		foreground.draw_circle(mote,0.7,Color(0.88,0.88,0.88,sin(age*PI)*0.13),true,-1,true)

# Reject the entire projected root footprint once, so a foreground tree never
# sweeps across the pond/pit and is never culled into view mid-walk.
func _near_tree_land_range(left:float,right:float)->bool:
	var x:=left
	while x<=right:
		if Scene1Ref.in_pit(x) or Scene1Ref.ground_top(x)>Scene1Ref.GROUND_Y+1.0 or x>Scene1Ref.Crevice.LEFT-160 or absf(x-(Scene1Ref.START_X+Scene1Ref.BRAMBLE_OFFSET+42))<135:return false
		x+=12.0
	return true
