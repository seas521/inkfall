shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_color : hint_screen_texture,filter_linear,repeat_disable;
uniform sampler2D forest_light_texture : source_color,filter_linear,repeat_disable;
uniform sampler2D ground_profile : filter_linear,repeat_disable;
uniform sampler2D gameplay_coverage : filter_linear,repeat_disable;
uniform vec3 ground_sampling=vec3(-640.0,4.0,3961.0);
uniform int lighting_region=0; // valley, forest, mine, gorge
uniform vec2 forest_light_camera=vec2(0.0);
uniform float forest_light_clock=0.0;
uniform vec2 world_origin=vec2(0.0);
uniform vec2 world_axis_x=vec2(1280.0,0.0);
uniform vec2 world_axis_y=vec2(0.0,720.0);
#include "res://assets/shaders/valley_light_field.gdshaderinc"
#include "res://assets/shaders/chapter_light_field.gdshaderinc"
vec4 ground_at(float x){return texture(ground_profile,vec2(((x-ground_sampling.x)/ground_sampling.y+.5)/ground_sampling.z,.5));}
void fragment(){
 vec2 uv=SCREEN_UV;
 vec2 world=world_origin+uv.x*world_axis_x+uv.y*world_axis_y;
 vec4 ground=ground_at(world.x);
 float floor_y=ground.r;
 if(ground.a<99999.0 && world.y>floor_y+8.0)floor_y=ground.a;
 float above=floor_y-world.y;
 float wet=ground.g*step(574.0,world.y);
 vec3 base=texture(scene_color,uv).rgb;
 vec3 incident=vec3(0.0);
 if(wet<.999 && (ground.b<.5 || above> -16.0)){
  incident=chapter_incident(world);
  if(valley_transport_ready>.5){
   float energy=texture(valley_transport_texture,uv).r;
   incident=vec3(0.0,-energy,energy);
  }else if(lighting_region==0){
   float canopy=valley_player_sunlight(forest_light_texture,uv*vec2(1280,720),forest_light_camera,forest_light_clock,world);
   incident=vec3(vec2(.62,-.78)*canopy,canopy);
  }
 }
 float sun=incident.z;
 if(sun>.0001 || valley_transport_ready>.5){
 float air=smoothstep(-3.0,9.0,above)*(1.0-smoothstep(180.0,340.0,above));
 if(ground.b<.1)air=1.0;
 float luma=dot(base,vec3(.299,.587,.114));
 float solid=1.0-smoothstep(.012,.070,luma);
 float coverage=texture(gameplay_coverage,uv).a;
 // Receiver materials own solid-surface lighting. A screen-space gradient
 // interpreted every black/bright boundary as a specular edge, and the
 // ground Gaussian painted gray patches inside otherwise black terrain.
 float clear_air=1.0-smoothstep(.02,.40,coverage);
 if(valley_transport_ready>.5){
  vec4 medium=texture(valley_transport_texture,uv);
  // A bounded foreground segment of participating air. The soil interior,
  // water and opaque near-camera framing are not a luminous fog overlay.
  float air_path=air;
  if(above<0.0)air_path=0.0;
  float eligible=1.0-solid*(1.0-clamp(coverage,0.0,1.0));
  float optical_depth=medium.b*air_path*eligible*mix(1.0,.38,clamp(coverage,0.0,1.0))*.13;
  float transmittance=exp(-optical_depth);
  // Henyey-Greenstein phase relative to isotropic scattering. Orthographic
  // viewing and the authored sun direction give a constant view/light angle.
  float phase=medium.a;
  vec3 scattering=vec3(.24)*sun*phase*(1.0-transmittance);
  COLOR=vec4(base*transmittance+scattering,1.0);
 }else{
 // The existing background already holds the main light volumes. Only a
 // restrained, broken veil joins that air to the receiving plane.
 float mist=air*sun*(.0025+.002*valley_noise(world*.012+vec2(forest_light_clock*.013,0)))*(1.0-solid*.98)*clear_air;
 vec2 dust_p=(world+vec2(-forest_light_clock*1.7,forest_light_clock*2.3))/39.0;
 vec2 cell=floor(dust_p);
 vec2 centre=vec2(valley_hash(cell+vec2(9,2)),valley_hash(cell+vec2(4,7)))*.7+.15;
 float radius=mix(.45,.95,valley_hash(cell+17.0));
 float dust=(1.0-smoothstep(.15,radius,length((fract(dust_p)-centre)*39.0)));
 dust*=step(.94,valley_hash(cell+31.0))*air*sun*(1.0-solid)*.035*clear_air;
 float light=(mist+dust)*(1.0-wet);
 COLOR=vec4(base+vec3(light),1.0);
 }
 }else{COLOR=vec4(base,1.0);}
}
