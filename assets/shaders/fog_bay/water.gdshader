shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D landscape : source_color, filter_linear_mipmap;
uniform sampler2D swell : filter_linear;
uniform vec2 camera=vec2(640,360);
uniform float zoom=1.;
uniform float clock=0.;
uniform vec2 boat=vec2(772,550);
uniform float boat_speed=0.;
uniform float afloat=0.;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0,1)).xy;}
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1)),f.x),f.y);}
void fragment(){
 float wave=texture(swell,vec2(clamp((world.x-580.)/2240.,0.,1.),.5)).r;
 float surface=575.+sin(world.x*.035+clock*1.6)*.55-wave;
 float depth=world.y-surface;
 float mask=smoothstep(-.7,1.1,depth)*smoothstep(450.,640.,world.x)*(1.-smoothstep(2480.,2740.,world.x));
 vec2 ripple=vec2(sin(world.y*.17+clock*.8+world.x*.008),cos(world.x*.019-clock*.8))*.00065*smoothstep(0.,60.,depth);
 vec3 beneath=textureLod(screen_tex,SCREEN_UV+ripple,clamp(depth*.025,0.,3.8)).rgb;
 vec2 reflect_uv=vec2(.43+(world.x-1500.)/6700.+ripple.x,.73-abs(depth)*.00034+ripple.y);
 vec3 sky=texture(landscape,reflect_uv).rgb;
 float fresnel=mix(.19,.10,smoothstep(0.,170.,depth));
 float extinction=1.-exp(-max(depth,0.)*.0028);
 vec3 transmitted=mix(beneath,sky*.42,extinction*.65);
 vec3 water=mix(transmitted,sky,fresnel);
 float crinkle=noise(vec2(world.x*.021,world.y*.32-clock*.27));
 water+=vec3((crinkle-.5)*.009);
 float reflected_ribbons=pow(noise(vec2(world.x*.007,world.y*.16-clock*.10)),6.);
 water+=vec3(reflected_ribbons*.075*exp(-max(depth,0.)*.005));
 float dx=world.x-boat.x;
 float wake=exp(-pow((depth-3.)/8.8,2.))*exp(-pow((abs(dx)-69.)/28.,2.));
 float trailing=exp(-pow((depth-8.)/8.,2.))*exp(-pow((dx+sign(boat_speed)*100.)/80.,2.));
 water+=vec3((wake*.34+trailing*.16)*afloat*clamp(abs(boat_speed)/95.,.24,1.));
 COLOR=vec4(water,mask*smoothstep(-2.,25.,depth)*.94);
}
