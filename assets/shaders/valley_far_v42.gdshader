shader_type canvas_item;
render_mode unshaded;
uniform sampler2D forest : source_color, filter_linear, repeat_disable;
uniform float scroll=0.;
uniform float camera_y=0.;
uniform float clock=0.;
#include "res://assets/shaders/valley_light_field.gdshaderinc"
void fragment(){
 float l=valley_light_luminance(forest,UV*vec2(1280.,720.),vec2(scroll,camera_y),clock);
 COLOR=vec4(vec3(l),1.);
}
