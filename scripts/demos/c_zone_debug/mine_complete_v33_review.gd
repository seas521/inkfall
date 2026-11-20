extends "res://scripts/demos/c_zone_debug/mine_basket_free_throw_v32_review.gd"
var support_samples:Dictionary={}
var impact_sampled:=false
var max_bob:=0.
func frames(n:int)->void:
 for i in n:
  await super.frames(1)
  if hoist==null:continue
  max_bob=maxf(max_bob,absf(hoist.basket_bob))
  if not impact_sampled and hoist.basket_bob>3.:
   impact_sampled=true
   await shot("02b-heavy-impact-sag")
  if room.cart_gripped:
   for x in [610.,660.,720.]:
    if absf(room.bays[0]-x)<2 and not support_samples.has(x):
     support_samples[x]=true
     await shot("08-cart-passing-post-"+str(int(x)))
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var directory:="res://artifacts/mine-terrain-basket-input-v33/game"
 DirAccess.make_dir_recursive_absolute(directory)
 var raw=FileAccess.open(directory+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta=FileAccess.open(directory+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
