extends SceneTree
var tree
var view:SubViewport
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func capture(name:String)->Image:
 await process_frame
 await RenderingServer.frame_post_draw
 var picture:=view.get_texture().get_image()
 picture.save_png("res://artifacts/mine-descent-v8/twig-review/"+name+".png")
 return picture
func residue(image:Image)->int:
 var count:=0
 for x in range(25,145):
  for y in range(385,408):
   var p:Vector2=tree.to_global((Vector2(x,y)-tree.pivot)*tree.size_factor)
   if image.get_pixelv(Vector2i(p)).a>0.1:count+=1
 return count
func run()->void:
 view=SubViewport.new()
 view.size=Vector2i(1000,720)
 view.transparent_bg=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 tree=load("res://scripts/chapters/cliff_tree_platform.gd").new()
 view.add_child(tree)
 tree.build(2,Vector2(640,410))
 var before:=await capture("before")
 tree.touch_twigs(tree.branch.to_global(tree.twig_area.get_center()),Vector2(0,250))
 if not tree.twig_broken:failures.append("twig did not detach")
 for i in 85:tree.tick(1.0/60.0,false,false,0)
 var after:=await capture("after")
 print("LOW LEAF PIXELS before=",residue(before)," after=",residue(after))
 if residue(before)<10 or residue(after)>0:failures.append("low leaves remain floating")
 tree.reset()
 var restored:=await capture("restored")
 if before.get_data()!=restored.get_data():failures.append("reset did not restore original complete silhouette")
 print("TWIG RESIDUE ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
