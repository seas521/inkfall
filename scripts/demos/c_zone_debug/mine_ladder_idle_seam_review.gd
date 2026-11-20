extends "res://scripts/demos/c_zone_debug/mine_pair_ladders_review.gd"
var samples:Array=[]
var previous_texture:Texture2D
var seam_count:=0
func sample()->void:
 var a=level.actor
 var origin:Vector2=a.sprite.to_global(Vector2.ZERO)-route.feet()
 if not samples.is_empty() and samples[-1].clip=="mine_ladder_settle" and a.current_clip==&"idle_left":
  var previous:Dictionary=samples[-1]
  check(origin.distance_to(Vector2(previous.origin[0],previous.origin[1]))<.001,"idle handoff must preserve rendered sprite origin")
  check(absf(control.sole_world_y()-float(previous.sole))<.001,"idle handoff must preserve visible soles")
  check(a.body.scale.distance_to(Vector2(previous.scale[0],previous.scale[1]))<.00001,"idle handoff must preserve scale")
  check(a.sprite.texture.get_image().get_data()==previous_texture.get_image().get_data(),"last rendered ladder frame must equal the canonical idle pixels")
  seam_count+=1
 samples.append({"mode":control.mode,"source":control.source_frame,"clip":String(a.current_clip),"frame":a.current_frame_index,"origin":[origin.x,origin.y],"scale":[a.body.scale.x,a.body.scale.y],"feet":[route.feet().x,route.feet().y],"sole":control.sole_world_y(),"support":a.support_offset})
 previous_texture=a.sprite.texture
func run()->void:
 root.size=Vector2i(1280,720)
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(30)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;control=room.ladders
 for index in 2:
  var d:Dictionary=control.definitions()[index]
  await warp(Vector2(d.x,d.bottom));Input.action_press("climb_up")
  for i in 700:
   await frames(1)
   if control.mode==control.Mode.EXIT:sample()
   if control.completed_up[index]>0:break
  release()
  for i in 20:await frames(1);sample()
 var out:=OS.get_environment("INKFALL_SEAM_REPORT")
 if out.is_empty():out="res://artifacts/mine-ladder-idle-seam-v1/before.json"
 var file=FileAccess.open(out,FileAccess.WRITE);file.store_string(JSON.stringify(samples,"  "))
 check(seam_count==2,"both ladder-to-idle handoffs must be checked")
 print("MINE LADDER IDLE SEAM RECORDED ",samples.size())
 quit(1 if failed else 0)
