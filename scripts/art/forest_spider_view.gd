extends SubViewport
# Native skinned spider, black orthographic output, with terrain-aware foot pins.
const MODEL=preload("res://assets/art/polyfork/spider-v1/garden-orb-weaver-animated.glb")
const DISPLAY:=0.58
const CAMERA_SIZE:=5.8
const PIXELS:=640.0/CAMERA_SIZE*DISPLAY
var source:Node3D
var skeleton:Skeleton3D
var animation:AnimationPlayer
var camera:Camera3D
var legs:Array[Dictionary]=[]
var names:Dictionary={}
var current_clip:=""
var current_frame:=0
var blend_from:Array[Transform3D]=[]
var blend_age:=1.0
var last_facing:=0.0
var attachment:=Vector2.ZERO
var foot_contacts:Array[Dictionary]=[]
var maximum_contact_error:=0.0
var touchdown_count:=0
var age:=0.0
var phase_clock:=0.0
var last_cpu_usec:=0
var execution_from:=Vector2.ZERO
var execution_started:=false
var carrier_started:=false
var carrier_from:=Vector2.ZERO
var carrier_error:=0.0
var execution_error:=0.0
var last_state:=-1
func _ready()->void:
	size=Vector2i(1024,640)
	transparent_bg=true
	own_world_3d=true
	msaa_3d=Viewport.MSAA_4X
	render_target_update_mode=SubViewport.UPDATE_DISABLED
	source=MODEL.instantiate()
	add_child(source)
	var material_value:=StandardMaterial3D.new()
	material_value.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material_value.albedo_color=Color(0.003,0.003,0.003)
	material_value.cull_mode=BaseMaterial3D.CULL_DISABLED
	for mesh in source.find_children("*","MeshInstance3D",true,false):mesh.material_override=material_value
	skeleton=source.find_child("Skeleton3D",true,false) as Skeleton3D
	if skeleton==null:
		for node in source.find_children("*","Skeleton3D",true,false):skeleton=node;break
	assert(skeleton!=null,"Spider must retain its native skin")
	animation=source.find_child("AnimationPlayer",true,false)
	for clip in animation.get_animation_list():names[String(clip).get_file().to_lower()]=clip
	assert(names.has("run") and names.has("walk"),"Native Run and Walk clips are required")
	animation.play(names.run)
	animation.pause()
	var rig:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/polyfork/spider-v1/hunter-rig.json"))
	for item:Dictionary in rig.legs:
		var foot:Array=item.foot_local
		legs.append({"hip":skeleton.find_bone(item.hip),"knee":skeleton.find_bone(item.knee),"tip":skeleton.find_bone(item.tip),"foot":Vector3(foot[0],foot[1],foot[2]),"front":bool(item.front),"side":float(item.side),"number":int(item.number),"planted":false,"initialized":false,"anchor":0.0,"range":{}})
	for clip:String in ["walk","run"]:
		animation.play(names[clip]);animation.pause()
		var duration:float=animation.get_animation(names[clip]).length
		for leg:Dictionary in legs:leg.range[clip]=Vector2(INF,-INF)
		for i in 24:
			animation.seek(duration*float(i)/24.0,true)
			skeleton.force_update_all_bone_transforms()
			for leg:Dictionary in legs:
				var y:float=_foot(leg).y
				var limits:Vector2=leg.range[clip]
				leg.range[clip]=Vector2(minf(limits.x,y),maxf(limits.y,y))
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=CAMERA_SIZE
	camera.position=Vector3(12,1.25,1.8)
	add_child(camera)
	camera.look_at(Vector3(0,1.25,0))
	camera.current=true
func pivot()->Vector2:return camera.unproject_position(Vector3.ZERO)
func _foot(leg:Dictionary)->Vector3:
	return skeleton.get_bone_global_pose(int(leg.tip))*Vector3(leg.foot)
func _turn(bone:int,from:Vector3,to:Vector3)->void:
	if from.length_squared()<0.00001 or to.length_squared()<0.00001:return
	var delta:=Quaternion(from.normalized(),to.normalized())
	var global_q:=skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	var parent:=skeleton.get_bone_parent(bone)
	var parent_q:=skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent>=0 else Quaternion.IDENTITY
	var rest_q:=skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone,(rest_q.inverse()*parent_q.inverse()*delta*global_q).normalized())
	skeleton.force_update_all_bone_transforms()
func _solve(leg:Dictionary,target:Vector3)->void:
	var hip:int=leg.hip
	var knee:int=leg.knee
	var h:=skeleton.get_bone_global_pose(hip).origin
	var k:=skeleton.get_bone_global_pose(knee).origin
	var f:=_foot(leg)
	var upper:=h.distance_to(k)
	var lower:=k.distance_to(f)
	var direction:Vector3=(target-h).normalized()
	var distance:=clampf(h.distance_to(target),absf(upper-lower)+0.001,upper+lower-0.002)
	var a:float=(upper*upper-lower*lower+distance*distance)/(2.0*distance)
	var height:=sqrt(maxf(0,upper*upper-a*a))
	var pole:Vector3=k-h-direction*(k-h).dot(direction)
	if pole.length_squared()<0.00001:pole=direction.cross(Vector3.FORWARD)
	var next_knee:Vector3=h+direction*a+pole.normalized()*height
	_turn(hip,k-h,next_knee-h)
	var now_k:=skeleton.get_bone_global_pose(knee).origin
	_turn(knee,_foot(leg)-now_k,target-now_k)
func _surface(encounter,x:float)->float:
	var fallback:float=encounter.scene.ground_top(x)
	var ray:=PhysicsRayQueryParameters2D.create(Vector2(x,encounter.position.y-300),Vector2(x,encounter.position.y+300),1)
	var hit:Dictionary=encounter.scene.level.get_world_2d().direct_space_state.intersect_ray(ray)
	return float(hit.position.y) if not hit.is_empty() else fallback
func _touchdown(encounter,x:float,y:float)->void:
	touchdown_count+=1
	for pool in encounter.scene.pools:
		if x>pool.x_start and x<pool.x_end and y>pool.surface_y:
			pool.splash(x,210.0,8.0)
			return
	if touchdown_count%3==0:
		encounter.scene.level.art.emit_drag_dust([Vector2(x,y)],7.0)
func sync_pose(delta:float,encounter,active:bool)->void:
	render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active:
		foot_contacts.clear()
		for leg:Dictionary in legs:leg.initialized=false;leg.planted=false
		return
	var cpu_start:=Time.get_ticks_usec()
	age+=delta
	var airborne:bool=encounter.state in [encounter.State.DESCEND,encounter.State.ASCEND]
	var hunting:bool=encounter.state in [encounter.State.CHASE,encounter.State.STOP,encounter.State.LAND,encounter.State.CAUGHT,encounter.State.FRENZY]
	var executing:bool=encounter.state==encounter.State.CAUGHT and encounter.supported_execution()
	if not executing:execution_started=false
	if encounter.state!=encounter.State.CAUGHT:carrier_started=false
	var clip:String="run" if hunting else "walk"
	var rage:float=encounter.rage()
	var rate:float=1.65+rage*0.45 if hunting else (1.5 if airborne else 0.95)
	if clip!=current_clip or last_state!=encounter.state:
		blend_from.clear()
		for i in skeleton.get_bone_count():blend_from.append(skeleton.get_bone_pose(i))
		blend_age=0
		current_clip=clip
		last_state=encounter.state
		animation.play(names[clip]);animation.pause()
		for leg:Dictionary in legs:leg.planted=false;leg.initialized=false
	blend_age+=delta
	var duration:float=animation.get_animation(names[clip]).length
	var clock:float=encounter.motion_clock
	phase_clock+=delta*rate*(-1.0 if encounter.state==encounter.State.RETREAT else 1.0)
	var phase:float=duration*0.18 if executing else fposmod(phase_clock,duration)
	animation.seek(phase,true)
	current_frame=int(phase/duration*60)
	if blend_age<0.14 and blend_from.size()==skeleton.get_bone_count():
		var weight:=smoothstep(0,0.14,blend_age)
		for i in skeleton.get_bone_count():
			var desired:=skeleton.get_bone_pose(i)
			skeleton.set_bone_pose_position(i,blend_from[i].origin.lerp(desired.origin,weight))
			skeleton.set_bone_pose_rotation(i,blend_from[i].basis.get_rotation_quaternion().slerp(desired.basis.get_rotation_quaternion(),weight))
	# Forward recoil and abdomen twitch sharpen the Run's hunting posture.
	var hips:=skeleton.find_bone("Hips")
	var body:=skeleton.get_bone_pose_position(hips)
	if hunting:
		body.y-=0.12+rage*0.06
		body.z+=0.08*sin(clock*17.0)*(0.25+rage)
		if executing:body.z+=0.12*exp(-pow((encounter.time-encounter.impact_time())/0.10,2))
		skeleton.set_bone_pose_position(hips,body)
	if airborne:
		for leg:Dictionary in legs:
			var bone:int=leg.hip
			var q:=skeleton.get_bone_pose_rotation(bone)
			var kick:float=sin(clock*10.5+float(leg.number)*1.7+float(leg.side))*0.14
			skeleton.set_bone_pose_rotation(bone,q*Quaternion(Vector3.FORWARD,kick*float(leg.side)))
	skeleton.force_update_all_bone_transforms()
	var flip:float=-encounter.facing
	if last_facing!=encounter.facing:
		for leg:Dictionary in legs:leg.planted=false;leg.initialized=false
	last_facing=encounter.facing
	foot_contacts.clear()
	maximum_contact_error=0
	if not airborne:
		var right:=camera.global_basis.x
		for leg:Dictionary in legs:
			var raw:=_foot(leg)
			var limits:Vector2=leg.range[clip]
			var amount:=clampf((raw.y-limits.x)/maxf(limits.y-limits.x,0.08),0,1)
			if executing:amount=0.0
			var world_x:float=encounter.position.x+(camera.unproject_position(raw).x-pivot().x)*DISPLAY*flip
			var just_landed:=false
			if amount>0.40:leg.planted=false
			if amount<0.32 and not leg.planted:
				leg.planted=true
				leg.anchor=world_x
				just_landed=bool(leg.initialized)
			leg.initialized=true
			var x:float=leg.anchor if leg.planted else world_x
			# Never drag an anchored foot beyond the leg's reachable stride.
			if absf(x-world_x)>95:leg.anchor=world_x;x=world_x
			var lift:float=0.0 if leg.planted else pow(amount,1.1)*0.46
			if rage>0.1 and leg.front:
				var stab:float=maxf(0,sin(clock*13.0+float(leg.side)*1.6+float(leg.number)))
				lift+=stab*0.65*rage
				x+=encounter.facing*stab*24*rage
			if encounter.position.x>encounter.scene.Crevice.LEFT-500 and encounter.state!=encounter.State.CAUGHT and not encounter.log_hunt:
				x=minf(x,encounter.scene.Crevice.LEFT-16)
			var floor_y:float=encounter.log_surface(x) if encounter.log_hunt else _surface(encounter,x)
			var target:=raw+right*((x-world_x)/(PIXELS*flip))
			target.y=-(floor_y-encounter.position.y)/PIXELS+lift
			var reporting_log_tip:bool=encounter.log_attacking() and int(leg.number)==1 and float(leg.side)>0
			if reporting_log_tip:
				var strike:Vector2=encounter.log_tip(Vector2(world_x,encounter.position.y-raw.y*PIXELS))
				target=raw+right*((strike.x-world_x)/(PIXELS*flip))
				target.y=-(strike.y-encounter.position.y)/PIXELS
				leg.planted=false
			if executing and int(leg.number)==1 and (float(leg.side)<0 if encounter.execution_airborne else float(leg.side)>0):
				if not execution_started:
					execution_from=Vector2(world_x,encounter.position.y-raw.y*PIXELS)
					execution_started=true
				var stab_tip:Vector2=encounter.execution_tip(execution_from)
				target=raw+right*((stab_tip.x-world_x)/(PIXELS*flip))
				target.y=-(stab_tip.y-encounter.position.y)/PIXELS
				leg.planted=false
			var carrying:bool=encounter.state==encounter.State.CAUGHT and encounter.execution_airborne and int(leg.number)==1 and float(leg.side)>0
			if carrying:
				if not carrier_started:
					carrier_from=Vector2(world_x,encounter.position.y-raw.y*PIXELS)
					carrier_started=true
				var pin:Vector2=encounter.carrier_tip(carrier_from)
				target=raw+right*((pin.x-world_x)/(PIXELS*flip))
				target.y=-(pin.y-encounter.position.y)/PIXELS
				leg.planted=false
			_solve(leg,target)
			if just_landed and lift<0.08:_touchdown(encounter,x,floor_y)
			var actual:=_foot(leg)
			var actual_screen:Vector2=encounter.position+(camera.unproject_position(actual)-pivot())*Vector2(flip,1)*DISPLAY
			if reporting_log_tip:encounter.report_log_tip(actual_screen)
			if executing and int(leg.number)==1 and (float(leg.side)<0 if encounter.execution_airborne else float(leg.side)>0):
				execution_error=actual_screen.distance_to(encounter.execution_tip(execution_from))
			if carrying:carrier_error=actual_screen.distance_to(encounter.carrier_tip(carrier_from))
			var error:=absf(actual_screen.y-(floor_y-lift*PIXELS))
			# A cliff/roof can lie outside this leg's reach. Do not claim a
			# planted contact for an IK-clamped foot; release it for the next step.
			if leg.planted and error>4.0:
				leg.planted=false
				lift=maxf(lift,0.06)
			if leg.planted and lift<0.001:maximum_contact_error=maxf(maximum_contact_error,error)
			foot_contacts.append({"p":actual_screen,"floor":floor_y,"lift":lift,"planted":bool(leg.planted),"error":error,"front":bool(leg.front)})
	var abdomen:=skeleton.find_bone("Abdomen")
	var anchor:Vector3=skeleton.get_bone_global_pose(abdomen)*Vector3(0,0.64,-0.15)
	attachment=(camera.unproject_position(anchor)-pivot())*Vector2(flip,1)*DISPLAY

	last_cpu_usec=Time.get_ticks_usec()-cpu_start
