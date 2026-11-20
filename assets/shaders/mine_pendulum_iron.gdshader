shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*.65;
 vec4 c=texture(TEXTURE,UV)*.5;
 c+=texture(TEXTURE,UV+vec2(d.x,d.y))*.125;
 c+=texture(TEXTURE,UV-d)*.125;
 c+=texture(TEXTURE,UV+vec2(-d.x,d.y))*.125;
 c+=texture(TEXTURE,UV+vec2(d.x,-d.y))*.125;
 float value=dot(c.rgb,vec3(.299,.587,.114));
 COLOR=vec4(vec3(.00012+min(value*value*.020,.0013)),smoothstep(.10,.95,c.a));
}
