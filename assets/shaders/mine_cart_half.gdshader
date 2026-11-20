shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool near_half=true;
uniform float lamp_strength=0.0;
uniform float iron_tone=0.01;
uniform float wreck_amount=0.0;
varying float depth;
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 if(wreck_amount>0.0){
  float nose=smoothstep(-0.12,0.65,world.x)*wreck_amount;
  world.x-=0.20*nose;
  world.y-=nose*(0.12+0.045*abs(sin(world.z*11.0)));
  VERTEX=(inverse(MODEL_MATRIX)*vec4(world,1.0)).xyz;
 }
 depth=world.z;
}
void fragment(){
 if(near_half ? depth<0.0 : depth>=0.0)discard;
 ALBEDO=vec3(iron_tone*(0.8+0.8*lamp_strength));
}
