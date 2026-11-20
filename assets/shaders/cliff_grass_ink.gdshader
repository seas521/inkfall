shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*1.8;
 float l=texture(TEXTURE,UV).r*0.4;
 l+=(texture(TEXTURE,UV+vec2(d.x,0)).r+texture(TEXTURE,UV-vec2(d.x,0)).r+texture(TEXTURE,UV+vec2(0,d.y)).r+texture(TEXTURE,UV-vec2(0,d.y)).r)*0.15;
 float f=fract(UV.x*11.0);
 float sides=smoothstep(0.02,0.30,f)*(1.0-smoothstep(0.70,0.98,f));
 COLOR=vec4(vec3(0.005),(1.0-smoothstep(0.18,0.85,l))*sides);
}
