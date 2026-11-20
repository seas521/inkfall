extends SceneTree
var level
func _initialize()->void:call_deferred("run")
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 for i in 8:await physics_frame
 level.enter_mine_cart_gap_test()
 var trial=level.bridge_to_c.mine_trial
 for x:float in [-1465,-1450,-1439,-1425,-1400,-1380,-1360,-1335,-1300,-1200]:
  print("GRADE ",x," y ",trial.ground(x)," gradient ",(trial.ground(x+10)-trial.ground(x-10))/20)
 quit()
