shader_type canvas_item;
render_mode unshaded;
uniform float rows=1.0;
uniform float row=0.0;
#include "res://assets/shaders/mine_collapse_warp.gdshaderinc"
void vertex(){
 float x=(MODEL_MATRIX*vec4(VERTEX,0,1)).x;
 float attached=1.0-smoothstep(.12,.82,UV.y*rows-row);
 VERTEX.y+=mix(mine_floor_warp(x),mine_roof_warp(x),attached);
}
void fragment(){
 float v=UV.y*rows-row;
 float l=dot(texture(TEXTURE,UV).rgb,vec3(0.299,0.587,0.114));
 float near_post=smoothstep(0.17,0.20,UV.x)*(1.0-smoothstep(0.285,0.30,UV.x));
 float mask=(1.0-smoothstep(0.012,0.035,l))*near_post*smoothstep(0.35,0.45,v);
 COLOR=vec4(vec3(0.002),mask);
}
