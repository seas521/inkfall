shader_type canvas_item;
render_mode unshaded;
uniform float ink = 0.08;
uniform float softness = 1.5;
uniform float opacity=1.;
uniform float root_mist=0.;
uniform float scroll = 0.;
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*softness;
 float a=texture(TEXTURE,UV).a*.227027;
 a+=(texture(TEXTURE,UV+vec2(d.x*1.384615,0)).a+texture(TEXTURE,UV-vec2(d.x*1.384615,0)).a)*.158108;
 a+=(texture(TEXTURE,UV+vec2(0,d.y*1.384615)).a+texture(TEXTURE,UV-vec2(0,d.y*1.384615)).a)*.158108;
 a+=(texture(TEXTURE,UV+d*3.230769).a+texture(TEXTURE,UV-d*3.230769).a)*.07027;
 float received=.88+.12*sin(FRAGCOORD.x*.007+scroll*.0019+UV.y*2.);
 a*=opacity*(1.-root_mist*smoothstep(.70,1.,UV.y));
 COLOR=vec4(vec3(ink*received),a);
}
