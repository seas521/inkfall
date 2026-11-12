shader_type canvas_item;
uniform sampler2D roof_image : filter_linear,repeat_disable;
uniform sampler2D base_profile : filter_linear,repeat_disable;
uniform sampler2D ceiling_profile : filter_linear,repeat_disable;
uniform float image_scale=0.221354;
uniform vec4 ink=vec4(0.003,0.003,0.003,1.0);
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
 float base=texture(base_profile,vec2(UV.x,0.5)).r;
 float ceiling=texture(ceiling_profile,vec2(UV.x,0.5)).r;
 float y=(world.y-ceiling)/(image_scale*1024.0)+base/1024.0;
 float inside=step(0.0,y)*step(y,1.0);
 float a=texture(roof_image,vec2(UV.x,y)).a*inside;
 COLOR=vec4(ink.rgb,a*ink.a);
}
