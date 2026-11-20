shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/mine_collapse_warp.gdshaderinc"
void vertex(){float x=(MODEL_MATRIX*vec4(VERTEX,0,1)).x;VERTEX.y+=mine_floor_warp(x);}
void fragment(){COLOR=vec4(0,0,0,1);}
