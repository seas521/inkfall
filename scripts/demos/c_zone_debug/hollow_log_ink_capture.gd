extends SceneTree
# Material/composition preview inside the existing complete chapter scene.
# Uses the original forest, ground, grass, camera, film look and player.
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const ForestPlates=preload("res://scripts/demos/c_zone_debug/forest_plates.gd")
var level
var log_sprite:Sprite2D
var source_scale:=0.432
const VERTICAL_SCALE:=0.36
var origin:=Vector2.ZERO
func _initialize():call_deferred("run")
func frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func place(x:float,low:=false)->void:
	level.player.position=Vector2(x-13,S.ground_top(x)-54)
	level.player.velocity=Vector2.ZERO
	level.scene1.low_stance.mode=level.scene1.low_stance.Mode.LOW if low else level.scene1.low_stance.Mode.UP
	level.scene1.low_stance.time=.25
	level.scene1.low_stance.distance=28
	if low:level.player.velocity.x=60
func run()->void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_size(Vector2i(1280,720))
	level=SCENE.instantiate();root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8)
	level.debug_enter_scene1()
	level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
	level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
	level.set_physics_process(false)
	level.art.crevice_art.hide()
	log_sprite=Sprite2D.new();log_sprite.centered=false
	log_sprite.texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/art/hollow-log/user-tree-pure-black.png"))
	log_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shader:=Shader.new();shader.code=ForestPlates.KEY_SHADER
	# Same uniform-ink / alpha cutout as the approved old log. Only source
	# placement is terrain-calibrated: the lower wood is embedded in soil.
	shader.code="""shader_type canvas_item;
uniform vec4 ink : source_color = vec4(.012,.013,.013,1.);
uniform sampler2D ground_profile:filter_linear,repeat_disable;
uniform sampler2D source_floor:filter_linear,repeat_disable;
uniform float vertical_scale=.36;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;}
void fragment(){
 float floor_y=texture(ground_profile,vec2(UV.x,.5)).r;
 float sf=texture(source_floor,vec2(UV.x,.5)).r;
 float sy=sf+(world.y-floor_y)/vertical_scale;
 vec4 source=texture(TEXTURE,vec2(UV.x,clamp(sy/1254.,0.,1.)));
 float l=dot(source.rgb,vec3(.299,.587,.114));
 float a=(1.-smoothstep(.20,.80,l))*source.a;
 if(sy<0.||sy>1254.)a=0.;
 COLOR=vec4(ink.rgb,a);
}"""
	var material_value:=ShaderMaterial.new();material_value.shader=shader
	material_value.set_shader_parameter("vertical_scale",VERTICAL_SCALE)
	log_sprite.material=material_value
	log_sprite.scale=Vector2.ONE*source_scale
	log_sprite.z_index=6
	origin=Vector2(S.Crevice.LEFT+50-450*source_scale,S.ground_top(S.Crevice.LEFT)-1030*source_scale)
	var ground_image:=Image.create(256,1,false,Image.FORMAT_RF)
	var source_image:=Image.create(256,1,false,Image.FORMAT_RF)
	var foot_profile:Array=[Vector2(0,940),Vector2(150,940),Vector2(250,950),Vector2(350,950),Vector2(450,870),Vector2(550,830),Vector2(700,820),Vector2(850,790),Vector2(1000,780),Vector2(1150,840),Vector2(1254,850)]
	for i in 256:
		var u:=float(i)/255
		ground_image.set_pixel(i,0,Color(S.ground_top(origin.x+1254*source_scale*u),0,0))
		source_image.set_pixel(i,0,Color(S.Crevice.profile(foot_profile,u*1254),0,0))
	material_value.set_shader_parameter("ground_profile",ImageTexture.create_from_image(ground_image))
	material_value.set_shader_parameter("source_floor",ImageTexture.create_from_image(source_image))
	log_sprite.position=origin
	level.art.add_child(log_sprite)
	place(origin.x-40)
	level.camera_x=origin.x-240
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	DirAccess.make_dir_recursive_absolute("res://artifacts/hollow-log/in-game")
	for item in [["01-overview",origin.x-40,false],["02-entry",origin.x+450*source_scale,true],["03-near-shell",origin.x+550*source_scale,true]]:
		place(item[1],item[2])
		for i in 35:
			level._present(1./60.)
			level.art.crevice_art.hide()
			await process_frame
		RenderingServer.force_draw()
		var picture:=root.get_texture().get_image()
		picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
		picture.save_png("res://artifacts/hollow-log/in-game/"+item[0]+".png")
		print("ACTUAL FOREST PREVIEW ",item[0])
	print("Existing KEY_SHADER, alpha-cut silhouette; no generated background; player visual_scale=",level.pose.visual_scale)
	quit()
