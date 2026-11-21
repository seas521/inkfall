extends CanvasLayer
# Chapter-wide V83 response: world-space light/air for the boy and props.
# The legacy filename/property is retained for existing review launchers.
# Fixed forest openings, actual mine fixtures and shared fixed valley sun
# apertures supply incoming light. This is a targeted 2D art pass,
# not normal-mapped relighting or automatic global illumination.
const Forest=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const SHADER=preload("res://assets/shaders/forest_environment_integration.gdshader")
const GRASS=preload("res://assets/art/polyfork/forest-v1/scorched-grass-no-soil-v1.png")
var level:Node2D
var material_value:ShaderMaterial
var enabled:=true
var fusion_gain:=3.0
var amount:=0.0
var tufts:Node2D
var forest_ground:Texture2D
var region:StringName=&"forest"
var sources:=PackedVector4Array()
var axes:=PackedVector2Array()
var barriers:=PackedVector4Array()
var source_count:=0
var profiles_ready:=false

func setup(host:Node2D)->void:
	level=host
	layer=89
	var quad:=ColorRect.new()
	quad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quad.mouse_filter=Control.MOUSE_FILTER_IGNORE
	material_value=ShaderMaterial.new();material_value.shader=SHADER
	quad.material=material_value;add_child(quad)
	# Godot otherwise reuses the FIRST screen copy for the later film pass,
	# silently discarding this composition when Film reads screen_tex.
	var resolved:=BackBufferCopy.new()
	resolved.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(resolved)
	var ground:=Image.create(1024,1,false,Image.FORMAT_RF)
	for i in 1024:
		ground.set_pixel(i,0,Color(Forest.ground_top(lerpf(-9800.,-3300.,float(i)/1023.)),0,0))
	forest_ground=ImageTexture.create_from_image(ground)
	sources.resize(12);axes.resize(12);barriers.resize(4)
	tufts=Node2D.new();tufts.name="forest_clearing_front_grass";tufts.z_index=8
	level.add_child(tufts)
	# One broken, overlapping patch, not equally spaced potted clumps. Its
	# tips cross ankles/shins while the interaction space above stays open.
	for row in [[-6615.,.055,false],[-6593.,.065,true],[-6568.,.07,false],[-6548.,.048,true],[-6529.,.06,false],[-6508.,.055,true],[-6490.,.065,false],[-6470.,.045,true],[-6454.,.058,false],[-6430.,.05,true]]:
		var blade:=Sprite2D.new();blade.texture=GRASS;blade.centered=false
		blade.scale=Vector2.ONE*float(row[1]);blade.flip_h=bool(row[2])
		blade.position=Vector2(float(row[0]),Forest.ground_top(float(row[0]))+3)-Vector2(269.303,425.342)*float(row[1])
		var ink:=ShaderMaterial.new();ink.shader=preload("res://assets/shaders/forest_prop_soft_ink.gdshader")
		ink.set_shader_parameter("key_white",false);ink.set_shader_parameter("edge_softness",1.0)
		ink.set_shader_parameter("ink",Color(.003,.003,.003,1))
		blade.material=ink;tufts.add_child(blade)
	hide();tufts.hide()

func sync(active:bool,coverage:Texture2D)->void:
	var feet:Vector2=level.player.position+Vector2(13,54)
	amount=1.0 if active and enabled else 0.0
	var forest_amount:float=(1.-smoothstep(-4150.,-3800.,feet.y))*(1.-smoothstep(-3450.,-3100.,feet.x))
	visible=amount>.001;tufts.visible=visible and forest_amount>.99
	if level.actor.sprite.material!=null:
		level.actor.sprite.material.set_shader_parameter("forest_environment_blend",amount)
	if not visible:return
	var inverse:=level.get_canvas_transform().affine_inverse()
	var size:Vector2=level.get_viewport_rect().size
	material_value.set_shader_parameter("world_origin",inverse*Vector2.ZERO)
	material_value.set_shader_parameter("world_x",inverse.basis_xform(Vector2(size.x,0)))
	material_value.set_shader_parameter("world_y",inverse.basis_xform(Vector2(0,size.y)))
	material_value.set_shader_parameter("coverage",coverage)
	material_value.set_shader_parameter("strength",amount)
	material_value.set_shader_parameter("fusion_gain",fusion_gain)
	var contact:=feet
	if level.actor.has_method("_sole_points_of_frame"):
		var samples:PackedVector2Array=level.actor._sole_points_of_frame()
		var bottom:float=-INF
		for pixel in samples:
			var point:Vector2=level.actor.sprite.to_global(pixel)
			if point.y>bottom:bottom=point.y;contact=point
	material_value.set_shader_parameter("contact_point",contact)
	material_value.set_shader_parameter("grounded_contact",1.0 if level.actor.pose.grounded else 0.0)
	var preview:bool=level.art.mine_preview
	region=&"valley" if preview else level.art.valley_player_focus._region()
	material_value.set_shader_parameter("valley_preview_offset",Vector2(3600,-3050) if preview else Vector2.ZERO)
	var profiles=level.art.valley_player_light
	if not profiles_ready and level.bridge_to_c!=null and level.bridge_to_c.mine_trial!=null:
		for key in [&"gorge",&"mine",&"valley"]:profiles._profile(key)
		material_value.set_shader_parameter("forest_profile",forest_ground)
		material_value.set_shader_parameter("mine_profile",profiles.profiles[&"mine"].texture)
		material_value.set_shader_parameter("mine_sampling",profiles.profiles[&"mine"].sampling)
		material_value.set_shader_parameter("valley_profile",profiles.profiles[&"valley"].texture)
		material_value.set_shader_parameter("valley_sampling",profiles.profiles[&"valley"].sampling)
		profiles_ready=true
	# Only cached geometry data is reused. The rejected V56 transport and
	# receiving shaders stay disabled; all depth selection is per world point.
	_sync_lamps()

func _fixture(fixture:Node2D,power:float,candidates:Array,view:Rect2)->void:
	if not is_instance_valid(fixture) or not fixture.is_visible_in_tree() or not fixture.has_method("light_position"):return
	if fixture.get_meta("light_plane",&"gameplay")!=&"gameplay":return
	var energy:float=float(fixture.get("energy")) if fixture.get("energy")!=null else 1.0
	var at:Vector2=fixture.light_position()
	if energy<=.001 or not view.grow(430.).has_point(at):return
	candidates.append({"at":at,"axis":Vector2.DOWN.rotated(fixture.light_angle()),"power":power*energy,"distance":at.distance_squared_to(view.get_center())})

func _sync_lamps()->void:
	var route=level.get("bridge_to_c")
	source_count=0;sources.fill(Vector4.ZERO);axes.fill(Vector2.DOWN);barriers.fill(Vector4.ZERO)
	var candidates:Array=[]
	if route!=null and route.mine_trial!=null:
		var half:Vector2=Vector2(640,360)/level.camera.zoom
		var view:=Rect2(level.camera.get_screen_center_position()-half,half*2.)
		for lamp in [route.art.chamber.lamp,route.art.chase_chamber.lamp,route.mine_trial.escape.chase_lamp,route.mine_trial.escape.end_lamp]:_fixture(lamp,.72,candidates,view)
		var room=route.mine_trial.gap.art.pair_room
		if room!=null:
			for i in room.lamps.size():_fixture(room.lamps[i],.68 if i<4 else .18,candidates,view)
			_fixture(room.relay.art.fixture,.80,candidates,view)
			barriers[0]=Vector4(-549.,-231.,room.UPPER_Y,3.)
			barriers[1]=Vector4(-410.,315.,room.MID_Y,4.)
		candidates.sort_custom(func(a,b):return a.distance<b.distance)
		for entry in candidates.slice(0,12):
			sources[source_count]=Vector4(entry.at.x,entry.at.y,390.,entry.power)
			axes[source_count]=entry.axis;source_count+=1
	material_value.set_shader_parameter("lamp_count",source_count)
	material_value.set_shader_parameter("lamps",sources)
	material_value.set_shader_parameter("lamp_axes",axes)
	material_value.set_shader_parameter("decks",barriers)

func _process(_delta:float)->void:
	if not is_instance_valid(level):return
	if not level.is_visible_in_tree():
		hide();tufts.hide()
		level.actor.sprite.material.set_shader_parameter("forest_environment_blend",0.)
	elif visible:
		# Present uses the actual lamp pose after its physics/swing update.
		_sync_lamps()

func _exit_tree()->void:
	if is_instance_valid(tufts):tufts.queue_free()
