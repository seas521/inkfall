shader_type canvas_item;
render_mode unshaded;
uniform vec2 lamps[8];
uniform float tilts[8];
varying vec2 world;
#include "res://assets/shaders/mine_lamp_pool.gdshaderinc"
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0,1)).xy;}
void fragment(){
 float l=dot(texture(TEXTURE,UV).rgb,vec3(.299,.587,.114));
 float light=0.0;
 for(int i=0;i<8;i++)light=max(light,mine_lamp_pool(world,lamps[i],tilts[i]));
 float outside=smoothstep(-820.0,40.0,world.y);
 float structure=smoothstep(.0004,.08,l);
 float tone=structure*(.001+.25*light)+pow(l,.77)*outside*.55;
 float exit_fade=1.0-smoothstep(-300.0,-185.0,world.x)*smoothstep(140.0,300.0,world.y);
 COLOR=vec4(vec3(tone),exit_fade);
}
