extends Node2D

# Polyfork meshes are a presentation layer over the accepted 2D puzzle.
# GLB geometry and named pivots are used; no three.js source is executed.
const DIR:="res://assets/art/polyfork/station-v1/"
const Layout=preload("res://scripts/chapters/descent_route_layout.gd")
const PIXELS_PER_METRE:=100.0
const VIEW_SIZE:=Vector2i(2760,1200)
const VIEW_ORIGIN:=Vector2(-120,-420)
var route
var view:SubViewport
var world:Node3D
var output:Sprite2D
var cart:Dictionary
var weight:Dictionary
var left_hoist:Dictionary
var frame:Dictionary
var left_pulley:Node3D
var assets:Array[Dictionary]=[]
var _last_pose:=Vector3(INF,INF,INF)

func _ready()->void:
	var front:=_viewport(1)
	view=front.view
	world=front.world
	output=front.output
	frame=_asset("timber-shaft-frame-87f96b",world,Vector2(190,260),-0.12,false,false,Color.BLACK,true)
	_place(frame,Vector2(330,0))
	left_hoist=_asset("mine-headframe-de1ad0",world,Vector2(76,145),0.16,false,true,Color.BLACK)
	_place(left_hoist,Vector2(805,280))
	left_pulley=_named(left_hoist.source,"pulley")
	cart=_asset("mine-cart-94bd76",world,Vector2(66,48),PI*0.5,false,false,Color.BLACK)
	weight=_asset("mine-cart-94bd76",world,Vector2(66,48),PI*0.5,false,false,Color.BLACK)
	sync(false)

func _viewport(layer:int)->Dictionary:
	var viewport:=SubViewport.new()
	viewport.size=VIEW_SIZE
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var root3d:=Node3D.new()
	viewport.add_child(root3d)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=float(VIEW_SIZE.y)/PIXELS_PER_METRE
	camera.position=Vector3(float(VIEW_SIZE.x)/PIXELS_PER_METRE*0.5,-camera.size*0.5,40)
	camera.near=0.1
	camera.far=100
	root3d.add_child(camera)
	camera.current=true
	var sprite:=Sprite2D.new()
	sprite.centered=false
	sprite.texture=viewport.get_texture()
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position=Layout.ORIGIN+VIEW_ORIGIN
	sprite.z_index=layer
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform float edge_softness=0.38;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
 vec2 p=TEXTURE_PIXEL_SIZE*edge_softness;
 vec4 c=texture(TEXTURE,UV);vec3 rgb=c.rgb*c.a*0.5;float a=c.a*0.5;
 vec4 l=texture(TEXTURE,UV+vec2(p.x,0));rgb+=l.rgb*l.a*0.125;a+=l.a*0.125;
 l=texture(TEXTURE,UV-vec2(p.x,0));rgb+=l.rgb*l.a*0.125;a+=l.a*0.125;
 l=texture(TEXTURE,UV+vec2(0,p.y));rgb+=l.rgb*l.a*0.125;a+=l.a*0.125;
 l=texture(TEXTURE,UV-vec2(0,p.y));rgb+=l.rgb*l.a*0.125;a+=l.a*0.125;
 COLOR=vec4(rgb/max(a,0.0001),a)*tint;
}"""
	var material:=ShaderMaterial.new()
	material.shader=shader
	sprite.material=material
	add_child(sprite)
	return {"view":viewport,"world":root3d,"output":sprite}

func _asset(id:String,parent:Node3D,pixels:Vector2,yaw:float,top:bool,hide_bucket:bool,tone:Color,stretch:=false)->Dictionary:
	var holder:=Node3D.new()
	parent.add_child(holder)
	var turn:=Node3D.new()
	turn.rotation.y=yaw
	holder.add_child(turn)
	var packed:PackedScene=load(DIR+id+".glb")
	var source:Node3D=packed.instantiate()
	turn.add_child(source)
	if hide_bucket:
		var bucket:=_named(source,"bucket")
		if bucket!=null:bucket.hide()
		var rope:=_named(source,"rope")
		if rope!=null:rope.hide()
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=tone
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	for mesh in source.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=material
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bounds:AABB=_bounds(turn)
	var sx:float=pixels.x/PIXELS_PER_METRE/maxf(bounds.size.x,0.001)
	var sy:float=pixels.y/PIXELS_PER_METRE/maxf(bounds.size.y,0.001)
	var uniform:float=minf(sx,sy)
	holder.scale=Vector3(sx,sy,minf(sx,sy)) if stretch else Vector3.ONE*uniform
	turn.position=Vector3(-bounds.get_center().x,-(bounds.end.y if top else bounds.position.y),-bounds.get_center().z)
	var wheels:Array[Node3D]=[]
	for name in ["wheel-fl","wheel-fr","wheel-rl","wheel-rr"]:
		var node:=_named(source,name)
		if node!=null:wheels.append(node)
	var item:Dictionary={"id":id,"holder":holder,"source":source,"bounds":bounds,"wheels":wheels,"scale":holder.scale,"pixels":pixels}
	assets.append(item)
	return item

func _named(root:Node,name:String)->Node3D:
	if String(root.name).to_lower()==name:return root as Node3D
	for child in root.get_children():
		var found:=_named(child,name)
		if found!=null:return found
	return null

func _bounds(root:Node3D)->AABB:
	var result:=AABB()
	var first:=true
	var stack:Array=[{"node":root,"transform":Transform3D.IDENTITY}]
	while not stack.is_empty():
		var item:Dictionary=stack.pop_back()
		var node:Node=item.node
		var transform:Transform3D=item.transform
		if node is Node3D:
			if not node.visible:continue
			transform=transform*node.transform
		if node is MeshInstance3D:
			var box:AABB=transform*node.get_aabb()
			result=box if first else result.merge(box)
			first=false
		for child in node.get_children():stack.append({"node":child,"transform":transform})
	return result

func _place(item:Dictionary,local:Vector2)->void:
	item.holder.position=Vector3((local.x-VIEW_ORIGIN.x)/PIXELS_PER_METRE,-(local.y-VIEW_ORIGIN.y)/PIXELS_PER_METRE,0)

func anchor(pulley:Node3D)->Vector2:
	var p:Vector3=pulley.global_position
	return Layout.ORIGIN+VIEW_ORIGIN+Vector2(p.x,-p.y)*PIXELS_PER_METRE

func sync(enabled:bool)->void:
	if view==null:return
	var screen:=Rect2(Vector2(route.level.camera_x,route.level.camera_y),Vector2(1280,720))
	var intersects:bool=screen.intersects(Rect2(Layout.ORIGIN+VIEW_ORIGIN,Vector2(VIEW_SIZE)))
	output.visible=enabled and intersects
	if not output.visible:
		view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	var pose:=Vector3(route.upper_travel,route.weight_travel,route.basket_y)
	if pose==_last_pose:return
	_last_pose=pose
	# The orthographic plate is independent of the game camera. Re-render only
	# when an actual mechanism moves; retained texture follows as a 2D sprite.
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
	_place(cart,route.trolley.position-Layout.ORIGIN+Vector2(28,48))
	_place(weight,route.weight.position-Layout.ORIGIN+Vector2(28,48))
	for wheel in cart.wheels:wheel.rotation.x=-route.upper_travel/8.5
	for wheel in weight.wheels:wheel.rotation.x=-route.weight_travel/8.5
	if left_pulley!=null:left_pulley.rotation.x=route.basket_y/25.0
