extends SceneTree
# Isolated design review. Uses the actual game's actor renderer and clips.
# Does not alter the playable cave, route, actor resources or animation.
const Actor=preload("res://scripts/actors/hood_frame_actor.gd")
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const OUT="res://artifacts/rock-crevice/concepts/"
var background:Texture2D
var canvas:SubViewport
var stage:Node2D
var factor:=2304.0/1881.0
func _initialize():call_deferred("run")
func actor_at(parent:Node,feet:Vector2,clip:StringName,frame:int)->Node2D:
	var a:=Actor.new()
	parent.add_child(a)
	a.load_group("core");a.load_group("low_stance")
	var p:=Pose.new();p.feet=feet;p.facing=1;p.grounded=true
	a.pose=p;a.play(clip,frame);a.playing=false
	a._apply();a.show();a.z_index=2
	return a
func plate(parent:Node,front:=false)->void:
	var s:=Sprite2D.new();s.texture=background;s.centered=false
	s.scale=Vector2.ONE*factor
	parent.add_child(s)
	if front:
		s.z_index=3
		var shader:=Shader.new()
		shader.code="""shader_type canvas_item;
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 // Original art is unchanged. Only its opaque black near rock/threshold
 // is repeated in front of the real actor, including the eye.
 float dark=1.-smoothstep(.055,.085,max(c.r,max(c.g,c.b)));
 COLOR=vec4(c.rgb,c.a*dark);
}"""
		var m:=ShaderMaterial.new();m.shader=shader;s.material=m
func label_at(text:String,at:Vector2,size:=24)->void:
	var l:=Label.new();l.text=text;l.position=at
	l.add_theme_font_size_override("font_size",size)
	l.modulate=Color(.75,.75,.75)
	stage.add_child(l)
func save(name:String)->void:
	for i in 6:await process_frame
	RenderingServer.force_draw()
	canvas.get_texture().get_image().save_png(OUT+name+".png")
	print("SAVED ",name)
func new_canvas(size:Vector2i)->void:
	if canvas!=null:
		canvas.queue_free();await process_frame
	canvas=SubViewport.new();canvas.size=size
	canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	stage=Node2D.new();canvas.add_child(stage)
func run()->void:
	background=ImageTexture.create_from_image(Image.load_from_file(OUT+"long-opaque-passage-v2-environment.png"))
	await new_canvas(Vector2i(2304,1024))
	plate(stage)
	actor_at(stage,Vector2(436,739),&"low_enter",22)
	actor_at(stage,Vector2(1760,718),&"low_walk",10)
	plate(stage,true)
	await save("long-opaque-passage-v2-actors")
	await new_canvas(Vector2i(1600,900))
	# Two enlarged inspection frames preserve the same environment/actor ratio.
	for i in 2:
		var view:=SubViewport.new();view.size=Vector2i(792,470)
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		canvas.add_child(view)
		var local:=Node2D.new();view.add_child(local)
		local.scale=Vector2.ONE*2.3
		local.position=Vector2(370,355)-Vector2(436 if i==0 else 1760,739 if i==0 else 718)*2.3
		plate(local)
		actor_at(local,Vector2(436,739) if i==0 else Vector2(1760,718),&"low_enter" if i==0 else &"low_walk",22 if i==0 else 10)
		plate(local,true)
		var image:=Sprite2D.new();image.texture=view.get_texture();image.centered=false
		image.position=Vector2(i*808,0);stage.add_child(image)
	label_at("ENTRY / existing low_enter frame 22",Vector2(25,482),22)
	label_at("EXIT / existing low_walk frame 10",Vector2(830,482),22)
	var diagram:=Node2D.new();stage.add_child(diagram)
	diagram.draw.connect(func():
		diagram.draw_rect(Rect2(0,550,1600,350),Color(.07,.07,.07))
		var mass:=PackedVector2Array([Vector2(200,830),Vector2(210,760),Vector2(290,710),Vector2(420,650),Vector2(630,610),Vector2(870,595),Vector2(1160,590),Vector2(1390,680),Vector2(1400,830)])
		diagram.draw_colored_polygon(mass,Color.BLACK)
		var floor_points:=PackedVector2Array([Vector2(180,810),Vector2(310,804),Vector2(480,802),Vector2(660,797),Vector2(840,800),Vector2(1020,794),Vector2(1190,798),Vector2(1410,795)])
		var tunnel:=PackedVector2Array()
		for p:Vector2 in floor_points:tunnel.append(p-Vector2(0,46))
		for j in range(floor_points.size()-1,-1,-1):tunnel.append(floor_points[j])
		diagram.draw_colored_polygon(tunnel,Color(.24,.24,.24))
		for x in range(370,1350,180):
			diagram.draw_line(Vector2(x,778),Vector2(x+35,778),Color(.65,.65,.65),1)
			diagram.draw_line(Vector2(x+28,774),Vector2(x+35,778),Color(.65,.65,.65),1)
	)
	label_at("STRUCTURE ONLY - this cutaway is hidden in the game",Vector2(26,562),23)
	label_at("~1,320 world px / ~22 s at current 60 px/s low walk",Vector2(420,837),22)
	label_at("Two-foot low walk; solid rock occludes the middle",Vector2(420,867),18)
	await save("long-opaque-passage-v2-details")
	quit()
