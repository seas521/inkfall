extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_root_cliff_test();await frames(10)
 route=level.bridge_to_c
 for v in [0.,350.,500.,650.]:
  route.checkpoint_step=2;route.reached_step=2;route.restore_checkpoint();await frames(2)
  if v>0:
   level.player.position=Vector2(-3295,-3450)-Vector2(13,54);level.player.velocity=Vector2(0,v);route.fall_origin=-3450
  Input.action_press("move_right")
  var previous:Vector2=route.feet();var stalls:=0
  for i in 300:
   await frames(1)
   var p:Vector2=route.feet()
   if i>20 and p.x-previous.x<.3 and p.x> -3270 and p.x< -3050:
    stalls+=1
    var hits:Array=[]
    for j in level.player.get_slide_collision_count():
     var hit:KinematicCollision2D=level.player.get_slide_collision(j)
     hits.append({"collider":str(hit.get_collider().get_path()),"normal":str(hit.get_normal()),"position":str(hit.get_position())})
    print("CONTACT BLOCK v=",v," p=",p," dx=",p.x-previous.x," velocity=",level.player.velocity," angle=",route.trees[2].angle," hits=",hits)
   previous=p
   if route.failure_time>0 or p.x> -2950:break
  release()
  check(stalls==0,"tree flex must never expose a blocking approach edge")
  check(route.failure_time==0 and route.feet().x> -2960,"every landing must allow holding right into the mine")
  print("CONTACT RUN ",v," stalls=",stalls," end=",route.feet()," failure=",route.failure_time," twig=",route.trees[2].twig_broken)
 print("ENTRY CONTACT ","FAIL" if failed else "PASS");quit(1 if failed else 0)
