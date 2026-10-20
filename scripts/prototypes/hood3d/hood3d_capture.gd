extends SceneTree

# Renders the simplified 3D hooded boy as a flat black side silhouette.  POSE = rest | walk | scared | fall
const MODEL := "res://assets/art/prototypes/hood3d/hood_boy.glb"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.745, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var world := WorldEnvironment.new()
	world.environment = env
	root.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.2
	camera.position = Vector3(0.0, 0.8, 6.0)
	root.add_child(camera)
	var holder := Node3D.new()
	root.add_child(holder)
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	holder.add_child(model)
	var skeleton: Skeleton3D = _find(model, "Skeleton3D")
	if skeleton == null:
		push_error("no skeleton in the model")
		quit(1)
		return
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.012, 0.013, 0.013)
	for child in _all(model):
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = ink
	var bones: PackedStringArray = []
	for i in range(skeleton.get_bone_count()):
		bones.append(skeleton.get_bone_name(i))
	print("bones: ", bones)
	var attach := BoneAttachment3D.new()
	attach.bone_name = "mixamorig_Head"
	skeleton.add_child(attach)
	var eye := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06
	eye.mesh = sphere
	eye.scale = Vector3(0.6, 1.0, 0.45)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.62, 0.12)
	eye.material_override = glow
	attach.add_child(eye)
	for i in range(4):
		await process_frame
	eye.global_position = Vector3(0.20, 1.22, 0.17)
	_pose(skeleton, OS.get_environment("POSE"))
	for i in range(4):
		await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/hood3d"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/hood3d/%s.png" % OS.get_environment("POSE")))
	quit()

func _find(node: Node, type: String) -> Node:
	if node.get_class() == type:
		return node
	for c in node.get_children():
		var r := _find(c, type)
		if r:
			return r
	return null

func _all(node: Node) -> Array:
	var out := [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out

# Absolute screen-plane angle (degrees, counter-clockwise on screen, side view) from the rest pose.
func _swing(skeleton: Skeleton3D, bone_name: String, degrees: float) -> void:
	var i := skeleton.find_bone(bone_name)
	var parent := skeleton.get_bone_parent(i)
	var rest_global := skeleton.get_bone_global_rest(i)
	var wanted := Basis(Vector3(0, 0, 1), deg_to_rad(degrees)) * rest_global.basis
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(i, (parent_basis.inverse() * wanted).get_rotation_quaternion())

func _pose(skeleton: Skeleton3D, which: String) -> void:
	match which:
		"walk":
			# Side-view stride, angles measured on screen (counter-clockwise positive; the figure faces right).
			_swing(skeleton, "mixamorig_Spine", -5.0)
			_swing(skeleton, "mixamorig_LeftUpLeg", 28.0)
			_swing(skeleton, "mixamorig_LeftLeg", 8.0)
			_swing(skeleton, "mixamorig_RightUpLeg", -24.0)
			_swing(skeleton, "mixamorig_RightLeg", -45.0)
			_swing(skeleton, "mixamorig_LeftArm", -25.0)
			_swing(skeleton, "mixamorig_RightArm", 20.0)
		"scared":
			_swing(skeleton, "mixamorig_Spine", 12.0)
			_swing(skeleton, "mixamorig_Spine1", 10.0)
			_swing(skeleton, "mixamorig_Head", 8.0)
			_swing(skeleton, "mixamorig_LeftArm", -150.0)
			_swing(skeleton, "mixamorig_RightArm", -120.0)
			_swing(skeleton, "mixamorig_LeftUpLeg", 20.0)
			_swing(skeleton, "mixamorig_RightUpLeg", -10.0)
			_swing(skeleton, "mixamorig_RightLeg", -50.0)
