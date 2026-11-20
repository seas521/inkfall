extends SceneTree
var level
var route
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func snap(name:String)->void:
 await RenderingServer.frame_post_draw
 var picture:Image=root.get_texture().get_image()
 picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 picture.save_png("res://artifacts/mine-descent-v4/review/"+name+".png")
func check(ok:bool,message:String)->void:
 if not ok:failures.append(message);push_error(message)
func run()->void:
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
 root.add_child(level)
 preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 level.enter_root_cliff_test()
 route=level.bridge_to_c
 route.checkpoint_step=route.MOUTH_STEP
 route.restore_checkpoint()
 await frames(8)
 var tree=route.trees[1]
 level.set_physics_process(false)
 level.actor.hide()
 level.camera_x=-4050
 level.camera_y=-3840
 level.camera.position=Vector2(-3410,-3480)
 var main_sprite=tree.get_child(1)
 var branch_sprite=tree.branch.get_child(0)
 check(main_sprite.material.get_shader_parameter("cut_count")==tree.LEFT_BREAK_OUTLINE.size(),"main tree uses complete bough cutout")
 check(branch_sprite.material.get_shader_parameter("cut_outline")==main_sprite.material.get_shader_parameter("cut_outline"),"leaves and trunk use complementary masks")
 await snap("branch-before")
 # Apply the same sustained player load as gameplay; isolate it from player death/reset.
 for i in 55:tree.tick(1.0/60.0,true,false,0)
 await snap("branch-loaded")
 for i in 85:tree.tick(1.0/60.0,true,false,0)
 check(tree.broken and tree.body.collision_layer==0,"loaded bough detaches with its collision")
 await frames(8)
 await snap("branch-falling")
 for i in 55:tree.tick(1.0/60.0,false,false,0)
 await frames(2)
 await snap("branch-after")
 check(tree.branch.position.y>200,"whole bough has fallen clear of the tree")
 tree.reset()
 check(not tree.broken and tree.body.collision_layer==1 and tree.branch.position==tree.branch_home,"checkpoint restores the complete branch")
 await frames(4)
 await snap("branch-restored")
 print("BRANCH BREAK ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
