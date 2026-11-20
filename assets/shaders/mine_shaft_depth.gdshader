shader_type canvas_item;
render_mode unshaded;
uniform vec2 lamps[8];
uniform float tilts[8];
uniform bool silhouette=false;
varying vec2 world;
#include "res://assets/shaders/mine_lamp_pool.gdshaderinc"
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0,1)).xy;}
void fragment(){
 vec4 t=texture(TEXTURE,UV);
 float light=0.0;
 for(int i=0;i<8;i++)light=max(light,mine_lamp_pool(world,lamps[i],tilts[i]));
 float l=dot(t.rgb,vec3(0.299,0.587,0.114));
 float tone=silhouette?(0.003+0.075*light)*smoothstep(0.0,0.05,l):(0.001+0.30*light)*smoothstep(0.0005,0.009,l);
 COLOR=vec4(vec3(tone),t.a);
}
