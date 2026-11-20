extends Node2D
# Retained ground-following grass from the established forest photograph,
# with rooted fern and broadleaf silhouettes in independent optical planes.
const GRASS=preload("res://assets/art/c_zone_debug/forest/forest_grass_strip.jpg")
const INK=preload("res://assets/shaders/valley_plant_ink.gdshader")
const Softness=preload("res://scripts/chapters/mine_cached_softness.gd")
var ground:Callable
var start_x:=2310.0
var end_x:=3800.0
func _ready()->void:
 for near in [false,true]:
  var source:=Node2D.new()
  var grass:=Node2D.new();source.add_child(grass)
  var ink:=ShaderMaterial.new();ink.shader=INK;ink.set_shader_parameter("grass_key",true)
  grass.material=ink;grass.draw.connect(func():_grass(grass,near))
  var plants:=Node2D.new();source.add_child(plants)
  plants.draw.connect(func():_plants(plants,near))
  var low:=INF;var high:=-INF
  for x in range(int(start_x)-70,int(end_x)+71,16):
   var y:float=ground.call(x);low=minf(low,y);high=maxf(high,y)
  var bounds:=Rect2(Vector2(start_x-70,low-110),Vector2(end_x-start_x+140,high-low+130))
  Softness.node(self,source,bounds,.85 if near else .65,7 if near else 3).name="near_understory" if near else "rooted_grass_and_ferns"
func _grass(canvas:Node2D,near:bool)->void:
 var rng:=RandomNumberGenerator.new();rng.seed=25031 if near else 25017
 var x:=start_x+8.0
 while x<end_x:
  var patch:=.55+.27*sin(x*.019)+.18*sin(x*.047+2.7)
  var width:=rng.randf_range(42,77)
  var forest:=smoothstep(start_x+190,end_x-150,x)
  var height:=rng.randf_range(13,28)*lerpf(.65,1.35,forest)*lerpf(.45,1.0,patch)
  if near:height*=.55
  if (not near or rng.randf()<.30) and patch>.17:
   var first:=rng.randf_range(0,1280-135)
   var mirror:=rng.randf()<.5
   var vertices:=PackedVector2Array();var uv:=PackedVector2Array()
   for i in 11:
    var t:=float(i)/10.0;var wx:=x+(t-.5)*width
    vertices.append(Vector2(wx,float(ground.call(wx))-height))
    uv.append(Vector2((first+(1-t if mirror else t)*135)/1280.0,418.0/720.0))
   for i in range(10,-1,-1):
    var t:=float(i)/10.0;var wx:=x+(t-.5)*width
    vertices.append(Vector2(wx,float(ground.call(wx))+5))
    uv.append(Vector2((first+(1-t if mirror else t)*135)/1280.0,575.0/720.0))
   canvas.draw_polygon(vertices,PackedColorArray([Color.WHITE]),uv,GRASS)
  x+=rng.randf_range(24,43)
func _leaf(canvas:Node2D,base:Vector2,tip:Vector2,width:float,color:Color)->void:
 var axis:=tip-base;var n:=axis.normalized().orthogonal()
 var points:=PackedVector2Array()
 for side in [1.0,-1.0]:
  for k in range(10 if side>0 else 8):
   var t:=float(k)/9.0 if side>0 else 1.0-float(k+1)/9.0
   points.append(axis*t+n*(sin(t*PI)*width*side+sin(t*PI)*width*.25))
 canvas.draw_set_transform(base)
 canvas.draw_colored_polygon(points,color)
 canvas.draw_set_transform(Vector2.ZERO)
func _fern(canvas:Node2D,base:Vector2,height:float,seed_value:int,color:Color)->void:
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 for lean in [-.95,-.58,-.23,.18,.55,.93]:
  var h:=height*(1.0-absf(lean)*.32)*rng.randf_range(.88,1.12)
  var spine:=PackedVector2Array()
  for i in 15:
   var t:=float(i)/14.0
   spine.append(base+Vector2(lean*h*t,-h*(1.5*t-.5*t*t)))
  canvas.draw_polyline(spine,color,.75,true)
  for i in range(2,13):
   var t:=float(i)/14.0
   var at:Vector2=spine[i]
   var tangent:Vector2=(spine[i+1]-spine[i-1]).normalized()
   var reach:=h*.20*sin(t*PI)*rng.randf_range(.85,1.12)
   for side in [-1.0,1.0]:
    var tip:Vector2=at+tangent*h*.09+tangent.orthogonal()*side*reach
    _leaf(canvas,at,tip,h*.023,color)
func _plants(canvas:Node2D,near:bool)->void:
 var rng:=RandomNumberGenerator.new();rng.seed=25111 if near else 25091
 var placements:=[2395.,2502.,2795.,2908.,3050.,3207.,3375.,3558.,3730.]
 for i in placements.size():
  var x:float=placements[i]+rng.randf_range(-17,17)
  if near and i%3!=1:continue
  var forest:=smoothstep(start_x+210,end_x-200,x)
  var height:=rng.randf_range(34,56)*lerpf(.65,1.3,forest)*(.53 if near else 1.0)
  var base:=Vector2(x,float(ground.call(x))+4)
  var color:=Color(.0003,.0003,.0003)
  _fern(canvas,base,height,2500+i,color)
  if not near:
   var offset:=rng.randf_range(16,25)*(-1 if i%2==0 else 1)
   var companion:=Vector2(x+offset,float(ground.call(x+offset))+4)
   _fern(canvas,companion,height*rng.randf_range(.35,.58),2590+i,color)
  # A few low, arching broad leaves interrupt the feathery fern rhythm.
  for j in 4:
   var lean:=rng.randf_range(-.9,.9)
   var tip:=base+Vector2(lean*height*.65,-height*rng.randf_range(.35,.62))
   canvas.draw_line(base,tip,color,.9,true)
   _leaf(canvas,base.lerp(tip,.28),tip,height*rng.randf_range(.055,.10),color)
