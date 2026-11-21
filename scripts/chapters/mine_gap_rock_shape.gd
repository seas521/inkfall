extends RefCounted
# Geology below the usable lips. Walking collision, rail and deck are retained.
static func left_edge(floor_y:float)->PackedVector2Array:
 var anchors:=PackedVector2Array([Vector2(0,0),Vector2(5,28),Vector2(-12,74),Vector2(-42,128),Vector2(-38,190),Vector2(-52,227),Vector2(-94,302),Vector2(-100,396),Vector2(-61,465),Vector2(-70,536),Vector2(-116,582),Vector2(-108,670),Vector2(-151,775),Vector2(-142,917),Vector2(-126,1020),Vector2(-158,1200)])
 var edge:=PackedVector2Array()
 for i in anchors.size()-1:
  for step in 5:
   var t:float=float(step)/5.
   var rounded:float=lerpf(t,smoothstep(0.,1.,t),.55 if i>1 else 0.)
   edge.append(Vector2(-1014+lerpf(anchors[i].x,anchors[i+1].x,rounded),floor_y+lerpf(anchors[i].y,anchors[i+1].y,t)))
 edge.append(Vector2(-1014+anchors[-1].x,floor_y+anchors[-1].y))
 return edge
static func right_edge()->PackedVector2Array:
 return PackedVector2Array([Vector2(-600,-3050),Vector2(-606,-3025),Vector2(-629,-2972),Vector2(-620,-2890),Vector2(-642,-2810),Vector2(-612,-2740),Vector2(-560,-2660),Vector2(-551,-2580),Vector2(-578,-2520),Vector2(-548,-2430),Vector2(-568,-2320),Vector2(-602,-2240),Vector2(-590,-2110),Vector2(-566,-1960),Vector2(-594,-1790),Vector2(-578,-1600)])
static func configure(material:ShaderMaterial)->void:
 material.set_shader_parameter("gap_rock_enabled",true)
 material.set_shader_parameter("gap_rock_points",right_edge())
 material.set_shader_parameter("gap_rock_count",16)
static func solid_material()->ShaderMaterial:
 var shader:=Shader.new()
 shader.code="""shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/mine_gap_rock_profile.gdshaderinc"
varying vec2 rock_world;
void vertex(){rock_world=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;}
void fragment(){COLOR.a*=mine_gap_rock_coverage(rock_world);}
"""
 var material:=ShaderMaterial.new();material.shader=shader;configure(material);return material
