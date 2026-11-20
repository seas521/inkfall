// Shared projection of the canopy light: backdrop and receiving silhouettes
// sample the same field, including its shadows and slow atmospheric drift.
float valley_mirror(float x){return 1.-abs(mod(x,2.)-1.);}
float valley_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float valley_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(valley_hash(i),valley_hash(i+vec2(1,0)),f.x),mix(valley_hash(i+vec2(0,1)),valley_hash(i+vec2(1,1)),f.x),f.y);}
float valley_light_luminance(sampler2D field,vec2 p,vec2 camera,float time_value){
 vec2 q=vec2((p.x+1250.+camera.x*.105)/2780.,(p.y+110.+camera.y*.12)/927.);
 q.x=valley_mirror(q.x);q.y=clamp(q.y,0.,1.);
 vec2 d=vec2(2.0)/vec2(2172.,724.);
 vec3 c=texture(field,q).rgb*.25;
 c+=(texture(field,q+vec2(d.x,0)).rgb+texture(field,q-vec2(d.x,0)).rgb+texture(field,q+vec2(0,d.y)).rgb+texture(field,q-vec2(0,d.y)).rgb)*.125;
 c+=(texture(field,q+d).rgb+texture(field,q-d).rgb+texture(field,q+vec2(d.x,-d.y)).rgb+texture(field,q+vec2(-d.x,d.y)).rgb)*.0625;
 float l=dot(c,vec3(.299,.587,.114));
 float haze=valley_noise(q*vec2(10.,6.)+vec2(time_value*.007,-time_value*.004));
 l*=1.-smoothstep(.02,.25,l)*haze*.065;
 return min(l*1.22,.7);
}

// Player-plane breakup follows the same projected opening, with broad gaps
// fixed in the world. Three taps suffice for this already defocused light map.
float valley_player_sunlight(sampler2D field,vec2 p,vec2 camera,float time_value,vec2 world){
 vec2 q=vec2((p.x+1250.+camera.x*.105)/2780.,(p.y+110.+camera.y*.12)/927.);
 q.x=valley_mirror(q.x);q.y=clamp(q.y,0.,1.);
 vec2 d=vec2(1.5)/vec2(2172,724);
 vec3 c=texture(field,q).rgb*.5+(texture(field,q+d).rgb+texture(field,q-d).rgb)*.25;
 float strength=smoothstep(.052,.175,dot(c,vec3(.299,.587,.114))*1.22);
 float opening=valley_noise(vec2((world.x+world.y*.795)*.017,world.y*.004)+vec2(time_value*.012,0));
 return strength*mix(.30,1.0,smoothstep(.24,.76,opening));
}
