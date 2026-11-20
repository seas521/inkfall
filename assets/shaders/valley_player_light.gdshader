shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_color : hint_screen_texture,filter_linear,repeat_disable;
uniform sampler2D forest_light_texture : source_color,filter_linear,repeat_disable;
uniform sampler2D ground_profile : filter_linear,repeat_disable;
uniform vec2 forest_light_camera=vec2(0.0);
uniform float forest_light_clock=0.0;
uniform vec2 world_origin=vec2(0.0);
uniform vec2 world_axis_x=vec2(1280.0,0.0);
uniform vec2 world_axis_y=vec2(0.0,720.0);
uniform vec2 light_screen_step=vec2(.000484375,-.0010833333);
#include "res://assets/shaders/valley_light_field.gdshaderinc"
float scene_luma(vec2 at){return dot(texture(scene_color,at).rgb,vec3(.299,.587,.114));}
vec3 ground_at(float x){return texture(ground_profile,vec2(((x+640.0)/4.0+.5)/3961.0,.5)).rgb;}
void fragment(){
 vec2 uv=SCREEN_UV;
 vec2 world=world_origin+uv.x*world_axis_x+uv.y*world_axis_y;
 vec3 ground=ground_at(world.x);
 float floor_y=ground.r*1024.0;
 float above=floor_y-world.y;
 float wet=ground.g*step(574.0,world.y);
 float sun=valley_player_sunlight(forest_light_texture,uv*vec2(1280,720),forest_light_camera,forest_light_clock,world);
 float air=(1.0-smoothstep(125.0,270.0,above))*smoothstep(-1.0,8.0,above);
 float luma=scene_luma(uv);
 float solid=1.0-smoothstep(.012,.070,luma);
 // The opaque body interrupts the near mist instead of turning pale with it.
 float mist=air*sun*(.020+.012*valley_noise(world*.012+vec2(forest_light_clock*.013,0)))*(1.0-solid*.94);
 float surface=exp(-pow((above+1.0)/6.0,2.0))*ground.b*(1.0-ground.g);
 // Short screen-space visibility rays cast a restrained shadow across the
 // same ground contour. Only surface pixels pay for these extra samples.
 float shadow=0.0;
 if(surface>.015 && sun>.02){
  for(int i=0;i<7;i++){
   float distance=4.0+float(i)*10.0;
   vec2 sample_uv=uv+light_screen_step*distance;
   vec2 sample_world=world+vec2(.62,-.78)*distance;
   float height=ground_at(sample_world.x).r*1024.0-sample_world.y;
   float blocker=(1.0-smoothstep(.012,.055,scene_luma(sample_uv)))*smoothstep(3.0,10.0,height);
   shadow=max(shadow,blocker*(1.0-float(i)*.045));
  }
 }
 float mottling=smoothstep(.35,.70,valley_noise(vec2(world.x*.045,world.y*.022)));
 float ground_light=surface*sun*mottling*.055*(1.0-shadow*.88)*solid;
 // A little grazing light reaches nearby grass and props, on the source side.
 float ahead=scene_luma(uv+light_screen_step*1.4);
 float edge=max(ahead-luma,0.0)*solid;
 float prop_light=edge*sun*.075*air;
 // Sparse slow motes, anchored in world space and revealed only inside light.
 vec2 dust_p=(world+vec2(-forest_light_clock*1.7,forest_light_clock*2.3))/39.0;
 vec2 cell=floor(dust_p);
 vec2 centre=vec2(valley_hash(cell+vec2(9,2)),valley_hash(cell+vec2(4,7)))*.7+.15;
 float radius=mix(.45,.95,valley_hash(cell+17.0));
 float dust=(1.0-smoothstep(.15,radius,length((fract(dust_p)-centre)*39.0)));
 dust*=step(.91,valley_hash(cell+31.0))*air*sun*(1.0-solid)*.18;
 float light=mist+ground_light+prop_light+dust;
 COLOR=vec4(vec3(.8),clamp(light*(1.0-wet),0.0,.065));
}
