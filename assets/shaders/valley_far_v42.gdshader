shader_type canvas_item;
render_mode unshaded;
uniform sampler2D forest : source_color, filter_linear, repeat_disable;
uniform float framing_zoom=1.0;
uniform float scroll=0.;
uniform float camera_y=0.;
uniform float clock=0.;
#include "res://assets/shaders/valley_light_field.gdshaderinc"
void fragment(){
 vec2 p=vec2(640,360)+(UV*vec2(1280,720)-vec2(640,360))/framing_zoom;
 vec2 camera=vec2(scroll,camera_y);
 vec2 world=p+camera;
 float l=valley_light_luminance(forest,p,camera,0.);
 // One forest projection continues through both regions. Fog removes
 // contrast/detail over the lake, then thins across a wide world-space band.
 float lake=smoothstep(250.,1100.,world.x)*(1.-smoothstep(1800.,3350.,world.x));
 vec2 q=vec2((p.x+1250.+scroll*.105)/2780.,(p.y+110.+camera_y*.12)/927.);
 q.x=valley_mirror(q.x);q.y=clamp(q.y,0.,1.);
 vec2 d=vec2(.022,.030);
 vec3 broad=texture(forest,q).rgb*.4+(texture(forest,q+d).rgb+texture(forest,q-d).rgb)*.3;
 float air=dot(broad,vec3(.299,.587,.114))*1.05+.055;
 float density=lake*(.72+.12*smoothstep(40.,500.,world.y));
 l=mix(l,air,density);
 COLOR=vec4(vec3(l),1.);
}
