extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-cart-visibility-v14/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func inspect_carts(label:String)->void:
 await RenderingServer.frame_post_draw
 for i in 2:
  var c=room.carts[i]
  var pixels:=0
  var im:Image=c.front_view.get_texture().get_image()
  for y in range(0,im.get_height(),3):
   for x in range(0,im.get_width(),3):
    if im.get_pixel(x,y).a>.5:pixels+=1
  print("CART VIS ",label," index=",i," alpha=",pixels," vis=",c.is_visible_in_tree()," sprite=",c.front.visible," at=",c.front.global_position," updates=",c.render_updates," rendered=",c.rendered," mode=",c.front_view.render_target_update_mode," lost=",relay.cart_lost[i])
  if c.front.visible:check(pixels>100,"visible cart must contain opaque rendered wheels and body")
func run()->void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90)
 level=main.river;route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await inspect_carts("entry");await shot("00-entry")
 for i in 2:
  await warp(Vector2(room.bays[i]+100,room.TRACK_Y));await frames(150)
  await inspect_carts("approach-"+str(i));await shot("01-cart-"+str(i))
 await warp(Vector2(room.bays[0]+100,room.TRACK_Y));await frames(150)
 await inspect_carts("return-to-first");await shot("02-return")
 var c=room.carts[0]
 c.hide();await frames(5)
 check(not c.rendered,"hidden cart must invalidate cached completion")
 var updates:int=c.render_updates
 c.show();await frames(12);await inspect_carts("show-again")
 check(c.render_updates>updates,"showing a previously hidden cart must request a new draw")
 updates=c.render_updates;await frames(30)
 check(c.render_updates==updates,"settled visible cart must retain cached render performance")
 print("MINE CART VISIBILITY ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
