extends SceneTree
var level
var route
var label:="before"
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func snap(name:String)->void:
 await frames(6)
 await RenderingServer.frame_post_draw
 var picture:=root.get_texture().get_image()
 picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 picture.save_png("res://artifacts/cliff-film-v1/"+label+"-"+name+".png")
func run()->void:
 if OS.get_cmdline_user_args().size()>0:label=OS.get_cmdline_user_args()[0]
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
 root.add_child(level)
 await frames(8)
 print("FILM LAYERS ",get_nodes_in_group("film_look").size())
 await snap("forest")
 level.debug_enter_rope_ladder(false)
 await frames(15)
 await snap("ladder")
 level.enter_root_cliff_test()
 route=level.bridge_to_c
 await snap("landing")
 route.checkpoint_step=0
 route.restore_checkpoint()
 await frames(12)
 await snap("first-tree")
 route.checkpoint_step=2
 route.restore_checkpoint()
 await frames(12)
 await snap("trees")
 route.trees[2].touch_twigs(route.trees[2].branch.to_global(route.trees[2].twig_area.get_center()),Vector2(0,250))
 await frames(85)
 await snap("broken-twig")
 quit()
