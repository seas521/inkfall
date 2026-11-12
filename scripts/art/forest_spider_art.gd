extends Node2D
# Native Run/Walk with pointed geometry and eight independently planted feet.
const SpiderView=preload("res://scripts/art/forest_spider_view.gd")
const BLOOD_SHADER=preload("res://assets/shaders/forest_spider_blood.gdshader")
const DISPLAY:=SpiderView.DISPLAY
var encounter
var sprite:Sprite2D
var silk:Line2D
var view:SubViewport
var blood:ColorRect
var fluid_blobs:=PackedVector4Array()
var fluid_axes:=PackedVector2Array()
var fluid_material:ShaderMaterial
var rig:Node2D
var current_clip:=""
var current_frame:=-1
func _ready()->void:
	z_index=4
	view=SpiderView.new()
	add_child(view)
	silk=Line2D.new()
	silk.width=1.0
	silk.default_color=Color(0.12,0.12,0.12,0.7)
	silk.antialiased=true
	add_child(silk)
	rig=Node2D.new()
	add_child(rig)
	blood=ColorRect.new()
	blood.z_index=3
	blood.size=Vector2(440,280)
	blood.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fluid_material=ShaderMaterial.new()
	fluid_material.shader=BLOOD_SHADER
	blood.material=fluid_material
	add_child(blood)
	sprite=Sprite2D.new()
	sprite.centered=false
	sprite.texture=view.get_texture()
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	rig.add_child(sprite)
	hide()
func sync(delta:float,camera_x:float,camera_y:float,active:bool)->void:
	visible=active and encounter!=null and encounter.is_visible()
	var on_screen:bool=visible and Rect2(camera_x-500,camera_y-600,2280,1720).has_point(encounter.position)
	view.sync_pose(delta,encounter,on_screen)
	if not visible:return
	z_index=6 if encounter.state==encounter.State.CAUGHT else 4
	_sync_blood()
	current_clip=view.current_clip
	current_frame=view.current_frame
	sprite.scale=Vector2(-encounter.facing,1)*DISPLAY
	sprite.position=-view.pivot()*sprite.scale
	var suspended:bool=encounter.state in [encounter.State.DESCEND,encounter.State.ASCEND]
	rig.rotation=sin(encounter.motion_clock*3.1)*0.045 if suspended else 0.0
	# Suspend around the abdomen attachment, never around an invisible foot.
	rig.position=encounter.position+view.attachment-view.attachment.rotated(rig.rotation)
	silk.visible=encounter.silk_visible()
	if silk.visible:
		var top:Vector2=encounter.silk_top()
		var end:Vector2=rig.position+view.attachment.rotated(rig.rotation)
		silk.points=PackedVector2Array([top,top.lerp(end,0.5)+Vector2(sin(encounter.motion_clock*1.2)*1.4,0),end])

func _blob(at:Vector2,rx:float,ry:float,axis:=Vector2.RIGHT)->void:
	if fluid_blobs.size()>=96 or rx<0.2 or ry<0.2:return
	var local:=at-blood.position
	fluid_blobs.append(Vector4(local.x,local.y,rx,ry))
	fluid_axes.append(axis.normalized())
func _sync_blood()->void:
	blood.visible=encounter.stabbed
	if not blood.visible:return
	blood.position=encounter.execution_target-Vector2(220,220)
	fluid_blobs.clear()
	fluid_axes.clear()
	var age:float=encounter.time-encounter.impact_time()
	for jet:Dictionary in encounter.blood_jets:
		var head:float=age-float(jet.delay)
		if head<=0 or head>0.65:continue
		var tail:float=maxf(0,head-float(jet.emit))
		for i in 14:
			var u:=float(i)/13.0
			var t:=lerpf(tail,head,u)
			var v:Vector2=jet.v
			var at:Vector2=encounter.execution_target+v*t+Vector2(0,340*t*t)
			var velocity:Vector2=v+Vector2(0,680*t)
			var thickness:float=float(jet.width)*(0.7+0.22*sin(u*8+float(jet.phase)))*(1.0-smoothstep(0.25,0.65,head))
			_blob(at,thickness*(1.2 if i==13 else 1.0),thickness,velocity.normalized())
	for drop:Dictionary in encounter.blood:
		if drop.age<0:continue
		var radius:float=float(drop.size)*(1.0-smoothstep(0.8,1.0,float(drop.age)/float(drop.life)))
		if drop.landed:
			_blob(drop.p,radius*(1.6+smoothstep(0,0.20,drop.age)),radius*0.45)
		else:
			var velocity:Vector2=drop.v
			_blob(drop.p,radius*(1.0+minf(0.65,velocity.length()/600)),radius,velocity.normalized())
	# A thin viscous strand stretches during withdrawal, then breaks.
	if age>0.32 and age<0.47:
		var tip:Vector2=encounter.execution_tip(view.execution_from)
		for i in 7:
			var u:=float(i)/6.0
			var at:Vector2=encounter.execution_target.lerp(tip,u)
			at.x+=sin(u*PI)*3.0
			_blob(at,1.1*(1.0-smoothstep(0.40,0.47,age)),1.2)
	var count:=fluid_blobs.size()
	fluid_blobs.resize(96)
	fluid_axes.resize(96)
	fluid_material.set_shader_parameter("blob_count",count)
	fluid_material.set_shader_parameter("blobs",fluid_blobs)
	fluid_material.set_shader_parameter("axes",fluid_axes)
