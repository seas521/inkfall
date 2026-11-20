extends Node2D
# Two views of the same hollow cart: the passenger sits between the far wall
# and near wall. Wheel phase is distance/radius, never elapsed animation time.
const CART=preload("res://assets/art/polyfork/station-v1/mine-cart-94bd76.glb")
const HALF=preload("res://assets/shaders/mine_cart_half.gdshader")
const WHEEL_RADIUS:=0.25
const PIXELS_PER_METRE:=160.0/2.4*0.95
const ROLL_RADIUS:=WHEEL_RADIUS*PIXELS_PER_METRE
var front_view:SubViewport
var back_view:SubViewport
var front:Sprite2D
var back:Sprite2D
var models:Array[Node3D]=[]
var axles:Array[Node3D]=[]
var tubs:Array[Node3D]=[]
var tub_heights:Array[float]=[]
var last_heave:=INF
var materials:Array[ShaderMaterial]=[]
var wheel_mesh:Mesh
var rendered:=false
var wreck_amount:=0.0
var last_wreck:=-1.0
var last_phase:=INF
var last_tub:=INF
var last_front_phase:=INF
var render_updates:=0
var grip_outline:=PackedVector2Array()

func _notification(what:int)->void:
	if what==NOTIFICATION_VISIBILITY_CHANGED:
		# Cached viewport pixels are not valid after hidden ancestors prevented
		# a scheduled first draw. Re-entering the room needs a fresh frame.
		rendered=false

func _ready()->void:
	back_view=_view(false);front_view=_view(true)
	back=_sprite(back_view,3);front=_sprite(front_view,6)

func _view(near:bool)->SubViewport:
	var view:=SubViewport.new()
	view.size=Vector2i(512,320)
	view.transparent_bg=true;view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(view)
	var world:=Node3D.new();view.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.4;camera.position=Vector3(0,1.65,8)
	camera.look_at(Vector3(0,.45,0));camera.current=true
	var turn:=Node3D.new();turn.rotation.y=PI*.5;world.add_child(turn)
	var model:Node3D=CART.instantiate();turn.add_child(model);models.append(model)
	var body_material:=_material(near,.009 if near else .020)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=body_material
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tub:=_named(model,"tub");tub.position.y+=WHEEL_RADIUS-.124724
	if not near:
		# Project the actual tub, excluding wheels and handles. This silhouette
		# is shared by the rendering and the player's hand contact fitting.
		var points:=PackedVector2Array()
		for mesh in tub.find_children("*","MeshInstance3D",true,false)+([tub] if tub is MeshInstance3D else []):
			for surface in mesh.mesh.get_surface_count():
				var vertices:PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					points.append((camera.unproject_position(mesh.to_global(vertex))-Vector2(256,160))*.475+Vector2(0,-29.5))
		grip_outline=Geometry2D.convex_hull(points)
	tubs.append(tub);tub_heights.append(tub.position.y)
	_named(model,"frame-metal").position.y+=WHEEL_RADIUS-.124724
	for key in ["wheel-fl","wheel-fr","wheel-rl","wheel-rr"]:
		var axle:=_named(model,key);axle.position.y=WHEEL_RADIUS
		axle.position.z=signf(axle.position.z)*.33
		for child in axle.get_children():child.hide()
		# Only the two wheels on this half can reach its camera. Do not submit
		# another complete set just to discard every fragment in the shader.
		if near==(axle.position.x<0):_wheel(axle,near)
		axle.set_meta("front_axle",key in ["wheel-fl","wheel-fr"])
		axles.append(axle)
	return view

func _material(near:bool,tone:float)->ShaderMaterial:
	var ink:=ShaderMaterial.new();ink.shader=HALF
	ink.set_shader_parameter("near_half",near);ink.set_shader_parameter("iron_tone",tone)
	materials.append(ink);return ink

func _mesh(parent:Node3D,shape:Mesh,ink:Material)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=shape;node.material_override=ink
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node);return node

func _wheel(axle:Node3D,near:bool)->void:
	if wheel_mesh==null:
		var merged:=SurfaceTool.new();merged.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rim:=TorusMesh.new();rim.inner_radius=.194;rim.outer_radius=WHEEL_RADIUS
		rim.rings=32;rim.ring_segments=12
		merged.append_from(rim,0,Transform3D(Basis(Vector3.FORWARD,PI*.5),Vector3.ZERO))
		var hub:=CylinderMesh.new();hub.top_radius=.055;hub.bottom_radius=.055;hub.height=.115;hub.radial_segments=16
		merged.append_from(hub,0,Transform3D(Basis(Vector3.FORWARD,PI*.5),Vector3.ZERO))
		for i in 5:
			var angle:=TAU*float(i)/5.0+.12
			var spoke:=BoxMesh.new();spoke.size=Vector3(.067,.17,.03)
			merged.append_from(spoke,0,Transform3D(Basis(Vector3.RIGHT,angle),Vector3(0,cos(angle)*.127,sin(angle)*.127)))
		wheel_mesh=merged.commit()
	_mesh(axle,wheel_mesh,_material(near,.019 if near else .014))

func _sprite(view:SubViewport,depth:int)->Sprite2D:
	var sprite:=Sprite2D.new();sprite.texture=view.get_texture()
	sprite.scale=Vector2.ONE*.475;sprite.z_index=depth
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var ink:=ShaderMaterial.new();ink.shader=preload("res://assets/shaders/mine_cart_rim.gdshader")
	sprite.material=ink;add_child(sprite);return sprite

func _named(node:Node,key:String)->Node3D:
	if String(node.name).to_lower()==key:return node as Node3D
	for child in node.get_children():
		var found:=_named(child,key)
		if found!=null:return found
	return null

func grip_surface(at:Vector2,motion:Vector3,hand_y:float,side:float)->Vector2:
	# Intersect the pitched silhouette at palm height, rather than using a
	# fixed centre-to-player distance on both level track and slopes.
	var edge:float=-INF if side>0 else INF
	for i in maxi(0,grip_outline.size()-1):
		var a:Vector2=at+(grip_outline[i]+Vector2(0,motion.y)).rotated(motion.x)
		var b:Vector2=at+(grip_outline[i+1]+Vector2(0,motion.y)).rotated(motion.x)
		if absf(b.y-a.y)<.0001 or hand_y<minf(a.y,b.y) or hand_y>maxf(a.y,b.y):continue
		var x:float=lerpf(a.x,b.x,(hand_y-a.y)/(b.y-a.y))
		edge=maxf(edge,x) if side>0 else minf(edge,x)
	return Vector2(edge-side,hand_y) if is_finite(edge) else Vector2(at.x+side*29,hand_y)

func set_wreck(amount:float)->void:
	wreck_amount=clampf(amount,0,1)
func sync_cart(at:Vector2,rotation_angle:float,heave:float,tub_pitch:float,distance:float,light:float,draw_cart:bool,front_distance:float=INF,axles_on_rail:bool=false)->void:
	for sprite in [front,back]:
		sprite.visible=draw_cart
		sprite.position=at+Vector2(0,-29.5+(0.0 if axles_on_rail else heave)).rotated(rotation_angle)
		sprite.rotation=rotation_angle
		sprite.material.set_shader_parameter("illumination",light)
	for material in materials:material.set_shader_parameter("wreck_amount",wreck_amount)
	for axle in axles:axle.visible=not (wreck_amount>.45 and axle.get_meta("front_axle",false))
	# Original wheel axis is local x. The body turns 90 degrees into side view.
	for wheel in axles:wheel.rotation.x=(front_distance if wheel.get_meta("front_axle",false) and is_finite(front_distance) else distance)/ROLL_RADIUS
	var sprung_heave:float=heave if axles_on_rail else 0.0
	for i in tubs.size():
		tubs[i].rotation.x=-tub_pitch
		tubs[i].position.y=tub_heights[i]-sprung_heave/PIXELS_PER_METRE
	# Lamp shading is 2D; it does not invalidate the 3D alpha. A settled cart
	# therefore reuses both textures while the pendant continues swinging.
	var phase:=distance/ROLL_RADIUS
	var front_phase:=front_distance/ROLL_RADIUS if is_finite(front_distance) else phase
	var dirty:bool=not rendered or absf(sprung_heave-last_heave)>.0001 or absf(wreck_amount-last_wreck)>.0001 or absf(phase-last_phase)>.00001 or absf(front_phase-last_front_phase)>.00001 or absf(tub_pitch-last_tub)>.00001
	var can_render:=draw_cart and is_visible_in_tree()
	if not can_render:rendered=false
	for view in [front_view,back_view]:
		# UPDATE_ONCE disables itself after the draw. A second physics tick
		# before that draw must not cancel the pending texture render.
		if can_render and dirty:view.render_target_update_mode=SubViewport.UPDATE_ONCE
		elif not can_render:view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if can_render and dirty:
		rendered=true;last_heave=sprung_heave;last_wreck=wreck_amount;last_phase=phase;last_tub=tub_pitch;last_front_phase=front_phase;render_updates+=1
