// Water-plane radiance shared by the immersion and distant surface. World
// projection gives compressed distant detail and slower broad moving slopes.
float river_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float river_noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(river_hash(i),river_hash(i+vec2(1,0)),f.x),mix(river_hash(i+vec2(0,1)),river_hash(i+vec2(1,1)),f.x),f.y);
}
float river_surface_value(vec2 world,float time_value){
 float depth=max(world.y-495.,0.);
 float perspective=log(1.+depth/38.);
 vec2 q=vec2(world.x*.009,perspective*7.);
 float slope=river_noise(q+vec2(time_value*.032,-time_value*.11));
 float detail=river_noise(q*vec2(2.4,1.6)-vec2(time_value*.02,time_value*.04));
 // The plane separates from aerial fog by tone and perspective. No constant
 // white waterline; the narrow bright distance is reflected sky through mist.
 return .024+.055*exp(-depth/105.)+.010*exp(-depth/22.)+(slope-.5)*.003+(detail-.5)*.001;
}
