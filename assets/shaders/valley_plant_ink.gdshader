shader_type canvas_item;
render_mode unshaded;
uniform bool grass_key=false;
uniform float tone=.0003;
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 float coverage=grass_key?smoothstep(.10,.83,1.0-dot(c.rgb,vec3(.299,.587,.114))):smoothstep(.06,.94,c.a);
 COLOR=vec4(vec3(tone),coverage*COLOR.a);
}
