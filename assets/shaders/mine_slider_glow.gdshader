shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float strength=0.0;
void fragment(){
 vec2 q=UV*2.-1.;
 float bloom=exp(-dot(q,q)*5.)*(1.-smoothstep(.55,1.,length(q)));
 COLOR=vec4(vec3(.018)*strength*bloom,bloom*strength);
}
