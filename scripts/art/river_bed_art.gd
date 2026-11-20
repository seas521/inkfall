extends Node2D
# Submerged scenery only: two receding shelves behind the actual collision
# banks. A quiet basin replaces the unrelated forest backdrop below the water.
var shelves:Array[Dictionary]=[]
var stones:Array[Dictionary]=[]
func _ready()->void:
 var rng:=RandomNumberGenerator.new();rng.seed=49163
 for layer in 2:
  var edge:=PackedVector2Array()
  var start:=1040.0
  var finish:=2160.0
  for i in 141:
   var x:=lerpf(start,finish,float(i)/140.)
   edge.append(Vector2(x,_shelf_y(x,layer)))
  edge.append(Vector2(finish,980));edge.append(Vector2(start,980))
  shelves.append({"shape":edge,"tone":.22 if layer==0 else .14})
  # Sparse embedded stones, never a repeating gravel strip or white rim.
  for i in (13 if layer==0 else 9):
   var x:=rng.randf_range(1090,2120)
   var base:=Vector2(x,_shelf_y(x,layer)+rng.randf_range(2,7))
   var size:=Vector2(rng.randf_range(17,49),rng.randf_range(10,24))
   var shape:=PackedVector2Array()
   for j in 13:
    var angle:=PI+float(j)/12.*PI
    var radius:=rng.randf_range(.83,1.12)
    shape.append(base+Vector2(cos(angle)*size.x,sin(angle)*size.y)*radius)
   stones.append({"shape":shape,"tone":.18 if layer==0 else .10,"layer":layer})
 queue_redraw()
func _shelf_y(x:float,layer:int)->float:
 var basin:=sin(clampf((x-1000.)/1200.,0,1)*PI)
 return 610.+basin*(78. if layer==0 else 145.)+sin(x*.012+layer)*4.+sin(x*.031)*1.7
func _draw()->void:
 # The water shader supplies absorption and refraction over this opaque depth.
 draw_rect(Rect2(1000,575,1200,405),Color(.34,.34,.34))
 for layer in 2:
  var shelf:Dictionary=shelves[layer]
  var tone:float=shelf.tone
  draw_colored_polygon(shelf.shape,Color(tone,tone,tone))
  for stone in stones:
   if stone.layer!=layer:continue
   tone=stone.tone
   draw_colored_polygon(stone.shape,Color(tone,tone,tone))
