extends SceneTree
var failed:=false
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:
  await physics_frame
  await process_frame
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func run()->void:
 var owner:=Node2D.new();root.add_child(owner)
 preload("res://scripts/effects/film_look.gd").attach(owner);await frames(3)
 var film=get_nodes_in_group("film_look")[0]
 film.set_route_softness(owner,1.);film.set_mine_environment(1.)
 await frames(30)
 check(float(film.lens_material.get_shader_parameter("route_softness"))==1.,"live gameplay must enable common optics")
 owner.hide();await frames(3)
 check(float(film.lens_material.get_shader_parameter("route_softness"))==0.,"hidden gameplay cannot leave the stronger lens on a menu")
 owner.show();await frames(3)
 check(float(film.lens_material.get_shader_parameter("route_softness"))==1.,"showing the world must restore the common lens")
 owner.queue_free();await frames(3)
 check(float(film.lens_material.get_shader_parameter("route_softness"))==0.,"freed gameplay cannot leave stale optics")
 var replacement:=Node2D.new();root.add_child(replacement)
 preload("res://scripts/effects/film_look.gd").attach(replacement)
 film.set_route_softness(replacement,1.);await frames(3)
 check(get_nodes_in_group("film_look").size()==1,"scene re-entry must reuse one film pass")
 check(float(film.lens_material.get_shader_parameter("route_softness"))==1.,"a replacement chapter must register correctly")
 replacement.queue_free();await frames(3)
 check(float(film.lens_material.get_shader_parameter("route_softness"))==0.,"replacement cleanup must release common optics")
 print("ROUTE OPTICS LIFECYCLE V35 ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
