extends Node2D

# Artwork follows the same fixed world geometry as contact. The valley trees
# have fixed ground anchors; descending reveals crowns, then trunks and roots.
const KIT=preload("res://assets/art/descent/post-bridge/root-cliff-kit-v1.png")
const DEPTH=preload("res://assets/art/descent/post-bridge/root-cliff-depth-v1.png")
const LIGHT=preload("res://assets/shaders/cinematic_light_cone.gdshader")
var route
var background:Sprite2D
var ink:Node2D
var supports:Node2D
var dust:Node2D
var near:Node2D
var cones:Array[ColorRect]=[]
var jets:Dictionary={}
var clock:=0.0

func _ready()->void:
	background=Sprite2D.new()
	background.z_index=-5
	background.texture=DEPTH
	background.centered=false
	background.position=Vector2(-2700,-4250)
	background.scale=Vector2(2800,5100)/Vector2(DEPTH.get_size())
	background.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(background)
	supports=Node2D.new()
	supports.z_index=-1
	supports.draw.connect(draw_supports)
	add_child(supports)
	var root_shader:=Shader.new()
	root_shader.code="""shader_type canvas_item;
void fragment(){
 float t=smoothstep(0.70,0.98,UV.y);
 float a=texture(TEXTURE,UV).a*(1.0-smoothstep(0.87,1.0,UV.y));
 COLOR=vec4(vec3(mix(0.008,0.15,t)),a);
}"""
	var root_material:=ShaderMaterial.new()
	root_material.shader=root_shader
	supports.material=root_material
	ink=Node2D.new()
	ink.z_index=2
	ink.draw.connect(draw_ink)
	add_child(ink)
	# Normalize source RGB: only the image-authored alpha contour survives.
	var sh:=Shader.new()
	sh.code="shader_type canvas_item; varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){vec4 c=texture(TEXTURE,UV); COLOR=vec4(tint.rgb,c.a*tint.a);}"
	var mat:=ShaderMaterial.new()
	mat.shader=sh
	ink.material=mat
	var back_shader:=Shader.new()
	back_shader.code="""shader_type canvas_item;
void fragment(){
 vec3 c=texture(TEXTURE,UV).rgb*0.4;
 vec2 d=TEXTURE_PIXEL_SIZE*1.3;
 c+=(texture(TEXTURE,UV+vec2(d.x,0)).rgb+texture(TEXTURE,UV-vec2(d.x,0)).rgb+texture(TEXTURE,UV+vec2(0,d.y)).rgb+texture(TEXTURE,UV-vec2(0,d.y)).rgb)*0.15;
 float v=pow(max(dot(c,vec3(0.333333)),0.0),0.454545);
 float edge=smoothstep(0.0,0.16,UV.x)*(1.0-smoothstep(0.88,1.0,UV.x));
 float altitude=smoothstep(0.0,0.14,UV.y)*(1.0-smoothstep(0.70,0.94,UV.y));
 COLOR=vec4(vec3(clamp(v*0.82+0.06,0.14,0.56)),edge*altitude);
}"""
	var back_material:=ShaderMaterial.new()
	back_material.shader=back_shader
	background.material=back_material
	near=Node2D.new()
	near.z_index=8
	near.material=mat
	near.draw.connect(draw_near)
	add_child(near)
	dust=Node2D.new()
	dust.z_index=3
	dust.draw.connect(draw_dust)
	add_child(dust)
	for i in 5:
		var light:=ColorRect.new()
		light.position=Vector2(-2300+i*200,-3500+i*760)
		light.size=Vector2(900,760)
		light.z_index=-2
		light.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var lm:=ShaderMaterial.new()
		lm.shader=LIGHT
		lm.set_shader_parameter("intensity",0.055)
		lm.set_shader_parameter("light_tint",Vector3(0.52,0.52,0.52))
		lm.set_shader_parameter("seed",i*2.31)
		light.material=lm
		add_child(light)
		cones.append(light)

	for index in route.VENTS:
		var jet:=ColorRect.new()
		jet.position=route.vent_position(index)-Vector2(26,108)
		jet.size=Vector2(52,110)
		jet.z_index=3
		jet.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var jm:=ShaderMaterial.new()
		jm.shader=preload("res://assets/shaders/root_fissure_jet.gdshader")
		jm.set_shader_parameter("seed",float(index))
		jet.material=jm
		add_child(jet)
		jets[index]=jet

func sync(delta:float)->void:
	clock+=delta
	visible=route.enabled
	if not visible:return
	var cam:=Vector2(route.level.camera_x,route.level.camera_y)
	# Parallax about anchored terrain, never a per-state fade.
	background.position=Vector2(-2700,-4250)+cam*Vector2(0.06,0.025)
	near.position=cam*Vector2(-0.06,-0.03)
	for light in cones:
		light.material.set_shader_parameter("clock",clock)
		light.visible=absf(light.position.y-cam.y)<1200
	for index in jets:
		var phase:float=route.vent_phase(index)
		var force:=smoothstep(0.0,0.16,phase-1.1)*(1.0-smoothstep(2.15,2.35,phase)) if route.vent_active(index) else 0.0
		jets[index].material.set_shader_parameter("clock",clock)
		jets[index].material.set_shader_parameter("strength",force)

	for node in [supports,ink,dust,near]:node.queue_redraw()

func draw_supports()->void:
	var cam:=Vector2(route.level.camera_x,route.level.camera_y)
	for i in range(1,route.X.size()-2):
		var p:Vector2=route.landing(i)
		if absf(p.y-cam.y-360)>650:continue
		var side:=1.0 if i%5<3 else -1.0
		var width:=150.0+float(i%4)*22.0
		var height:=180.0+float(i%3)*35.0
		if i in route.FRAGILE:width*=0.65
		supports.draw_set_transform(p,0,Vector2(side,1))
		supports.draw_texture_rect_region(KIT,Rect2(-20,-5,width,height),Rect2(600,830,654,424))
		supports.draw_set_transform(Vector2.ZERO)

func draw_ink()->void:
	var camera:=Vector2(route.level.camera_x,route.level.camera_y)
	var view:=Rect2(camera-Vector2(300,300),Vector2(1880,1320))
	for i in route.X.size():
		var p:Vector2=route.landing(i)
		if not view.has_point(p):continue
		var w:float=route.width(i)
		var age:float=route.age.get(i,0.0)
		var sink:=maxf(0,age-0.95)
		if sink>1.2:continue
		var bend:=sin(age*27)*minf(age,0.95)*1.6 if age>0 else 0.0
		# Different portions of the authored contour avoid repeating identical shelves.
		var root:bool=i in route.FRAGILE
		var source:=Rect2(0,440,1254,380)
		var h:=65.0 if root else 95.0
		ink.draw_texture_rect_region(KIT,Rect2(p+Vector2(-w*0.5-8,-h*90.0/380.0+bend+sink*sink*420),Vector2(w+16,h)),source,Color(0.006,0.006,0.006,1-smoothstep(0.5,1.2,sink)))

	# Entry shoulders and final slope are load-bearing masses tied into land.
	ink.draw_texture_rect_region(KIT,Rect2(-2395,-3741,325,105),Rect2(0,440,1254,380),Color(0.006,0.006,0.006))
	ink.draw_texture_rect_region(KIT,Rect2(-410,262,190,95),Rect2(0,440,1254,380),Color(0.006,0.006,0.006))

func draw_near()->void:
	# Keep all landing and hazard silhouettes visible; framing is provided
	# by the existing global lens and the cliff shoulders, not opaque cards.
	pass

func draw_dust()->void:
	var cam:=Vector2(route.level.camera_x,route.level.camera_y)
	for i in route.VENTS:
		var p:Vector2=route.vent_position(i)
		if absf(p.y-cam.y-360)>600:continue
		var phase:float=route.vent_phase(i)
		var warning:bool=phase<1.1
		if phase>=2.35:continue
		for k in 24:
			var t:=fposmod(clock*(1.3 if warning else 2.4)+k*0.137,1.0)
			var height:=20.0 if warning else 100.0
			var pos:=p+Vector2(sin(k*2.399+t*3)*t*(6 if warning else 19),-t*height)
			dust.draw_circle(pos,lerpf(1.3,4.3,t) if not warning else 1.0,Color(0.40,0.40,0.40,sin(t*PI)*0.32),true,-1,true)
	for index in route.age:
		var age:float=route.age[index]
		var p:Vector2=route.landing(index)
		if age>2.1:continue
		for k in 12:
			var t:=maxf(0,age-0.12-float(k)*0.035)
			if t<=0:continue
			var pos:=p+Vector2(sin(k*2.39)*route.width(index)*0.42,8+t*t*155)
			var alpha:=1.0-smoothstep(0.4,1.4,t)
			dust.draw_circle(pos,1.0+float(k%3),Color(0.15,0.15,0.15,alpha),true,-1,true)

	for i in 30:
		var t:=fposmod(clock*0.045+i*0.173,1)
		var pos:=cam+Vector2(fposmod(i*137.4+clock*2,1280),720-t*740)
		dust.draw_circle(pos,0.65,Color(0.5,0.5,0.5,sin(t*PI)*0.08),true,-1,true)
