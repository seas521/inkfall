// Material response on actual geometry, not a screen-space bright contour.
#include "res://assets/shaders/valley_light_field.gdshaderinc"
#include "res://assets/shaders/chapter_light_field.gdshaderinc"
uniform sampler2D forest_light_texture : source_color,filter_linear,repeat_disable;
uniform float forest_received_light=0.0;
uniform vec2 forest_light_camera=vec2(0.0);
uniform float forest_light_clock=0.0;
uniform vec3 light_screen_x=vec3(1.0,0.0,0.0);
uniform vec3 light_screen_y=vec3(0.0,1.0,0.0);
uniform sampler2D ground_profile : filter_linear,repeat_disable;
uniform vec3 ground_sampling=vec3(-640.0,4.0,3961.0);
uniform vec2 source_world_offset=vec2(0.0);
uniform float surface_response=.006;
uniform bool only_exposed_tops=false;
float chapter_surface_light(vec2 world){
 float exposure=1.0;
 if(only_exposed_tops){
  vec4 ground=texture(ground_profile,vec2(((world.x-ground_sampling.x)/ground_sampling.y+.5)/ground_sampling.z,.5));
  if(ground.b<.5 || ground.g>.5)return 0.0;
  exposure=smoothstep(-1.0,7.0,ground.r-world.y);
  if(exposure<.001)return 0.0;
 }
 vec3 p=vec3(world,1.0);
 vec2 screen=vec2(dot(light_screen_x,p),dot(light_screen_y,p));
 float sun=chapter_incident(world).z;
 if(valley_transport_ready>.5){
  sun=texture(valley_transport_texture,screen/vec2(1280,720)).r;
 }else if(forest_received_light>0.0){
  sun+=valley_player_sunlight(forest_light_texture,screen,forest_light_camera,forest_light_clock,world)*forest_received_light;
 }
 float broad=valley_noise(world*vec2(.019,.035));
 return min(sun,1.0)*exposure*surface_response*mix(.65,1.0,broad);
}
