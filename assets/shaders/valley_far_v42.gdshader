shader_type canvas_item;
render_mode unshaded;
uniform sampler2D forest : source_color, filter_linear, repeat_disable;
uniform float scroll=0.;
uniform float camera_y=0.;
uniform float clock=0.;
float mirror(float x){return 1.-abs(mod(x,2.)-1.);}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(1280.,720.);
 vec2 q=vec2((p.x+1250.+scroll*.105)/2780.,(p.y+110.+camera_y*.12)/927.);
 q.x=mirror(q.x);q.y=clamp(q.y,0.,1.);
 vec2 d=vec2(2.0)/vec2(2172.,724.);
 vec3 c=texture(forest,q).rgb*.25;
 c+=(texture(forest,q+vec2(d.x,0)).rgb+texture(forest,q-vec2(d.x,0)).rgb+texture(forest,q+vec2(0,d.y)).rgb+texture(forest,q-vec2(0,d.y)).rgb)*.125;
 c+=(texture(forest,q+d).rgb+texture(forest,q-d).rgb+texture(forest,q+vec2(d.x,-d.y)).rgb+texture(forest,q+vec2(-d.x,d.y)).rgb)*.0625;
 float l=dot(c,vec3(.299,.587,.114));
 // Only luminous air carries subtle drifting mist. Trunk shadows stay shadows.
 float haze=noise(q*vec2(10.,6.)+vec2(clock*.007,-clock*.004));
 l*=1.-smoothstep(.02,.25,l)*haze*.065;
 COLOR=vec4(vec3(min(l*1.22,.7)),1.);
}
