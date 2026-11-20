shader_type canvas_item;
render_mode unshaded;
uniform float edge_x=-1974.0;
uniform float floor_y=-3170.0;
uniform vec2 lamp;
uniform float shade_angle;
#include "res://assets/shaders/mine_lamp_pool.gdshaderinc"
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0,1)).xy;}
void fragment(){
 float l=dot(texture(TEXTURE,UV).rgb,vec3(.299,.587,.114));
 float opening=max(smoothstep(edge_x-150.0,edge_x+30.0,world.x)*(1.0-smoothstep(floor_y-12.0,floor_y+4.0,world.y)),smoothstep(edge_x+4.0,edge_x+32.0,world.x));
 float soft=smoothstep(0.0,.15,UV.y)*(1.0-smoothstep(.72,1.0,UV.y))*(1.0-smoothstep(.72,1.0,UV.x));
 COLOR=vec4(vec3(pow(l,.85)*(.20+.10*mine_lamp_pool(world,lamp,shade_angle))),opening*soft*.8);
}
