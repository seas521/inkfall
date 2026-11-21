shader_type canvas_item;
render_mode unshaded;
// All optical inputs are world resources. No screen snapshots or clamped
// screen-edge colour can enter the water when the camera first approaches.
uniform sampler2D forest:source_color,repeat_disable,filter_linear;
uniform sampler2D bank_height:repeat_disable,filter_linear;
uniform sampler2D waves:repeat_disable,filter_linear;
uniform vec2 camera_position=vec2(0.);
uniform vec2 world_offset=vec2(0.);
uniform float wave_x0=1100.;
uniform float wave_dx=4.;
uniform float wave_n=264.;
uniform float water_y=575.;
uniform float clock=0.;
#include "res://assets/shaders/river_water_field.gdshaderinc"
varying vec2 world_position;
float bank_at(float x){return texture(bank_height,vec2(((x+120.)/4.+.5)/706.,.5)).r*1024.;}
float mirror_x(float x){return 1.-abs(mod(x,2.)-1.);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy-world_offset;}
void fragment(){
 vec2 p=world_position;
 float u=((p.x-wave_x0)/wave_dx+.5)/wave_n;
 float swell=texture(waves,vec2(u,.5)).r;
 float slope=(texture(waves,vec2(u+1./wave_n,.5)).r-texture(waves,vec2(u-1./wave_n,.5)).r)/(2.*wave_dx);
 float depth=p.y-water_y+swell;
 float d=max(depth,0.);
 float bed=bank_at(p.x);
 float bank_slope=(bank_at(p.x+24.)-bank_at(p.x-24.))/48.;
 // Distance normal to the actual bank, not a rectangle or a dry/wet cut.
 float signed_bank=(p.y-bed)/sqrt(1.+bank_slope*bank_slope);
 float width=1.8+min(d*.20,42.);
 float bank=smoothstep(-width,width,signed_bank);
 float immersion=smoothstep(-18.,48.,depth);
 // Continuous volume over the whole river cross section. Inside solid
 // soil the result converges to the identical black ink, so there is no
 // local coverage boundary or luminous strip along a shore-mask edge.
 float alpha=smoothstep(-29.,-12.,depth)*((1.-bank)+bank*immersion);
 if(alpha<.001){discard;}
 // Reflect the same far-forest resource/projection as the valley. Sampling
 // extends outside the current view, so scrolling cannot reveal capture edges.
 float ripple=river_noise(vec2(p.x*.012,log(1.+d/45.)*8.)+vec2(clock*.03,-clock*.12))-.5;
 float reflected_y=water_y-d*.72;
 vec2 q=vec2((p.x+1250.-camera_position.x*.895)/2780.,(reflected_y+110.-camera_position.y*.88)/927.);
 q.x=mirror_x(q.x+ripple*.002+slope*.001);
 q.y=clamp(q.y+ripple*.0008,.015,.985);
 vec2 blur=vec2(.012,.016)*(1.+min(d/220.,1.));
 vec3 reflected=texture(forest,q).rgb*.4+(texture(forest,q+blur).rgb+texture(forest,q-blur).rgb)*.3;
 float reflection=dot(reflected,vec3(.299,.587,.114));
 float fresnel=.32+.22*exp(-d/150.);
 vec3 clear_water=mix(vec3(.19),vec3(reflection),fresnel);
 // Black soil transmitted through the whole coherent water volume, rather
 // than brightening a local shore patch with neighbouring screen pixels.
 float transmission=.985+.015*smoothstep(0.,80.,signed_bank);
 vec3 water=mix(clear_water,vec3(.0015),bank*transmission);
 float horizon=exp(-pow(depth/6.,2.))*(1.-bank)*.014;
 water+=vec3(horizon+ripple*.003*(1.-bank));
 COLOR=vec4(water,alpha);
}
