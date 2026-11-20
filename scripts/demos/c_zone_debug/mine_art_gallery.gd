extends Node2D

const Chamber=preload("res://scripts/chapters/mine_chamber_art.gd")
var level
var camera:Camera2D
var view_x:=-2880.0
var ready_for_review:=false
var extensions:Array[Node2D]=[]
var rails:Node2D

func _ready()->void:
	level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
	add_child(level)
	for i in 8:await get_tree().physics_frame
	level.enter_root_cliff_test()
	level.bridge_to_c.checkpoint_step=3
	level.bridge_to_c.restore_checkpoint()
	for i in 12:await get_tree().physics_frame
	level.process_mode=Node.PROCESS_MODE_DISABLED
	level.bridge_to_c.art.chamber.process_mode=Node.PROCESS_MODE_ALWAYS
	level.camera.enabled=false
	# Keep the accepted entrance in its real cliff context. Only the art preview
	# extends beyond the live doorway stop; it does not turn on archived gameplay.
	for i in [1,2]:
		var chamber:=Chamber.new();add_child(chamber)
		chamber.build(i,-1974.0+(i-1)*1086.0,1086.0,preview_floor)
		extensions.append(chamber)
	rails=Node2D.new();rails.z_index=4;add_child(rails);rails.draw.connect(_draw_rails)
	camera=Camera2D.new();add_child(camera);camera.make_current()
	ready_for_review=true
	set_view(view_x)
	queue_redraw()

func preview_floor(x:float)->float:
	return -3170.0+(x+1974.0)*0.07

func set_view(x:float)->void:
	view_x=clampf(x,-2920.0,-260.0)
	var ground:float=level.bridge_to_c.mine_floor_y(view_x) if view_x< -1974 else preview_floor(view_x)
	camera.position=Vector2(view_x,ground-100)
	camera.reset_smoothing()
	camera.force_update_scroll()
	# Screen-space forest dressing belongs to the live entry, not the gallery.
	level.art.visible=view_x< -2000
	level.bridge_to_c.art.cart_sprite.visible=view_x< -2000

func _process(delta:float)->void:
	if not ready_for_review:return
	rails.queue_redraw()
	level.bridge_to_c.art.cart_sprite.material.set_shader_parameter("illumination",level.bridge_to_c.art.chamber.light_at(level.bridge_to_c.MINE_CART_X))
	var axis:=Input.get_axis("move_left","move_right")
	if axis!=0:set_view(view_x+axis*420*delta)
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().set_meta(&"inkfall_debug_return",12)
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _draw_rails()->void:
	for i in 112:
		var x:float=-1974+i*19.0
		var y:=preview_floor(x)
		var glow:=0.035
		for chamber in extensions:glow=maxf(glow,0.035+chamber.light_at(x)*0.17)
		rails.draw_line(Vector2(x,y+2),Vector2(x+11,y+5),Color(0.014,0.014,0.014),3.5,true)
		rails.draw_line(Vector2(x,y-1),Vector2(x+19,preview_floor(x+19)-1),Color(glow,glow,glow),1.7,true)
		rails.draw_line(Vector2(x,y+4),Vector2(x+19,preview_floor(x+19)+4),Color(glow*0.5,glow*0.5,glow*0.5),1.8,true)
