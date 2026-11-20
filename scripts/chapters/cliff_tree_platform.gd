extends Node2D

# Each rooted tree owns a separate detachable bough and its physical surface.
# Art, contact surface and handhold all rotate about the same attachment.
const ATLAS=preload("res://assets/art/descent/mine-v4/rooted-trees.png")
const DAMAGED_ATLAS=preload("res://assets/art/descent/mine-v6/fractured-tree-atlas.png")
const INK=preload("res://assets/shaders/cliff_tree_ink.gdshader")
var size_factor:=0.65
var branch_home:=Vector2.ZERO
var damage_materials:Array[ShaderMaterial]=[]
var branch:Node2D
var body:AnimatableBody2D
var surface:CollisionPolygon2D
var top:=PackedVector2Array()
var pivot:=Vector2.ZERO
var angle:=0.0
var angular_velocity:=0.0
var load_time:=0.0
var broken:=false
var fall_velocity:=Vector2.ZERO
var fragile:=false
var side:=1.0
var index:=0
var warning_stage:=0
var warning_pulse:=false
var creak:AudioStreamPlayer
var committed:=false
var twig:Node2D
var twig_home:=Vector2.ZERO
var twig_area:=Rect2()
var twig_broken:=false
var twig_velocity:=Vector2.ZERO
var twig_pulse:=false
const BREAK_DELAY:=0.14
var stable_top:=PackedVector2Array()
var stable_body:StaticBody2D
const FRACTURE_X:=510.0
# Follow the underside of the complete left leaf spray, then meet its stem
# where it joins solid wood. A horizontal crop left low leaves floating and
# also sliced through a separate upright shoot near the right-hand root.
const LAST_TWIG_OUTLINE:=[Vector2(0,270),Vector2(320,270),Vector2(320,380),Vector2(220,378),Vector2(205,405),Vector2(155,412),Vector2(0,412)]
const LEFT_BREAK_OUTLINE:=[Vector2(503,340),Vector2(724,340),Vector2(724,620),Vector2(507,620),Vector2(512,550),Vector2(508,540),Vector2(512,530),Vector2(507,515),Vector2(504,495)]
# The entire left-growing bough, including its attached leaf sprays. The only
# boundary crossing opaque wood is the irregular fracture at the trunk joint.
const BREAK_OUTLINE:=[
 Vector2(0,270),Vector2(280,270),Vector2(335,320),Vector2(380,350),
 Vector2(448,370),Vector2(479,388),Vector2(467,400),Vector2(489,413),
 Vector2(477,425),Vector2(491,439),Vector2(475,454),Vector2(445,469),
 Vector2(350,500),Vector2(0,520)]

func build(which:int,at:Vector2)->void:
	index=which
	size_factor=0.75 if which==1 else 0.65
	position=at
	fragile=which==1
	side=1.0 if which==1 else -1.0
	var starts:=[0,724,1448]
	var pivots:=[Vector2(525,510),Vector2(255,525),Vector2(485,420)]
	var cuts:=[Rect2(285,467,240,98),Rect2(260,466,320,112),Rect2(125,370,360,112)]
	var ranges:=[Vector3(312,505,475),Vector3(290,540,480),Vector3(166,465,385)]
	pivot=pivots[which]
	var cut:Rect2=cuts[which]
	var global_cut:=Rect2(cut.position+Vector2(starts[which],0),cut.size)
	branch=Node2D.new()
	add_child(branch)
	for part in 2:
		var sprite:=Sprite2D.new()
		sprite.texture=DAMAGED_ATLAS if fragile else ATLAS
		sprite.region_enabled=true
		sprite.region_rect=Rect2(starts[which],0,724,724)
		sprite.region_filter_clip_enabled=true
		sprite.centered=false
		sprite.position=-pivot*size_factor
		sprite.scale=Vector2.ONE*size_factor
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var mat:=ShaderMaterial.new()
		mat.shader=INK
		mat.set_shader_parameter("branch",part==1)
		if fragile:
			mat.set_shader_parameter("damaged",true)
			damage_materials.append(mat)
		mat.set_shader_parameter("cut_rect",Vector4(global_cut.position.x/2172.0,global_cut.position.y/724.0,global_cut.end.x/2172.0,global_cut.end.y/724.0))
		if which==1 or which==2:
			var shape_points:Array=LEFT_BREAK_OUTLINE if which==1 else BREAK_OUTLINE
			var outline:=PackedVector2Array()
			for point in shape_points:outline.append((point+Vector2(starts[which],0))/Vector2(2172,724))
			mat.set_shader_parameter("cut_count",outline.size())
			outline.resize(24)
			mat.set_shader_parameter("cut_outline",outline)
		sprite.material=mat
		(branch if part==1 else self).add_child(sprite)
	if which>0:
		var twig_source:=Rect2(365,340,359,145) if which==1 else Rect2(0,270,320,142)
		twig_area=Rect2((twig_source.position-pivot)*size_factor,twig_source.size*size_factor)
		var global_twig:=Rect2(twig_source.position+Vector2(starts[which],0),twig_source.size)
		twig=Node2D.new()
		branch.add_child(twig)
		var source_sprite:Sprite2D=branch.get_child(0)
		var loose:=Sprite2D.new()
		loose.texture=source_sprite.texture
		loose.region_enabled=true
		loose.region_rect=source_sprite.region_rect
		loose.region_filter_clip_enabled=true
		loose.centered=false
		loose.position=source_sprite.position
		loose.scale=source_sprite.scale
		loose.texture_filter=source_sprite.texture_filter
		loose.material=source_sprite.material.duplicate()
		var rect_uv:=Vector4(global_twig.position.x/2172.0,global_twig.position.y/724.0,global_twig.end.x/2172.0,global_twig.end.y/724.0)
		for sprite in [source_sprite,get_child(1),loose]:
			sprite.material.set_shader_parameter("split_twig",true)
			sprite.material.set_shader_parameter("twig_rect",rect_uv)
			if which==2:
				var twig_outline:=PackedVector2Array()
				for point in LAST_TWIG_OUTLINE:twig_outline.append((point+Vector2(starts[which],0))/Vector2(2172,724))
				sprite.material.set_shader_parameter("twig_count",twig_outline.size())
				twig_outline.resize(16)
				sprite.material.set_shader_parameter("twig_outline",twig_outline)
		loose.material.set_shader_parameter("twig_only",true)
		twig.add_child(loose)
	# The fractured tree has its own silhouette. Sampling the old intact atlas
	# made invisible bumps and put the launch surface above the visible wood.
	var image:Image=(DAMAGED_ATLAS if fragile else ATLAS).get_image()
	if image.is_compressed():image.decompress()
	var scan:Vector3=ranges[which]
	for i in 17:
		var x:=int(lerpf(scan.x,scan.y,float(i)/16.0))
		var y:=int(scan.z)+20
		for row in range(int(scan.z),int(cut.end.y)-10):
			if (image.get_pixel(starts[which]+x,row).a>0.9 and image.get_pixel(starts[which]+x,row+8).a>0.9) if which==0 else _thick_wood(image,starts[which]+x,row):
				y=row
				break
		top.append((Vector2(x,y)-pivot)*size_factor)
	if which==2:
		# The last bough continues into the mine approach. Its old final
		# samples climbed the solid trunk silhouette and formed a hidden wall.
		# Keep the visible landing/wood surface; the rooted tail is supported
		# by the continuous entrance descent owned by the route.
		top.resize(14)
	body=AnimatableBody2D.new()
	body.sync_to_physics=false
	body.collision_layer=1
	body.collision_mask=0
	body.set_meta("cliff_handhold",true)
	body.set_meta("cliff_handhold_step",which)
	branch.add_child(body)
	surface=CollisionPolygon2D.new()
	var polygon:=top.duplicate()
	polygon.append(top[-1]+Vector2(0,22))
	polygon.append(top[0]+Vector2(0,22))
	surface.polygon=polygon
	surface.one_way_collision=true
	body.add_child(surface)
	creak=AudioStreamPlayer.new()
	creak.stream=preload("res://assets/audio/level01/tree_creak_03.mp3")
	creak.volume_db=-21
	add_child(creak)
	if fragile:
		# Move the rotation hinge to the surviving fibers, preserving every sprite
		# and collision point in world space before the first load.
		branch_home=(Vector2(FRACTURE_X,542)-pivot)*size_factor
		branch.position=branch_home
		for child in branch.get_children():
			if child is Node2D:child.position-=branch_home
		for i in top.size():top[i]-=branch_home
		twig_area.position-=branch_home
		twig_home=twig.position
		var fixed:=PackedVector2Array()
		var loose_top:=PackedVector2Array()
		for i in top.size():
			var point:=top[i]
			if i>0 and top[i-1].x<0 and point.x>=0:
				var crossing:=top[i-1].lerp(point,inverse_lerp(top[i-1].x,point.x,0))
				fixed.append(crossing+branch_home)
				loose_top.append(crossing)
			if point.x<0:fixed.append(point+branch_home)
			else:loose_top.append(point)
		stable_top=fixed
		top=loose_top
		var loose_polygon:=top.duplicate()
		loose_polygon.append(top[-1]+Vector2(0,22))
		loose_polygon.append(top[0]+Vector2(0,22))
		body.position=Vector2.ZERO
		surface.polygon=loose_polygon
		stable_body=StaticBody2D.new()
		stable_body.collision_layer=1
		add_child(stable_body)
		var stable_shape:=CollisionPolygon2D.new()
		var stable_polygon:=stable_top.duplicate()
		stable_polygon.append(stable_top[-1]+Vector2(0,22))
		stable_polygon.append(stable_top[0]+Vector2(0,22))
		stable_shape.polygon=stable_polygon
		stable_shape.one_way_collision=true
		stable_body.add_child(stable_shape)

func _thick_wood(image:Image,x:int,y:int)->bool:
	# A twig or separated leaf cluster must not become a standing platform.
	for dy in range(25):
		if image.get_pixel(x,y+dy).a<0.85:return false
	return true

func world_top()->PackedVector2Array:
	var result:=PackedVector2Array()
	for point in stable_top:result.append(to_global(point))
	if not broken:
		for point in top:result.append(branch.global_transform*point)
	return result

func dangerous(feet:Vector2)->bool:
	return fragile and not broken and branch.to_local(feet).x>=0.0

func touch_twigs(feet:Vector2,velocity:Vector2)->void:
	if twig==null or twig_broken or broken or velocity.y<10:return
	var local:=branch.to_local(feet)
	if twig_area.grow(8).has_point(local):
		twig_broken=true
		twig_pulse=true
		twig_velocity=Vector2(velocity.x*0.25,maxf(40,velocity.y*0.3))
		creak.pitch_scale=1.55
		creak.volume_db=-24
		creak.play()

func tick(delta:float,loaded:bool,gripped:bool,landing_speed:float)->void:
	if twig_broken:
		twig_velocity.y+=1500*delta
		twig.position+=twig_velocity*delta
		twig.rotation+=side*0.5*delta
		twig.modulate.a=maxf(0,1.0-(twig.position.y-twig_home.y)/650.0)
	warning_pulse=false
	for material in damage_materials:material.set_shader_parameter("stress",clampf(load_time/BREAK_DELAY,0,1))
	if broken:
		fall_velocity.y+=1500*delta
		branch.position+=fall_velocity*delta
		branch.rotation+=side*1.8*delta
		return
	if landing_speed>0:angular_velocity+=side*minf(landing_speed/650.0,1.0)*0.12
	var target:=side*0.025 if loaded else 0.0
	if gripped:target=side*0.012
	if fragile and loaded:committed=true
	if committed:load_time+=delta
	else:load_time=maxf(0.0,load_time+delta if loaded else load_time-delta*0.3)
	var stage:=0
	if fragile:
		if load_time>0.015:stage=1
		if load_time>0.06:stage=2
		if load_time>0.10:stage=3
	if stage>warning_stage:
		warning_stage=stage
		warning_pulse=true
		creak.pitch_scale=0.88+stage*0.08
		creak.volume_db=-23+stage*2
		creak.play()
	if fragile and load_time>0.5:
		target+=side*minf((load_time-0.5)*0.022,0.045)
		angular_velocity+=sin(load_time*35.0)*delta*0.04
	angular_velocity+=((target-angle)*35.0-angular_velocity*8.0)*delta
	angle+=angular_velocity*delta
	branch.rotation=angle
	# Plenty of time to complete the existing climb animation before failure.
	if fragile and committed and not gripped and load_time>BREAK_DELAY:
		broken=true
		body.collision_layer=0
		fall_velocity=Vector2(side*28,25)

func reset()->void:
	twig_broken=false
	twig_pulse=false
	twig_velocity=Vector2.ZERO
	if twig!=null:
		twig.position=twig_home
		twig.rotation=0
		twig.modulate.a=1
	for material in damage_materials:material.set_shader_parameter("stress",0.0)
	angle=0
	angular_velocity=0
	load_time=0
	warning_stage=0
	warning_pulse=false
	committed=false
	if creak!=null:creak.stop()
	broken=false
	fall_velocity=Vector2.ZERO
	branch.position=branch_home
	branch.rotation=0
	body.collision_layer=1
