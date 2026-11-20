shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec4 s=texture(TEXTURE,UV);
 float cloth=(1.0-smoothstep(0.28,0.36,UV.y))*smoothstep(0.06,0.12,UV.y);
 // Reflected cloth value, never emissive and never an outline.
 COLOR=vec4(s.rgb*(1.05+cloth*0.65),s.a);
}
