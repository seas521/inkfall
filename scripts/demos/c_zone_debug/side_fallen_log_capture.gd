extends SceneTree
# Plain side-view solid fallen log, using the already-approved forest asset.
# Art-only preview in the actual chapter. No opening, cavity or hole shader.
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const LOG=preload("res://assets/art/c_zone_debug/forest/forest_fallen_log.jpg")
const SCALE:=0.60
var level
func _initialize():call_deferred("run")
func run()->void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_size(Vector2i(1280,720))
	level=SCENE.instantiate();root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	for i in 8:await physics_frame;await process_frame
	level.debug_enter_scene1()
	level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
	level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
	level.set_physics_process(false)
	var left:float=S.Crevice.LEFT-270*SCALE
	var surface:=Image.create(256,1,false,Image.FORMAT_RF)
	for i in 256:
		var x:float=left+1280*SCALE*float(i)/255
		surface.set_pixel(i,0,Color(S.ground_top(x),0,0))
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform sampler2D plate:filter_linear,repeat_disable;
uniform sampler2D terrain:filter_linear,repeat_disable;
uniform vec4 ink:source_color=vec4(.012,.013,.013,1.);
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;}
void fragment(){
 float floor_y=texture(terrain,vec2(UV.x,.5)).r;
 float sy=495.+(world.y-floor_y)/.60;
 vec4 source=texture(plate,vec2(UV.x,clamp(sy/720.,0.,1.)));
 float l=dot(source.rgb,vec3(.299,.587,.114));
 float a=(1.-smoothstep(.20,.80,l))*source.a;
 if(sy<0.||sy>720.)a=0.;
 COLOR=vec4(ink.rgb,a);
}"""
	var mat:=ShaderMaterial.new();mat.shader=shader
	mat.set_shader_parameter("plate",LOG)
	mat.set_shader_parameter("terrain",ImageTexture.create_from_image(surface))
	var log_art:=ColorRect.new()
	log_art.position=Vector2(left,S.ground_top(S.Crevice.LEFT)-495*SCALE)
	log_art.size=Vector2(1280,720)*SCALE
	log_art.material=mat;log_art.z_index=6
	log_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	level.art.add_child(log_art)
	var player_x:float=left-28
	level.player.position=Vector2(player_x-13,S.ground_top(player_x)-54)
	level.player.velocity=Vector2.ZERO
	level.scene1.low_stance.reset()
	level.camera_x=left-210
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	for i in 40:
		level._present(1./60.)
		level.art.crevice_art.hide()
		await process_frame
	RenderingServer.force_draw()
	var picture:=root.get_texture().get_image()
	picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("res://artifacts/fallen-log-side-view")
	picture.save_png("res://artifacts/fallen-log-side-view/in-game.png")
	print("SOLID SIDE LOG: existing forest_fallen_log.jpg, no cavity or new background, actor scale=",level.pose.visual_scale)
	quit()
