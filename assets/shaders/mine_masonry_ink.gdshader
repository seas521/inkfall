shader_type canvas_item;
render_mode unshaded;
uniform vec2 lamp_position;
uniform float lamp_angle;
uniform float lamp_strength=1.0;
#include "res://assets/shaders/mine_lamp_pool.gdshaderinc"
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
 vec4 s=texture(TEXTURE,UV)*COLOR;
 float l=dot(s.rgb,vec3(0.299,0.587,0.114));
 float lamp=mine_entry_lamp_pool(world,lamp_position,lamp_angle)*lamp_strength;
 COLOR=vec4(vec3(l*(0.025+0.62*lamp)),s.a);
}
