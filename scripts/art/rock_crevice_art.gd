extends Node2D
# User-approved isolated Seedance timber, integrated with the real forest.
const Layout=preload("res://scripts/chapters/rock_crevice_layout.gd")
var scene
var timber:Polygon2D
var timber_origin:=Vector2.ZERO
var chips:Array[Dictionary]=[]
var dust:Array[Dictionary]=[]
var chips_spawned:=0
var chips_landed:=0
var dust_bursts:=0
var last_strike:=-1
var hit_age:=99.0
var last_frame:=-1
var rng:=RandomNumberGenerator.new()
func _ready()->void:
	rng.seed=47891
	timber=Polygon2D.new();timber.z_index=6
	# User-provided isolated timber (2026-11-12); no landscape is cut out.
	timber.polygon=PackedVector2Array([Vector2(0,0),Vector2(2816,0),Vector2(2816,1584),Vector2(0,1584)])
	timber.uv=timber.polygon
	timber.texture=load("res://assets/art/hollow-log/seedance-approved-timber-v3.png")
	timber.position=Vector2(Layout.ART_LEFT,Layout.ART_Y)
	timber.scale=Vector2.ONE*Layout.ART_SCALE/1.375
	timber.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shader:=preload("res://assets/shaders/forest_prop_soft_ink.gdshader")
	var mat:=ShaderMaterial.new();mat.shader=shader;timber.material=mat
	timber_origin=timber.position
	add_child(timber)
	z_index=0
func burst(x:float)->void:
	hit_age=0;dust_bursts+=1
	for i in 15:
		chips.append({"p":Vector2(x+rng.randf_range(-16,16),Layout.ceiling(x,Callable())+3),"v":Vector2(rng.randf_range(-55,55),rng.randf_range(-25,40)),"age":0.,"size":rng.randf_range(1.,3.8)})
		chips_spawned+=1
func sync(delta:float,camera_x:float,camera_y:float,active:bool)->void:
	visible=active and camera_y< -3900 and camera_x+1280>Layout.ART_LEFT-100 and camera_x<Layout.ART_RIGHT+100
	if not visible or scene.level.paused:return
	var frame:=Engine.get_physics_frames()
	if frame==last_frame:return
	last_frame=frame;hit_age+=delta
	if scene.spider.log_strike_count!=last_strike:
		if last_strike>=0:burst(scene.spider.log_strike_x)
		last_strike=scene.spider.log_strike_count
	timber.position.y=timber_origin.y+(sin(hit_age*70)*exp(-hit_age*13)*1.7 if hit_age<.5 else 0.)
	for i in range(chips.size()-1,-1,-1):
		var c:Dictionary=chips[i];c.age+=delta;c.v.y+=450*delta;c.p+=c.v*delta
		if c.p.y>=scene.ground_top(c.p.x):chips_landed+=1;chips.remove_at(i)
		elif c.age>1.8:chips.remove_at(i)
	queue_redraw()
func _draw()->void:
	for c:Dictionary in chips:
		var p:Vector2=c.p;var s:float=c.size
		draw_colored_polygon(PackedVector2Array([p+Vector2(-s,-s*.4),p+Vector2(s*.7,-s),p+Vector2(s,s*.4),p+Vector2(-s*.6,s*.7)]),Color(.015,.015,.015,1.-smoothstep(.8,1.8,c.age)))
