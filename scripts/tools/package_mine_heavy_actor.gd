extends SceneTree
# Incremental pack: do not regenerate or overwrite any accepted actor groups.
const NAMES=["big_pickup","big_hold","big_walk","big_throw_charge","big_throw_release","big_throw_recover"]
func _initialize()->void:
 var result:Dictionary={}
 for clip:String in NAMES:
  var source:String="res://assets/art/prototypes/hood_clips/"+clip+"/"
  var info:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source+"manifest.json"))
  var dest:String="res://assets/art/actors/hood_boy/heavy/"+clip+"/"
  DirAccess.make_dir_recursive_absolute(dest)
  var rects:Array=[];var eyes:Array=[];var soles:Array=[]
  for frame in int(info.frames):
   var img:=Image.load_from_file(source+"frame_%03d.png"%frame)
   var used:=img.get_used_rect();var crop:=used.grow(5).intersection(Rect2i(0,0,img.get_width(),img.get_height()))
   img.get_region(crop).save_png(dest+"f_%03d.png"%frame)
   rects.append([crop.position.x,crop.position.y,crop.size.x,crop.size.y])
   var weight:=0.0;var center:=Vector2.ZERO
   for y in range(used.position.y,used.end.y):
    for x in range(used.position.x,used.end.x):
     var c:=img.get_pixel(x,y)
     if c.a>.31 and c.r>.216 and c.r-c.g>.094 and c.g-c.b>.016:
      var w:float=(c.r-c.g)*c.a
      center+=Vector2(x+.5,y+.5)*w;weight+=w
   if weight>.001:
    center=center/weight-Vector2(float(info.root[0]),float(info.root[1]))
    eyes.append([snappedf(center.x,.001),snappedf(center.y,.001),0,1])
   else:eyes.append([0,-150,0,0])
   var points:Array=[]
   for x in range(used.position.x,used.end.x,3):
    for y in range(used.end.y-1,maxi(used.position.y,used.end.y-13)-1,-1):
     if img.get_pixel(x,y).a>.6:
      points.append(x+.5-crop.position.x);points.append(y+1.0-crop.position.y);break
   soles.append(points)
  info.group="heavy";info.rects=rects
  # The heavy hold is a breathing pose, and walking is a real two-step loop.
  info.loop=clip in ["big_hold","big_walk"]
  result[clip]={"info":info,"eyes":eyes,"soles":soles}
  print("PACKED HEAVY ",clip," frames ",info.frames)
 var file:=FileAccess.open("res://artifacts/mine-cart-gap-v1/heavy-pack.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(result));file.close()
 quit()
