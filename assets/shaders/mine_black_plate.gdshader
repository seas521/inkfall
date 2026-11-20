shader_type canvas_item;
render_mode unshaded;
uniform float rows=1.0;
uniform float row=0.0;
uniform bool entry=false;
uniform float entry_left=-3060.0;
uniform vec2 rest_light;
uniform vec2 end_lamp=vec2(1000000.0);
uniform float end_tilt=0.0;
uniform vec2 aux_lamp=vec2(1000000.0);
uniform float aux_angle=0.0;
uniform float aux_strength=1.0;
uniform vec2 aux2_lamp=vec2(1000000.0);
uniform float aux2_angle=0.0;
uniform float end_strength=1.0;
uniform bool stopping_bay=false;
uniform float rock_end_x=1000000.0;
uniform float seam_left=-1000000.0;
uniform float fade_out_from=1000000.0;
uniform float fade_out_to=1000100.0;
uniform vec2 lamp;
uniform float angle=0.0;
uniform float lamp_strength=1.0;
varying vec2 world;
varying vec4 canvas_tint;
#include "res://assets/shaders/mine_collapse_warp.gdshaderinc"
void vertex(){
 canvas_tint=COLOR;
 float x=(MODEL_MATRIX*vec4(VERTEX,0,1)).x;
 if(COLOR.r<.5)VERTEX.y+=UV.y*mine_roof_warp(x);
 else{
  float attached=1.0-smoothstep(.12,.82,UV.y*rows-row);
  VERTEX.y+=mix(mine_floor_warp(x),mine_roof_warp(x),attached);
 }
 world=(MODEL_MATRIX*vec4(VERTEX,0,1)).xy;
}
#include "res://assets/shaders/mine_lamp_pool.gdshaderinc"
void fragment(){
 vec2 lo=vec2(0.001,row/rows+0.002),hi=vec2(0.999,(row+1.0)/rows-0.002);
 vec3 rgb=texture(TEXTURE,clamp(UV,lo,hi)).rgb;
 float l=dot(rgb,vec3(0.299,0.587,0.114));
 // The plate supplies rock silhouette, not a second baked light source.
 float rock=smoothstep(0.0015,0.012,l);
 // The end of this source plate is painted in deep shadow. Its nonzero
 // diffuse wall must still receive the real pendant, independently of the
 // baked exposure. Zero pixels keep the overhanging rock silhouette.
 float bay=stopping_bay?(1.0-smoothstep(220.0,420.0,abs(world.x-end_lamp.x))):0.0;
 rock=mix(rock,smoothstep(0.0008,0.003,l),bay);
 float illumination=entry?mine_entry_lamp_pool(world,lamp,angle):mine_lamp_pool(world,lamp,angle);
 illumination*=lamp_strength;
 if(world.x>-2390.0)illumination=max(illumination,(stopping_bay?mine_stop_lamp_pool(world,end_lamp,end_tilt):mine_lamp_pool(world,end_lamp,end_tilt))*end_strength);
 illumination=max(illumination,mine_lamp_pool(world,aux_lamp,aux_angle)*aux_strength);
 illumination=max(illumination,mine_lamp_pool(world,aux2_lamp,aux2_angle));
 float tone=rock*(0.001+(entry?0.46:0.52)*illumination);
 // The outer mouth stays in rock shadow; the working corner remains lit.
 if(entry)tone*=mix(0.06,1.0,smoothstep(entry_left-15.0,entry_left+105.0,world.x));
 float opacity=(entry?smoothstep(entry_left-120.0,entry_left-30.0,world.x):1.0);
 opacity*=smoothstep(seam_left,seam_left+130.0,world.x)*(1.0-smoothstep(fade_out_from,fade_out_to,world.x));
 // Feather the authored wall into the outer rock shadow before the end
 // of its drawing strip; illumination must never expose a rectangular cut.
 float seam=sin(world.y*.025)*6.0;
 if(stopping_bay)opacity*=1.0-smoothstep(rock_end_x-58.0+seam,rock_end_x-10.0+seam,world.x);
 COLOR=vec4(vec3(tone)*canvas_tint.rgb,opacity);
}
