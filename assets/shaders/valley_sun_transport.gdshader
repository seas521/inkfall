shader_type canvas_item;
render_mode unshaded,blend_disabled;
#include "res://assets/shaders/valley_light_field.gdshaderinc"
#include "res://assets/shaders/chapter_light_field.gdshaderinc"
uniform float valley_mode=1.0;
uniform sampler2D source_forest : source_color,filter_linear,repeat_disable;
uniform sampler2D ground_profile : filter_linear,repeat_disable;
uniform vec3 ground_sampling=vec3(-640.0,4.0,3961.0);
uniform sampler2D blocker_texture : filter_linear,repeat_disable;
uniform vec4 blocker_rect=vec4(0.0,0.0,1280.0,720.0);
uniform float blocker_ready=0.0;
uniform sampler2D structure_texture : filter_linear,repeat_disable;
uniform sampler2D foreground_texture : filter_linear,repeat_disable;
uniform vec4 structure_rect=vec4(0.0,0.0,1672.0,941.0);
uniform float structure_ready=0.0;
uniform vec2 world_origin=vec2(0.0);
uniform vec2 world_axis_x=vec2(1280.0,0.0);
uniform vec2 world_axis_y=vec2(0.0,720.0);
uniform vec2 forest_light_camera=vec2(0.0);
uniform float forest_light_clock=0.0;
float opacity_at(vec2 world){
 vec4 ground=texture(ground_profile,vec2(((world.x-ground_sampling.x)/ground_sampling.y+.5)/ground_sampling.z,.5));
 // Water is transmitting, not a solid wall at the waterline.
 if(ground.b>.5 && ground.g<.5){
  bool solid=world.y>ground.r+3.0;
  if(ground.a<99999.0)solid=(world.y>ground.r+3.0 && world.y<ground.r+20.0)||world.y>ground.a+3.0;
  if(solid)return 1.0;
 }
 float alpha=0.0;
 vec2 uv=(world-blocker_rect.xy)/blocker_rect.zw;
 if(blocker_ready>.5 && uv.x>=0.0 && uv.y>=0.0 && uv.x<=1.0 && uv.y<=1.0)alpha=texture(blocker_texture,uv).a;
 vec2 local=(world-structure_rect.xy)/structure_rect.zw;
 if(structure_ready>.5 && local.x>=0.0 && local.y>=0.0 && local.x<=1.0 && local.y<=1.0){
  alpha=max(alpha,texture(structure_texture,local).a);
  alpha=max(alpha,texture(foreground_texture,local).a);
 }
 return smoothstep(.08,.90,alpha);
}
float sunlight_visibility(vec2 world,vec2 toward,float reach){
 vec2 across=vec2(-toward.y,toward.x);
 float visible=1.0;
 // A projected 2D visibility test through actual main-plane silhouettes.
 // It is not a 3D shadow map and cannot infer offscreen/background depth.
 for(int i=0;i<48;i++){
  float distance=mix(8.0,max(8.0,reach),float(i)/47.0);
  vec2 p=world+toward*distance;
  float penumbra=mix(.7,3.5,distance/640.0);
  float opacity=opacity_at(p)*.5;
  opacity+=opacity_at(p+across*penumbra)*.25;
  opacity+=opacity_at(p-across*penumbra)*.25;
  visible=min(visible,1.0-opacity);
  if(visible<.002)break;
 }
 return visible;
}
float phase_hg(float cosine){
 float g=.35;
 return (1.0-g*g)/pow(1.0+g*g-2.0*g*cosine,1.5);
}
void fragment(){
 vec2 world=world_origin+UV.x*world_axis_x+UV.y*world_axis_y;
 float incident=0.0;float direct=0.0;float phase_sum=0.0;
 if(valley_mode>.5){
  incident=valley_unshadowed_sunlight(source_forest,UV*vec2(1280,720),forest_light_camera,forest_light_clock,world);
  float visible=incident>.001?sunlight_visibility(world,normalize(vec2(.62,-.78)),624.0):0.0;
  direct=incident*visible;phase_sum=direct*phase_hg(.45);
 }else{
  float canopy_mask=chapter_canopy_mask(world);
  for(int i=0;i<12;i++){
   if(i>=chapter_light_count)break;
   float energy=chapter_source_energy(world,i,canopy_mask);
   if(energy<.001)continue;
   vec2 delta=chapter_lights[i].xy-world;
   float visible=sunlight_visibility(world,normalize(delta+vec2(.0001)),min(length(delta),624.0));
   incident+=energy;direct+=energy*visible;
   phase_sum+=energy*visible*phase_hg(mix(0.0,.45,chapter_light_canopy[i]));
  }
 }
 float visibility=direct/max(incident,.0001);
 vec2 flow=vec2(forest_light_clock*.65,-forest_light_clock*.23);
 float density=valley_noise((world+flow)*.008)*.64;
 density+=valley_noise((world-flow*.6)*.019+vec2(7.3,2.1))*.26;
 density+=valley_noise((world+flow*.3)*.043+vec2(1.7,9.2))*.10;
 density=mix(.42,1.0,smoothstep(.16,.84,density));
 // Phase approximates the authored out-of-plane source/view angle.
 COLOR=vec4(min(direct,1.0),visibility,density,phase_sum/max(direct,.0001));
}
