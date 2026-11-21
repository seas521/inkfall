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
 // Preserve the rare bright apertures for lens bloom; do not flatten all
 // highlights to the same gray ceiling. Most of the image is unchanged.
 return min(l*1.22,.7);
}

// Player-plane breakup follows the same projected opening, with broad gaps
// fixed in the world. Three taps suffice for this already defocused light map.
uniform sampler2D valley_transport_texture : filter_linear,repeat_disable;
uniform float valley_transport_ready=0.0;
float valley_unshadowed_sunlight(sampler2D field,vec2 p,vec2 camera,float time_value,vec2 world){
 vec2 q=vec2((p.x+1250.+camera.x*.105)/2780.,(p.y+110.+camera.y*.12)/927.);
 q.x=valley_mirror(q.x);q.y=clamp(q.y,0.,1.);
 vec2 d=vec2(1.5)/vec2(2172,724);
 vec3 c=texture(field,q).rgb*.5+(texture(field,q+d).rgb+texture(field,q-d).rgb)*.25;
 // Calibrate to the same exposed gray range as the visible shafts. The
 // old threshold suppressed the bank's clearly visible, softer sunlight.
 float strength=smoothstep(.020,.100,dot(c,vec3(.299,.587,.114))*1.22);
 float opening=valley_noise(vec2((world.x+world.y*.795)*.017,world.y*.004)+vec2(time_value*.012,0));
 // The image already contains the major shaded openings. A second strong
 // procedural shadow could cancel a visibly bright shaft on the actor.
 return strength*mix(.65,1.0,smoothstep(.24,.76,opening));
}
float valley_player_sunlight(sampler2D field,vec2 p,vec2 camera,float time_value,vec2 world){
 if(valley_transport_ready>.5)return texture(valley_transport_texture,p/vec2(1280,720)).r;
 return valley_unshadowed_sunlight(field,p,camera,time_value,world);
}
