// Shared incident field for receiving silhouettes and near air. These are
// authored Inkfall sources, not a claim about LIMBO's renderer.
uniform int chapter_light_count=0;
uniform vec4 chapter_lights[12]; // world x/y, reach, energy
uniform vec2 chapter_light_axes[12];
uniform float chapter_light_canopy[12]; // individual outdoor sources, not lamps
uniform int chapter_barrier_count=0;
uniform vec4 chapter_barriers[4]; // left/right, platform y, penumbra
uniform float chapter_canopy=0.0;
uniform float chapter_light_clock=0.0;
float chapter_canopy_mask(vec2 world){
 if(chapter_canopy<=0.0)return 1.0;
 float opening=valley_noise(vec2((world.x+world.y*.62)*.015,world.y*.003)+vec2(chapter_light_clock*.007,0));
 return mix(.12,1.0,smoothstep(.27,.76,opening));
}
float chapter_source_energy(vec2 world,int index,float canopy_mask){
 vec4 source=chapter_lights[index];vec2 delta=world-source.xy;
 float reach2=dot(delta,delta)/max(source.z*source.z,1.0);
 if(reach2>1.21)return 0.0;
 vec2 axis=chapter_light_axes[index];
 float along=dot(delta,axis);
 float across=abs(delta.x*axis.y-delta.y*axis.x);
 if(along< -12.0 || across>1.30*max(along,26.0))return 0.0;
 float cone=(1.0-smoothstep(.35,1.30,across/max(along,26.0)))*smoothstep(-12.0,25.0,along);
 float leaf=chapter_light_canopy[index];
 float outside=1.0-smoothstep(-3170.0,-3020.0,world.x)*smoothstep(-3540.0,-3450.0,world.y);
 float value=source.w*cone*exp(-reach2*1.6)*(1.0-smoothstep(.6724,1.21,reach2));
 value*=mix(1.0,canopy_mask*outside,leaf);
 if(value<.0001)return 0.0;
 for(int j=0;j<4;j++){
  if(j>=chapter_barrier_count)break;
  vec4 barrier=chapter_barriers[j];
  if(source.y<barrier.z-3.0 && world.y>barrier.z+3.0){
   float t=(barrier.z-source.y)/max(world.y-source.y,.001);
   float x=mix(source.x,world.x,t);
   float block=smoothstep(barrier.x-barrier.w,barrier.x+barrier.w,x)*(1.0-smoothstep(barrier.y-barrier.w,barrier.y+barrier.w,x));
   value*=1.0-block*.96;
  }
 }
 return value;
}
vec3 chapter_incident(vec2 world){
 vec2 direction_sum=vec2(0.0);float energy=0.0;
 float canopy_mask=chapter_canopy_mask(world);
 for(int i=0;i<12;i++){
  if(i>=chapter_light_count)break;
  float value=chapter_source_energy(world,i,canopy_mask);
  direction_sum+=normalize(chapter_lights[i].xy-world+vec2(.0001))*value;
  energy+=value;
 }
 return vec3(direction_sum,min(energy,1.0));
}
