shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 float v=dot(c.rgb,vec3(.299,.587,.114));
 float ink=.0004+min(v*.0012,.0004);
 COLOR=vec4(vec3(ink),smoothstep(.06,.95,c.a));
}
