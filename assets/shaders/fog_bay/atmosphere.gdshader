shader_type canvas_item;
render_mode unshaded;
uniform sampler2D landscape : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 camera = vec2(640.,360.);
uniform float zoom = 1.;
uniform float clock = 0.;
float n(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(n(i),n(i+vec2(1,0)),f.x),mix(n(i+vec2(0,1)),n(i+vec2(1)),f.x),f.y);}
void fragment(){
 vec2 world=(UV-.5)*vec2(1280,720)/zoom+camera;
 // Same photographic valley in every camera position. No region crossfade.
 vec2 uv=vec2(.43+(world.x-1500.)/6700.,.73+(world.y-360.)/1700.);
 vec3 photo=textureLod(landscape,uv,2.4).rgb;
 float fog=exp(-pow((world.y-450.)/300.,2.))*.28;
 float drift=noise(vec2(world.x*.002-clock*.014,world.y*.006+clock*.009));
 photo=mix(photo,vec3(.48),fog*(.75+drift*.25));
 // Lake recedes into fog at the far shore, not a separate opaque background slab.
 float lake=smoothstep(495.,561.,world.y);
 vec2 ruv=vec2(.43+(world.x-1500.)/6700.,.73-abs(world.y-575.)*.00034);
 vec3 reflection=texture(landscape,ruv).rgb;
 photo=mix(photo,reflection*.80,lake*.80);
 // Broad reflected openings are stretched along the plane; no ring texture.
 float shimmer=noise(vec2(world.x*.006,world.y*.13-clock*.08));
 float streak=pow(shimmer,5.)*.055*lake*exp(-max(world.y-575.,0.)*.004);
 photo+=vec3(streak);
 photo+=vec3(.025*exp(-pow((world.y-570.)/25.,2.))*noise(vec2(world.x*.004,2.)));
 COLOR=vec4(photo,1.);
}
