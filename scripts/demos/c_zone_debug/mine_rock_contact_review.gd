extends SceneTree
var level
var route
var trial
var gap
var results:Array=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func snap(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image()
 var scale:Vector2=Vector2(img.get_size())/Vector2(1280,720)
 var p:Vector2=(route.feet()-Vector2(level.camera_x,level.camera_y)-Vector2(90,120))*scale
 var crop:=Rect2i(Vector2i(p),Vector2i(Vector2(160,140)*scale)).intersection(Rect2i(Vector2i.ZERO,img.get_size()))
 img.get_region(crop).save_png("res://artifacts/mine-rock-contact-v3/"+label+".png")
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 for distance:float in [45.0,52.0]:
  if trial!=null:trial.reset()
  level.enter_mine_cart_gap_test();route=level.bridge_to_c;trial=route.mine_trial;gap=trial.gap
  var x:float=trial.escape.chock_body.position.x+distance
  level.player.position=Vector2(x-13,trial.ground(x)-55);level.player.velocity=Vector2.ZERO
  route.fall_origin=trial.ground(x);await frames(20)
  var origin:Vector2=trial.escape.chock_body.position
  var initial_height:float=level.actor.sprite.texture.get_height()*absf(level.actor.body.scale.y)
  var minimum_height:=initial_height
  var previous:Vector2=origin
  var attached:=false;var first_step:=0.0;var max_error:=0.0
  var down_saved:=false;var grip_saved:=false;var lift_saved:=false
  Input.action_press("interact");await frames(2);Input.action_release("interact")
  for i in 175:
   await frames(1)
   minimum_height=minf(minimum_height,level.actor.sprite.texture.get_height()*absf(level.actor.body.scale.y))
   if not gap.rock_attached:
    assert(gap.rock_position.distance_to(origin)<.02,"stone must stay grounded until palms contact")
    assert(trial.escape.chock_present,"chock collision must persist until contact")
   elif not attached:
    first_step=gap.rock_position.distance_to(previous)
    assert(first_step<.30,"first hand attachment must not attract/snap the rock")
    attached=true
   if attached and gap.rock_state in [1,2]:
    var hand=level.actor.hand_local()
    var expected:Vector2=level.actor.body.to_global(hand+gap.rock_grip_offset)
    max_error=maxf(max_error,expected.distance_to(gap.rock_position))
    assert(max_error<.03,"hands and heavy stone must retain the actual grip offset")
   if distance==45:
    if not down_saved and gap.rock_state==1 and gap.rock_age>.64:
     down_saved=true;await snap("01-deep-crouch")
    if not grip_saved and gap.rock_attached:
     grip_saved=true;await snap("02-palm-contact")
    if not lift_saved and gap.rock_state==1 and gap.rock_age>gap.PICKUP_TIME*.86:
     lift_saved=true;await snap("03-lifting-weight")
   previous=gap.rock_position
   if gap.rock_state==2:break
  await frames(8)
  assert(attached and gap.rock_state==2,"both normal and outer-range approaches must complete the pickup")
  assert(initial_height-minimum_height>12,"existing clip must visibly squat before lifting")
  assert(level.actor.current_clip==&"hug_hold")
  if distance==45:await snap("04-two-hand-hold")
  results.append({"distance":distance,"attach_step":first_step,"grip_error":max_error,"crouch_height_change":initial_height-minimum_height})
 print("HEAVY ROCK CONTACT PASS ",JSON.stringify(results))
 var file:=FileAccess.open("res://artifacts/mine-rock-contact-v3/verification.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(results));file.close()
 quit()
