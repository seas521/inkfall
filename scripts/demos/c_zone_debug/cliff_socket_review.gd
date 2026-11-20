extends SceneTree
var tree
var view:SubViewport
func _initialize()->void:call_deferred("run")
func capture(name:String)->Image:
 await process_frame
 await RenderingServer.frame_post_draw
 var picture:=view.get_texture().get_image()
 picture.save_png("res://artifacts/cliff-film-v1/"+name+".png")
 return picture
func run()->void:
 view=SubViewport.new()
 view.size=Vector2i(1000,720)
 view.transparent_bg=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 tree=load("res://scripts/chapters/cliff_tree_platform.gd").new()
 view.add_child(tree)
 tree.build(0,Vector2(640,410))
 var baseline:=await capture("socket-rest")
 var leaks:=0
 var tested:=0
 for angle in [-0.035,0.035]:
  tree.branch.rotation=angle
  var loaded:=await capture("socket-"+str(angle))
  for x in range(510,525):
   for y in range(490,530):
    var p:=Vector2i(tree.to_global((Vector2(x,y)-tree.pivot)*tree.size_factor))
    if baseline.get_pixelv(p).a>0.99:
     tested+=1
     if loaded.get_pixelv(p).a<0.95:leaks+=1
 print("SOCKET ","PASS" if leaks==0 and tested>0 else "FAIL"," tested=",tested," leaks=",leaks)
 quit(0 if leaks==0 and tested>0 else 1)
