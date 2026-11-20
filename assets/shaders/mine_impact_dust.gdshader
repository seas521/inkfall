shader_type canvas_item;
render_mode unshaded;
uniform vec2 lamp_position;
uniform float lamp_angle;
uniform float lamp_strength=1.0;
varying vec2 world;
varying vec4 particle;
#include "res://assets/shaders/mine_lamp_pool.gdshaderinc"
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;particle=COLOR;}
void fragment(){
 float age=particle.r;
 vec2 uv=UV;
 if(particle.g>0.5)uv.x=1.0-uv.x;
 vec4 dust=texture(TEXTURE,uv);
 // The texture supplies actual wisps and alpha. No radial puff, grid, or
 // narrow procedural bands. Only a soft outer fade guards atlas boundaries.
 float edge=smoothstep(0.0,.09,UV.x)*(1.0-smoothstep(.90,1.0,UV.x));
 edge*=smoothstep(0.0,.09,UV.y)*(1.0-smoothstep(.90,1.0,UV.y));
 float density=dust.a*dot(dust.rgb,vec3(.299,.587,.114));
 float fade=smoothstep(0.0,.055,age)*pow(1.0-age,1.4);
 float light=mine_entry_lamp_pool(world,lamp_position,lamp_angle)*lamp_strength;
 float tone=.055+.25*light;
 COLOR=vec4(vec3(tone),density*edge*fade*.26);
}
