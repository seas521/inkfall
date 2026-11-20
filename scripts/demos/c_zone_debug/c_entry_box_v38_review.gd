extends SceneTree
var failed:=false
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func run()->void:
 var level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 for i in 5:await physics_frame
 level.set_physics_process(false)
 level.debug_enter_scene1()
 var route=level.bridge_to_c
 check(is_equal_approx(level.puzzle_box.position.x,3150.),"fixture must reproduce inherited forest staging")
 print("Inherited forest box: ",level.puzzle_box.position)
 route.c_zone_prepared=false
 level.puzzle_box.velocity=Vector2(80,0)
 route.prepare_c_zone_preview()
 check(level.puzzle_box.position==level.PUZZLE_BOX_START,"fresh C entry must reset unsolved box")
 check(level.puzzle_box.velocity==Vector2.ZERO,"fresh box cannot inherit motion")
 print("Fresh C box: ",level.puzzle_box.position)
 level.puzzle_box.position.x=3075.
 route.prepare_c_zone_preview()
 check(is_equal_approx(level.puzzle_box.position.x,3075.),"revisiting C must retain player placement")
 level.checkpoint=2;level.marsh_save=1;level.restore_checkpoint()
 check(level.puzzle_box.position==level.PUZZLE_BOX_START,"ledge checkpoint must restore unsolved box")
 level.checkpoint=2;level.marsh_save=2;level.restore_checkpoint()
 check(is_equal_approx(level.puzzle_box.position.x,3150.),"later hill checkpoint must preserve existing solved staging")
 print("C ENTRY BOX V38 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
