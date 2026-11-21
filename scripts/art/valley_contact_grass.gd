extends Node2D
# Fixed rooted clumps in front of/behind the walking plane. Lighting and wind
# animate in the material; positions are never regenerated as the camera moves.
const GRASS=preload("res://assets/art/c_zone_debug/forest/forest_grass_strip.jpg")
var art:Node2D
var layers:Array[Node2D]=[]
func setup(host:Node2D,shader:Shader)->void:
 art=host
 for front:bool in [false,true]:
  var plane:=Node2D.new();plane.z_as_relative=false;plane.z_index=9 if front else 3
  plane.name="front_clumps" if front else "rear_clumps"
  plane.add_to_group(&"chapter_gameplay_focus")
  plane.add_to_group(&"chapter_lit_ground")
  var material:=ShaderMaterial.new();material.shader=shader
  material.set_shader_parameter("source_softness",.9 if front else .75)
  material.set_shader_parameter("blade_sway",1.0 if front else .65)
  plane.material=material
  plane.draw.connect(func():_draw_clumps(plane,front))
  add_child(plane);layers.append(plane)
func _height(x:float)->float:
 return float(art._bank_edge_y(x)) if x<2780 else float(art.level.marsh_rock_surface_y(x))
func _draw_clumps(plane:Node2D,front:bool)->void:
 var spans:Array=[Vector2(210,430),Vector2(825,1230),Vector2(2050,2390),Vector2(2545,2740)]
 for profile:PackedVector2Array in art.level.MARSH_LANDS:spans.append(Vector2(profile[0].x+12,profile[-1].x-12))
 var rng:=RandomNumberGenerator.new();rng.seed=98537 if front else 98521
 for span:Vector2 in spans:
  var x:float=span.x
  while x<span.y:
   var patch:=clampf(.52+.28*sin(x*.017+.8)+.22*sin(x*.039+2.7),0.,1.)
   var width:=rng.randf_range(36,66)
   var edge:=smoothstep(0.,30.,minf(x-span.x,span.y-x))
   var height:=rng.randf_range(35,65) if front else rng.randf_range(18,34)
   height*=lerpf(.45,1.,patch)*edge
   # Keep the authored puzzle-box handle and takeoff lips legible.
   var mechanism:=absf(x-float(art.level.PUZZLE_BOX_START.x))<70.
   if front and mechanism:height*=.25
   # Above-water contact grass must not continue down submerged collision
   # slopes: this layer renders above the water and would expose a dry edge.
   var dry_root:bool=span.x>=2780. or maxf(_height(x-width*.5),_height(x+width*.5))<art.level.WATER_Y-8.
   if dry_root and height>4. and patch>(.22 if front else .12) and (not front or rng.randf()>.18):
    var index:=rng.randi_range(0,10);var mirror:=rng.randf()<.5
    var points:=PackedVector2Array();var uv:=PackedVector2Array()
    for row in 2:
     for i in 11:
      var t:=float(i if row==0 else 10-i)/10.
      var wx:=clampf(x+(t-.5)*width,span.x,span.y)
      points.append(Vector2(wx,_height(wx)+(5. if row==1 else -height)))
      uv.append(Vector2((index+(.02+.96*(1.-t if mirror else t)))/11.,(575. if row==1 else 454.)/720.))
    plane.draw_polygon(points,PackedColorArray([Color.WHITE]),uv,GRASS)
   x+=rng.randf_range(15,27) if front else rng.randf_range(22,37)
