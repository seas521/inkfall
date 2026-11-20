shader_type canvas_item;
render_mode unshaded;
uniform float tone=.025;
uniform float strength=.7;
uniform float softness=2.;
uniform float root_haze=.35;
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*softness;
 float a=texture(TEXTURE,UV).a*.25;
 a+=(texture(TEXTURE,UV+vec2(d.x,0)).a+texture(TEXTURE,UV-vec2(d.x,0)).a+texture(TEXTURE,UV+vec2(0,d.y)).a+texture(TEXTURE,UV-vec2(0,d.y)).a)*.125;
 a+=(texture(TEXTURE,UV+d).a+texture(TEXTURE,UV-d).a+texture(TEXTURE,UV+vec2(d.x,-d.y)).a+texture(TEXTURE,UV+vec2(-d.x,d.y)).a)*.0625;
 // Alpha only: eliminate generated bark, pale contour and translucent halo.
 a=smoothstep(.08,.92,a)*strength;
 a*=1.-root_haze*smoothstep(.64,.94,UV.y);
 COLOR=vec4(vec3(tone),a);
}
