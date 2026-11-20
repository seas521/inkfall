shader_type canvas_item;
render_mode unshaded;
void fragment(){
 float a=texture(TEXTURE,UV).a;
 COLOR=vec4(vec3(0.002),smoothstep(0.12,0.55,a));
}
